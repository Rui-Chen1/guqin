#!/usr/bin/env python3
"""从真实琴曲录音（assets/audio/*.mp3）提取音高序列，生成「智能演奏辅助」的标准谱。

流程：
  1. afconvert 将 mp3 解码为 22.05kHz 单声道 PCM（本机无 ffmpeg/soundfile）。
  2. YIN 算法（FFT 加速的自相关差分函数 + 累积均值归一化）逐帧估计基频。
  3. 中值滤波去毛刺 → 按半音量化 → 按起音切分音符，得到 (起始ms, MIDI, 时值ms)。
  4. 由脉冲拟合残差自动判定整曲为散板还是入调，决定记谱是否需要小节线。
  5. 写出 lib/data/practice_scores.dart（供 practice_data.dart 使用）。

这样标准谱的旋律与时值均直接来自真人录音本身，练习长度与该曲实际时长一致；
散板与否亦由录音自身的律动特征自动判出，无需人工标注。

用法： python3 gen_practice.py
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(ROOT, "assets", "audio")
OUT_DART = os.path.join(ROOT, "lib", "data", "practice_scores.dart")
TMP = "/tmp/gq_practice"

SR = 22050
FRAME = 1024
HOP = 256
FMIN = 62.0
FMAX = 1400.0
YIN_THRESH = 0.10
YIN_MAX = 0.60      # 归一化差值高于此值视为无音高
MIN_DUR_MS = 50.0  # 滚拂等快速指法需捕捉短音
MERGE_GAP_MS = 40.0  # 减小合并间隙以保留快速连奏
MIDI_LO = 26
MIDI_HI = 98

# 曲目清单（与资料库一致）：slug、曲名、难度、提示、BPM 需与 survey 结果对齐
PIECES = [
    ("liushui", "流水", "精研", "天闻阁琴谱 · 七十二滚拂"),
    ("shenrenchang", "神人畅", "进阶", "西麓堂琴统 · 音节古峭"),
    ("meihua", "梅花三弄", "进阶", "泛音三弄 · 傲雪凌霜"),
    ("pingsha", "平沙落雁", "入门", "古音正宗 · 雁阵起落"),
    ("yangguan", "阳关三叠", "入门", "王维词 · 一唱三叹"),
    ("peilan", "佩兰", "精研", "毛敏仲 · 纫秋兰以为佩"),
    ("jiukuang", "酒狂", "入门", "阮籍 · 三拍子摇曳"),
    ("kongziduyi", "孔子读易", "进阶", "天闻阁琴谱 · 韦编三绝"),
    ("zuiyu", "醉渔唱晚", "进阶", "陆龟蒙 · 渔翁醉歌"),
    ("qiufengci", "秋风词", "入门", "李白词 · 秋夜怀人"),
]


def decode(slug):
    os.makedirs(TMP, exist_ok=True)
    wav = os.path.join(TMP, slug + ".wav")
    src = os.path.join(AUDIO, slug + ".mp3")
    if not os.path.exists(wav) or os.path.getmtime(wav) < os.path.getmtime(src):
        subprocess.run(
            ["/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", "-c", "1", src, wav],
            check=True,
            capture_output=True,
        )
    with wave.open(wav, "rb") as f:
        raw = f.readframes(f.getnframes())
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    return x


def yin_f0(x):
    """逐帧 YIN 基频估计，返回 (f0 数组, rms 数组)。无音高帧 f0 为 0。"""
    tau_min = max(2, int(SR / FMAX))
    tau_max = min(FRAME - 2, int(SR / FMIN))
    n = 1 + max(0, (len(x) - FRAME) // HOP)
    if n <= 0:
        return np.zeros(0), np.zeros(0)

    starts = np.arange(n) * HOP
    idx = starts[:, None] + np.arange(FRAME)[None, :]
    frames = x[idx]
    rms = np.sqrt((frames ** 2).mean(axis=1))

    nfft = 1 << int(np.ceil(np.log2(FRAME * 2)))
    taus = np.arange(tau_max + 1)
    cm_all = np.empty((n, tau_max + 1))

    chunk = 2048
    for s in range(0, n, chunk):
        e = min(n, s + chunk)
        f = frames[s:e]
        m = f.shape[0]
        sp = np.fft.rfft(f, nfft, axis=1)
        acf = np.fft.irfft(sp * np.conj(sp), nfft, axis=1)[:, : tau_max + 1]
        cs = np.cumsum(f ** 2, axis=1)
        total = cs[:, -1][:, None]
        suffix = total - np.concatenate([np.zeros((m, 1)), cs[:, :-1]], axis=1)
        suffix = suffix[:, : tau_max + 1]
        d = np.maximum(suffix[:, 0][:, None] + suffix - 2.0 * acf, 0.0)
        cum = np.cumsum(d, axis=1)
        cm = d * taus[None, :] / np.maximum(cum, 1e-12)
        cm[:, 0] = 1.0
        cm_all[s:e] = cm

    band = cm_all[:, tau_min : tau_max + 1]
    below = band < YIN_THRESH
    has = below.any(axis=1)
    tau = np.where(
        has,
        tau_min + below.argmax(axis=1),
        tau_min + band.argmin(axis=1),
    )
    clarity = band[np.arange(n), tau - tau_min]

    # 抛物线插值细化
    t = np.clip(tau, 1, tau_max - 1)
    a = cm_all[np.arange(n), t - 1]
    b = cm_all[np.arange(n), t]
    c = cm_all[np.arange(n), t + 1]
    denom = a - 2 * b + c
    shift = np.where(np.abs(denom) < 1e-12, 0.0, 0.5 * (a - c) / denom)
    tau_f = np.clip(t + np.clip(shift, -1.0, 1.0), tau_min, tau_max)

    f0 = np.where((clarity < YIN_MAX) & (rms > 0), SR / tau_f, 0.0)
    return f0, rms


def median_filter(vals, valid, win=5):
    out = vals.copy()
    half = win // 2
    for i in range(len(vals)):
        lo = max(0, i - half)
        hi = min(len(vals), i + half + 1)
        window = vals[lo:hi][valid[lo:hi]]
        if window.size >= max(3, half + 1):
            out[i] = float(np.median(window))
    return out


def to_notes(x):
    f0, rms = yin_f0(x)
    if f0.size == 0:
        return []

    floor = max(0.005, float(np.percentile(rms, 90)) * 0.05)
    valid = (f0 > 0) & (rms > floor)
    if valid.sum() < 16:
        return []

    midi = np.zeros(f0.size)
    midi[valid] = 69.0 + 12.0 * np.log2(f0[valid] / 440.0)
    midi = median_filter(midi, valid)

    frame_ms = HOP / SR * 1000.0
    notes = []
    i = 0
    n = f0.size
    while i < n:
        if not valid[i] or midi[i] <= 0:
            i += 1
            continue
        base = round(midi[i])
        j = i
        while j + 1 < n and valid[j + 1] and abs(midi[j + 1] - base) < 0.6:
            j += 1
        t0 = i * frame_ms
        t1 = (j + 1) * frame_ms
        if t1 - t0 >= MIN_DUR_MS and MIDI_LO <= base <= MIDI_HI:
            notes.append([t0, base, t1 - t0])
        i = j + 1

    # 合并同音高、间隔很小的相邻音（录音余韵造成的碎裂）
    merged = []
    for nt in notes:
        if merged and nt[1] == merged[-1][1] and nt[0] - (merged[-1][0] + merged[-1][2]) <= MERGE_GAP_MS:
            prev = merged[-1]
            prev[2] = nt[0] + nt[2] - prev[0]
        else:
            merged.append(nt)

    # 落到毫秒整数，并保证严格递增（避免渲染时的重叠）
    out = []
    last = -1
    for t0, m, dur in merged:
        ti = int(round(t0))
        if ti <= last:
            ti = last + 1
        last = ti
        out.append((ti, int(m), int(round(dur))))
    return out


def estimate_bpm(notes):
    """对起音脉冲串做自相关，取 40~112 BPM 区间内的主周期作为拍速。"""
    if len(notes) < 8:
        return 60
    onsets = np.array([n[0] for n in notes], dtype=float)
    step = 10.0
    n = int(onsets.max() / step) + 2
    train = np.zeros(n)
    for t in onsets:
        train[int(t / step)] += 1.0
    train -= train.mean()
    spec = np.fft.rfft(train, 2 * n)
    acf = np.fft.irfft(spec * np.conj(spec))[:n]
    lag1 = int(round(60000.0 / 112.0 / step))
    lag2 = int(round(60000.0 / 40.0 / step))
    seg = acf[lag1 : lag2 + 1]
    if seg.size == 0 or seg.max() <= 0:
        return 60
    peak = float(seg.max())
    lag = lag1 + int(np.argmax(seg >= peak * 0.85))  # 取达到主峰 85% 的最早周期
    return int(round(60000.0 / (lag * step)))


# 散板（自由节拍）判定参数
RUBATO_BUCKET_MS = 20000.0  # 逐段估计律动规整度的分桶长度
RUBATO_MIN_NOTES = 4        # 参与估计的分桶最少音数
RUBATO_RESID = 0.22         # 脉冲拟合残差阈值：低于此值视为有稳定拍点（入调）


def pulse_residual(notes):
    """度量全曲的「律动规整度」：把各段起音间隔归整到局部基本拍的整数倍，
    取残差的中位数。残差越小说明越接近恒定拍点（入调），越大说明越自由（散板）。

    古琴绝大多数琴曲无恒定拍点，散板本身即是其本相；该指标用于在
    「以实录驱动记谱」的前提下，自动区分「入调（有稳定律动）」与「散板」，
    从而决定记谱是否需要小节线。
    """
    if len(notes) < 2 * RUBATO_MIN_NOTES:
        return None
    onsets = np.array([t for t, _, _ in notes], dtype=float)
    ioi = np.diff(onsets)
    resid = []
    b = 0.0
    end = float(onsets[-1])
    while b < end:
        m = (onsets[:-1] >= b) & (onsets[:-1] < b + RUBATO_BUCKET_MS)
        b += RUBATO_BUCKET_MS
        if m.sum() < RUBATO_MIN_NOTES:
            continue
        seg = ioi[m]
        short = seg[seg <= np.median(seg) * 1.6]  # 长气口不参与基本拍估计
        base = float(np.median(short)) if short.size else float(np.median(seg))
        if base <= 1.0:
            continue
        r = seg / base
        resid.append(float(np.median(np.abs(r - np.maximum(1.0, np.round(r))))))
    return float(np.median(resid)) if resid else None


def main():
    built = []
    for slug, title, level, hint in PIECES:
        x = decode(slug)
        total = len(x) / SR
        notes = to_notes(x)
        bpm = estimate_bpm(notes)
        resid = pulse_residual(notes)
        rubato = resid is None or resid > RUBATO_RESID
        span = notes[-1][0] / 1000.0 if notes else 0.0
        built.append((slug, title, level, hint, bpm, notes, rubato))
        print(f"  {slug:14s} {title:6s} 音频 {total:6.1f}s  提取 {len(notes):5d} 音  "
              f"末音 @ {span:6.1f}s  BPM {bpm}  "
              f"律动规整度 {resid if resid is None else round(resid, 3)}  "
              f"{'散板' if rubato else '入调'}")
        if notes:
            head = "  ".join(f"{n[1]}" for n in notes[:14])
            print(f"      首音 MIDI: {head}")

    lines = [
        "// 由 gen_practice.py 从真实琴曲录音自动提取生成，请勿手改。",
        "// 每个音为三元组：(起始毫秒, MIDI 音高, 时值毫秒)，起始时刻相对本曲开头。",
        "// rubato 为整曲律动判定：由录音的脉冲拟合残差自动判出，",
        "// 琴曲多为散板（无恒定拍点），此时记谱不设小节线。",
        "",
        "import 'practice_data.dart';",
        "",
        "List<TargetNote> _notes(List<int> flat) {",
        "  final out = <TargetNote>[];",
        "  for (var i = 0; i + 2 < flat.length; i += 3) {",
        "    out.add(TargetNote(flat[i], flat[i + 1], flat[i + 2]));",
        "  }",
        "  return out;",
        "}",
        "",
        "/// 十首琴曲的标准谱（取自真人演奏录音的音高与时值，散板与否自动判定）。",
        "final List<PracticePhrase> kPracticePhrases = [",
    ]
    for slug, title, level, hint, bpm, notes, rubato in built:
        lines.append("  PracticePhrase(")
        lines.append(f"    id: '{slug}',")
        lines.append(f"    title: '《{title}》',")
        lines.append(f"    level: '{level}',")
        lines.append(f"    hint: '{hint}',")
        lines.append(f"    baseBpm: {bpm},")
        lines.append(f"    rubato: {'true' if rubato else 'false'},")
        lines.append("    notes: _notes(const [")
        flat = []
        for t0, m, dur in notes:
            flat.extend((t0, m, dur))
        for k in range(0, len(flat), 21):
            lines.append("      " + ", ".join(str(v) for v in flat[k : k + 21]) + ",")
        lines.append("    ]),")
        lines.append("  ),")
    lines.append("];")
    lines.append("")

    with open(OUT_DART, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    size = os.path.getsize(OUT_DART) / 1024.0
    total_notes = sum(len(b[5]) for b in built)
    print(f"\n已写出 {OUT_DART}  ({size:.0f} KB, {total_notes} 个音)")


if __name__ == "__main__":
    main()

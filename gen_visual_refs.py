#!/usr/bin/env python3
"""从 assets/audio/sfx 的单音音效中提取「散音 / 按音 / 泛音」三种音色的真实谐波包络。

琴音可视化需要把麦克风实时采到的音与三种音色比对，这里先从项目自带的单音音效
（gen_sfx.py 生成的 open_i / press_i / harm_i）中量出参考指纹：

  1. afconvert 把 m4a 解码为 44.1kHz 单声道 WAV；
  2. 截取起振后 30~280ms 的稳定段（避开指甲触弦瞬态），加 Hann 窗后做 FFT；
  3. 已知该音效的基频（正调七弦散音 C2 D2 F2 G2 A2 C3 D3，泛音取高八度），
     在 k·f0 附近取谱峰，得到第 1~16 次谐波的相对幅度；
  4. 七根弦各自归一后取平均，再峰值归一，得到该音色的 16 维谐波包络。

输出：lib/features/visualize/harmonic_references.dart
"""
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = os.path.dirname(os.path.abspath(__file__))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
OUT_DART = os.path.join(ROOT, "lib", "features", "visualize", "harmonic_references.dart")

SR = 44100
NFFT = 16384
WINDOW_START = 0.030   # 跳过指甲触弦瞬态
WINDOW_LEN = 0.250
HARMONICS = 16

# 正调（F 调）七弦散音频率：C2 D2 F2 G2 A2 C3 D3
STRING_FREQS = [65.41, 73.42, 87.31, 98.00, 110.00, 130.81, 146.83]

KINDS = [("open", "散音", 1.0), ("press", "按音", 1.0), ("harm", "泛音", 2.0)]


def decode(path, out):
    r = subprocess.run(
        ["/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", "-c", "1", path, out],
        capture_output=True,
    )
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode(errors="ignore").strip())


def read_wav(path):
    with wave.open(path, "rb") as f:
        raw = f.readframes(f.getnframes())
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0


def harmonic_profile(x, f0):
    """返回 (16 维谐波幅度, 谱心比, 高频占比, 衰减 20dB 时间)。"""
    a = int(WINDOW_START * SR)
    b = a + int(WINDOW_LEN * SR)
    seg = x[a:b]
    if seg.size < NFFT:
        seg = np.pad(seg, (0, NFFT - seg.size))
    spec = np.abs(np.fft.rfft(seg[:NFFT] * np.hanning(NFFT), NFFT))
    freqs = np.fft.rfftfreq(NFFT, 1.0 / SR)
    df = SR / NFFT

    out = np.zeros(HARMONICS)
    for k in range(1, HARMONICS + 1):
        fk = k * f0
        if fk >= SR / 2:
            break
        lo = max(0, int((fk - fk * 0.03) / df))
        hi = min(spec.size, int((fk + fk * 0.03) / df) + 1)
        if hi > lo:
            out[k - 1] = float(spec[lo:hi].max())

    # 谱心比（谱心 / 基频）：与音高无关的「亮度」指标
    lo = int(f0 * 0.9 / df)
    band = spec[lo:]
    bfreq = freqs[lo:]
    total = float(np.sum(band ** 2))
    centroid_ratio = float(np.sum(bfreq * band ** 2) / total / f0) if total > 0 else 0.0

    # 高频占比：4 倍基频以上的能量占 (0.9·f0 以上) 总能量的比例
    hi_mask = bfreq >= 4 * f0
    high_ratio = float(np.sum(band[hi_mask] ** 2) / total) if total > 0 else 0.0

    # 衰减 20dB 所需时间（10ms 帧的 RMS 包络）
    win = int(0.01 * SR)
    n = x.size // win
    env = np.sqrt((x[: n * win].reshape(n, win) ** 2).mean(axis=1))
    if env.size == 0 or env.max() <= 0:
        decay_ms = 0.0
    else:
        peak = int(np.argmax(env))
        thr = env[peak] * 0.1
        after = np.nonzero(env[peak:] < thr)[0]
        decay_ms = float(after[0] * 10) if after.size else float((n - peak) * 10)

    return out, centroid_ratio, high_ratio, decay_ms


def main():
    af = shutil.which("afconvert") or "/usr/bin/afconvert"
    if not os.path.exists(af):
        print("未找到 afconvert", file=sys.stderr)
        return 1

    tmp = tempfile.mkdtemp(prefix="guqin_refs_")
    profiles = []
    labels = []
    metrics = []
    try:
        for kind, label, octave in KINDS:
            acc = np.zeros(HARMONICS)
            c_ratio = h_ratio = d_ms = 0.0
            used = 0
            for i, f in enumerate(STRING_FREQS):
                src = os.path.join(SFX, f"{kind}_{i}.m4a")
                if not os.path.exists(src):
                    print(f"[skip] 缺少 {src}", file=sys.stderr)
                    continue
                wav = os.path.join(tmp, f"{kind}_{i}.wav")
                decode(src, wav)
                prof, cr, hr, dm = harmonic_profile(read_wav(wav), f * octave)
                peak = prof.max()
                if peak <= 0:
                    continue
                acc += prof / peak
                c_ratio += cr
                h_ratio += hr
                d_ms += dm
                used += 1
            if used == 0:
                print(f"[fail] {label} 无可用样本", file=sys.stderr)
                return 1
            avg = acc / used
            avg /= avg.max()
            profiles.append(avg)
            labels.append(label)
            metrics.append((c_ratio / used, h_ratio / used, d_ms / used))
            head = "  ".join(f"{v:.3f}" for v in avg[:8])
            print(f"  {label}（{used} 根弦平均）")
            print(f"    前 8 次谐波：{head}")
            print(f"    谱心比 {c_ratio / used:.2f} · 高频占比 {h_ratio / used * 100:.1f}%"
                  f" · 衰减20dB {d_ms / used:.0f}ms")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    lines = [
        "// 由 gen_visual_refs.py 从 assets/audio/sfx 的单音音效中提取生成，请勿手改。",
        "//",
        "// 三种音色的实测声学指纹，供琴音可视化把实时采集的琴音与参考对照。",
        "// 特征取自起振后 30~280ms 的稳定段，七根弦取平均。",
        "",
        "class TimbreReference {",
        "  const TimbreReference({",
        "    required this.name,",
        "    required this.envelope,",
        "    required this.centroidRatio,",
        "    required this.highRatio,",
        "    required this.decayMs,",
        "  });",
        "",
        "  /// 音色名。",
        "  final String name;",
        "",
        "  /// 16 维谐波包络：第 n 项为第 (n+1) 次谐波的相对幅度，峰值归一为 1。",
        "  final List<double> envelope;",
        "",
        "  /// 谱心 / 基频——与音高无关的「亮度」指标。",
        "  final double centroidRatio;",
        "",
        "  /// 4 倍基频以上的能量占比（0~1）。",
        "  final double highRatio;",
        "",
        "  /// 起振后衰减 20dB 所需时间（毫秒），越小衰减越快。",
        "  final double decayMs;",
        "}",
        "",
        "const List<TimbreReference> kTimbreReferences = [",
    ]
    for label, prof, (cr, hr, dm) in zip(labels, profiles, metrics):
        body = ", ".join(f"{v:.4f}" for v in prof)
        lines.append("  TimbreReference(")
        lines.append(f"    name: '{label}',")
        lines.append(f"    envelope: [{body}],")
        lines.append(f"    centroidRatio: {cr:.3f},")
        lines.append(f"    highRatio: {hr:.4f},")
        lines.append(f"    decayMs: {dm:.0f},")
        lines.append("  ),")
    lines.append("];")
    lines.append("")

    os.makedirs(os.path.dirname(OUT_DART), exist_ok=True)
    with open(OUT_DART, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"\n已写出 {OUT_DART}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

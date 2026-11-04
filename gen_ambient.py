#!/usr/bin/env python3
"""程序化合成 3 段「无缝循环」的环境氛围音效（离线资源）。

供古琴 App 在弹奏 / 试听时铺底，营造琴境：

  · amb_forest —— 山林：松风。带通噪声为底，叠缓慢起伏的阵风，混极轻溪涧流水；
  · amb_study  —— 书斋：檐雨。宽带噪声做雨底，叠随机分布的雨滴打檐瞬态；
  · amb_night  —— 月夜：夜虫。极低电平底噪，叠周期性虫鸣（多声短促高频脉冲），
                  再混很轻的低频水声。

工程约定与 gen_sfx.py 完全一致：numpy 合成、SR=44100 单声道、标准库 wave 写
16bit PCM、afconvert 转 m4a、临时目录放中间 wav 并清理；单个文件失败不影响其余。

无缝循环做法：每段先生成 26 秒素材，再把「末尾 2 秒」与「开头 2 秒」做等功率
交叉淡化（sin/cos 曲线，非线性），得到 24 秒输出。所有随机成分（雨滴、虫鸣、
阵风起伏）都一并参与交叉淡化，因此首尾自然衔接，循环播放无爆音、无忽然静音。

输出：assets/audio/sfx/amb_forest.m4a / amb_study.m4a / amb_night.m4a
"""

import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, 'assets', 'audio', 'sfx')

TOTAL_SEC = 26.0   # 生成素材时长
OUT_SEC = 24.0     # 成品时长
XFADE_SEC = 2.0    # 首尾等功率交叉淡化长度
PEAK = 0.6         # 成品峰值（背景音，留足余量与人声/琴声叠加）
FADE_SEC = 0.05    # 起始淡入，消除第一次播放的爆音


# ---------------------------------------------------------------- 基础工具

def bandpass(x, lo, hi, order=1):
    """零相位带通：lo / hi 为 -6dB 拐点频率（order 越大边沿越陡）。"""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    f = np.maximum(f, 1e-6)
    hp = (f / lo) ** order / (1.0 + (f / lo) ** order)   # 低于 lo 抑制
    lp = 1.0 / (1.0 + (f / hi) ** order)                 # 高于 hi 抑制
    spec *= hp * lp
    return np.fft.irfft(spec, len(x))


def smooth(x, win_sec):
    """滑动平均，用作慢速随机游走 / 缓慢起伏。"""
    k = max(1, int(win_sec * SR))
    return np.convolve(x, np.ones(k) / k, mode='same')


def norm(x, peak=1.0):
    """按峰值归一化到指定幅度。"""
    m = float(np.max(np.abs(x))) or 1.0
    return x / m * peak


def add_pulse(buf, start, pulse):
    """把短脉冲叠加到缓冲区的指定起始位置（越界自动裁剪）。"""
    i = int(start * SR)
    if i < 0:
        pulse = pulse[-i:]
        i = 0
    end = min(len(buf), i + len(pulse))
    if end <= i:
        return
    buf[i:end] += pulse[:end - i]


def seamless_loop(x, out_sec=OUT_SEC, xf_sec=XFADE_SEC):
    """等功率交叉淡化，把 (out_sec + xf_sec) 秒素材折成 out_sec 秒无缝循环。

    交叉段用 sin/cos 曲线：cos²+sin² = 1，功率恒定。
    交叉段开头取自素材 out_sec 处（正是尾部 x[out_sec-1] 的自然延续），
    因此循环接点连续；交叉段末尾平滑过渡到 x[0]，衔接同样连续。
    """
    n_out = int(out_sec * SR)
    n_xf = int(xf_sec * SR)
    p = np.arange(n_xf) / n_xf
    a = np.cos(p * np.pi / 2.0)   # 末尾 2 秒权重：1 → 0
    b = np.sin(p * np.pi / 2.0)   # 开头 2 秒权重：0 → 1
    head = x[n_out:n_out + n_xf] * a + x[:n_xf] * b
    return np.concatenate([head, x[n_xf:n_out]])


# ---------------------------------------------------------------- 三段氛围

def gen_forest(rng, nsec):
    """山林：松风。带通噪声 + 缓慢阵风起伏 + 极轻溪涧流水。"""
    n = int(nsec * SR)
    t = np.arange(n) / SR

    # 阵风包络：多条 4–9 秒周期低频正弦 + 慢速随机游走，制造呼吸感
    env = np.full(n, 0.30)
    for _ in range(3):
        per = rng.uniform(4.0, 9.0)
        env += 0.24 * (0.5 + 0.5 * np.sin(2.0 * np.pi * t / per
                                               + rng.uniform(0.0, 2.0 * np.pi)))
    walk = smooth(rng.normal(0.0, 1.0, n), 0.9)
    walk /= (float(np.max(np.abs(walk))) or 1.0)
    env += 0.16 * (0.5 + 0.5 * walk)
    env -= env.min()
    env = 0.22 + 0.78 * env / (float(env.max()) or 1.0)

    # 松风主体：宽带带通噪声（中心约 400–900Hz，带宽较宽）+ 低频体感层
    body = bandpass(rng.normal(0.0, 1.0, n), 250.0, 1200.0, order=1)
    body += 0.7 * bandpass(rng.normal(0.0, 1.0, n), 120.0, 450.0, order=1)
    body *= env

    # 松针摩擦的高频嘶声，随阵风增强
    hiss = bandpass(rng.normal(0.0, 1.0, n), 1300.0, 4200.0, order=1) \
        * (0.05 + 0.10 * env)

    # 极轻的溪涧流水：高频段噪声，电平更低，带缓慢潺潺起伏
    stream = bandpass(rng.normal(0.0, 1.0, n), 2200.0, 6500.0, order=1)
    stream *= 0.09 * (0.85 + 0.15 * np.sin(2.0 * np.pi
                                          * rng.uniform(0.7, 1.4) * t
                                          + rng.uniform(0.0, 2.0 * np.pi)))

    return body + hiss + stream


def gen_study(rng, nsec):
    """书斋：檐雨。宽带噪声雨底 + 随机分布的雨滴打檐瞬态。"""
    n = int(nsec * SR)

    # 雨底：多段滤波噪声叠加（高频为主的平稳沙沙声）
    bed = bandpass(rng.normal(0.0, 1.0, n), 800.0, 9000.0, order=1)
    bed += 0.5 * bandpass(rng.normal(0.0, 1.0, n), 300.0, 3000.0, order=1)
    bed += 0.3 * bandpass(rng.normal(0.0, 1.0, n), 200.0, 800.0, order=1)
    bed = norm(bed, 0.45)   # 雨底相对电平，给雨滴留出动态空间

    sig = bed.copy()

    # 雨滴打檐：每秒 15–40 滴，随机时间 / 频率 / 强度 / 衰减
    n_drops = int(rng.uniform(15.0, 40.0) * nsec)
    for _ in range(n_drops):
        tau = rng.uniform(0.030, 0.080)          # 指数衰减 30–80ms
        f = rng.uniform(800.0, 4000.0)           # 高频随机音高
        amp = rng.uniform(0.15, 1.0)             # 强度随机
        m = int(tau * 6.0 * SR)
        tt = np.arange(m) / SR
        pulse = amp * np.exp(-tt / tau) * np.sin(2.0 * np.pi * f * tt)
        # 极短的击打噪声瞬态，让「打檐」更脆
        m2 = int(0.004 * SR)
        pulse[:m2] += amp * 0.5 * (rng.random(m2) - 0.5) \
            * np.exp(-np.arange(m2) / (0.0015 * SR))
        add_pulse(sig, rng.uniform(0.0, nsec), pulse)

    return sig


def _cricket_pulse(f0, dur, fm_ratio, rng):
    """单声虫鸣：短促高频脉冲，带轻微调频 / 颤音。"""
    m = max(1, int(dur * SR))
    tt = np.arange(m) / SR
    env = np.sin(np.pi * tt / dur) ** 1.5                       # 快起快落
    vib = fm_ratio * f0 * np.sin(2.0 * np.pi * rng.uniform(20.0, 40.0) * tt)
    phase = 2.0 * np.pi * np.cumsum(f0 + vib) / SR              # 轻微调频
    return env * np.sin(phase)


def gen_night(rng, nsec):
    """月夜：夜虫。极低电平底噪 + 周期虫鸣（多声脉冲）+ 很轻的低频水声。"""
    n = int(nsec * SR)

    # 虫声底噪 + 低频水声（恒定存在，保证循环接点始终有底噪、不会静音）
    sig = bandpass(rng.normal(0.0, 1.0, n), 2000.0, 8000.0, order=1) * 0.060
    sig += bandpass(rng.normal(0.0, 1.0, n), 100.0, 500.0, order=1) * 0.055

    # 周期性虫鸣：每 0.8–2.2 秒一组，组内 3–5 声、间隔 120–200ms；
    # 组与组之间的基频、节奏、声数均随机，避免机械重复。
    t = rng.uniform(0.2, 1.0)
    while t < nsec:
        n_pulses = int(rng.integers(3, 6))          # 3–5 声
        group_f0 = rng.uniform(3500.0, 5000.0)      # 本组基频
        for k in range(n_pulses):
            dur = rng.uniform(0.040, 0.070)         # 每声 40–70ms
            f0 = group_f0 * (1.0 + rng.uniform(-0.03, 0.03))
            f0 *= 1.0 + 0.01 * k                    # 组内轻微上行
            add_pulse(sig, t, _cricket_pulse(f0, dur, rng.uniform(0.02, 0.06), rng))
            t += dur + rng.uniform(0.12, 0.20)      # 组内间隔 120–200ms
        t += rng.uniform(0.8, 2.2)                  # 组间间隔

    return sig


# ---------------------------------------------------------------- 输出

def write_wav(path, data):
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def postprocess(out):
    """统一后处理：去直流 → 轻微淡入 → 峰值归一化。"""
    out = out - float(np.mean(out))                 # 去直流
    fi = int(FADE_SEC * SR)
    out[:fi] *= np.linspace(0.0, 1.0, fi)           # 前 0.05s 淡入
    out = norm(out, PEAK)                           # 峰值归一化到 0.6
    return out


def stats(out):
    rms = float(np.sqrt(np.mean(out ** 2)))
    peak = float(np.max(np.abs(out)))
    k = int(0.5 * SR)
    head = float(np.sqrt(np.mean(out[:k] ** 2)))
    tail = float(np.sqrt(np.mean(out[-k:] ** 2)))
    return (len(out) / SR, rms, peak, head, tail)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    af = shutil.which('afconvert') or '/usr/bin/afconvert'
    if not os.path.exists(af):
        print('未找到 afconvert，无法输出 m4a', file=sys.stderr)
        return 1

    # (文件名, 生成函数, 随机种子)
    jobs = [
        ('amb_forest', gen_forest, 11071),
        ('amb_study', gen_study, 22307),
        ('amb_night', gen_night, 33599),
    ]

    tmp = tempfile.mkdtemp(prefix='guqin_amb_')
    ok = 0
    try:
        for name, gen, seed in jobs:
            wav = os.path.join(tmp, name + '.wav')
            m4a = os.path.join(OUT_DIR, name + '.m4a')
            try:
                rng = np.random.default_rng(seed)
                raw = gen(rng, TOTAL_SEC)
                out = postprocess(seamless_loop(raw))
                dur, rms, peak, head, tail = stats(out)
                write_wav(wav, out)
            except Exception as e:                  # 单个失败不影响其余
                print(f'[fail] {name}: {e}', file=sys.stderr)
                continue

            r = subprocess.run(
                [af, '-f', 'm4af', '-d', 'aac', '-b', '128000', wav, m4a],
                capture_output=True, text=True)
            if r.returncode != 0:
                print(f'[fail] {name}: {r.stderr.strip()}', file=sys.stderr)
                continue

            ok += 1
            print(f'[ok] {name}.m4a  时长 {dur:.2f}s  RMS {rms:.4f}  '
                  f'峰值 {peak:.4f}  首0.5s RMS {head:.4f}  尾0.5s RMS {tail:.4f}')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print(f'[done] {ok}/{len(jobs)} 段环境音 → {OUT_DIR}')
    return 0 if ok == len(jobs) else 1


if __name__ == '__main__':
    sys.exit(main())

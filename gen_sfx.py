#!/usr/bin/env python3
"""生成古琴单音音效（离线资源）。

供「数字琴境体验 / 指法动画教学 / 智能演奏辅助 / 琴音可视化」使用。

这一版换成更接近真实丝弦的物理合成模型，不再是「正弦叠加＋统一包络」：

  · 分音列：弦的刚性使高次分音略微偏高（inharmonicity），每根弦的分音相位
    与微失谐固定，同一根弦无论用哪种指法弹出，听起来都是同一根弦；
  · 拨弦位置梳状滤波：右手在岳山附近下指，拨弦点距岳山的比例会在分音列上
    形成深浅不一的梳状缺口——这是古琴「苍、松、透」的关键，也是电子合成音
    最缺的一层；
  · 双段衰减：丝弦起振后先有一次短促的能量释放，再进入绵长的余韵，高次
    分音衰减快于基频，形成由亮到暗的自然过渡；
  · 琴体共鸣：在频域叠加古琴琴腔的木胎／空气共振峰（约 100–2200Hz 数处），
    并把 45Hz 以下削掉，避免手机小喇叭放不出的低频轰鸣；
  · 触弦瞬态：指甲擦弦的短噪声（带通 600–6000Hz）＋一次极轻的木质低鸣；
  · 立体声：左右声道分音相位轻微错开，混响脉冲响应也各自独立，听感有真实
    空间的宽度，而不是单声道贴在脸上。

输出：assets/audio/sfx/<kind>_0..6.m4a（正调 F 调七弦：C2 D2 F2 G2 A2 C3 D3）
  open 散音 / press 按音 / harm 泛音
  擘 bai 托 tuo 抹 mo 挑 tiao 勾 gou 剔 ti 打 da 摘 zhai
  吟 yin 猱 nao 绰 chuo 注 zhu
"""

import math
import os
import shutil
import subprocess
import sys
import tempfile
import wave
import zlib

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, 'assets', 'audio', 'sfx')

# 正调（F 调）七弦散音 MIDI
STRINGS = (36, 38, 41, 43, 45, 48, 50)

# ---------------------------------------------------------------- 音色定义

# n 分音数 / tau 基频衰减时间 / damp 高次分音加速衰减 / vib 吟猱深度 /
# amp 力度 / dur 时长 / power 分音能量幂 / noise 指甲瞬态强度 /
# pluck 拨弦点距岳山的比例（越小越靠岳山，音色越紧、越「金石」）
BASE = {
    'open':  dict(n=18, tau=1.55, damp=0.30, vib=0.0, amp=1.00, dur=3.4,
                  power=1.08, noise=0.48, pluck=0.135),
    'press': dict(n=15, tau=1.20, damp=0.34, vib=1.15, vib_hz=4.6,
                  vib_decay=2.8, amp=0.92, dur=2.9, power=1.16, noise=0.42,
                  pluck=0.190),
    'harm':  dict(n=9,  tau=0.80, damp=0.24, vib=0.0, amp=0.74, dur=2.1,
                  power=0.92, noise=0.32, pluck=0.260),
}

# 右手四指：触弦的肉 / 甲比例不同 → 厚薄、亮度、力度各异
#   大指沉厚、食指清亮、中指圆润、无名指轻细
FINGERS = {
    'thumb':  dict(n=17, tau=1.65, power=1.26, noise=0.38, amp=1.00, pluck=0.150),
    'index':  dict(n=20, tau=1.50, power=0.98, noise=0.60, amp=0.95, pluck=0.118),
    'middle': dict(n=18, tau=1.58, power=1.12, noise=0.50, amp=0.99, pluck=0.135),
    'ring':   dict(n=15, tau=1.38, power=1.20, noise=0.40, amp=0.85, pluck=0.165),
}

# 右手指法 → (手指, 出弦方向)；向外略亮而脆，向内略厚而柔
RH = {
    'bai':  ('thumb',  'out'),  # 擘：大指向外
    'tuo':  ('thumb',  'in'),   # 托：大指向内
    'mo':   ('index',  'in'),   # 抹：食指向内
    'tiao': ('index',  'out'),  # 挑：食指向外
    'gou':  ('middle', 'in'),   # 勾：中指向内
    'ti':   ('middle', 'out'),  # 剔：中指向外
    'da':   ('ring',   'in'),   # 打：无名指向内
    'zhai': ('ring',   'out'),  # 摘：无名指向外
}

# 左手指法：吟（快而细）猱（慢而大）
LH = {
    'yin': dict(n=15, tau=1.32, power=1.14, noise=0.42, amp=0.94, level=1.0,
                vib=1.0, vib_hz=6.8, vib_decay=3.2, dur=4.2, pluck=0.185),
    'nao': dict(n=15, tau=1.25, power=1.16, noise=0.42, amp=0.94, level=1.0,
                vib=4.8, vib_hz=2.2, vib_decay=2.1, dur=4.2, pluck=0.185),
}

# 滑音：绰自下方就本位（由低滑高），注自上方就本位（由高滑低）
SLIDE = {
    'chuo': dict(cents=-240, n=15, tau=1.30, power=1.12, noise=0.44,
                 amp=0.90, dur=4.0, glide=0.34, pluck=0.180),
    'zhu':  dict(cents=+240, n=15, tau=1.30, power=1.12, noise=0.44,
                 amp=0.90, dur=4.0, glide=0.34, pluck=0.180),
}

# 古琴琴体共振：中心频率 / 带宽 / 提升(dB)
BODY_MODES = (
    (96.0,   28.0,  2.6),
    (186.0,  55.0,  2.2),
    (332.0,  90.0,  1.9),
    (618.0,  150.0, 1.4),
    (1180.0, 320.0, 0.9),
    (2100.0, 700.0, 0.4),
)


def midi_to_freq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def build_specs():
    """汇总全部音色的合成参数（含 kind / mode）。"""
    specs = {}
    for kind, s in BASE.items():
        specs[kind] = dict(mode='note', kind=kind, **s)
    for kind, (finger, dirn) in RH.items():
        f = FINGERS[finger]
        s = dict(mode='note', kind=kind, n=f['n'], tau=f['tau'], damp=0.30,
                 vib=0.0, amp=f['amp'], dur=4.9, power=f['power'],
                 noise=f['noise'], pluck=f['pluck'])
        if dirn == 'out':   # 向外：出弦略亮、音头略脆，拨点更靠岳山
            s['power'] -= 0.05
            s['noise'] += 0.10
            s['pluck'] -= 0.012
        else:               # 向内：入弦略厚、音头略柔
            s['power'] += 0.03
            s['noise'] -= 0.05
            s['pluck'] += 0.008
        specs[kind] = s
    for kind, s in LH.items():
        specs[kind] = dict(mode='note', damp=0.32, kind=kind, **s)
    for kind, s in SLIDE.items():
        specs[kind] = dict(mode='slide', damp=0.32, kind=kind, **s)
    for s in specs.values():
        s.setdefault('level', s['amp'])   # 力度差别：由 amp 决定各音轻重
    return specs


# ---------------------------------------------------------------- 合成

def _partial_amp(base_amp, power, k, rng, pluck):
    """分音振幅：能量幂衰减 × 固定微扰 × 拨弦位置梳状滤波。"""
    a = base_amp / k ** power * (0.80 + 0.40 * rng.random())
    # 拨弦点梳状滤波：弦上该点为节的分音就被削弱
    comb = abs(math.sin(math.pi * k * pluck))
    a *= (0.55 + 0.45 * comb) ** 0.7
    return a


def _pluck_noise(noise, rng):
    """指甲擦弦：带通噪声，短促的一个「嚓」。"""
    n = int(0.014 * SR)
    env = np.exp(-np.arange(n) / (0.0022 * SR))
    x = rng.normal(0.0, 1.0, n)
    # 简易带通：一阶差分削低频 + 一阶低通限高频
    x = np.diff(np.concatenate([[0.0], x]))
    x = np.convolve(x, np.ones(4) / 4.0, mode='same')
    return x * env * noise * 0.55


def _low_thump(amp, rng):
    """琴身被弦带动的一次极轻的木胎低鸣。"""
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    f = 68.0 + rng.random() * 8.0
    env = np.exp(-t / 0.035) * (1 - np.exp(-t / 0.004))
    return np.sin(2 * math.pi * f * t) * env * amp * 0.16


def synth_note(midi, spec, rng):
    """合成单音（单声道基底）：分音列 + 不成谐性 + 双段衰减 + 瞬态。"""
    f0 = midi_to_freq(midi)
    n = int(spec['dur'] * SR)
    t = np.arange(n, dtype=np.float64) / SR
    sig = np.zeros(n, dtype=np.float64)

    B = 4.2e-5  # 弦的刚性：高次分音略微偏高
    # 极缓的音高漂移：丝弦不是电子振荡器
    drift = 1.0 + 0.00035 * np.sin(2 * math.pi * 0.55 * t + rng.random() * 6.28) \
        * np.exp(-t / 2.8)

    for k in range(1, spec['n'] + 1):
        fk = f0 * k * math.sqrt(1.0 + B * k * k) * (1.0 + rng.normal(0, 0.0006))
        if fk > SR * 0.45:
            break
        a = _partial_amp(spec['amp'], spec['power'], k, rng, spec['pluck'])
        tau = spec['tau'] / (1.0 + spec['damp'] * (k - 1) ** 1.25)
        # 真实拨弦时各分音几乎同相起振：相位只留极小抖动，音头才「立」得起来
        phase = 2.0 * math.pi * np.cumsum(fk * drift) / SR \
            + rng.uniform(-0.12, 0.12)
        if spec.get('vib'):                       # 吟 / 猱：音波往复
            phase += spec['vib'] * np.sin(2.0 * math.pi * spec['vib_hz'] * t) \
                * np.exp(-t / spec['vib_decay'])
        # 双段衰减：起振先快落，随后进入绵长余韵
        env = (0.76 * np.exp(-t / (tau * 0.50))
               + 0.24 * np.exp(-t / (tau * 1.30)))
        sig += a * env * np.sin(phase)

    tr = _pluck_noise(spec['noise'], rng)
    sig[:len(tr)] += tr
    thump = _low_thump(spec['noise'], rng)
    sig[:len(thump)] += thump
    return sig


def synth_slide(midi, spec, rng):
    """合成滑音：基频自本音偏移 spec['cents'] 处滑入本位。"""
    f_target = midi_to_freq(midi)
    n = int(spec['dur'] * SR)
    t = np.arange(n, dtype=np.float64) / SR

    glide = spec['glide']
    ratio = np.clip(t / glide, 0.0, 1.0)
    cents = spec['cents'] * (1.0 - ratio) ** 2
    f0 = f_target * 2.0 ** (cents / 1200.0)

    sig = np.zeros(n, dtype=np.float64)
    B = 4.2e-5
    for k in range(1, spec['n'] + 1):
        fk = f0 * k * math.sqrt(1.0 + B * k * k) * (1.0 + rng.normal(0, 0.0006))
        if np.max(fk) > SR * 0.45:
            break
        a = _partial_amp(spec['amp'], spec['power'], k, rng, spec['pluck'])
        tau = spec['tau'] / (1.0 + spec['damp'] * (k - 1) ** 1.25)
        phase = 2.0 * math.pi * np.cumsum(fk) / SR \
            + rng.uniform(-0.12, 0.12)
        env = (0.76 * np.exp(-t / (tau * 0.50))
               + 0.24 * np.exp(-t / (tau * 1.30)))
        sig += a * env * np.sin(phase)

    tr = _pluck_noise(spec['noise'], rng)
    sig[:len(tr)] += tr
    thump = _low_thump(spec['noise'], rng)
    sig[:len(thump)] += thump
    return sig


def synth_click(rng):
    """节拍器拍点音：短促的木质「嗒」。"""
    dur = 0.14
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    sig = np.zeros(n, dtype=np.float64)
    for k, a in ((1.0, 1.0), (2.02, 0.42), (3.05, 0.20)):
        sig += a * np.exp(-t / 0.026) * np.sin(2.0 * math.pi * 1180.0 * k * t)
    m = int(0.006 * SR)
    env = np.exp(-np.arange(m) / (0.0012 * SR))
    sig[:m] += (rng.random(m) - 0.5) * 0.9 * env
    return sig


# ---------------------------------------------------------------- 后处理

def body_eq(x):
    """零相位琴体共鸣：叠加木胎／琴腔的共振峰，并削掉超低频。"""
    n = 1 << (len(x) - 1).bit_length()
    spec = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f = np.maximum(f, 1e-6)
    gain = np.ones_like(f)
    for center, bw, db in BODY_MODES:
        g = 10.0 ** (db / 20.0) - 1.0
        gain += g * np.exp(-0.5 * ((f - center) / bw) ** 2)
    # 45Hz 高通：手机放不出的低频只会变成浑浊
    gain *= (f ** 2) / (f ** 2 + 42.0 ** 2)
    # 5.2k 低通：多弦同时响起时高频毛刺是吵感主因
    gain *= 1.0 / (1.0 + (f / 5200.0) ** 2)
    return np.fft.irfft(spec * gain, n)[:len(x)]


def make_ir(rng, rt=1.55):
    """带早期反射的立体声脉冲响应（小琴室）。"""
    n = int(rt * SR)
    t = np.arange(n, dtype=np.float64) / SR
    chans = []
    for _ in range(2):
        ir = rng.normal(0.0, 1.0, n) * np.exp(-6.9 * t / rt)
        ir = np.convolve(ir, np.ones(18) / 18.0, mode='same')
        # 几次早期反射，让空间有「墙」而不是一团糊
        for delay, g in ((0.009, 0.55), (0.014, -0.32), (0.023, 0.22),
                         (0.031, -0.14)):
            idx = int(delay * SR)
            if idx < n:
                ir[idx] += g
        pre = int(0.012 * SR)
        ir[:pre] *= np.linspace(0.0, 1.0, pre)
        ir /= math.sqrt(float(np.sum(ir ** 2)))
        chans.append(ir)
    return chans


def convolve_reverb(x, ir, mix=0.12):
    n = len(x) + len(ir) - 1
    N = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:len(x)]
    return (1.0 - mix) * x + mix * wet


def render_stereo(midi, spec, irs):
    # 同一根弦共享谐波结构（相位 / 微失谐固定），音色差异只由指法参数决定，
    # 听感上即「同一根弦被不同指法弹出」，而非各弹一根不同的弦。
    rng = np.random.default_rng(zlib.crc32(f'{midi}'.encode()))
    if spec['mode'] == 'slide':
        sig = synth_slide(midi, spec, rng)
    else:
        sig = synth_note(midi, spec, rng)

    sig = body_eq(sig)

    # 立体声：干声共用，只让左右各自的房间混响错开——宽度来自空间，
    # 而不是把同一根弦做成两把相位相反的假琴
    left = convolve_reverb(sig, irs[0], mix=0.07)
    right = convolve_reverb(sig, irs[1], mix=0.07)

    # 起振包络：消除零起点的爆音
    atk = int(0.004 * SR)
    for ch in (left, right):
        ch[:atk] *= np.linspace(0.0, 1.0, atk)

    peak = float(max(np.max(np.abs(left)), np.max(np.abs(right)))) or 1.0
    left = np.tanh(left / peak * 1.15) / math.tanh(1.15)
    right = np.tanh(right / peak * 1.15) / math.tanh(1.15)
    # level 保留各指法的力度差别（大指沉厚、无名指轻细），而非一律等响
    scale = 0.60 * spec['level'] / (
        float(max(np.max(np.abs(left)), np.max(np.abs(right)))) or 1.0)
    left *= scale
    right *= scale

    fade = int(0.60 * SR)                                   # 尾部收束
    for ch in (left, right):
        ch[-fade:] *= np.linspace(1.0, 0.0, fade) ** 0.8

    return np.stack([left, right], axis=1)


def write_wav(path, data):
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2 if data.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def encode(af, wav, m4a, bitrate='160000'):
    r = subprocess.run(
        [af, '-f', 'm4af', '-d', 'aac', '-b', bitrate, wav, m4a],
        capture_output=True, text=True)
    if r.returncode != 0:
        print(f'[fail] {os.path.basename(m4a)}: {r.stderr.strip()}',
              file=sys.stderr)
        return False
    return True


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    af = shutil.which('afconvert') or '/usr/bin/afconvert'
    if not os.path.exists(af):
        print('未找到 afconvert，无法输出 m4a', file=sys.stderr)
        return 1

    specs = build_specs()
    irs = make_ir(np.random.default_rng(4242))
    tmp = tempfile.mkdtemp(prefix='guqin_sfx_')
    # 环境氛围音由 gen_ambient.py 单独生成，不参与本脚本的清理
    keep = {'amb_forest.m4a', 'amb_study.m4a', 'amb_night.m4a'}
    try:
        for kind, spec in specs.items():
            for i, m in enumerate(STRINGS):
                midi = m + 12 if kind == 'harm' else m   # 泛音取高八度
                name = f'{kind}_{i}.m4a'
                keep.add(name)

                wav = os.path.join(tmp, f'{kind}_{i}.wav')
                m4a = os.path.join(OUT_DIR, name)
                write_wav(wav, render_stereo(midi, spec, irs))
                encode(af, wav, m4a)

        # 节拍器拍点音（智能演奏辅助的节拍引导；保持干声，不叠加混响）
        keep.add('click.m4a')
        sig = synth_click(np.random.default_rng(2024))
        peak = float(np.max(np.abs(sig))) or 1.0
        sig *= 0.92 / peak
        fade = int(0.03 * SR)
        sig[-fade:] *= np.linspace(1.0, 0.0, fade)
        wav = os.path.join(tmp, 'click.wav')
        m4a = os.path.join(OUT_DIR, 'click.m4a')
        write_wav(wav, sig)
        encode(af, wav, m4a, bitrate='128000')

        print(f'[ok] {len(keep)} 个音效 → {OUT_DIR}')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # 清理旧版本遗留的音效文件
    for f in sorted(os.listdir(OUT_DIR)):
        if f.endswith('.m4a') and f not in keep:
            os.remove(os.path.join(OUT_DIR, f))
            print(f'[del] {f}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

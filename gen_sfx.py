#!/usr/bin/env python3
"""生成古琴单音音效（离线资源）。

供「数字琴境体验 / 指法动画教学 / 智能演奏辅助 / 琴音可视化」使用：

  · 与 gen_audio.py 采用同一套合成模型（谐波列 + 弦刚性不成谐性 + 卷积混响），
    使零散单音与整曲试听的音色完全一致，不再有「电子音 / 敲击音」的突兀感；
  · 按「实际指法」区分音色：右手八法因手指触弦的肉甲比例与出弦方向不同，
    音色厚薄、亮度、音头质感各不相同；左手吟猱为不同速率的音波，
    绰注为不同方向的滑音。让指法教学里每个指法弹出各自的声音；
  · 指甲触弦瞬态 + 45Hz 高通（滤掉手机小喇叭放不出的低频轰鸣）
    + 小琴室混响，逼近真实琴弦的余韵。

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

# 基本音色：n 分音数 / tau 基频衰减时间 / damp 高次分音加速衰减 /
# vib 吟猱深度 / amp 力度 / dur 时长 / power 分音能量幂 / noise 指甲瞬态强度
BASE = {
    'open':  dict(n=16, tau=3.10, damp=0.20, vib=0.0,  amp=1.00, dur=4.6, power=1.12, noise=0.50),
    'press': dict(n=13, tau=2.20, damp=0.26, vib=1.25, vib_hz=4.8, vib_decay=2.6,
                  amp=0.90, dur=3.6, power=1.20, noise=0.45),
    'harm':  dict(n=6,  tau=1.40, damp=0.18, vib=0.0,  amp=0.72, dur=2.6, power=0.95, noise=0.35),
}

# 右手四指：触弦的肉 / 甲比例不同 → 厚薄、亮度、力度各异
#   大指沉厚、食指清亮、中指圆润、无名指轻细
FINGERS = {
    'thumb':  dict(n=15, tau=3.25, power=1.30, noise=0.40, amp=1.00),  # 大指：沉厚
    'index':  dict(n=18, tau=3.00, power=0.98, noise=0.62, amp=0.95),  # 食指：清亮
    'middle': dict(n=16, tau=3.15, power=1.14, noise=0.52, amp=0.99),  # 中指：圆润
    'ring':   dict(n=14, tau=2.75, power=1.22, noise=0.42, amp=0.85),  # 无名指：轻细
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
#   「吟」细而密，如人之吟咏；「猱」大而缓，波动深长。二者速率相差数倍，
#   听感上一为轻颤、一为深晃，区别明显。
LH = {
    'yin': dict(n=13, tau=2.70, power=1.18, noise=0.45, amp=0.94, level=1.0,
                vib=1.1, vib_hz=7.0, vib_decay=3.2, dur=4.2),
    'nao': dict(n=13, tau=2.40, power=1.20, noise=0.45, amp=0.94, level=1.0,
                vib=5.6, vib_hz=2.3, vib_decay=2.0, dur=4.2),
}

# 滑音：绰自下方就本位（由低滑高），注自上方就本位（由高滑低）
SLIDE = {
    'chuo': dict(cents=-260, n=13, tau=2.60, power=1.16, noise=0.46,
                 amp=0.90, dur=3.8, glide=0.38),
    'zhu':  dict(cents=+260, n=13, tau=2.60, power=1.16, noise=0.46,
                 amp=0.90, dur=3.8, glide=0.38),
}


def midi_to_freq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def build_specs():
    """汇总全部音色的合成参数（含 kind / mode）。"""
    specs = {}
    for kind, s in BASE.items():
        specs[kind] = dict(mode='note', kind=kind, **s)
    for kind, (finger, dirn) in RH.items():
        f = FINGERS[finger]
        s = dict(mode='note', kind=kind, n=f['n'], tau=f['tau'], damp=0.20,
                 vib=0.0, amp=f['amp'], dur=4.3, power=f['power'], noise=f['noise'])
        if dirn == 'out':   # 向外：出弦略亮、音头略脆
            s['power'] -= 0.05
            s['noise'] += 0.10
        else:               # 向内：入弦略厚、音头略柔
            s['power'] += 0.03
            s['noise'] -= 0.06
        specs[kind] = s
    for kind, s in LH.items():
        specs[kind] = dict(mode='note', damp=0.26, kind=kind, **s)
    for kind, s in SLIDE.items():
        specs[kind] = dict(mode='slide', kind=kind, damp=0.26, **s)
    for s in specs.values():
        s.setdefault('level', s['amp'])   # 力度差别：由 amp 决定各音轻重
    return specs


def _partial_amp(base_amp, power, k, rng):
    return base_amp / k ** power * (0.78 + 0.44 * rng.random())


def synth_note(midi, spec, rng):
    """合成单音：谐波列 + 不成谐性 + 分音独立衰减（+ 可选的吟猱频扰）。"""
    f0 = midi_to_freq(midi)
    n = int(spec['dur'] * SR)
    t = np.arange(n, dtype=np.float64) / SR
    sig = np.zeros(n, dtype=np.float64)

    B = 4.0e-5  # 弦的刚性：高次分音略微偏高
    for k in range(1, spec['n'] + 1):
        fk = f0 * k * math.sqrt(1.0 + B * k * k)
        if fk > SR * 0.45:
            break
        a = _partial_amp(spec['amp'], spec['power'], k, rng)
        tau = spec['tau'] / (1.0 + spec['damp'] * (k - 1))
        phase = 2.0 * math.pi * fk * t + rng.random() * 2.0 * math.pi
        if spec.get('vib'):                       # 吟 / 猱：音波往复
            phase += spec['vib'] * np.sin(2.0 * math.pi * spec['vib_hz'] * t) \
                * np.exp(-t / spec['vib_decay'])
        sig += a * np.exp(-t / tau) * np.sin(phase)

    tr = _pluck_transient(spec['noise'], rng)
    sig[:len(tr)] += tr
    return sig


def synth_slide(midi, spec, rng):
    """合成滑音：基频自本音偏移 spec['cents'] 处滑入本位。"""
    f_target = midi_to_freq(midi)
    n = int(spec['dur'] * SR)
    t = np.arange(n, dtype=np.float64) / SR

    # 音分曲线：在 glide 时长内由偏移量缓入本位
    glide = spec['glide']
    ratio = np.clip(t / glide, 0.0, 1.0)
    cents = spec['cents'] * (1.0 - ratio) ** 2
    f0 = f_target * 2.0 ** (cents / 1200.0)

    sig = np.zeros(n, dtype=np.float64)
    B = 4.0e-5
    for k in range(1, spec['n'] + 1):
        fk = f0 * k * math.sqrt(1.0 + B * k * k)
        if np.max(fk) > SR * 0.45:
            break
        a = _partial_amp(spec['amp'], spec['power'], k, rng)
        tau = spec['tau'] / (1.0 + spec['damp'] * (k - 1))
        phase = 2.0 * math.pi * np.cumsum(fk) / SR + rng.random() * 2.0 * math.pi
        sig += a * np.exp(-t / tau) * np.sin(phase)

    tr = _pluck_transient(spec['noise'], rng)
    sig[:len(tr)] += tr
    return sig


def _pluck_transient(noise, rng):
    """指甲触弦的极短噪声瞬态。"""
    n = int(0.010 * SR)
    env = np.exp(-np.arange(n) / (0.0018 * SR))
    return (rng.random(n) - 0.5) * noise * env


def synth_click(rng):
    """节拍器拍点音：短促的木质「嗒」。"""
    dur = 0.14
    n = int(dur * SR)
    t = np.arange(n, dtype=np.float64) / SR
    sig = np.zeros(n, dtype=np.float64)
    for k, a in ((1.0, 1.0), (2.02, 0.42), (3.05, 0.20)):
        sig += a * np.exp(-t / 0.026) * np.sin(2.0 * math.pi * 1180.0 * k * t)
    # 木质敲击的极短「咔」声瞬态
    m = int(0.006 * SR)
    env = np.exp(-np.arange(m) / (0.0012 * SR))
    sig[:m] += (rng.random(m) - 0.5) * 0.9 * env
    return sig


def highpass(x, fc=45.0):
    """零相位高通：削掉手机扬声器无法还原、只会变成浑浊轰鸣的超低频。"""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec *= (f ** 2) / (f ** 2 + fc ** 2)
    return np.fft.irfft(spec, len(x))


def make_ir(rng, rt=1.3):
    """指数衰减噪声脉冲响应（小琴室）。"""
    n = int(rt * SR)
    t = np.arange(n, dtype=np.float64) / SR
    ir = rng.normal(0.0, 1.0, n) * np.exp(-6.9 * t / rt)
    ir = np.convolve(ir, np.ones(24) / 24.0, mode='same')
    pre = int(0.012 * SR)
    ir[:pre] *= np.linspace(0.0, 1.0, pre)
    ir /= np.sqrt(np.sum(ir ** 2))
    return ir


def convolve_reverb(x, ir, mix=0.32):
    n = len(x) + len(ir) - 1
    N = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:len(x)]
    return (1.0 - mix) * x + mix * wet


def render(midi, spec, ir):
    # 同一根弦共享谐波结构（相位 / 分音微扰一致），音色差异只由指法参数决定，
    # 听感上即「同一根弦被不同指法弹出」，而非各弹一根不同的弦。
    rng = np.random.default_rng(zlib.crc32(f'{midi}'.encode()))
    if spec['mode'] == 'slide':
        sig = synth_slide(midi, spec, rng)
    else:
        sig = synth_note(midi, spec, rng)

    sig = highpass(sig)
    sig = convolve_reverb(sig, ir, mix=0.30)

    # 起振包络：消除零起点的爆音
    atk = int(0.004 * SR)
    sig[:atk] *= np.linspace(0.0, 1.0, atk)

    peak = float(np.max(np.abs(sig))) or 1.0
    sig = np.tanh(sig / peak * 1.2) / math.tanh(1.2)       # 软限幅
    # level 保留各指法的力度差别（大指沉厚、无名指轻细），而非一律等响
    sig *= 0.92 * spec['level'] / (float(np.max(np.abs(sig))) or 1.0)

    fade = int(0.55 * SR)                                   # 尾部收束
    sig[-fade:] *= np.linspace(1.0, 0.0, fade) ** 0.8
    return sig


def write_wav(path, data):
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    af = shutil.which('afconvert') or '/usr/bin/afconvert'
    if not os.path.exists(af):
        print('未找到 afconvert，无法输出 m4a', file=sys.stderr)
        return 1

    specs = build_specs()
    ir = make_ir(np.random.default_rng(4242))
    tmp = tempfile.mkdtemp(prefix='guqin_sfx_')
    keep = set()
    try:
        for kind, spec in specs.items():
            for i, m in enumerate(STRINGS):
                midi = m + 12 if kind == 'harm' else m   # 泛音取高八度
                name = f'{kind}_{i}.m4a'
                keep.add(name)

                wav = os.path.join(tmp, f'{kind}_{i}.wav')
                m4a = os.path.join(OUT_DIR, name)
                write_wav(wav, render(midi, spec, ir))
                r = subprocess.run(
                    [af, '-f', 'm4af', '-d', 'aac', '-b', '128000', wav, m4a],
                    capture_output=True, text=True)
                if r.returncode != 0:
                    print(f'[fail] {name}: {r.stderr.strip()}', file=sys.stderr)
                    continue

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
        r = subprocess.run(
            [af, '-f', 'm4af', '-d', 'aac', '-b', '128000', wav, m4a],
            capture_output=True, text=True)
        if r.returncode != 0:
            print(f'[fail] click.m4a: {r.stderr.strip()}', file=sys.stderr)

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

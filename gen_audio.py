#!/usr/bin/env python3
"""从真实琴谱（MusicXML）渲染 10 首古琴曲的试听片段（离线资源）。

不再随机编配，而是解析 `tools/scores/*.xml`（Guqin-Dataset，由正式出版带简谱的
琴谱转录）中的**真实旋律、时值、泛音标记**，用与 gen_sfx.py 完全一致的音色模型
（赫姆霍兹泛音列 + 弦刚性不成谐性 + 分音独立衰减 + 指甲瞬态 + 卷积混响）逐音渲染。

  · 散音：音高恰为七弦空弦者（正调 C2 D2 F2 G2 A2 C3 D3）；
  · 按音：其余音高，长音带吟猱；
  · 泛音：谱中以 staccato 标记的泛音段。

输出：assets/audio/<slug>.m4a（AAC），中间 WAV 写入临时目录后删除。
"""

import math
import os
import shutil
import subprocess
import sys
import tempfile
import wave
import xml.etree.ElementTree as ET
import zlib

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.abspath(__file__))
SCORE_DIR = os.path.join(ROOT, 'tools', 'scores')
OUT_DIR = os.path.join(ROOT, 'assets', 'audio')

# 正调（F 调）七弦散音 MIDI
STRINGS = (36, 38, 41, 43, 45, 48, 50)

# ---------------------------------------------------------------- 音色定义
# 与 gen_sfx.py 的 BASE 保持一致，使整曲试听与零散单音音色统一
BASE = {
    'open':  dict(n=16, tau=3.10, damp=0.20, vib=0.0,  amp=1.00, dur=4.6, power=1.12, noise=0.50),
    'press': dict(n=13, tau=2.20, damp=0.26, vib=1.25, vib_hz=4.8, vib_decay=2.6,
                  amp=0.90, dur=3.6, power=1.20, noise=0.45),
    'harm':  dict(n=6,  tau=1.40, damp=0.18, vib=0.0,  amp=0.72, dur=2.6, power=0.95, noise=0.35),
}
# 短按音不加吟猱，避免每个音都在抖
BASE['press_plain'] = dict(BASE['press'], vib=0.0)
SPECS = {k: dict(mode='note', **v) for k, v in BASE.items()}

# 曲目：slug / 主题 / 四分音符每分钟 / 起始拍 / 取用拍数
# 取较长段落（约 1–2 分钟），自曲首起，保留该曲最核心的旋律陈述。
PIECES = [
    dict(slug='meihua',       title='梅花三弄', bpm=60, start=0.0, length=124),
    dict(slug='pingsha',      title='平沙落雁', bpm=56, start=0.0, length=112),
    dict(slug='yangguan',     title='阳关三叠', bpm=54, start=0.0, length=106),
    dict(slug='jiukuang',     title='酒狂',     bpm=76, start=0.0, length=132),
    dict(slug='liangxiao',    title='良宵引',   bpm=52, start=0.0, length=102),
    dict(slug='zuiyu',        title='醉渔唱晚', bpm=66, start=0.0, length=124),
    dict(slug='yuqiao',       title='渔樵问答', bpm=60, start=0.0, length=118),
    dict(slug='yiguren',      title='忆故人',   bpm=56, start=0.0, length=106),
    dict(slug='guanshanyue',  title='关山月',   bpm=54, start=0.0, length=59),
    dict(slug='changmenyuan', title='长门怨',   bpm=54, start=0.0, length=112),
]


def midi_to_freq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# ---------------------------------------------------------------- 谱面解析

STEP = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def pitch_to_midi(p):
    st = STEP[p.find('step').text.strip()]
    octv = int(p.find('octave').text)
    alt = p.find('alter')
    alt = int(float(alt.text)) if alt is not None and alt.text else 0
    return (octv + 1) * 12 + st + alt


def load_events(slug):
    """解析 MusicXML → [(起始拍, midi, 时值拍, 是否泛音)]，均为四分音符为单位。"""
    path = os.path.join(SCORE_DIR, slug + '.xml')
    root = ET.parse(path).getroot()
    events = []
    div = 1
    pos = 0.0        # 当前拍位
    start = 0.0      # 上一音的起始拍（供和弦复用）
    for part in root.findall('part'):
        for measure in part.findall('measure'):
            attrs = measure.find('attributes')
            if attrs is not None:
                d = attrs.find('divisions')
                if d is not None and d.text:
                    div = int(d.text)
            for note in measure.findall('note'):
                dur_el = note.find('duration')
                dur = int(dur_el.text) if dur_el is not None and dur_el.text else 0
                beats = dur / div
                is_chord = note.find('chord') is not None
                is_rest = note.find('rest') is not None
                if not is_chord:
                    start = pos
                    pos += beats
                if is_rest:
                    continue
                p = note.find('pitch')
                if p is None:
                    continue
                harm = note.find('notations/articulations/staccato') is not None
                events.append((start, pitch_to_midi(p), max(beats, 0.25), harm))
    return events


# ---------------------------------------------------------------- 音色合成

_NOTE_CACHE = {}


def synth_note(midi, kind):
    """合成单音并缓存：谐波列 + 不成谐性 + 分音独立衰减（+ 可选吟猱）。"""
    key = (midi, kind)
    if key in _NOTE_CACHE:
        return _NOTE_CACHE[key]

    spec = SPECS[kind]
    f0 = midi_to_freq(midi)
    n = int(spec['dur'] * SR)
    t = np.arange(n, dtype=np.float64) / SR
    sig = np.zeros(n, dtype=np.float64)

    # 同一根弦共享谐波结构（相位 / 分音微扰一致），音色差异只由音型决定
    rng = np.random.default_rng(zlib.crc32(f'{midi}'.encode()))

    B = 4.0e-5
    for k in range(1, spec['n'] + 1):
        fk = f0 * k * math.sqrt(1.0 + B * k * k)
        if fk > SR * 0.45:
            break
        a = spec['amp'] / k ** spec['power'] * (0.78 + 0.44 * rng.random())
        tau = spec['tau'] / (1.0 + spec['damp'] * (k - 1))
        phase = 2.0 * math.pi * fk * t + rng.random() * 2.0 * math.pi
        if spec.get('vib'):
            phase += spec['vib'] * np.sin(2.0 * math.pi * spec['vib_hz'] * t) \
                * np.exp(-t / spec['vib_decay'])
        sig += a * np.exp(-t / tau) * np.sin(phase)

    # 指甲触弦的极短噪声瞬态
    tn = int(0.010 * SR)
    env = np.exp(-np.arange(tn) / (0.0018 * SR))
    sig[:tn] += (rng.random(tn) - 0.5) * spec['noise'] * env

    atk = int(0.004 * SR)
    sig[:atk] *= np.linspace(0.0, 1.0, atk)

    _NOTE_CACHE[key] = sig
    return sig


# ---------------------------------------------------------------- 混响

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


def highpass(x, fc=45.0):
    """零相位高通：削掉手机扬声器还原不出、只会浑浊轰鸣的超低频。"""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec *= (f ** 2) / (f ** 2 + fc ** 2)
    return np.fft.irfft(spec, len(x))


def convolve_reverb(x, ir, mix=0.30):
    n = len(x) + len(ir) - 1
    N = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:len(x)]
    return (1.0 - mix) * x + mix * wet


# ---------------------------------------------------------------- 渲染

def render_piece(cfg):
    slug = cfg['slug']
    spb = 60.0 / cfg['bpm']                      # 每拍秒数
    events = load_events(slug)
    if not events:
        raise RuntimeError(f'{slug}: 谱面未解析出音符')

    avail_end = max(b + d for (b, _, d, _) in events)
    start = cfg['start']
    length = min(cfg['length'], avail_end - start)
    end = start + length
    total = length * spb

    buf = np.zeros(int((total + 5.0) * SR), dtype=np.float64)
    rng = np.random.default_rng(zlib.crc32(slug.encode()))

    played = 0
    for (b, m, d, harm) in events:
        if b < start - 1e-6 or b >= end:
            continue
        t = (b - start) * spb
        nd = d * spb
        if harm:
            kind = 'harm'
        elif m in STRINGS:
            kind = 'open'
        elif nd >= 0.45:
            kind = 'press'          # 长按音带吟猱
        else:
            kind = 'press_plain'    # 短按音干净利落
        note = synth_note(m, kind)
        # 轻微力度起伏，避免机械等响；泛音、高音略收
        amp = 0.84 + 0.26 * rng.random()
        if kind == 'harm':
            amp *= 0.92
        s = int(t * SR)
        e = min(len(buf), s + len(note))
        if e <= s:
            continue
        buf[s:e] += note[:e - s] * amp
        played += 1

    buf = highpass(buf)
    ir = make_ir(np.random.default_rng(4242))
    buf = convolve_reverb(buf, ir, mix=0.32)

    peak = float(np.max(np.abs(buf))) or 1.0
    buf = np.tanh(buf / peak * 1.25) / math.tanh(1.25)   # 软限幅
    buf *= 0.90 / (float(np.max(np.abs(buf))) or 1.0)

    fi, fo = int(0.6 * SR), int(2.4 * SR)
    buf[:fi] *= np.linspace(0.0, 1.0, fi)
    buf[-fo:] *= np.linspace(1.0, 0.0, fo) ** 0.8       # 尾音自然收束
    return buf[:int((total + 2.4) * SR)], played, total


# ---------------------------------------------------------------- 导出

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

    tmp = tempfile.mkdtemp(prefix='guqin_audio_')
    try:
        for cfg in PIECES:
            slug = cfg['slug']
            data, played, total = render_piece(cfg)
            wav = os.path.join(tmp, slug + '.wav')
            m4a = os.path.join(OUT_DIR, slug + '.m4a')
            write_wav(wav, data)
            cmd = [af, '-f', 'm4af', '-d', 'aac', '-b', '80000', wav, m4a]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                print(f'[fail] {slug}: {r.stderr.strip()}', file=sys.stderr)
                continue
            size = os.path.getsize(m4a) / 1024
            print(f"[ok] {slug:<12s} {cfg['title']:<5s} "
                  f"notes={played:4d}  {total + 2.4:5.1f}s  {size:5.0f} KB")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""生成「弦上知音」App 图标（水墨国风：宣纸底 + 墨色古琴 + 朱砂落款印）。

一次生成：Android mipmap / iOS AppIcon / macOS AppIcon / assets/images/logo.png。
主图以 2048 px 渲染后 LANCZOS 降采样，天然抗锯齿。
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
S = 2048

PAPER_HI = (250, 245, 234)
PAPER_LO = (219, 205, 179)
INK = (40, 34, 29)
BRIDGE = (98, 86, 70)
STRING = (230, 216, 190)
GOLD = (192, 158, 100)
CINNABAR = (164, 58, 46)
SEAL_TEXT = (246, 238, 226)

# 琴身半宽轮廓：t=0 为琴头（岳山端），t=1 为琴尾
PROFILE = [
    (0.000, 0.30), (0.006, 0.62), (0.025, 0.84), (0.060, 0.88), (0.120, 0.72),
    (0.200, 0.70), (0.300, 0.70), (0.420, 0.66), (0.520, 0.63), (0.620, 0.66),
    (0.720, 0.71), (0.820, 0.74), (0.900, 0.72), (0.960, 0.68), (0.990, 0.58),
    (1.000, 0.28),
]


def load_font(size):
    for path, idx in (
        ('/System/Library/Fonts/Supplemental/Songti.ttc', 0),
        ('/System/Library/Fonts/Supplemental/Kaiti.ttc', 0),
        ('/System/Library/Fonts/Supplemental/STHeiti Medium.ttc', 0),
        ('/System/Library/Fonts/PingFang.ttc', 0),
    ):
        try:
            return ImageFont.truetype(path, size, index=idx)
        except Exception:
            continue
    return ImageFont.load_default()


def paper_background():
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((x - 0.42 * S) ** 2 + (y - 0.36 * S) ** 2) / (0.98 * S)
    a = np.clip(d, 0.0, 1.0)[..., None]
    img = np.array(PAPER_HI, np.float32) * (1 - a) + np.array(PAPER_LO, np.float32) * a
    return Image.fromarray(img.astype(np.uint8), 'RGB')


def ink_wash(base):
    """在宣纸上晕开几团淡墨，营造水墨质感。"""
    wash = Image.new('L', (S, S), 0)
    wd = ImageDraw.Draw(wash)
    rng = np.random.default_rng(20261021)
    for _ in range(8):
        cx, cy = rng.uniform(0.05, 0.95) * S, rng.uniform(0.05, 0.95) * S
        rr = rng.uniform(0.13, 0.30) * S
        wd.ellipse([cx - rr, cy - rr * rng.uniform(0.7, 1.0), cx + rr * rng.uniform(0.7, 1.0), cy + rr],
                   fill=int(rng.uniform(16, 44)))
    wash = wash.filter(ImageFilter.GaussianBlur(S * 0.045))
    return Image.composite(Image.new('RGB', (S, S), INK), base, wash)


def qin_profile(n=640):
    ts = np.linspace(0.0, 1.0, n)
    vs = np.interp(ts, [p[0] for p in PROFILE], [p[1] for p in PROFILE])
    k = np.exp(-0.5 * (np.arange(-14, 15) / 4.5) ** 2)
    k /= k.sum()
    vs = np.convolve(np.pad(vs, 14, mode='edge'), k, 'valid')
    return ts, vs


def draw_qin(layer):
    d = ImageDraw.Draw(layer)
    x0, x1 = 0.155 * S, 0.855 * S
    length = x1 - x0
    cy = 0.505 * S
    H = 0.118 * S

    ts, vs = qin_profile()
    top = [(x0 + t * length, cy - v * H) for t, v in zip(ts, vs)]
    bot = [(x0 + t * length, cy + v * H) for t, v in zip(ts[::-1], vs[::-1])]
    d.polygon(top + bot, fill=INK + (255,))

    # 岳山（架弦之木）
    xk = x0 + 0.078 * length
    d.rectangle([xk - 0.0085 * S, cy - 0.60 * H, xk + 0.0085 * S, cy + 0.60 * H],
                fill=BRIDGE + (225,))

    # 七弦
    xa, xb = x0 + 0.062 * length, x0 + 0.955 * length
    gap = 0.1333 * H
    for i in range(7):
        y = cy + (i - 3) * gap
        d.line([(xa, y), (xb, y)], fill=STRING + (190,), width=int(0.0072 * S))

    # 十三徽（按岳山至龙龈的等分音位）
    xa, xb = x0 + 0.078 * length, x0 + 0.955 * length
    r = 0.0105 * S
    for fr in (1 / 8, 1 / 6, 1 / 5, 1 / 4, 1 / 3, 2 / 5, 1 / 2, 3 / 5, 2 / 3, 3 / 4, 4 / 5, 5 / 6, 7 / 8):
        x = xa + fr * (xb - xa)
        y = cy + 0.50 * H
        d.ellipse([x - r, y - r, x + r, y + r], fill=GOLD + (238,))


def draw_moon(layer):
    """琴后一轮淡墨圆窗，作古典框景。"""
    d = ImageDraw.Draw(layer)
    c = 0.505 * S, 0.495 * S
    rr = 0.335 * S
    d.ellipse([c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr],
              outline=INK + (52,), width=int(0.0055 * S))


def draw_seal(layer):
    """朱砂落款印：印面「琴」字。"""
    d = ImageDraw.Draw(layer)
    size = 0.235 * S
    x1, y1 = 0.955 * S, 0.945 * S
    x0, y0 = x1 - size, y1 - size
    rad = 0.022 * S
    d.rounded_rectangle([x0, y0, x1, y1], radius=rad, fill=CINNABAR + (255,))
    inset = 0.020 * S
    d.rounded_rectangle([x0 + inset, y0 + inset, x1 - inset, y1 - inset],
                        radius=rad * 0.6, outline=SEAL_TEXT + (170,), width=int(0.0055 * S))

    font = load_font(int(size * 0.60))
    box = d.textbbox((0, 0), '琴', font=font)
    d.text(((x0 + x1) / 2 - (box[0] + box[2]) / 2, (y0 + y1) / 2 - (box[1] + box[3]) / 2),
           '琴', font=font, fill=SEAL_TEXT + (255,))


def finish(img):
    a = np.asarray(img, np.float32)

    # 纸纹颗粒
    rng = np.random.default_rng(88)
    n = rng.normal(0.0, 3.2, (S, S, 1))
    a = a + n

    # 边缘暗角
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((x - S / 2) ** 2 + (y - S / 2) ** 2) / (S * 0.72)
    v = np.clip(1.0 - 0.16 * np.clip(d - 0.55, 0, 1) / 0.45, 0, 1)[..., None]
    a = a * v

    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB')


def master():
    base = paper_background()
    base = ink_wash(base)

    moon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_moon(moon)
    base = Image.alpha_composite(base.convert('RGBA'), moon)

    qin = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_qin(qin)
    base = Image.alpha_composite(base, qin)

    seal = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_seal(seal)
    base = Image.alpha_composite(base, seal)

    return finish(base.convert('RGB'))


def save(img, path, size, alpha=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img if size == S else img.resize((size, size), Image.LANCZOS)
    if not alpha:
        out = out.convert('RGB')
    out.save(path)
    return os.path.getsize(path)


def main():
    img = master()
    total = []

    targets = [
        ('assets/images/logo.png', 512),
        ('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48),
        ('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72),
        ('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96),
        ('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144),
        ('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png', 20),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png', 40),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png', 60),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png', 29),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png', 58),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png', 87),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png', 40),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png', 80),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png', 120),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png', 120),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', 180),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png', 76),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png', 152),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png', 167),
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png', 16),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png', 32),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png', 64),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png', 128),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png', 256),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png', 512),
        ('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png', 1024),
    ]
    for rel, size in targets:
        total.append(save(img, os.path.join(ROOT, rel), size))

    arr = np.asarray(img.resize((512, 512), Image.LANCZOS), np.float32)
    print(f'[ok] 主图 {S}x{S}  mean={arr.mean():.1f}  std={arr.std():.1f}')
    print(f'[ok] 共 {len(targets)} 个尺寸，合计 {sum(total)/1024:.0f} KB')


if __name__ == '__main__':
    main()

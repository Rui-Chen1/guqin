"""临时脚本：生成水墨风插画资源（10 首琴曲 + 8 篇文化 + 首页头图）。"""
import math
import os
import random
import traceback

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = "/Users/rachel/Documents/trae_projects/guqin_doc"
OUT = os.path.join(ROOT, "assets/images")
FW, FH = 1200, 800
S = 2
CW, CH = FW * S, FH * S

PAPER_A = (248, 243, 232)
PAPER_B = (228, 215, 191)
INK = (43, 38, 32)
INK_SOFT = (92, 82, 70)
CINNABAR = (158, 59, 47)
JADE = (78, 110, 93)
GOLD = (176, 141, 87)
BONE = (226, 213, 186)
WARM = (226, 166, 108)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


def load_font(size):
    for path in (
        "/System/Library/Fonts/Supplemental/Songti.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
    ):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return None


def paper():
    s = 80
    img = Image.new("RGB", (s, s))
    px = img.load()
    cx, cy = s * 0.34, s * 0.26
    md = math.hypot(s, s)
    for y in range(s):
        for x in range(s):
            d = min(1.0, math.hypot(x - cx, y - cy) / md)
            px[x, y] = mix(PAPER_A, PAPER_B, d ** 0.85)
    return img.resize((CW, CH), Image.BICUBIC).convert("RGBA")


def layer():
    return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))


def add(img, lay, blur=0.0):
    if blur:
        lay = lay.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(img, lay)


def scene(dark=0.0):
    img = paper()
    if dark > 0:
        lay = layer()
        ImageDraw.Draw(lay, "RGBA").rectangle(
            [0, 0, CW, CH], fill=INK + (int(dark * 255),)
        )
        img = Image.alpha_composite(img, lay)
    return img


def ridge(rng, base, amp, octaves=3, step=0.006):
    ph = [rng.uniform(0, math.tau) for _ in range(octaves)]
    pts = []
    n = -0.04
    while n <= 1.04:
        y = base
        for k in range(octaves):
            y += amp * (0.55 ** k) * math.sin(math.tau * (1.6 ** k) * n + ph[k])
        pts.append((n * CW, y * CH))
        n += step
    return pts


def mountain(img, rng, base, amp, octaves=3, color=INK, alpha=180, blur=4.0):
    lay = layer()
    pts = ridge(rng, base, amp, octaves)
    poly = pts + [(pts[-1][0], CH + 80), (pts[0][0], CH + 80)]
    ImageDraw.Draw(lay, "RGBA").polygon(poly, fill=color + (int(alpha),))
    return add(img, lay, blur * S)


def mist(img, rng, y, h, alpha=120):
    """横向云雾带。"""
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    x = -0.1
    while x < 1.1:
        w = rng.uniform(0.25, 0.6)
        d.ellipse(
            [x * CW, (y - h * 0.5) * CH, (x + w) * CW, (y + h * 0.5) * CH],
            fill=(250, 247, 239, alpha),
        )
        x += w * rng.uniform(0.45, 0.8)
    return add(img, lay, 12 * S)


def water(img, rng, top=0.62, rows=22, alpha=34):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    for i in range(rows):
        t = (i + 1) / rows
        y = (top + (1 - top) * (t ** 1.25)) * CH
        a = int(alpha * (0.35 + 0.65 * (1 - t)))
        x = rng.uniform(-0.05, 0.3) * CW
        while x < CW:
            ln = rng.uniform(0.03, 0.16) * CW * (1 - t * 0.3)
            d.line([(x, y), (x + ln, y)], fill=INK + (a,), width=int(1.7 * S))
            x += ln + rng.uniform(0.02, 0.09) * CW
    return add(img, lay, 1.0 * S)


def sun_moon(img, cx, cy, r, color, alpha=95, halo=True):
    rr = r * CW
    px, py = cx * CW, cy * CH
    if halo:
        lay = layer()
        ImageDraw.Draw(lay, "RGBA").ellipse(
            [px - rr * 2.4, py - rr * 2.4, px + rr * 2.4, py + rr * 2.4],
            fill=color + (int(alpha * 0.42),),
        )
        img = add(img, lay, 30 * S)
    lay = layer()
    ImageDraw.Draw(lay, "RGBA").ellipse(
        [px - rr, py - rr, px + rr, py + rr], fill=color + (alpha,)
    )
    return add(img, lay, 1.6 * S)


def branch(img, rng, x0, y0, x1, y1, blos=22, width=9.0):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    n = 16
    pts = []
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t + math.sin(t * 3.4) * 0.028
        y = y0 + (y1 - y0) * (t ** 0.88) + math.cos(t * 4.2) * 0.02
        pts.append((x * CW, y * CH))
    for i in range(len(pts) - 1):
        w = max(2, int((width - width * 0.72 * i / len(pts)) * S / 2))
        d.line([pts[i], pts[i + 1]], fill=INK + (216,), width=w, joint="curve")
    for _ in range(blos):
        i = rng.randint(2, len(pts) - 1)
        bx, by = pts[i]
        ang = rng.uniform(-2.5, -0.55)
        ln = rng.uniform(0.018, 0.07) * CW
        ex, ey = bx + math.cos(ang) * ln, by + math.sin(ang) * ln
        d.line([(bx, by), (ex, ey)], fill=INK + (170,), width=int(2.0 * S))
        rr = rng.uniform(0.005, 0.0105) * CW
        col = CINNABAR if rng.random() < 0.5 else (128, 62, 54)
        d.ellipse([ex - rr, ey - rr, ex + rr, ey + rr], fill=col + (225,))
    return add(img, lay, 0.6 * S)


def geese(img, rng, n=6, cx=0.45, cy=0.18, spread=0.052):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    for i in range(n):
        k = i - (n - 1) / 2
        x = (cx + k * spread + rng.uniform(-0.012, 0.012)) * CW
        y = cy * CH + abs(k) * spread * 0.42 * CH + rng.uniform(-0.01, 0.01) * CH
        r = 0.019 * CW * rng.uniform(0.72, 1.18)
        d.line(
            [(x - r, y + r * 0.5), (x, y), (x + r, y + r * 0.5)],
            fill=INK + (205,),
            width=int(2.4 * S),
            joint="curve",
        )
    return add(img, lay, 0.5 * S)


def boat(img, cx=0.33, cy=0.73, w=0.085):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    ww = w * CW
    px, py = cx * CW, cy * CH
    d.arc([px - ww, py - ww * 0.26, px + ww, py + ww * 0.40], 0, 180,
          fill=INK + (218,), width=int(3.2 * S))
    d.line([(px - ww * 0.78, py), (px + ww * 0.78, py)], fill=INK + (218,), width=int(3.2 * S))
    d.arc([px - ww * 0.40, py - ww * 0.50, px + ww * 0.30, py], 180, 360,
          fill=INK + (200,), width=int(3.0 * S))
    rr = 0.0065 * CW
    d.ellipse([px + ww * 0.44 - rr, py - ww * 0.34 - rr, px + ww * 0.44 + rr, py - ww * 0.34 + rr],
              fill=INK + (218,))
    return add(img, lay, 0.5 * S)


def reeds(img, rng, y_base=0.94, n=18, x_from=0.0, x_to=0.55):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    for _ in range(n):
        x = rng.uniform(x_from, x_to) * CW
        h = rng.uniform(0.10, 0.25) * CH
        yb = y_base * CH + rng.uniform(-0.02, 0.02) * CH
        bend = rng.uniform(-0.028, 0.028) * CW
        d.line([(x, yb), (x + bend * 0.4, yb - h * 0.6), (x + bend, yb - h)],
               fill=INK + (172,), width=max(2, int(1.7 * S)), joint="curve")
    return add(img, lay, 0.7 * S)


def crow(d, cx, cy, s):
    d.ellipse([cx - s * 0.55, cy - s * 0.32, cx + s * 0.55, cy + s * 0.34], fill=INK + (226,))
    d.ellipse([cx + s * 0.34, cy - s * 0.62, cx + s * 0.78, cy - s * 0.20], fill=INK + (226,))
    d.polygon([(cx + s * 0.74, cy - s * 0.50), (cx + s * 1.08, cy - s * 0.38),
               (cx + s * 0.74, cy - s * 0.28)], fill=INK + (226,))
    d.polygon([(cx - s * 0.5, cy - s * 0.06), (cx - s * 1.4, cy - s * 0.32),
               (cx - s * 0.86, cy + s * 0.14)], fill=INK + (226,))


def figure_with_qin(img, cx=0.44, cy=0.80, s=0.10):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    sp = s * CW
    px, py = cx * CW, cy * CH
    d.ellipse([px - sp * 0.15, py - sp * 0.98, px + sp * 0.15, py - sp * 0.66], fill=INK + (212,))
    d.polygon([(px - sp * 0.34, py), (px + sp * 0.34, py),
               (px + sp * 0.19, py - sp * 0.65), (px - sp * 0.19, py - sp * 0.65)], fill=INK + (212,))
    d.polygon([(px - sp * 0.56, py + sp * 0.10), (px + sp * 0.56, py + sp * 0.10),
               (px + sp * 0.34, py - sp * 0.05), (px - sp * 0.34, py - sp * 0.05)], fill=INK + (188,))
    d.line([(px - sp * 0.2, py - sp * 0.46), (px + sp * 0.66, py - sp * 0.24)],
           fill=INK + (212,), width=int(4 * S))
    qx0, qx1 = px - sp * 0.95, px + sp * 1.05
    qy = py + sp * 0.02
    d.rounded_rectangle([qx0, qy, qx1, qy + sp * 0.13], radius=sp * 0.05, fill=INK + (215,))
    for i in range(7):
        yy = qy + sp * (0.02 + 0.015 * i)
        d.line([(qx0 + sp * 0.12, yy), (qx1 - sp * 0.12, yy)], fill=BONE + (110,), width=int(1.2 * S))
    return add(img, lay, 0.7 * S)


QIN_CTRL = [
    (0.00, 0.84), (0.05, 0.97), (0.11, 0.86), (0.17, 0.91), (0.23, 0.81),
    (0.34, 0.94), (0.48, 0.91), (0.56, 0.79), (0.66, 0.93), (0.83, 0.96),
    (0.93, 0.88), (1.00, 0.60),
]


def qin_curve(t):
    ctrl = QIN_CTRL
    if t <= ctrl[0][0]:
        return ctrl[0][1]
    for i in range(len(ctrl) - 1):
        t0, v0 = ctrl[i]
        t1, v1 = ctrl[i + 1]
        if t <= t1:
            u = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            s = (1 - math.cos(math.pi * u)) / 2
            return v0 + (v1 - v0) * s
    return ctrl[-1][1]


def draw_qin(img, x0, x1, cy, half, body=INK, alpha=225, strings=True, hui=True,
             text_ink=BONE, warp=0.0):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    n = 160
    top, bot = [], []
    for i in range(n + 1):
        t = i / n
        h = half * (qin_curve(t) + warp * math.sin(math.tau * t))
        x = x0 + (x1 - x0) * t
        top.append((x, cy - h))
        bot.append((x, cy + h))
    d.polygon(top + bot[::-1], fill=body + (alpha,))
    if hui:
        for i in range(13):
            t = (i + 1) / 14
            x = x0 + (x1 - x0) * (0.10 + 0.80 * t)
            rr = half * 0.075
            col = CINNABAR if i == 6 else GOLD
            d.ellipse([x - rr, cy - half * 1.16 - rr, x + rr, cy - half * 1.16 + rr],
                      fill=col + (200,))
    if strings:
        for i in range(7):
            t = (i + 0.5) / 7
            yy = cy - half * 0.62 + half * 1.24 * t
            d.line([(x0 + (x1 - x0) * 0.06, yy), (x0 + (x1 - x0) * 0.94, yy)],
                   fill=text_ink + (120,), width=max(1, int(1.1 * S)))
    return add(img, lay, 0.5 * S)


def crackle(img, rng, x0, x1, cy, half, n=26):
    """断纹：琴面上的细密纹路。"""
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    for _ in range(n):
        t0 = rng.uniform(0.02, 0.9)
        x = x0 + (x1 - x0) * t0
        y = cy + rng.uniform(-half, half) * qin_curve(t0)
        ln = rng.uniform(0.01, 0.055) * (x1 - x0)
        ang = rng.uniform(-0.9, 0.9)
        d.line([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)],
               fill=GOLD + (70,), width=max(1, int(0.9 * S)))
    return add(img, lay, 0.8 * S)


def seal(img, cx=0.925, cy=0.885, size=0.048):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    w = size * CW
    x, y = cx * CW - w, cy * CH - w
    d.rounded_rectangle([x, y, x + w * 2, y + w * 2], radius=w * 0.16, fill=CINNABAR + (225,))
    d.rounded_rectangle([x + w * 0.2, y + w * 0.2, x + w * 1.8, y + w * 1.8],
                        radius=w * 0.08, outline=PAPER_A + (215,), width=int(w * 0.09))
    return add(img, lay, 0.6 * S)


def strokes(img, rng, n=3, alpha=120):
    """斜向笔锋（用于表现气势）。"""
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    for _ in range(n):
        y0 = rng.uniform(0.1, 0.7)
        d.line([(-0.05 * CW, y0 * CH), (1.05 * CW, (y0 - rng.uniform(0.12, 0.3)) * CH)],
               fill=INK + (alpha,), width=max(2, int(rng.uniform(1.5, 4.0) * S)))
    return add(img, lay, 2.0 * S)


def notation_panel(img):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    d.rectangle([0.07 * CW, 0.06 * CH, 0.93 * CW, 0.94 * CH], fill=INK + (16,))
    cols = 6
    for i in range(cols + 1):
        x = (0.10 + 0.80 * i / cols) * CW
        d.line([(x, 0.10 * CH), (x, 0.90 * CH)], fill=INK_SOFT + (120,), width=int(2.2 * S))
    d.line([(0.10 * CW, 0.10 * CH), (0.90 * CW, 0.10 * CH)], fill=INK_SOFT + (140,), width=int(2.4 * S))
    d.line([(0.10 * CW, 0.90 * CH), (0.90 * CW, 0.90 * CH)], fill=INK_SOFT + (140,), width=int(2.4 * S))
    font = load_font(int(0.115 * CH))
    chars = ['大', '九', '勾', '一', '食', '七', '挑', '二', '中', '十', '抹', '三']
    if font is not None:
        rng = random.Random(7)
        for j in range(2):
            for i in range(cols):
                txt = chars[(j * cols + i) % len(chars)]
                box = d.textbbox((0, 0), txt, font=font)
                cx = (0.10 + 0.80 * (i + 0.5) / cols) * CW + rng.uniform(-8, 8)
                cy = (0.30 + 0.40 * j) * CH + rng.uniform(-8, 8)
                d.text((cx - (box[2] - box[0]) / 2, cy - (box[3] - box[1]) / 2 - box[1]),
                       txt, font=font, fill=INK + (238,))
    else:
        for j in range(2):
            for i in range(cols):
                cx = (0.10 + 0.80 * (i + 0.5) / cols) * CW
                cy = (0.30 + 0.40 * j) * CH
                h = 0.10 * CH
                d.rectangle([cx - h * 0.5, cy - h * 0.5, cx + h * 0.5, cy + h * 0.5],
                            outline=INK + (200,), width=int(2.6 * S))
    return add(img, lay, 0.5 * S)


def wave_band(d, y, amp, decay, freq, alpha, vib=0.0):
    pts = []
    for i in range(0, 420):
        t = i / 420
        x = (0.08 + 0.84 * t) * CW
        env = math.exp(-decay * t)
        v = math.sin(math.tau * freq * t + vib * math.sin(math.tau * 6.0 * t))
        pts.append((x, y * CH + amp * CH * env * v))
    # 音头处的墨晕，增强小尺寸下的辨识度
    d.ellipse([0.06 * CW, y * CH - amp * CH * 1.5, 0.16 * CW, y * CH + amp * CH * 1.5],
              fill=INK + (46,))
    d.line(pts, fill=INK + (alpha,), width=int(3.4 * S), joint="curve")


def wood(img, rng):
    lay = layer()
    d = ImageDraw.Draw(lay, "RGBA")
    for i in range(26):
        x = rng.uniform(0, 1) * CW
        pts = []
        for k in range(30):
            t = k / 29
            pts.append((x + math.sin(t * 4 + i) * 0.012 * CW, t * CH))
        d.line(pts, fill=(120, 96, 66, 34), width=max(2, int(rng.uniform(1.0, 3.2) * S)))
    return add(img, lay, 1.2 * S)


# ---------------- 场景表 ----------------

def piece_scenes():
    return {
        "piece_liushui": lambda r: water(
            mist(mountain(mountain(scene(), r, 0.40, 0.13, 4, INK, 86, 18),
                          r, 0.52, 0.10, 3, INK, 150, 8),
                 r, 0.46, 0.09, 108), r, 0.56, 32, 48),
        "piece_shenrenchang": lambda r: sun_moon(
            mist(mountain(mountain(mountain(scene(), r, 0.36, 0.14, 4, INK, 92, 20),
                                    r, 0.50, 0.12, 4, INK, 150, 10),
                           r, 0.64, 0.10, 3, INK, 202, 5),
                 r, 0.44, 0.10, 112),
            0.76, 0.20, 0.070, (250, 246, 238), 104),
        "piece_meihua": lambda r: branch(
            sun_moon(mountain(scene(), r, 0.42, 0.09, 3, INK, 58, 12),
                     0.80, 0.26, 0.055, (250, 246, 238), 78),
            r, 0.02, 0.99, 0.92, 0.16, 26),
        "piece_pingsha": lambda r: reeds(
            geese(water(mountain(scene(), r, 0.47, 0.08, 3, INK, 56, 12), r, 0.66, 20, 34),
                  r, 7, 0.50, 0.17, 0.055), r, 0.95, 16, 0.0, 0.42),
        "piece_yangguan": lambda r: sun_moon(
            mountain(mountain(mountain(scene(), r, 0.38, 0.09, 3, INK, 52, 16),
                              r, 0.52, 0.10, 3, INK, 92, 9),
                     r, 0.64, 0.11, 3, INK, 150, 4),
            0.72, 0.30, 0.062, WARM, 120),
        "piece_peilan": lambda r: reeds(
            mist(mountain(mountain(scene(), r, 0.46, 0.10, 3, INK, 96, 14),
                          r, 0.58, 0.09, 3, INK, 158, 7),
                 r, 0.52, 0.10, 110), r, 0.97, 30, 0.30, 1.0),
        "piece_jiukuang": lambda r: reeds(
            sun_moon(mountain(mountain(scene(0.03), r, 0.44, 0.12, 4, INK, 120, 12),
                              r, 0.60, 0.10, 4, INK, 190, 5),
                     0.76, 0.22, 0.058, (250, 246, 238), 92),
            r, 0.97, 24, 0.0, 0.9),
        "piece_kongziduyi": lambda r: figure_with_qin(
            sun_moon(mountain(mountain(scene(0.04), r, 0.42, 0.11, 4, INK, 108, 16),
                              r, 0.56, 0.10, 3, INK, 176, 7),
                     0.74, 0.22, 0.062, (250, 246, 238), 100),
            0.42, 0.80, 0.105),
        "piece_zuiyu": lambda r: boat(
            water(sun_moon(mountain(scene(), r, 0.42, 0.09, 3, INK, 54, 14),
                           0.80, 0.28, 0.058, WARM, 110), r, 0.62, 24, 40),
            0.34, 0.74, 0.09),
        "piece_qiufengci": lambda r: branch(
            sun_moon(mountain(scene(0.03), r, 0.44, 0.09, 3, INK, 52, 14),
                     0.72, 0.26, 0.070, (250, 246, 238), 96),
            r, 0.03, 0.98, 0.68, 0.34, 12, 7.5),
    }


def article_scenes():
    def structure(r):
        img = scene()
        img = draw_qin(img, 0.08 * CW, 0.92 * CW, 0.52 * CH, 0.085 * CH)
        return crackle(img, r, 0.08 * CW, 0.92 * CW, 0.52 * CH, 0.085 * CH, 22)

    def forms(r):
        img = scene()
        for i, warp in enumerate((0.02, -0.03, 0.05)):
            cy = (0.28 + 0.24 * i) * CH
            img = draw_qin(img, 0.12 * CW, 0.88 * CW, cy, 0.052 * CH,
                           alpha=200 - i * 18, warp=warp)
        return img

    def craft(r):
        img = wood(scene(), r)
        img = draw_qin(img, 0.10 * CW, 0.90 * CW, 0.55 * CH, 0.10 * CH,
                       body=(96, 74, 50), alpha=190, strings=False, hui=False)
        return crackle(img, r, 0.10 * CW, 0.90 * CW, 0.55 * CH, 0.10 * CH, 30)

    def spirit(r):
        img = sun_moon(mountain(mountain(scene(0.03), r, 0.46, 0.11, 3, INK, 100, 16),
                                r, 0.62, 0.09, 3, INK, 170, 6),
                       0.74, 0.22, 0.062, (250, 246, 238), 96)
        return figure_with_qin(img, 0.42, 0.82, 0.10)

    def schools(r):
        img = scene()
        for i, (b, a, bl) in enumerate(((0.30, 58, 26), (0.42, 88, 18),
                                        (0.53, 126, 11), (0.63, 168, 5))):
            img = mountain(img, r, b, 0.12, 4, INK, a, bl)
        return img

    def timbre(r):
        img = scene()
        lay = layer()
        d = ImageDraw.Draw(lay, "RGBA")
        wave_band(d, 0.26, 0.085, 1.7, 5.0, 195)
        wave_band(d, 0.50, 0.070, 2.6, 5.0, 195, vib=0.6)
        wave_band(d, 0.74, 0.055, 1.2, 13.0, 195)
        return add(img, lay, 1.0 * S)

    def history(r):
        return boat(sun_moon(mountain(mountain(scene(), r, 0.48, 0.10, 3, INK, 62, 14),
                                      r, 0.62, 0.09, 3, INK, 130, 6),
                             0.22, 0.24, 0.055, (250, 246, 238), 82),
                    0.36, 0.76, 0.075)

    return {
        "article_history-3000": history,
        "article_structure": structure,
        "article_forms": forms,
        "article_schools": schools,
        "article_craft": craft,
        "article_spirit": spirit,
        "article_notation": lambda r: notation_panel(scene()),
        "article_timbre": timbre,
    }


def hero():
    r = random.Random(2026)
    img = scene()
    img = mist(mountain(mountain(mountain(img, r, 0.34, 0.12, 4, INK, 62, 26),
                                 r, 0.46, 0.11, 4, INK, 100, 17),
                        r, 0.58, 0.10, 3, INK, 148, 9),
               r, 0.40, 0.09, 120)
    img = sun_moon(img, 0.20, 0.26, 0.062, (250, 246, 238), 96)
    img = draw_qin(img, 0.14 * CW, 0.86 * CW, 0.86 * CH, 0.062 * CH, alpha=215)
    return img


def finish(img, name, grain=0.5, vig=0.20):
    m = Image.new("L", (CW, CH), 0)
    ImageDraw.Draw(m).ellipse([-CW * 0.18, -CH * 0.22, CW * 1.18, CH * 1.22], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(CW, CH) * 0.09))
    dark = Image.new("RGBA", (CW, CH), (58, 48, 36, 255))
    dark.putalpha(m.point(lambda p: int((255 - p) * vig)))
    img = Image.alpha_composite(img, dark)
    if grain > 0:
        n = Image.effect_noise((CW, CH), 24).point(lambda v: int(max(0, v - 128) * grain))
        gl = Image.new("RGBA", (CW, CH), INK + (0,))
        gl.putalpha(n)
        img = Image.alpha_composite(img, gl)
    out = img.convert("RGB").resize((FW, FH), Image.LANCZOS)
    path = os.path.join(OUT, name + ".jpg")
    out.save(path, "JPEG", quality=86, optimize=True, progressive=True)
    return os.path.getsize(path) // 1024


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    jobs = list(piece_scenes().items()) + list(article_scenes().items())
    for name, fn in jobs:
        try:
            img = fn(random.Random(hash(name) & 0xFFFF))
            kb = finish(seal(img) if name.startswith("piece_") else img, name)
            total += kb
            print(f"  ok  {name}.jpg  {kb} KB")
        except Exception:
            print(f"  !!  {name} 失败")
            traceback.print_exc()
    kb = finish(hero(), "hero_home", grain=0.42, vig=0.16)
    total += kb
    print(f"  ok  hero_home.jpg  {kb} KB")
    print(f"合计约 {total / 1024:.1f} MB")


if __name__ == "__main__":
    main()

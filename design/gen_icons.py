# -*- coding: utf-8 -*-
"""用 Pillow 手绘三版扁平几何风的「识曲」App 图标，4x 超采样保证边缘锐利。"""
import math
import colorsys
import numpy as np
from PIL import Image, ImageDraw

S = 4           # 超采样倍率
SZ = 1024       # 输出尺寸
W = SZ * S
OUT = r"D:\HarmonyOS\Harmonymusic\design"


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient_bg(c1, c2, vertical=False):
    """对角线/垂直双色渐变底"""
    n = W
    t = np.linspace(0, 1, n)
    if vertical:
        grad = np.zeros((n, n, 3), np.uint8)
        for i, ti in enumerate(t):
            grad[i, :, :] = lerp(c1, c2, ti)
    else:
        tt = (np.add.outer(t, t) / 2)
        grad = np.zeros((n, n, 3), np.uint8)
        for k in range(3):
            grad[:, :, k] = (c1[k] + (c2[k] - c1[k]) * tt).astype(np.uint8)
    return Image.fromarray(grad, "RGB")


def rounded_bar(dr, cx, cy, w, h, color):
    dr.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2],
                         radius=w / 2, fill=color)


# ---------------- 方案 A：渐变底 + 白色律动音柱 ----------------
def icon_a():
    img = gradient_bg((79, 70, 229), (168, 85, 247))  # 靛蓝 -> 紫
    dr = ImageDraw.Draw(img)
    n = 9
    span = W * 0.56
    bw = span / n * 0.52
    # 音高包络：中间高两边低，带一点律动不对称
    env = [0.30, 0.44, 0.62, 0.86, 1.00, 0.72, 0.92, 0.52, 0.36]
    max_h = W * 0.46
    for i in range(n):
        cx = W / 2 - span / 2 + span / (n - 1) * i
        h = max_h * env[i]
        color = (255, 255, 255) if i != 6 else (253, 224, 71)  # 一根黄色点睛
        rounded_bar(dr, cx, W / 2, bw, h, color)
    return img


# ---------------- 方案 B：暗夜底 + 环形声纹 ----------------
def icon_b():
    img = Image.new("RGB", (W, W), (10, 10, 16))
    dr = ImageDraw.Draw(img)
    cx = cy = W / 2
    n = 72
    r_base = W * 0.30
    bar_w = int(W * 0.011)
    rng = np.random.RandomState(7)
    seed = rng.rand(n)
    for i in range(n):
        ang = 2 * math.pi * i / n
        # 平滑的声纹包络
        e = 0.5 + 0.5 * math.sin(ang * 3 + 1.2) * math.sin(ang * 5)
        e = 0.35 + 0.65 * (0.55 * e + 0.45 * seed[i])
        length = W * (0.05 + 0.11 * e)
        r1, r2 = r_base, r_base + length
        hue = 0.52 + 0.38 * (i / n)          # 青 -> 品红
        col = tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(hue % 1, 0.75, 1.0))
        x1, y1 = cx + r1 * math.cos(ang), cy + r1 * math.sin(ang)
        x2, y2 = cx + r2 * math.cos(ang), cy + r2 * math.sin(ang)
        dr.line([x1, y1, x2, y2], fill=col, width=bar_w)
        r = bar_w / 2
        dr.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=col)
        dr.ellipse([x2 - r, y2 - r, x2 + r, y2 + r], fill=col)
    # 中央播放键：白圆 + 深色三角
    pr = W * 0.135
    dr.ellipse([cx - pr, cy - pr, cx + pr, cy + pr], fill=(245, 245, 250))
    tw = pr * 0.78
    th = pr * 0.92
    off = pr * 0.10
    tri = [(cx - tw / 2 + off, cy - th / 2), (cx - tw / 2 + off, cy + th / 2), (cx + tw / 2 + off, cy)]
    dr.polygon(tri, fill=(10, 10, 16))
    return img


# ---------------- 方案 C：明黄底 + 黑色粗音柱（大字报式的年轻感） ----------------
def icon_c():
    img = Image.new("RGB", (W, W), (255, 209, 30))
    dr = ImageDraw.Draw(img)
    n = 7
    span = W * 0.58
    bw = span / n * 0.55
    env = [0.42, 0.70, 1.00, 0.55, 0.88, 0.60, 0.38]
    max_h = W * 0.44
    for i in range(n):
        cx = W / 2 - span / 2 + span / (n - 1) * i
        h = max_h * env[i]
        rounded_bar(dr, cx, W / 2, bw, h, (17, 17, 20))
    # 底部一条短横线当「地平线」，增加构成感
    lw = W * 0.20
    ly = W * 0.80
    dr.rounded_rectangle([W / 2 - lw / 2, ly, W / 2 + lw / 2, ly + bw], radius=bw / 2, fill=(17, 17, 20))
    return img


for name, fn in [("v4_pulse", icon_a), ("v5_ring", icon_b), ("v6_yellow", icon_c)]:
    im = fn().resize((SZ, SZ), Image.LANCZOS)
    p = rf"{OUT}\shiqu_icon_{name}.png"
    im.save(p)
    print("saved", p)

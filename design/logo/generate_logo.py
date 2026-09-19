# -*- coding: utf-8 -*-
"""生成轻舟 App「上岸」图标。

产出（与本脚本同目录）：
  logo_primary.png / logo_cream.png / logo_dark.png  圆角母版 1024
  logo_primary_bleed.png                              全出血方形（Android 自适应图标用）
  logo.svg                                            主色版矢量（字形已转路径，不依赖查看器字体）
  preview.png                                         三套配色预览板
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
S = 1024
RADIUS = 224  # 圆角母版的圆角半径

FONT_XK = "C:/Windows/Fonts/STXINGKA.TTF"  # 华文行楷：上岸
FONT_KAI = "C:/Windows/Fonts/STKAITI.TTF"  # 华文楷体：印章
FONT_EN = "C:/Windows/Fonts/arialbd.ttf"

CHARS = "上岸"
CHAR_GAP = 40
CHAR_SIZE = 330
CHAR_CY = 424
STROKE_W = 6  # 行楷笔画偏细，同色描边加粗

PINYIN = "QINGZHOU"
PINYIN_SIZE = 34
PINYIN_Y = 664
PINYIN_TRACK = 16

SEAL_CHARS = "轻舟"
SEAL_SIZE = 124
SEAL_CENTER = (818, 792)
SEAL_ROT = -4

# 三道水波纹：y 基线 / 振幅 / 波长 / 相位 / 线宽 / 透明度
WAVES = [
    (738, 10, 340, 0.0, 4, 40),
    (796, 13, 300, 1.8, 3, 32),
    (852, 9, 380, 3.6, 3, 27),
]

COLORWAYS = {
    "primary": dict(
        grad=("#4C7371", "#426464", "#34504E"),
        text="#FBF9F3",
        wave=(255, 255, 255),
        pinyin=(255, 255, 255, 118),
        seal="#995C5C",
        seal_text="#F7EFE6",
    ),
    "cream": dict(
        grad=("#F8F4EB", "#F0EADD", "#E7DFCE"),
        text="#426464",
        wave=(66, 100, 100),
        pinyin=(66, 100, 100, 150),
        seal="#995C5C",
        seal_text="#F8F4EB",
    ),
    "dark": dict(
        grad=("#1C2726", "#192322", "#141D1C"),
        text="#EDF4F2",
        wave=(107, 155, 155),
        pinyin=(107, 155, 155, 155),
        seal="#A96B6B",
        seal_text="#141D1C",
    ),
}


def _hex(c):
    c = c.lstrip("#")
    return tuple(int(c[i : i + 2], 16) for i in (0, 2, 4))


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(c1, c2, c3):
    """对角三段渐变，低分辨率生成后平滑放大。"""
    small = Image.new("RGB", (129, 129))
    px = small.load()
    a, b, c = _hex(c1), _hex(c2), _hex(c3)
    for y in range(129):
        for x in range(129):
            t = (x + y) / 256
            color = _mix(a, b, t * 2) if t < 0.5 else _mix(b, c, (t - 0.5) * 2)
            px[x, y] = color
    return small.resize((S, S), Image.BILINEAR)


def draw_waves(img, rgb, alphas):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for (base, amp, wl, phase, width, alpha), a in zip(WAVES, alphas):
        points = []
        for x in range(72, S - 72, 2):
            y = base + amp * math.sin(2 * math.pi * x / wl + phase)
            points.append((x, y))
        d.line(points, fill=rgb + (a,), width=width, joint="curve")
    img.alpha_composite(layer)


def draw_chars(img, font_path, text, size, color, cy, gap, tracking=0):
    """按紧致包围盒逐字水平居中绘制，同色描边加粗。"""
    font = ImageFont.truetype(font_path, size)
    d = ImageDraw.Draw(img)
    widths = []
    boxes = []
    for ch in text:
        bb = d.textbbox((0, 0), ch, font=font, stroke_width=STROKE_W)
        boxes.append(bb)
        widths.append(bb[2] - bb[0])
    total = sum(widths) + gap * (len(text) - 1) + tracking * (len(text) - 1)
    x = (S - total) / 2
    for ch, bb, w in zip(text, boxes, widths):
        d.text(
            (x - bb[0], cy - (bb[1] + bb[3]) / 2),
            ch,
            font=font,
            fill=color,
            stroke_width=STROKE_W,
            stroke_fill=color,
        )
        x += w + gap + tracking
    return total


def draw_pinyin(img, color):
    font = ImageFont.truetype(FONT_EN, PINYIN_SIZE)
    d = ImageDraw.Draw(img)
    widths = []
    for ch in PINYIN:
        bb = d.textbbox((0, 0), ch, font=font)
        widths.append(bb[2] - bb[0])
    total = sum(widths) + PINYIN_TRACK * (len(PINYIN) - 1)
    x = (S - total) / 2
    for ch, w in zip(PINYIN, widths):
        d.text((x, PINYIN_Y), ch, font=font, fill=color, anchor="lm")
        x += w + PINYIN_TRACK


def draw_seal(img, fill, text_color):
    """右下「轻舟」小印，砖红圆角方章，轻微旋转。"""
    pad = 10
    tile = Image.new("RGBA", (SEAL_SIZE + pad * 2, SEAL_SIZE + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle(
        (pad, pad, pad + SEAL_SIZE, pad + SEAL_SIZE),
        radius=18,
        fill=fill,
    )
    font = ImageFont.truetype(FONT_KAI, 44)
    cx = pad + SEAL_SIZE / 2
    for i, ch in enumerate(SEAL_CHARS):
        d.text(
            (cx, pad + SEAL_SIZE * (0.30 + 0.40 * i)),
            ch,
            font=font,
            fill=text_color,
            anchor="mm",
        )
    tile = tile.rotate(SEAL_ROT, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(
        tile,
        (int(SEAL_CENTER[0] - tile.width / 2), int(SEAL_CENTER[1] - tile.height / 2)),
    )


def render(name, bleed=False):
    cw = COLORWAYS[name]
    img = gradient(*cw["grad"]).convert("RGBA")

    # 顶部一层极淡的光晕，避免渐变过于呆板
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((152, -260, S - 152, 300), fill=(255, 255, 255, 16))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img.alpha_composite(glow)

    draw_waves(img, cw["wave"], [w[5] for w in WAVES])
    draw_pinyin(img, cw["pinyin"])
    draw_seal(
        img,
        _hex(cw["seal"]) + (238,),
        _hex(cw["seal_text"]) + (255,),
    )
    draw_chars(img, FONT_XK, CHARS, CHAR_SIZE, cw["text"], CHAR_CY, CHAR_GAP)

    if bleed:
        img.convert("RGB").save(os.path.join(OUT, f"logo_{name}_bleed.png"))
    else:
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, S, S), radius=RADIUS, fill=255)
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        out.save(os.path.join(OUT, f"logo_{name}.png"))


def preview():
    names = ["primary", "cream", "dark"]
    card = 340
    gap = 48
    W = gap * 4 + card * 3
    H = card + 150
    board = Image.new("RGBA", (W, H), "#E9E7E2")
    d = ImageDraw.Draw(board)
    font = ImageFont.truetype(FONT_KAI, 26)
    labels = {"primary": "主色版", "cream": "纸色版", "dark": "暗色版"}
    for i, name in enumerate(names):
        logo = Image.open(os.path.join(OUT, f"logo_{name}.png")).resize(
            (card, card), Image.LANCZOS
        )
        x = gap + i * (card + gap)
        board.alpha_composite(logo, (x, gap))
        d.text(
            (x + card / 2, gap + card + 52),
            labels[name],
            font=font,
            fill="#5A5A5A",
            anchor="mm",
        )
    board.convert("RGB").save(os.path.join(OUT, "preview.png"))


def svg():
    """矢量主色版：字形经 fontTools 转为路径，不依赖查看端字体。"""
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.ttLib import TTFont

    def glyph_path(font_path, ch, size_px):
        font = TTFont(font_path)
        cmap = font.getBestCmap()
        glyph_set = font.getGlyphSet()
        glyph = glyph_set[cmap[ord(ch)]]
        upm = font["head"].unitsPerEm
        scale = size_px / upm
        bp = BoundsPen(glyph_set)
        glyph.draw(bp)
        (x0, y0, x1, y1) = bp.bounds
        pen = SVGPathPen(glyph_set)
        glyph.draw(pen)
        return pen.getCommands(), scale, (x0, y0, x1, y1)

    def glyph_group(font_path, text, size_px, cx, cy, gap, fill, stroke_px):
        """多字水平居中排版并转为 SVG 路径（y 轴翻转）。"""
        out = []
        widths = []
        glyphs = []
        for ch in text:
            d, s, b = glyph_path(font_path, ch, size_px)
            glyphs.append((d, s, b))
            widths.append((b[2] - b[0]) * s)
        total = sum(widths) + gap * (len(text) - 1)
        x = cx - total / 2
        stroke_units = stroke_px / glyphs[0][1]
        for d, s, b in glyphs:
            h = (b[3] - b[1]) * s
            tx = x - b[0] * s
            ty = cy - h / 2 + b[3] * s
            out.append(
                f'<path transform="translate({tx:.1f} {ty:.1f}) scale({s:.5f} {-s:.5f})" '
                f'd="{d}" fill="{fill}" stroke="{fill}" '
                f'stroke-width="{stroke_units:.1f}" stroke-linejoin="round"/>'
            )
            x += (b[2] - b[0]) * s + gap
        return "".join(out)

    chars_svg = glyph_group(
        FONT_XK, CHARS, CHAR_SIZE, S / 2, CHAR_CY, CHAR_GAP,
        COLORWAYS["primary"]["text"], STROKE_W,
    )
    seal_svg = (
        glyph_group(
            FONT_KAI, "轻", 44, SEAL_CENTER[0], SEAL_CENTER[1] - 25, 0,
            COLORWAYS["primary"]["seal_text"], 1.5,
        )
        + glyph_group(
            FONT_KAI, "舟", 44, SEAL_CENTER[0], SEAL_CENTER[1] + 25, 0,
            COLORWAYS["primary"]["seal_text"], 1.5,
        )
    )

    waves = []
    for base, amp, wl, phase, width, alpha in WAVES:
        segs = []
        n = 72
        for i in range(n + 1):
            x0 = 72 + (S - 144) * i / n
            y0 = base + amp * math.sin(2 * math.pi * x0 / wl + phase)
            segs.append(f"{x0:.1f} {y0:.1f}")
        waves.append(
            f'<polyline points="{" ".join(segs)}" fill="none" '
            f'stroke="#FFFFFF" stroke-opacity="{alpha / 255:.2f}" '
            f'stroke-width="{width}" stroke-linecap="round"/>'
        )

    seal_fill = COLORWAYS["primary"]["seal"]
    svg_text = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{COLORWAYS["primary"]["grad"][0]}"/>
      <stop offset="0.5" stop-color="{COLORWAYS["primary"]["grad"][1]}"/>
      <stop offset="1" stop-color="{COLORWAYS["primary"]["grad"][2]}"/>
    </linearGradient>
    <clipPath id="card"><rect width="{S}" height="{S}" rx="{RADIUS}"/></clipPath>
  </defs>
  <g clip-path="url(#card)">
    <rect width="{S}" height="{S}" fill="url(#bg)"/>
    <ellipse cx="{S / 2}" cy="20" rx="{S / 2 - 150}" ry="280" fill="#FFFFFF" fill-opacity="0.06"/>
    {"".join(waves)}
    <g transform="rotate({SEAL_ROT} {SEAL_CENTER[0]} {SEAL_CENTER[1]})">
      <rect x="{SEAL_CENTER[0] - SEAL_SIZE / 2}" y="{SEAL_CENTER[1] - SEAL_SIZE / 2}"
            width="{SEAL_SIZE}" height="{SEAL_SIZE}" rx="18" fill="{seal_fill}" fill-opacity="0.93"/>
      {seal_svg}
    </g>
    <text x="{S / 2}" y="{PINYIN_Y + PINYIN_SIZE / 2}" font-family="Arial, sans-serif" font-weight="bold"
          font-size="{PINYIN_SIZE}" letter-spacing="{PINYIN_TRACK + 4}" fill="#FFFFFF" fill-opacity="0.46"
          text-anchor="middle">{PINYIN}</text>
    {chars_svg}
  </g>
</svg>
'''
    with open(os.path.join(OUT, "logo.svg"), "w", encoding="utf-8") as f:
        f.write(svg_text)


if __name__ == "__main__":
    for name in COLORWAYS:
        render(name)
    render("primary", bleed=True)
    preview()
    svg()
    print("generated:", sorted(os.listdir(OUT)))

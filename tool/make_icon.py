"""Pomento 앱 아이콘 생성기.

구성은 글래스모피즘 그대로다. 뒤에 색이 번지는 배경을 깔고, 그 위에 반투명한
유리 원을 얹고, 유리 안에 EQ 막대를 세운다. 유리는 뒤에 볼 것이 있어야
유리로 보이기 때문에 배경의 색 번짐이 장식이 아니라 필수다.

막대 높이는 이 앱의 기본 곡선을 닮게 잡았다. 가운데가 높고 양 끝이 낮다.

    python tool/make_icon.py
    python tool/install_icons.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")

SIZE = 1024
SS = 3  # 슈퍼샘플링 배수
S = SIZE * SS

BG_BASE = (11, 11, 15)
ACCENT = (165, 180, 252)
VIOLET = (124, 92, 255)
PINK = (255, 143, 177)
CYAN = (94, 231, 223)

# EQ 막대. (가로 위치 0~1, 높이 0~1, accent 여부)
BARS = [
    (0.12, 0.42, False),
    (0.31, 0.68, False),
    (0.50, 1.00, True),
    (0.69, 0.60, False),
    (0.88, 0.34, False),
]


def blurred_background(size: int) -> Image.Image:
    """어두운 바탕에 색 덩어리를 흩뿌리고 크게 흐린다."""
    img = Image.new("RGBA", (size, size), BG_BASE + (255,))

    blobs = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(blobs)

    def blob(cx, cy, r, color, alpha):
        d.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=color + (alpha,),
        )

    # 왼쪽 위가 밝고 오른쪽 아래로 갈수록 어두워지게 배치한다.
    blob(size * 0.26, size * 0.24, size * 0.34, ACCENT, 235)
    blob(size * 0.70, size * 0.20, size * 0.26, VIOLET, 210)
    blob(size * 0.78, size * 0.66, size * 0.30, PINK, 165)
    blob(size * 0.18, size * 0.78, size * 0.24, ACCENT, 130)
    blob(size * 0.52, size * 0.56, size * 0.24, PINK, 110)

    blobs = blobs.filter(ImageFilter.GaussianBlur(size * 0.115))
    img.alpha_composite(blobs)

    # 아래쪽을 눌러서 유리와 막대가 뜨게 한다.
    shade = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for y in range(size):
        t = y / (size - 1)
        sd.line([(0, y), (size, y)], fill=(0, 0, 0, int(120 * (t**1.6))))
    img.alpha_composite(shade)
    return img


def _composite(base: Image.Image, layer: Image.Image) -> None:
    base.alpha_composite(layer)


def glass_disc(size: int, radius: float) -> Image.Image:
    """가운데에 놓일 반투명 유리 원. 배경 위에 얹으면 뒤가 비친다."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = cy = size / 2
    box = [cx - radius, cy - radius, cx + radius, cy + radius]

    # 유리 면
    face = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(face).ellipse(box, fill=(255, 255, 255, 48))
    _composite(layer, face)

    # 왼쪽 위에서 빛이 드는 느낌. 흐린 흰 덩어리를 원 안에만 남긴다.
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    sd.ellipse(
        [
            cx - radius * 1.05,
            cy - radius * 1.35,
            cx + radius * 0.35,
            cy + radius * 0.05,
        ],
        fill=(255, 255, 255, 62),
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(radius * 0.20))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    sheen.putalpha(
        Image.composite(sheen.getchannel("A"), Image.new("L", (size, size), 0), mask)
    )
    _composite(layer, sheen)

    # 테두리. 위쪽이 밝고 아래로 갈수록 어두워진다.
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse(
        box, outline=(255, 255, 255, 255), width=int(radius * 0.028)
    )
    grad = Image.new("L", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        t = (y - (cy - radius)) / (2 * radius)
        t = min(max(t, 0.0), 1.0)
        gd.line([(0, y), (size, y)], fill=int(200 - 150 * t))
    ring.putalpha(
        Image.composite(grad, Image.new("L", (size, size), 0), ring.getchannel("A"))
    )
    _composite(layer, ring)

    return layer


def eq_bars(size: int, radius: float) -> Image.Image:
    """유리 안에 세우는 EQ 막대."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx = cy = size / 2
    span = radius * 1.06  # 막대가 놓이는 가로 폭
    bar_w = span / (len(BARS) * 2.1)
    max_h = radius * 1.12
    baseline = cy + max_h * 0.42

    for pos, height, is_accent in BARS:
        x = cx - span / 2 + span * pos
        h = max_h * height
        top = baseline - h
        color = ACCENT + (255,) if is_accent else (255, 255, 255, 232)
        d.rounded_rectangle(
            [x - bar_w / 2, top, x + bar_w / 2, baseline],
            radius=bar_w / 2,
            fill=color,
        )

    # accent 막대에만 은은한 빛을 준다.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for pos, height, is_accent in BARS:
        if not is_accent:
            continue
        x = cx - span / 2 + span * pos
        h = max_h * height
        gd.rounded_rectangle(
            [x - bar_w / 2, baseline - h, x + bar_w / 2, baseline],
            radius=bar_w / 2,
            fill=ACCENT + (190,),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.08))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(layer)
    return out


def foreground(size: int, radius: float) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.alpha_composite(glass_disc(size, radius))
    layer.alpha_composite(eq_bars(size, radius))
    return layer


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    bg = blurred_background(S)

    # 1) 전체 아이콘: 배경 + 유리 + 막대. iOS와 구형 안드로이드가 쓴다.
    full = bg.copy()
    full.alpha_composite(foreground(S, S * 0.30))
    full.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(
        os.path.join(OUT_DIR, "icon.png")
    )

    # 2) 적응형 아이콘 전경. 바깥이 잘리므로 가운데 66% 안에 담는다.
    foreground(S, S * 0.205).resize((SIZE, SIZE), Image.LANCZOS).save(
        os.path.join(OUT_DIR, "icon_foreground.png")
    )

    # 3) 적응형 아이콘 배경.
    bg.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(
        os.path.join(OUT_DIR, "icon_background.png")
    )

    print("wrote", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()

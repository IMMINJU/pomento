"""Pomento 앱 아이콘 생성기.

레터마크 하나다. Newsreader로 찍은 `P.` 를 남색 바탕에 올린다.

그림으로 가려던 시도를 여러 번 접었다. LP판, 레코드 축, 영사기, 음표 다
그려봤는데 축소하면 무엇인지 모르겠거나 다른 앱과 닮았다. 글자는 그럴
일이 없고, 마침표가 붙어서 `Po`로도 읽히고 문장의 끝으로도 읽힌다.

그림자와 그라디언트를 넣지 않는다. 단색으로 밀어야 목록에서 또렷하다.

글자 위치는 눈금으로 맞추지 않고 **잉크의 실제 경계를 재서** 맞춘다.
서체의 사이드 베어링과 `P`의 오른쪽 여백 때문에 글자 상자 기준으로 가운데
정렬하면 왼쪽으로 치우쳐 보인다.

    python tool/make_icon.py
    python tool/install_icons.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(ROOT, "assets", "icon")
FONT = os.path.join(ROOT, "assets", "fonts", "Newsreader-Medium.ttf")

SIZE = 1024
SS = 2  # 슈퍼샘플링 배수
S = SIZE * SS

# 시안의 --brand. 화면에서는 쓰지 않고 아이콘에만 쓴다
BRAND = (0x26, 0x32, 0x5C)
INK = (0xFB, 0xFC, 0xF9)

MARK = "P."

# 글자 크기. 아이콘 한 변에 대한 비율
MARK_SCALE = 0.53

# 적응형 아이콘의 안전 영역. 108dp 중 가운데 72dp만 항상 보인다.
# 전경을 그 안에 넣어야 원형이든 사각형이든 잘리지 않는다
SAFE = 72 / 108


def draw_mark(size: int, scale: float) -> Image.Image:
    """투명 바탕에 글자만 그린다. 잉크 경계를 재서 한가운데에 놓는다."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    font = ImageFont.truetype(FONT, int(size * scale))
    d = ImageDraw.Draw(img)

    # 실제로 칠해지는 영역. anchor를 쓰지 않고 직접 잰다
    left, top, right, bottom = d.textbbox((0, 0), MARK, font=font)
    x = (size - (right - left)) / 2 - left
    y = (size - (bottom - top)) / 2 - top

    d.text((x, y), MARK, font=font, fill=INK + (255,))
    return img


def flatten(fg: Image.Image, bg_color) -> Image.Image:
    out = Image.new("RGBA", fg.size, bg_color + (255,))
    out.alpha_composite(fg)
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    if not os.path.exists(FONT):
        raise SystemExit("Newsreader가 없다. assets/fonts를 먼저 채울 것")

    # ── 일반 아이콘 ──
    mark = draw_mark(S, MARK_SCALE)
    icon = flatten(mark, BRAND).resize((SIZE, SIZE), Image.LANCZOS)
    icon.convert("RGB").save(os.path.join(OUT_DIR, "icon.png"))

    # ── 적응형 배경 ──
    bg = Image.new("RGB", (SIZE, SIZE), BRAND)
    bg.save(os.path.join(OUT_DIR, "icon_background.png"))

    # ── 적응형 전경 ──
    # 안전 영역 안에 들어가야 하므로 글자를 그만큼 줄인다
    fg = draw_mark(S, MARK_SCALE * SAFE).resize((SIZE, SIZE), Image.LANCZOS)
    fg.save(os.path.join(OUT_DIR, "icon_foreground.png"))

    for name in ("icon.png", "icon_background.png", "icon_foreground.png"):
        path = os.path.join(OUT_DIR, name)
        print("  %-24s %d KB" % (name, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()

"""Pomento 런치 스크린 이미지 생성기.

Flutter 기본값은 1x1 투명 이미지에 순백 바탕이라, 앱을 열면 흰 화면이
번쩍하고 나서 미색 종이가 나온다. 그 사이의 색 차이가 눈에 띈다.

그래서 종이색 위에 아이콘과 같은 `P.` 를 남색으로 찍는다. 아이콘은 남색
바탕에 밝은 글자지만 여기서는 뒤집는다. 이 화면 다음에 오는 것이 종이라
바탕을 종이로 두어야 이어진다.

글자 위치는 아이콘과 같은 방법으로 잡는다. 눈금이 아니라 잉크의 실제
경계를 재서 놓는다. 사이드 베어링 때문에 글자 상자 기준으로 맞추면
왼쪽으로 치우친다.

    python tool/make_launch.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Newsreader-Medium.ttf")

IOS_DIR = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset"
)
AND_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# lib/ui/theme.dart의 brand. 아이콘과 같은 남색이다
BRAND = (0x26, 0x32, 0x5C)

MARK = "P."

# @1x 기준 글자 높이(pt). 화면 한가운데 놓이므로 크게 두지 않는다.
# 96pt면 아이폰에서 앱 아이콘 두 개쯤 되는 크기다
MARK_PT = 96

SS = 4  # 슈퍼샘플링 배수

# 안드로이드는 dp가 밀도마다 배수가 다르다
ANDROID_SCALES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}


def draw_mark(px: int) -> Image.Image:
    """투명 바탕에 글자만 그린다. 잉크 경계에 딱 맞는 크기로 잘라 낸다."""
    big = px * SS
    # 글자가 잘리지 않도록 넉넉한 판에 그린 뒤 실제 경계로 자른다
    canvas = Image.new("RGBA", (big * 2, big * 2), (0, 0, 0, 0))
    font = ImageFont.truetype(FONT, big)
    d = ImageDraw.Draw(canvas)
    d.text((big // 2, big // 2), MARK, font=font, fill=BRAND + (255,))

    box = canvas.getbbox()
    if box is None:
        raise SystemExit("글자가 안 그려졌다")
    cropped = canvas.crop(box)

    w = max(1, round(cropped.width / SS))
    h = max(1, round(cropped.height / SS))
    return cropped.resize((w, h), Image.LANCZOS)


def main() -> None:
    if not os.path.exists(FONT):
        raise SystemExit("Newsreader가 없다. assets/fonts를 먼저 채울 것")

    base = draw_mark(MARK_PT)
    print("  @1x 잉크 크기 %dx%d" % (base.width, base.height))

    # ── iOS ──
    # 스토리보드가 contentMode=center로 놓으므로 배수만 맞추면 된다
    for suffix, scale in (("", 1), ("@2x", 2), ("@3x", 3)):
        img = draw_mark(MARK_PT * scale)
        path = os.path.join(IOS_DIR, "LaunchImage%s.png" % suffix)
        img.save(path)
        print("  ios  %-22s %dx%d" % (os.path.basename(path), *img.size))

    # ── Android ──
    # launch_background.xml이 mipmap/launch_image를 가운데 놓는다
    for density, scale in ANDROID_SCALES.items():
        img = draw_mark(round(MARK_PT * scale))
        out = os.path.join(AND_RES, "mipmap-%s" % density)
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, "launch_image.png")
        img.save(path)
        print("  and  %-22s %dx%d" % ("%s/launch_image.png" % density, *img.size))

    print("\n  스토리보드의 <image name=\"LaunchImage\" width= height=> 를")
    print("  %d %d 로 맞출 것" % (base.width, base.height))


if __name__ == "__main__":
    main()

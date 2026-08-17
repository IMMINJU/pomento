"""만들어둔 아이콘을 안드로이드와 iOS 자리에 굽는다.

flutter_launcher_icons를 쓰지 않는다. 이 프로젝트의 다른 의존성과 물려서
옛 버전으로 내려앉기 때문이다. 필요한 일이 크기 조절과 XML 몇 개라 직접 한다.

    python tool/make_icon.py
    python tool/install_icons.py
"""

import io
import json
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ICON_DIR = os.path.join(ROOT, "assets", "icon")
ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ICONSET = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)

# 안드로이드 밀도별 배수. 런처 아이콘 기준 크기는 48dp.
DENSITIES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""


def save_scaled(src: Image.Image, path: str, size: int, rgb: bool) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = src.resize((size, size), Image.LANCZOS)
    if rgb:
        img = img.convert("RGB")
    img.save(path)


def do_android() -> None:
    full = Image.open(os.path.join(ICON_DIR, "icon.png")).convert("RGBA")
    fg = Image.open(os.path.join(ICON_DIR, "icon_foreground.png")).convert("RGBA")
    bg = Image.open(os.path.join(ICON_DIR, "icon_background.png")).convert("RGBA")

    for name, mult in DENSITIES.items():
        d = os.path.join(ANDROID_RES, f"mipmap-{name}")
        # 구형 런처가 쓰는 정사각 아이콘. 48dp 기준.
        save_scaled(full, os.path.join(d, "ic_launcher.png"), round(48 * mult), True)
        save_scaled(
            full, os.path.join(d, "ic_launcher_round.png"), round(48 * mult), True
        )
        # 적응형 아이콘 레이어는 108dp 기준이다.
        save_scaled(
            fg, os.path.join(d, "ic_launcher_foreground.png"), round(108 * mult), False
        )
        save_scaled(
            bg, os.path.join(d, "ic_launcher_background.png"), round(108 * mult), True
        )

    anydpi = os.path.join(ANDROID_RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with io.open(os.path.join(anydpi, name), "w", encoding="utf-8") as f:
            f.write(ADAPTIVE_XML)

    print("android icons written")


def do_ios() -> None:
    contents_path = os.path.join(IOS_ICONSET, "Contents.json")
    if not os.path.exists(contents_path):
        print("ios iconset not found, skipped")
        return

    # iOS 아이콘에 알파 채널이 있으면 앱 심사에서 거부된다.
    full = Image.open(os.path.join(ICON_DIR, "icon.png")).convert("RGB")

    with io.open(contents_path, encoding="utf-8") as f:
        contents = json.load(f)

    for image in contents.get("images", []):
        filename = image.get("filename")
        size = image.get("size")
        scale = image.get("scale")
        if not filename or not size or not scale:
            continue
        base = float(size.split("x")[0])
        mult = float(scale.rstrip("x"))
        px = round(base * mult)
        out = os.path.join(IOS_ICONSET, filename)
        full.resize((px, px), Image.LANCZOS).save(out)

    print("ios icons written")


if __name__ == "__main__":
    do_android()
    do_ios()

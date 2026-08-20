"""종이 질감 타일 두 장을 굽는다.

CSS 시안은 feTurbulence를 mix-blend-mode로 얹었다. Flutter에서 blend mode를
쓰면 saveLayer가 걸려 보급형 안드로이드에서 프레임이 떨어진다. 대신 결과를
알파에 미리 구워서 일반 합성(srcOver)으로 그린다.

밝은 바탕 위에서 곱하기는 알파 합성과 결과가 같다.

    곱하기:  B x (1 - a + a*g)
    알파:    B x (1 - a*(1-g)) + 0 x a*(1-g)

두 식이 같으므로 검정을 알파 a*(1-g)로 얹으면 곱하기와 구분되지 않는다.
얼룩은 soft-light라 정확히는 안 맞는데, 바탕 밝기를 0.96으로 고정하고
1차 근사한 값을 쓴다. 실제로 눈에 보이는 차이는 255단계에서 서너 단계다.

    python tool/make_paper.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "paper")

# 종이 밝기. 얼룩을 구울 때 기준으로 삼는다
PAPER_L = 0.96


def value_noise(size: int, cells: int, rng: np.random.Generator) -> np.ndarray:
    """이어붙여도 이음매가 없는 값 잡음 한 겹."""
    grid = rng.random((cells, cells), dtype=np.float64)
    # 가장자리를 되감아 타일이 서로 맞물리게 한다
    grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")

    t = np.linspace(0, cells, size, endpoint=False)
    i0 = np.floor(t).astype(int)
    f = t - i0
    # 3f^2-2f^3. 셀 경계에서 기울기가 0이라 격자 무늬가 안 생긴다
    w = f * f * (3 - 2 * f)

    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0 + 1, i0)]
    c = grid[np.ix_(i0, i0 + 1)]
    d = grid[np.ix_(i0 + 1, i0 + 1)]

    wx = w[:, None]
    wy = w[None, :]
    return (a * (1 - wx) + b * wx) * (1 - wy) + (c * (1 - wx) + d * wx) * wy


def fractal(size: int, cells: int, octaves: int, rng: np.random.Generator,
            spread: float = 1.3) -> np.ndarray:
    """옥타브를 겹쳐 feTurbulence fractalNoise에 가깝게 만든다."""
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        c = cells * (2**o)
        if c > size:
            break
        total += value_noise(size, c, rng) * amp
        norm += amp
        amp *= 0.5
    total /= norm
    # 0.5를 가운데 두고 폭을 넓힌다. 너무 벌리면 0과 1에 몰려
    # 소금후추처럼 거칠어진다
    return np.clip((total - total.mean()) * spread + 0.5, 0.0, 1.0)


def save_rgba(path: str, rgb: np.ndarray, alpha: np.ndarray) -> None:
    h, w = alpha.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(rgb * 255 + 0.5, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path, optimize=True)
    print(f"  {os.path.basename(path)}  {w}x{h}  {os.path.getsize(path) // 1024}KB")


def make_grain(rng: np.random.Generator) -> None:
    """알갱이. 한 텍셀이 화면 한 픽셀이 되게 깐다.

    CSS의 baseFrequency 0.75는 1.3픽셀짜리 잡음이다. 옥타브를 굵게 잡으면
    필름 그레인이 아니라 모래알이 되어 화면이 지글거린다. 가장 센 옥타브를
    2픽셀로 두고 그 위에 한 겹만 얹는다.
    """
    size = 320
    g = fractal(size, size // 2, 2, rng, spread=1.0)
    # 7%면 밝기가 17단계로 오르내려 화면이 지글거린다. 4.5%도 11단계라
    # 여전히 보였다. 2.4%면 진폭이 6단계이고, 평균 어두워짐이 3단계라
    # 종이가 시안과 같은 명도로 앉는다.
    alpha = 0.024 * (1.0 - g)
    rgb = np.zeros((size, size, 3))  # 검정
    save_rgba(os.path.join(OUT, "grain.png"), rgb, alpha)


def make_mottle(rng: np.random.Generator) -> None:
    """얼룩. 460 논리픽셀. 종이 섬유처럼 아주 옅은 색점이 섞인다."""
    size = 460
    g = fractal(size, 9, 3, rng, spread=1.2)

    d = (g - 0.5) * 2.0  # -1 .. 1
    up = d > 0

    # 밝은 쪽과 어두운 쪽의 세기를 맞춘다. 흰색은 종이(0.96)와 0.04밖에
    # 차이가 안 나고 어두운 색은 0.5 넘게 차이가 나서, 같은 알파를 주면
    # 어두운 얼룩만 튀어 때처럼 보인다
    warm = np.array([1.00, 0.99, 0.95])
    cool = np.array([0.45, 0.48, 0.44])
    a_up = 0.13   # (1.00 - 0.96) x 0.13 = +0.5%
    a_dn = 0.014  # (0.45 - 0.96) x 0.014 = -0.7%

    rgb = np.zeros((size, size, 3))
    rgb[up] = warm
    rgb[~up] = cool
    alpha = np.where(up, a_up, a_dn) * np.abs(d)

    save_rgba(os.path.join(OUT, "mottle.png"), rgb, alpha)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    # 씨앗을 고정해야 다시 구웠을 때 같은 종이가 나온다
    rng = np.random.default_rng(20260819)
    print("종이 타일을 굽는다")
    make_grain(rng)
    make_mottle(rng)


if __name__ == "__main__":
    main()

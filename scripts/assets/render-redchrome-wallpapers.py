#!/usr/bin/env python3
"""Generate deterministic red/silver chrome branding PNG assets."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SIZE = (1920, 1080)
GLYPHS = {
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "N": ("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
}


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def blend(dst: bytearray, width: int, x: int, y: int, color: tuple[int, int, int], alpha: float) -> None:
    if x < 0 or y < 0 or x >= width or y >= len(dst) // (width * 3):
        return
    offset = (y * width + x) * 3
    inv = 1.0 - alpha
    dst[offset] = int(dst[offset] * inv + color[0] * alpha)
    dst[offset + 1] = int(dst[offset + 1] * inv + color[1] * alpha)
    dst[offset + 2] = int(dst[offset + 2] * inv + color[2] * alpha)


def draw_line(
    pixels: bytearray,
    width: int,
    p0: tuple[float, float],
    p1: tuple[float, float],
    color: tuple[int, int, int],
    thickness: int,
    alpha: float,
) -> None:
    x0, y0 = p0
    x1, y1 = p1
    steps = max(1, int(math.hypot(x1 - x0, y1 - y0)))
    radius = max(1, thickness // 2)
    for step in range(steps + 1):
        t = step / steps
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        for yy in range(y - radius, y + radius + 1):
            for xx in range(x - radius, x + radius + 1):
                d = math.hypot(xx - x, yy - y)
                if d <= radius:
                    blend(pixels, width, xx, yy, color, alpha * (1.0 - d / (radius + 1)))


def draw_polyline(
    pixels: bytearray,
    width: int,
    points: list[tuple[float, float]],
    color: tuple[int, int, int],
    thickness: int,
    alpha: float,
) -> None:
    for left, right in zip(points, points[1:]):
        draw_line(pixels, width, left, right, color, thickness, alpha)


def draw_rect(
    pixels: bytearray,
    width: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    color: tuple[int, int, int],
    alpha: float,
) -> None:
    height = len(pixels) // (width * 3)
    for y in range(max(0, y0), min(height, y1)):
        for x in range(max(0, x0), min(width, x1)):
            blend(pixels, width, x, y, color, alpha)


def draw_glyph_text(
    pixels: bytearray,
    width: int,
    x: int,
    y: int,
    text: str,
    scale: int,
    color: tuple[int, int, int],
) -> None:
    cursor = x
    for char in text:
        glyph = GLYPHS[char]
        for row_index, row in enumerate(glyph):
            for col_index, bit in enumerate(row):
                if bit == "1":
                    draw_rect(
                        pixels,
                        width,
                        cursor + col_index * scale,
                        y + row_index * scale,
                        cursor + (col_index + 1) * scale,
                        y + (row_index + 1) * scale,
                        color,
                        1.0,
                    )
        cursor += (len(glyph[0]) + 1) * scale


def make_watermark(text: str, red: tuple[int, int, int]) -> bytes:
    width, height = 187, 72
    pixels = bytearray(width * height * 3)
    for y in range(height):
        yy = y / (height - 1)
        for x in range(width):
            xx = x / (width - 1)
            color = mix((3, 3, 4), (24, 25, 27), 0.44 * xx + 0.32 * yy)
            offset = (y * width + x) * 3
            pixels[offset : offset + 3] = bytes(color)

    scale = 4
    text_width = (len(text) * 5 + (len(text) - 1)) * scale
    x = (width - text_width) // 2
    draw_glyph_text(pixels, width, x + 1, 15 + 1, text, scale, (0, 0, 0))
    draw_glyph_text(pixels, width, x, 15, text, scale, (232, 237, 240))
    draw_rect(pixels, width, x, 50, x + text_width, 55, red, 1.0)
    draw_rect(pixels, width, x + 12, 58, x + text_width - 12, 61, (176, 184, 190), 1.0)
    return bytes(pixels)


def make_wallpaper(red: tuple[int, int, int], title_width: int, *, draw_badge: bool = False) -> bytes:
    width, height = SIZE
    pixels = bytearray(width * height * 3)
    for y in range(height):
        yy = y / (height - 1)
        for x in range(width):
            xx = x / (width - 1)
            base = mix((14, 15, 17), (48, 51, 55), 0.42 * xx + 0.36 * yy)
            vignette = math.hypot(xx - 0.5, yy - 0.45)
            color = mix(base, (4, 4, 5), min(0.72, vignette * 0.82))
            if x % 90 == 0 or y % 90 == 0:
                color = mix(color, (210, 216, 220), 0.06)
            if (x + y) % 180 == 0:
                color = mix(color, red, 0.055)
            offset = (y * width + x) * 3
            pixels[offset : offset + 3] = bytes(color)

    wave = [(x, 710 + 90 * math.sin(x / 160) + 46 * math.sin(x / 59)) for x in range(-80, width + 90, 18)]
    draw_polyline(pixels, width, wave, (226, 233, 236), 11, 0.58)
    red_wave = [(x, y + 23) for x, y in wave]
    draw_polyline(pixels, width, red_wave, red, 6, 0.9)

    return bytes(pixels)


def resize_rgb(src: bytes, src_width: int, src_height: int, width: int, height: int) -> bytes:
    out = bytearray(width * height * 3)
    for y in range(height):
        sy = min(src_height - 1, int(y * src_height / height))
        for x in range(width):
            sx = min(src_width - 1, int(x * src_width / width))
            src_offset = (sy * src_width + sx) * 3
            dst_offset = (y * width + x) * 3
            out[dst_offset : dst_offset + 3] = src[src_offset : src_offset + 3]
    return bytes(out)


def crop_rgb(src: bytes, src_width: int, x0: int, y0: int, width: int, height: int) -> bytes:
    out = bytearray(width * height * 3)
    for y in range(height):
        src_offset = ((y0 + y) * src_width + x0) * 3
        dst_offset = y * width * 3
        out[dst_offset : dst_offset + width * 3] = src[src_offset : src_offset + width * 3]
    return bytes(out)


def png_bytes(width: int, height: int, pixels: bytes) -> bytes:
    raw = b"".join(b"\x00" + pixels[y * width * 3 : (y + 1) * width * 3] for y in range(height))

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(raw, 6))
    out += chunk(b"IEND", b"")
    return out


def main() -> int:
    targets = [
        (
            "demuntu",
            ROOT / "packages/meta/demuntu-meta/branding",
            (215, 25, 32),
            540,
        ),
        (
            "demian",
            ROOT / "packages/meta/demian-meta/branding",
            (200, 15, 24),
            500,
        ),
    ]
    asset_targets = []
    for family, package_root, red, title_width in targets:
        wallpaper = make_wallpaper(red, title_width)
        boot_wallpaper = make_wallpaper(red, title_width, draw_badge=False)
        watermark = make_watermark(family.upper(), red)
        asset_targets.extend(
            [
                (
                    package_root / f"usr/share/backgrounds/{family}/{family}-default.png",
                    SIZE,
                    wallpaper,
                ),
                (
                    package_root / f"usr/share/backgrounds/{family}/{family}-grub.png",
                    (1024, 768),
                    resize_rgb(boot_wallpaper, *SIZE, 1024, 768),
                ),
                (
                    package_root / f"usr/share/plymouth/themes/{family}-chrome/splash.png",
                    SIZE,
                    wallpaper,
                ),
                (
                    package_root / f"usr/share/plymouth/themes/{family}-chrome/logo.png",
                    (720, 260),
                    resize_rgb(crop_rgb(wallpaper, SIZE[0], 600, 330, 720, 300), 720, 300, 720, 260),
                ),
                (
                    ROOT / f"assets/boot/{family}-isolinux.png",
                    (640, 480),
                    resize_rgb(boot_wallpaper, *SIZE, 640, 480),
                ),
                (
                    ROOT / f"assets/boot/{family}-plymouth-watermark.png",
                    (187, 72),
                    watermark,
                ),
            ]
        )

    for path, (width, height), pixels in asset_targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(png_bytes(width, height, pixels))
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

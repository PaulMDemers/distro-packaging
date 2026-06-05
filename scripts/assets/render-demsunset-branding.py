#!/usr/bin/env python3
"""Generate deterministic sunset grey/orange/pink Demuntu branding PNG assets."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SIZE = (1920, 1080)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def blend_pixel(
    pixels: bytearray,
    width: int,
    x: int,
    y: int,
    color: tuple[int, int, int],
    alpha: float,
) -> None:
    height = len(pixels) // (width * 3)
    if x < 0 or y < 0 or x >= width or y >= height:
        return
    offset = (y * width + x) * 3
    inv = 1.0 - alpha
    pixels[offset] = int(pixels[offset] * inv + color[0] * alpha)
    pixels[offset + 1] = int(pixels[offset + 1] * inv + color[1] * alpha)
    pixels[offset + 2] = int(pixels[offset + 2] * inv + color[2] * alpha)


def draw_soft_ellipse(
    pixels: bytearray,
    width: int,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    color: tuple[int, int, int],
    alpha: float,
) -> None:
    x0 = int(max(0, cx - rx * 1.15))
    x1 = int(min(width, cx + rx * 1.15))
    height = len(pixels) // (width * 3)
    y0 = int(max(0, cy - ry * 1.15))
    y1 = int(min(height, cy + ry * 1.15))
    for y in range(y0, y1):
        dy = (y - cy) / ry
        for x in range(x0, x1):
            dx = (x - cx) / rx
            d = dx * dx + dy * dy
            if d <= 1.35:
                edge = max(0.0, 1.0 - d / 1.35)
                blend_pixel(pixels, width, x, y, color, alpha * edge * edge)


def draw_band(
    pixels: bytearray,
    width: int,
    base_y: float,
    amplitude: float,
    color: tuple[int, int, int],
    alpha: float,
    thickness: float,
    phase: float,
) -> None:
    height = len(pixels) // (width * 3)
    for x in range(width):
        yy = base_y
        yy += amplitude * math.sin((x + phase) / 170.0)
        yy += amplitude * 0.45 * math.sin((x - phase) / 71.0)
        for y in range(max(0, int(yy - thickness)), min(height, int(yy + thickness))):
            d = abs(y - yy) / thickness
            blend_pixel(pixels, width, x, y, color, alpha * max(0.0, 1.0 - d) ** 1.6)


def make_wallpaper() -> bytes:
    width, height = SIZE
    pixels = bytearray(width * height * 3)
    top = (20, 21, 26)
    mid = (47, 48, 55)
    horizon = (227, 116, 52)
    low = (42, 37, 42)

    for y in range(height):
        yy = y / (height - 1)
        for x in range(width):
            xx = x / (width - 1)
            if yy < 0.48:
                color = mix(top, mid, yy / 0.48)
            elif yy < 0.72:
                color = mix(mid, horizon, (yy - 0.48) / 0.24)
            else:
                color = mix(horizon, low, (yy - 0.72) / 0.28)

            glow = math.exp(-((yy - 0.67) ** 2) / 0.018) * math.exp(-((xx - 0.55) ** 2) / 0.20)
            color = mix(color, (255, 142, 72), glow * 0.38)

            rose = math.exp(-((yy - 0.50) ** 2) / 0.012) * (0.7 + 0.3 * math.sin(x / 115.0))
            color = mix(color, (235, 91, 132), rose * 0.28)

            vignette = math.hypot(xx - 0.52, yy - 0.52)
            color = mix(color, (8, 8, 11), min(0.48, vignette * 0.42))

            grain = ((x * 37 + y * 19 + (x * y) % 31) % 17) - 8
            color = tuple(max(0, min(255, c + grain // 5)) for c in color)
            offset = (y * width + x) * 3
            pixels[offset : offset + 3] = bytes(color)

    for cx, cy, rx, ry, color, alpha in [
        (330, 385, 470, 95, (32, 33, 39), 0.75),
        (760, 330, 650, 120, (25, 26, 32), 0.62),
        (1280, 360, 560, 110, (32, 31, 37), 0.70),
        (1560, 455, 510, 120, (47, 40, 48), 0.58),
        (1020, 515, 760, 82, (235, 91, 132), 0.18),
        (920, 590, 720, 96, (255, 143, 58), 0.20),
    ]:
        draw_soft_ellipse(pixels, width, cx, cy, rx, ry, color, alpha)

    for args in [
        (442, 33, (236, 106, 139), 0.30, 42, 20),
        (504, 38, (212, 217, 218), 0.12, 28, 160),
        (585, 26, (255, 132, 59), 0.28, 52, 90),
        (690, 18, (239, 182, 125), 0.14, 34, 230),
    ]:
        draw_band(pixels, width, *args)

    return bytes(pixels)


def make_watermark() -> bytes:
    width, height = 187, 72
    pixels = bytearray(width * height * 3)
    for y in range(height):
        yy = y / (height - 1)
        for x in range(width):
            xx = x / (width - 1)
            color = mix((16, 17, 21), (50, 47, 55), 0.45 * xx + 0.35 * yy)
            offset = (y * width + x) * 3
            pixels[offset : offset + 3] = bytes(color)

    draw_soft_ellipse(pixels, width, 62, 36, 44, 18, (242, 93, 132), 0.45)
    draw_soft_ellipse(pixels, width, 115, 42, 58, 20, (245, 127, 53), 0.44)
    draw_band(pixels, width, 48, 4, (226, 230, 230), 0.42, 4, 12)
    draw_band(pixels, width, 54, 3, (238, 104, 139), 0.65, 3, 40)
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


def write_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png_bytes(width, height, pixels))
    print(path)


def main() -> int:
    package_root = ROOT / "packages/meta/demuntu-meta/branding"
    wallpaper = make_wallpaper()
    watermark = make_watermark()

    write_png(
        package_root / "usr/share/backgrounds/demuntu/demuntu-default.png",
        *SIZE,
        wallpaper,
    )
    write_png(
        package_root / "usr/share/backgrounds/demuntu/demuntu-sunset.png",
        *SIZE,
        wallpaper,
    )
    write_png(
        package_root / "usr/share/backgrounds/demuntu/demuntu-grub.png",
        1024,
        768,
        resize_rgb(wallpaper, *SIZE, 1024, 768),
    )
    write_png(
        package_root / "usr/share/plymouth/themes/demuntu-sunset/splash.png",
        *SIZE,
        wallpaper,
    )
    write_png(
        package_root / "usr/share/plymouth/themes/demuntu-sunset/logo.png",
        720,
        260,
        resize_rgb(crop_rgb(wallpaper, SIZE[0], 600, 330, 720, 300), 720, 300, 720, 260),
    )
    write_png(
        ROOT / "assets/boot/demuntu-isolinux.png",
        640,
        480,
        resize_rgb(wallpaper, *SIZE, 640, 480),
    )
    write_png(
        ROOT / "assets/boot/demuntu-plymouth-watermark.png",
        187,
        72,
        watermark,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

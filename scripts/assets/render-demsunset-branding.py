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


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")
    print(path)


def svg_doc(body: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" '
        'viewBox="0 0 64 64">\n'
        f"{body}\n"
        "</svg>\n"
    )


def folder_svg(glyph: str = "") -> str:
    return svg_doc(
        '  <path d="M7 19h18l5 6h27v8H7z" fill="#4a4a52"/>\n'
        '  <path d="M7 27h50v26H7z" fill="#303138"/>\n'
        '  <path d="M7 27h50v26H7z" fill="none" stroke="#d7dadd" '
        'stroke-width="2.5" stroke-linejoin="round"/>\n'
        '  <path d="M12 34h40v14H12z" fill="#ef7d35"/>\n'
        '  <path d="M12 44h40v4H12z" fill="#ec5c86"/>\n'
        f"{glyph}"
    )


def home_svg() -> str:
    return svg_doc(
        '  <path d="M9 32 32 13l23 19-4 5-19-16-19 16z" fill="#ef7d35"/>\n'
        '  <path d="M16 31h32v24H16z" fill="#303138" stroke="#d7dadd" '
        'stroke-width="2.5" stroke-linejoin="round"/>\n'
        '  <path d="M27 42h10v13H27z" fill="#ec5c86"/>\n'
        '  <path d="M21 35h9v7h-9zM34 35h9v7h-9z" fill="#4a4a52"/>'
    )


def trash_svg(full: bool) -> str:
    fill = "#ec5c86" if full else "#4a4a52"
    inner = '  <path d="M22 30h20v18H22z" fill="#ef7d35"/>\n' if full else ""
    return svg_doc(
        '  <path d="M22 13h20l2 5h9v6H11v-6h9z" fill="#d7dadd"/>\n'
        f'  <path d="M16 24h32l-3 29H19z" fill="{fill}" stroke="#d7dadd" '
        'stroke-width="2.5" stroke-linejoin="round"/>\n'
        f"{inner}"
        '  <path d="M25 30v17M32 30v17M39 30v17" stroke="#303138" '
        'stroke-width="3" stroke-linecap="round"/>'
    )


def computer_svg() -> str:
    return svg_doc(
        '  <path d="M10 13h44v31H10z" fill="#303138" stroke="#d7dadd" '
        'stroke-width="2.5" stroke-linejoin="round"/>\n'
        '  <path d="M15 18h34v20H15z" fill="#1b1c22"/>\n'
        '  <path d="M18 34h28v4H18z" fill="#ef7d35"/>\n'
        '  <path d="M26 44h12l2 7h7v4H17v-4h7z" fill="#4a4a52"/>\n'
        '  <path d="M20 29h24v3H20z" fill="#ec5c86"/>'
    )


def start_here_svg() -> str:
    return svg_doc(
        '  <circle cx="32" cy="32" r="26" fill="#303138" stroke="#d7dadd" '
        'stroke-width="3"/>\n'
        '  <path d="M32 14 38 27h14L41 36l4 14-13-8-13 8 4-14-11-9h14z" '
        'fill="#ef7d35"/>\n'
        '  <path d="M26 27h12l3 9-9 6-9-6z" fill="#ec5c86"/>'
    )


def app_logo_svg(letter: str = "D") -> str:
    return svg_doc(
        '  <rect x="9" y="9" width="46" height="46" rx="12" fill="#303138" '
        'stroke="#d7dadd" stroke-width="3"/>\n'
        '  <path d="M17 43c8-11 17-15 30-17v17z" fill="#ef7d35"/>\n'
        '  <path d="M17 38c8-8 18-10 30-9v8c-12-1-22 1-30 8z" fill="#ec5c86"/>\n'
        f'  <text x="32" y="36" text-anchor="middle" font-family="Sans,Arial" '
        f'font-size="22" font-weight="700" fill="#f2f0ef">{letter}</text>'
    )


def category_svg(kind: str) -> str:
    glyphs = {
        "accessories": '  <path d="M21 42 42 21" stroke="#f2f0ef" stroke-width="5" stroke-linecap="round"/>\n'
        '  <circle cx="44" cy="19" r="6" fill="#ec5c86"/>',
        "development": '  <path d="M25 22 15 32l10 10M39 22l10 10-10 10" fill="none" stroke="#f2f0ef" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>\n'
        '  <path d="M35 19 29 45" stroke="#ec5c86" stroke-width="4" stroke-linecap="round"/>',
        "education": '  <path d="M13 28 32 18l19 10-19 10z" fill="#f2f0ef"/>\n'
        '  <path d="M21 35v8c7 4 15 4 22 0v-8" fill="#ec5c86"/>',
        "games": '  <path d="M19 27h26c5 0 8 4 8 10 0 5-3 9-7 9-4 0-5-4-8-4H26c-3 0-4 4-8 4s-7-4-7-9c0-6 3-10 8-10z" fill="#f2f0ef"/>\n'
        '  <path d="M21 33v8M17 37h8" stroke="#303138" stroke-width="3" stroke-linecap="round"/>\n'
        '  <circle cx="40" cy="36" r="3" fill="#ec5c86"/><circle cx="47" cy="39" r="3" fill="#ef7d35"/>',
        "graphics": '  <path d="M17 42c6-15 14-24 27-26 6 10 2 22-9 28-7 4-13 3-18-2z" fill="#f2f0ef"/>\n'
        '  <circle cx="37" cy="26" r="4" fill="#ec5c86"/><circle cx="29" cy="35" r="4" fill="#ef7d35"/>',
        "internet": '  <circle cx="32" cy="32" r="17" fill="none" stroke="#f2f0ef" stroke-width="4"/>\n'
        '  <path d="M15 32h34M32 15c7 7 7 27 0 34M32 15c-7 7-7 27 0 34" fill="none" stroke="#ec5c86" stroke-width="3"/>',
        "multimedia": '  <path d="M22 18v28l25-14z" fill="#f2f0ef"/>\n'
        '  <rect x="15" y="46" width="34" height="5" rx="2.5" fill="#ec5c86"/>',
        "office": '  <path d="M20 14h20l8 8v28H20z" fill="#f2f0ef"/>\n'
        '  <path d="M40 14v9h8" fill="#d7dadd"/>\n'
        '  <path d="M26 31h16M26 38h16M26 45h10" stroke="#303138" stroke-width="3" stroke-linecap="round"/>',
        "science": '  <path d="M26 15h12M30 15v13L19 48h26L34 28V15" fill="none" stroke="#f2f0ef" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>\n'
        '  <path d="M25 41h14" stroke="#ec5c86" stroke-width="5" stroke-linecap="round"/>',
        "system": '  <circle cx="32" cy="32" r="8" fill="#303138"/>\n'
        '  <path d="M32 13 37 23l11-1-4 10 7 9-11 2-6 9-7-9-11-2 7-9-4-10 11 1z" fill="#f2f0ef" fill-rule="evenodd"/>\n'
        '  <circle cx="32" cy="32" r="6" fill="#ec5c86"/>',
        "other": '  <circle cx="23" cy="23" r="6" fill="#f2f0ef"/><circle cx="41" cy="23" r="6" fill="#ec5c86"/>\n'
        '  <circle cx="23" cy="41" r="6" fill="#ef7d35"/><circle cx="41" cy="41" r="6" fill="#f2f0ef"/>',
    }
    glyph = glyphs.get(kind, glyphs["other"])
    return svg_doc(
        '  <rect x="9" y="9" width="46" height="46" rx="10" fill="#303138" '
        'stroke="#d7dadd" stroke-width="2.5"/>\n'
        '  <path d="M13 46c9-12 22-17 38-15v15z" fill="#ef7d35"/>\n'
        '  <path d="M13 40c10-8 22-10 38-7v7c-15-3-28-1-38 8z" fill="#ec5c86"/>\n'
        f"{glyph}"
    )


def write_demsunset_icons(package_root: Path) -> None:
    icon_root = package_root / "usr/share/icons/DemSunset/scalable"
    place_glyphs = {
        "folder.svg": "",
        "folder-desktop.svg": '  <path d="M22 36h20v10H22z" fill="#303138" stroke="#f2f0ef" stroke-width="2"/>\n'
        '  <path d="M28 47h8l2 3H26z" fill="#f2f0ef"/>',
        "user-desktop.svg": '  <path d="M22 36h20v10H22z" fill="#303138" stroke="#f2f0ef" stroke-width="2"/>\n'
        '  <path d="M28 47h8l2 3H26z" fill="#f2f0ef"/>',
        "folder-documents.svg": '  <path d="M24 34h13l5 5v11H24z" fill="#f2f0ef"/>\n'
        '  <path d="M37 34v6h5" fill="#d7dadd"/>\n'
        '  <path d="M28 42h10M28 47h8" stroke="#303138" stroke-width="2" stroke-linecap="round"/>',
        "folder-download.svg": '  <path d="M32 34v12M25 40l7 7 7-7" fill="none" stroke="#f2f0ef" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>',
        "folder-music.svg": '  <path d="M39 34v11a5 5 0 1 1-3-4V34z" fill="#f2f0ef"/>\n'
        '  <path d="M39 34 48 32v5l-9 2z" fill="#ec5c86"/>',
        "folder-pictures.svg": '  <path d="M21 35h24v15H21z" fill="#f2f0ef"/>\n'
        '  <path d="M24 47 31 39l5 5 3-3 5 6z" fill="#303138"/>\n'
        '  <circle cx="40" cy="39" r="2" fill="#ef7d35"/>',
        "folder-publicshare.svg": '  <circle cx="27" cy="38" r="4" fill="#f2f0ef"/><circle cx="39" cy="38" r="4" fill="#f2f0ef"/>\n'
        '  <path d="M21 49c2-5 10-5 12 0M33 49c2-5 10-5 12 0" fill="none" stroke="#f2f0ef" stroke-width="3" stroke-linecap="round"/>',
        "folder-remote.svg": '  <path d="M21 42h22" stroke="#f2f0ef" stroke-width="3" stroke-linecap="round"/>\n'
        '  <circle cx="22" cy="42" r="4" fill="#f2f0ef"/><circle cx="32" cy="35" r="4" fill="#ec5c86"/><circle cx="43" cy="42" r="4" fill="#f2f0ef"/>',
        "folder-saved-search.svg": '  <circle cx="30" cy="40" r="7" fill="none" stroke="#f2f0ef" stroke-width="4"/>\n'
        '  <path d="M35 45 43 51" stroke="#f2f0ef" stroke-width="4" stroke-linecap="round"/>',
        "folder-templates.svg": '  <path d="M22 35h20v14H22z" fill="#f2f0ef"/>\n'
        '  <path d="M27 35v14M32 35v14M37 35v14" stroke="#303138" stroke-width="2"/>',
        "folder-videos.svg": '  <path d="M21 35h24v16H21z" fill="#f2f0ef"/>\n'
        '  <path d="M30 39v8l8-4z" fill="#ec5c86"/>',
    }
    for name, glyph in place_glyphs.items():
        write_text(icon_root / "places" / name, folder_svg(glyph))

    write_text(icon_root / "places/user-home.svg", home_svg())
    write_text(icon_root / "places/user-trash.svg", trash_svg(False))
    write_text(icon_root / "places/user-trash-full.svg", trash_svg(True))
    write_text(icon_root / "devices/computer.svg", computer_svg())
    write_text(icon_root / "apps/start-here.svg", start_here_svg())
    write_text(icon_root / "apps/distributor-logo-demuntu.svg", app_logo_svg("D"))

    category_map = {
        "applications-accessories.svg": "accessories",
        "applications-development.svg": "development",
        "applications-education.svg": "education",
        "applications-games.svg": "games",
        "applications-graphics.svg": "graphics",
        "applications-internet.svg": "internet",
        "applications-multimedia.svg": "multimedia",
        "applications-office.svg": "office",
        "applications-other.svg": "other",
        "applications-science.svg": "science",
        "applications-system.svg": "system",
        "applications-utilities.svg": "accessories",
        "preferences-desktop.svg": "system",
        "preferences-system.svg": "system",
        "system-tools.svg": "system",
    }
    for name, kind in category_map.items():
        write_text(icon_root / "categories" / name, category_svg(kind))


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
    write_demsunset_icons(package_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

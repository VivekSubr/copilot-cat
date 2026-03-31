"""Generate placeholder MSIX icon PNGs for Copilot Cat.

Usage:
    pip install Pillow
    python pkg/gen_icons.py

Generates placeholder icons in pkg/Assets/ with the cat's body color
(#7f849c) and "CC" text. Replace these with real artwork before
submitting to the Microsoft Store.

Falls back to writing minimal valid PNGs (solid color, no text) if
Pillow is not installed.
"""

import os
import struct
import zlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(SCRIPT_DIR, "Assets")

# Catppuccin-inspired palette
BG_COLOR = (0x7F, 0x84, 0x9C)       # body color
TEXT_COLOR = (0xCD, 0xD6, 0xF4)      # light text
OUTLINE_COLOR = (0x45, 0x47, 0x5A)   # outline/border

ICONS = [
    ("Square44x44Logo.png",   44,  44),
    ("Square150x150Logo.png", 150, 150),
    ("Wide310x150Logo.png",   310, 150),
    ("Square310x310Logo.png", 310, 310),
    ("StoreLogo.png",          50,  50),
    ("LargeTile.png",         310, 310),
]


def generate_with_pillow():
    """Generate icons using Pillow (nice text rendering)."""
    from PIL import Image, ImageDraw, ImageFont

    os.makedirs(ASSETS_DIR, exist_ok=True)

    for filename, w, h in ICONS:
        img = Image.new("RGBA", (w, h), BG_COLOR + (255,))
        draw = ImageDraw.Draw(img)

        # Draw a border
        border = max(1, min(w, h) // 20)
        draw.rectangle(
            [border, border, w - border - 1, h - border - 1],
            outline=OUTLINE_COLOR,
            width=border,
        )

        # Draw "CC" text centered
        label = "CC"
        font_size = max(10, min(w, h) // 3)
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except (OSError, IOError):
            font = ImageFont.load_default()

        bbox = draw.textbbox((0, 0), label, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        x = (w - tw) // 2
        y = (h - th) // 2
        draw.text((x, y), label, fill=TEXT_COLOR, font=font)

        path = os.path.join(ASSETS_DIR, filename)
        img.save(path, "PNG")
        print(f"  {filename} ({w}x{h})")


def _make_png_chunk(chunk_type, data):
    """Create a PNG chunk with CRC."""
    chunk = chunk_type + data
    crc = struct.pack(">I", zlib.crc32(chunk) & 0xFFFFFFFF)
    return struct.pack(">I", len(data)) + chunk + crc


def _make_minimal_png(w, h, r, g, b):
    """Create a minimal valid PNG with a solid color (no dependencies)."""
    # PNG signature
    sig = b"\x89PNG\r\n\x1a\n"

    # IHDR: width, height, bit_depth=8, color_type=2 (RGB)
    ihdr_data = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    ihdr = _make_png_chunk(b"IHDR", ihdr_data)

    # IDAT: raw image data (filter byte 0 + RGB pixels per row)
    raw_rows = b""
    row_data = bytes([r, g, b]) * w
    for _ in range(h):
        raw_rows += b"\x00" + row_data  # filter byte 0 = None
    compressed = zlib.compress(raw_rows)
    idat = _make_png_chunk(b"IDAT", compressed)

    # IEND
    iend = _make_png_chunk(b"IEND", b"")

    return sig + ihdr + idat + iend


def generate_minimal():
    """Generate solid-color PNGs without any dependencies."""
    os.makedirs(ASSETS_DIR, exist_ok=True)

    for filename, w, h in ICONS:
        png_data = _make_minimal_png(w, h, *BG_COLOR)
        path = os.path.join(ASSETS_DIR, filename)
        with open(path, "wb") as f:
            f.write(png_data)
        print(f"  {filename} ({w}x{h}) [solid color fallback]")


def main():
    print("Generating MSIX placeholder icons in pkg/Assets/...")
    try:
        generate_with_pillow()
        print("Done (generated with Pillow).")
    except ImportError:
        print("Pillow not found, using minimal PNG fallback...")
        generate_minimal()
        print("Done (solid color placeholders).")
    print()
    print("Replace these with real artwork before submitting to the Store.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate WhatsApp/Telegram sticker assets from the source eagle PNGs.

Reads <repo>/LezgiStickers/*.png and writes to
LezgiKeyboard/LezgiKeyboard/MessengerStickers/ (bundled into the app):
- <name>.webp - 512x512, under 100 KB (WhatsApp static sticker limit,
  also accepted by Telegram's import API)
- tray.png    - 96x96 pack icon, under 50 KB (WhatsApp tray image)

The sticker list and emoji mapping must stay in sync with
LezgiKeyboard/StickerSharing.swift (and the pack order in gen_stickers.swift).
"""
import io
from pathlib import Path

from PIL import Image

# file stem -> emojis (WhatsApp allows up to 3, Telegram needs at least 1)
STICKERS = [
    ("salam",      ["👋"]),
    ("thanks",     ["🙏"]),
    ("sweetheart", ["🥰"]),
    ("great",      ["👍"]),
    ("yes",        ["✅"]),
    ("no",         ["❌"]),
    ("howareyou",  ["🤗"]),
    ("loveyou",    ["❤️"]),
    ("sorry",      ["🥺"]),
    ("bravo",      ["👏"]),
    ("congrats",   ["🎉"]),
    ("welcome",    ["🤝"]),
    ("comehere",   ["🏃"]),
    ("morning",    ["☀️"]),
    ("angry",      ["😠"]),
    ("goodnight",  ["😴"]),
    ("prayer",     ["🤲"]),
    ("lezginka",   ["🕺"]),
    ("khinkal",    ["🥟"]),
    ("lezgiflag",  ["🦅"]),
]

MAX_STICKER_BYTES = 100_000  # WhatsApp static sticker limit
MAX_TRAY_BYTES = 50_000

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "LezgiStickers"
OUT = REPO / "LezgiKeyboard/LezgiKeyboard/MessengerStickers"


def trimmed_square(img: Image.Image, margin: float = 0.03) -> Image.Image:
    """Crop transparent margins, keeping a square canvas centered on the art."""
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return img
    left, top, right, bottom = bbox
    side = min(img.width, max(right - left, bottom - top) * (1 + 2 * margin))
    cx, cy = (left + right) / 2, (top + bottom) / 2
    x = max(0, min(cx - side / 2, img.width - side))
    y = max(0, min(cy - side / 2, img.height - side))
    return img.crop((round(x), round(y), round(x + side), round(y + side)))


def encode_webp(img: Image.Image) -> bytes:
    for quality in range(90, 20, -10):
        buf = io.BytesIO()
        img.save(buf, "WEBP", quality=quality, method=6)
        if buf.tell() <= MAX_STICKER_BYTES:
            return buf.getvalue()
    raise SystemExit(f"cannot fit sticker under {MAX_STICKER_BYTES} bytes")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, _ in STICKERS:
        img = trimmed_square(Image.open(SRC / f"{name}.png").convert("RGBA"))
        img = img.resize((512, 512), Image.LANCZOS)
        data = encode_webp(img)
        (OUT / f"{name}.webp").write_bytes(data)
        print(f"{name}.webp  {len(data) // 1024} KB")

    tray = trimmed_square(Image.open(SRC / "salam.png").convert("RGBA"))
    tray = tray.resize((96, 96), Image.LANCZOS)
    buf = io.BytesIO()
    tray.save(buf, "PNG", optimize=True)
    assert buf.tell() <= MAX_TRAY_BYTES, "tray image exceeds 50 KB"
    (OUT / "tray.png").write_bytes(buf.getvalue())
    print(f"tray.png  {buf.tell() // 1024} KB")


if __name__ == "__main__":
    main()

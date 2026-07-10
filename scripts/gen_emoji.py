#!/usr/bin/env python3
"""Generate EmojiData.swift from unicode.org emoji-test.txt.

Rules:
- fully-qualified entries only
- skip skin-tone variants (1F3FB..1F3FF) and the Component group
- cap at Emoji 15.1 (max version rendered by iOS 18.0, the extension's target)
- merge "Smileys & Emotion" + "People & Body" into one category like native iOS
"""
import re
from pathlib import Path

SRC = Path(__file__).parent / "emoji-test.txt"
OUT = Path(__file__).parent / "EmojiData.swift"

MAX_VERSION = 15.1
SKIN_TONES = {0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF}

# unicode group -> (category key, order)
GROUP_MAP = {
    "Smileys & Emotion": "smileys",
    "People & Body": "smileys",
    "Animals & Nature": "nature",
    "Food & Drink": "food",
    "Activities": "activity",
    "Travel & Places": "travel",
    "Objects": "objects",
    "Symbols": "symbols",
    "Flags": "flags",
}

# category key -> (Lezgi title, SF Symbol icon)
CATEGORIES = [
    ("smileys",  "Чинар ва инсанар", "face.smiling"),
    ("nature",   "Тӏебиат",          "pawprint"),
    ("food",     "Тӏуьн",            "fork.knife"),
    ("activity", "Къугъунар",        "soccerball"),
    ("travel",   "Сиягьат",          "car"),
    ("objects",  "Затӏар",           "lightbulb"),
    ("symbols",  "Символар",         "heart"),
    ("flags",    "Пайдахар",         "flag"),
]

buckets = {key: [] for key, _, _ in CATEGORIES}
group = None
line_re = re.compile(
    r"^([0-9A-F ]+?)\s*;\s*fully-qualified\s*#\s*(\S+)\s+E(\d+\.\d+)\s"
)

for line in SRC.read_text(encoding="utf-8").splitlines():
    if line.startswith("# group:"):
        group = line.split(":", 1)[1].strip()
        continue
    m = line_re.match(line)
    if not m or group not in GROUP_MAP:
        continue
    codepoints = [int(cp, 16) for cp in m.group(1).split()]
    if SKIN_TONES & set(codepoints):
        continue
    if float(m.group(3)) > MAX_VERSION:
        continue
    buckets[GROUP_MAP[group]].append(m.group(2))

lines = [
    "//",
    "//  EmojiData.swift",
    "//  LezgiChalKeyboard",
    "//",
    "//  Generated from unicode.org emoji-test.txt (fully-qualified, no skin",
    "//  tones, capped at Emoji 15.1 = max rendered by iOS 18.0).",
    "//  Regenerate with scripts/gen_emoji.py rather than editing by hand.",
    "//",
    "",
    "struct EmojiCategory {",
    "    let title: String   // section header in the grid",
    "    let icon: String    // SF Symbol shown in the bottom category bar",
    "    let emojis: [String]",
    "}",
    "",
    "enum EmojiData {",
    "",
    "    static let categories: [EmojiCategory] = [",
]

for key, title, icon in CATEGORIES:
    emojis = buckets[key]
    lines.append(f'        EmojiCategory(title: "{title}", icon: "{icon}", emojis: [')
    for i in range(0, len(emojis), 16):
        chunk = ",".join(f'"{e}"' for e in emojis[i:i + 16])
        lines.append(f"            {chunk},")
    lines.append("        ]),")

lines += ["    ]", "}", ""]
OUT.write_text("\n".join(lines), encoding="utf-8")

total = sum(len(v) for v in buckets.values())
for key, title, _ in CATEGORIES:
    print(f"{key:10} {len(buckets[key]):5}")
print(f"{'total':10} {total:5}")

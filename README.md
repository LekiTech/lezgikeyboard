# Lezgi Keyboard for iOS

A native iOS custom keyboard extension for the Lezgi language (лезги чIал), built entirely with Apple APIs — no third-party dependencies.

## Why This Exists

Lezgi is a Northeast Caucasian language spoken by approximately 800,000 people, primarily in southern Dagestan (Russia) and northern Azerbaijan. Despite being a living language with an active writing tradition, it has had no quality native keyboard on iOS.

A previous version of this keyboard existed on the App Store using the [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit) library. This project is a full rewrite from scratch using only `UIInputViewController`, `textDocumentProxy`, and SwiftUI — giving full control over layout, appearance, and behavior, and matching the native iOS keyboard look and feel as closely as possible.

The goal is simple: make typing in Lezgi feel exactly as natural as typing in Russian or English on iOS.

## Layout

The keyboard uses a Cyrillic-based layout adapted for Lezgi phonology. The Lezgi alphabet includes several sounds not present in Russian, represented via digraphs typed as two separate keystrokes:

| Base key | Long-press alternatives |
|----------|------------------------|
| ц | цI |
| у | уь |
| к | кI, кь, къ |
| е | ё |
| ш | щ |
| х | хь, хъ |
| п | пI |
| ч | чI |
| т | тI |

The palochka (vertical bar) is typed as Latin **I** (U+0049), which matches the encoding used in the bundled `lezgi_words.sqlite` dictionary.

**ъ** (hard sign) is placed in the bottom row next to the space bar — it is used frequently in Lezgi and deserves a dedicated key rather than being buried in the long-press menu.

## Architecture

| File | Role |
|------|------|
| `LezgiKeyboardLayout.swift` | Single source of truth for the layout — keys, callouts, weights, font sizes. Edit only this file to change the layout. |
| `KeyboardModel.swift` | State management — current page (letters/numbers/symbols), shift state, key handling logic. |
| `KeyboardView.swift` | SwiftUI rendering — key grid, suggestion bar, key preview bubble. |
| `KeyboardViewController.swift` | UIKit bridge — connects to `textDocumentProxy`, sets keyboard height, handles globe key. |
| `lezgi_words.sqlite` | 20,000+ word dictionary for suggestions (Step 5). |

## Roadmap

- [x] **Step 1** — Key grid, character input, shift, backspace, numbers/symbols pages, globe key
- [x] **Step 2** — Caps Lock (double-tap shift), auto-capitalize, key preview bubble
- [x] **Step 3** — Long-press callout menus with swipe selection
- [x] **Step 4** — Emoji page (custom emoji page with categories, ABC/АБВ returns to letters, emoji inserts directly)
- [x] **Step 5** — Word suggestions from `lezgi_words.sqlite`
- [ ] **Step 6** — Sound/haptic feedback (Full Access), landscape layout, iPad layout
- [x] **Row-level hit zones** — gaps between keys (horizontal and vertical) register on the nearest key, matching native iOS keyboard behavior
- [x] **Long-press callout bubbles** — not clipped; base letter included as first option in callout
- [x] **Auto-capitalization after period** — typing `.` on numbers/symbols page returns to letters layout with shift enabled for the next letter; respects Caps Lock
- [x] **Auto-capitalization on empty field** — deleting all text re-enables uppercase; respects Caps Lock
- [x] **Display name and localization** — app icon and keyboard extension show "Lezgi Keyboard" (en) / "Лезги Кхьин" (ru); main app instruction screen is localized in English and Russian
- [ ] **Suggestion bar hit areas** — tapping should work on the full suggestion cell, not only directly on the text
- [ ] **Spacebar cursor control** — long-press and drag on spacebar moves the insertion point through text, matching native iOS keyboard behavior
- [ ] **Emoji page redesign** — current page is MVP; investigate native iOS emoji keyboard access from a custom extension; if not possible, redesign to match native emoji keyboard (categories, recent emojis, scrolling, sizing, bottom controls)

## Web Prototype

Before installing the native keyboard you can try the layout in any browser — no Xcode needed.

**[Open prototype →](https://lekitech.github.io/lezgikeyboard/lezgi_keyboard_prototype.html)**

Or run locally (no server needed):
```
open lezgi_keyboard_prototype.html
```

The prototype supports:
- Both layout variants (ъ in bottom row vs. ъ in top row)
- Shift, Caps Lock (double-tap), auto-capitalize
- Long-press callout menus with swipe selection (цI, уь, кь, ё…)
- Backspace hold-to-repeat
- Double space → period

It is kept in sync with the native layout so it can be used to evaluate key placement before building.

## Requirements

- iOS 15+
- Xcode 15+
- No external dependencies

## Organization

Developed under [LekiTech](https://github.com/LekiTech) — a team building digital tools for Lezgi and other languages of Dagestan.

//
//  LezgiKeyboardLayout.swift
//  LezgiChalKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//
//  Single source of truth for key definitions, labels, callouts, and sizing.
//  To add or reorder keys, edit letterRows only.
//

import SwiftUI

/// What a key does when tapped.
/// .character("ӏ") inserts Cyrillic Palochka (U+04CF) — the correct Unicode character for the Lezgi bar letter.
/// lezgi_words.sqlite uses the same Cyrillic palochka, so queries need no normalization.
enum KeyCap: Equatable {
    case character(String)
    case shift
    case backspace
    case numbers    // switch to "123" page
    case symbols    // switch to "#+=" page
    case letters    // switch back to alphabet
    case globe      // input mode switch (required for App Store)
    case emoji      // emoji page (Step 4)
    case settings   // opens the in-keyboard settings panel
    case space
    case `return`
}

enum KeyboardPage {
    case letters, numbers, symbols, emoji
}

/// Where the hard sign «ъ» lives — user-selectable in the settings panel.
enum LayoutVariant: String {
    case classic   // ъ in the bottom row next to the space bar (default)
    case topRow    // ъ as the 12th key of the top letter row
}

enum LezgiLayout {

    // MARK: - Letter rows
    //
    // ↓↓↓  ADD OR REORDER KEYS HERE ONLY  ↓↓↓
    private static let baseLetterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","ӏ","з","х"].map { .character($0) },  // 11 keys
        ["ф","ы","в","а","п","р","о","л","д","ж","э"].map { .character($0) },  // 11 keys
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }
            + [.backspace],
    ]
    // ↑↑↑  -----------------------------------  ↑↑↑

    /// Letter rows for the chosen variant: `.classic` keeps «ъ» in the
    /// bottom row (added by `KeyboardModel.bottomRow`), `.topRow` appends it
    /// to the top letter row as a 12th key.
    static func letterRows(variant: LayoutVariant) -> [[KeyCap]] {
        var rows = baseLetterRows
        if variant == .topRow { rows[0].append(.character("ъ")) }
        return rows
    }

    // MARK: - Number page ("123") — standard iOS set
    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Symbol page ("#+=") — standard iOS set
    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","€","£","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Long-press callouts (Step 3)
    // Alternates are inserted as a whole string (e.g. "цӏ" = ц + palochka U+04CF).
    static let callouts: [String: [String]] = [
        "ц": ["цӏ"],
        "у": ["уь"],
        "к": ["кӏ", "кь", "къ"],
        "е": ["ё"],
        "г": ["гь", "гъ"],
        "ш": ["щ"],
        "х": ["хь", "хъ"],
        "п": ["пӏ"],
        "ч": ["чӏ"],
        "т": ["тӏ"],
    ]

    // MARK: - Case helpers

    /// Capitalizes only the first character — correct for digraphs: "къ" → "Къ", "цI" → "ЦI".
    static func capitalizedFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }

    /// Applies shift state to a string. Use instead of .uppercased().
    /// - capsLock true  → fully uppercase ("къ" → "КЪ")
    /// - capsLock false → first letter only ("къ" → "Къ")
    static func applyCase(_ s: String, capsLock: Bool) -> String {
        capsLock ? s.uppercased() : capitalizedFirst(s)
    }

    // MARK: - Key labels

    static func label(for cap: KeyCap, shifted: Bool) -> String {
        switch cap {
        case .character(let s): return shifted ? s.uppercased() : s
        case .shift:            return "⇧"
        case .backspace:        return "⌫"
        case .numbers:          return "123"
        case .symbols:          return "#+="
        case .letters:          return "АБВ"
        case .globe:            return "🌐"
        case .emoji:            return "😀"
        case .settings:         return ""    // gear icon, rendered by KeyButton
        case .space:            return "Ара"
        case .return:           return "Ракъун"
        }
    }

    // MARK: - Key width weight (relative, used as layoutPriority)

    static func weight(_ cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                    return 1.0
        case .shift, .backspace:            return 1.0
        // The «123» / gear / emoji cluster must be exactly equal-sized
        case .settings, .globe, .emoji,
             .numbers, .symbols, .letters:  return 1.2
        case .return:                       return 1.8
        case .space:                        return 4.5
        }
    }

    // MARK: - Return key

    /// Action label for the return key, in Lezgi. `.search` is empty on
    /// purpose: it renders as the universal magnifying-glass icon — the
    /// correct translation («Жагъурун») is too long for a key, and the
    /// icon is the familiar convention on modern keyboards. An empty
    /// label means "show an icon".
    static func returnLabel(for type: UIReturnKeyType) -> String {
        switch type {
        case .go:               return "Фин"
        case .send:             return "Ракъурун"
        case .done:             return "Хьанва"
        case .next:             return "Къведайди"
        case .`continue`:       return "Давамрун"
        case .join:             return "ЭкечIун"
        case .route:            return "Рехъ"
        case .emergencyCall:    return "Хаталувилин зенг"
        default:                return ""
        }
    }

    /// Return-key width in row units, adapted to its label: icons and
    /// short labels keep the native 1.8, longer Lezgi labels get more
    /// room so the typography stays readable instead of shrinking. Row
    /// weights normalize against their total, so the space bar absorbs
    /// the difference and the layout stays balanced.
    static func returnKeyWeight(for type: UIReturnKeyType) -> CGFloat {
        returnLabel(for: type).count <= 6 ? 1.8 : 2.3
    }

    // MARK: - Label font size

    static func fontSize(for cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                   return 22
        case .shift, .backspace,
             .globe, .emoji, .settings:    return 20
        case .space:                       return 13
        case .return:                      return 13
        case .numbers, .symbols, .letters: return 18
        }
    }

    /// Size for the label actually rendered on the key. Lowercase letters
    /// are optically much smaller than caps at the same point size (x-height
    /// vs cap height), so they get a 1.2× bump to match the native keyboard;
    /// uppercase already matches native one-to-one. Digits and punctuation
    /// have no case and keep the base size.
    static func fontSize(for cap: KeyCap, label: String) -> CGFloat {
        let base = fontSize(for: cap)
        if case .character = cap, label != label.uppercased() {
            return base * 1.2
        }
        return base
    }

    /// Character keys match the native iOS Russian keyboard, tuned by eye
    /// on device: SF's continuous variable axes via a UIKit descriptor,
    /// because SwiftUI's `Font.Weight` only exposes fixed steps and the
    /// match sits between regular (0.0) and medium (0.23). Width is
    /// slightly narrowed the same way (standard 0, condensed -0.2).
    /// All other key labels keep the plain system font.
    private static let characterWeight: CGFloat = 0.19
    private static let characterWidth: CGFloat = -0.1

    static func keyLabelFont(for cap: KeyCap, label: String) -> Font {
        let size = fontSize(for: cap, label: label)
        guard case .character = cap else {
            return .system(size: size)
        }
        let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            .addingAttributes([.traits: [
                UIFontDescriptor.TraitKey.weight: characterWeight,
                UIFontDescriptor.TraitKey.width: characterWidth,
            ]])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}

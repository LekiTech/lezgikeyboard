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
    case space
    case `return`
}

enum KeyboardPage {
    case letters, numbers, symbols, emoji
}

enum LezgiLayout {

    // MARK: - Letter rows (Variant 1: ъ in bottom row, not in top row)
    //
    // ↓↓↓  ADD OR REORDER KEYS HERE ONLY  ↓↓↓
    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","ӏ","з","х"].map { .character($0) },  // 11 keys
        ["ф","ы","в","а","п","р","о","л","д","ж","э"].map { .character($0) },  // 11 keys
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }
            + [.backspace],
    ]
    // ↑↑↑  -----------------------------------  ↑↑↑

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
        case .space:            return "Ара"
        case .return:           return "Ракъун"
        }
    }

    // MARK: - Key width weight (relative, used as layoutPriority)

    static func weight(_ cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                    return 1.0
        case .shift, .backspace:            return 1.0
        case .globe, .emoji:                return 1.2
        case .numbers, .symbols, .letters:  return 1.4
        case .return:                       return 1.8
        case .space:                        return 4.5
        }
    }

    // MARK: - Label font size

    static func fontSize(for cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                   return 22
        case .shift, .backspace,
             .globe, .emoji:               return 20
        case .space:                       return 13
        case .return:                      return 13
        case .numbers, .symbols, .letters: return 18
        }
    }
}

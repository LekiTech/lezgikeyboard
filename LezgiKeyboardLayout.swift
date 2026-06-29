//
//  LezgiKeyboardLayout.swift
//  LezgiChalKeyboard
//
//  ЕДИНСТВЕННЫЙ файл, который нужно менять, когда вы добавляете/переставляете буквы.
//  Здесь нет логики — только данные раскладки, подписи и веса (ширины) клавиш.
//

import SwiftUI

/// Что делает клавиша.
/// .character("й") — вставляет строку. Палочка хранится как латинская "I" (U+0049),
/// потому что именно так палочка записана в словаре lezgi_words.sqlite.
enum KeyCap: Equatable {
    case character(String)
    case shift
    case backspace
    case numbers      // переключатель "123"
    case symbols      // переключатель "#+="
    case letters      // переключатель "АБВ" (вернуться к буквам)
    case globe        // 🌐 переключение клавиатур (обязательно для App Store)
    case emoji        // 😀 (страница эмодзи добавляется в отдельном шаге)
    case space        // пробел, подпись "Ара"
    case `return`     // ввод, подпись "Ракъун"
}

enum KeyboardPage {
    case letters, numbers, symbols
}

enum LezgiLayout {

    // MARK: - БУКВЫ  (базовый вариант: ъ стоит справа от пробела, в верхнем ряду его НЕТ)
    //
    // ↓↓↓  ВОТ ЗДЕСЬ ДОБАВЛЯЙТЕ/ПЕРЕСТАВЛЯЙТЕ БУКВЫ  ↓↓↓
    // Просто допишите символ в нужный ряд — ширина клавиш пересчитается сама.
    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","I","з","х"].map { .character($0) },   // 11 клавиш
        ["ф","ы","в","а","п","р","о","л","д","ж","э"].map { .character($0) },   // 11 клавиш
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }
            + [.backspace],
    ]
    // ↑↑↑  ----------------------------------------  ↑↑↑

    // MARK: - ЦИФРЫ (страница "123")  — стандартный iOS-набор
    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - СИМВОЛЫ (страница "#+=")  — стандартный iOS-набор
    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","€","£","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Альтернативы по долгому нажатию (callouts)
    // Пока не отрисовываются (это Шаг 3), но данные уже готовы.
    // Альтернатива вставляется целиком (напр. "цI" = ц+I).
    static let callouts: [String: [String]] = [
        "ц": ["цI"],
        "у": ["уь"],
        "к": ["кI", "кь", "къ"],
        "е": ["ё"],
        "ш": ["щ"],
        "х": ["хь", "хъ"],
        "п": ["пI"],
        "ч": ["чI"],
        "т": ["тI"],
    ]

    /// Заглавная только у ПЕРВОЙ буквы — для диграфов: "къ" → "Къ", "цI" → "ЦI".
    static func capitalizedFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }

    /// Регистр с учётом режима Shift. Использовать вместо `uppercased()`.
    /// - capsLock = true  → всё заглавное ("къ" → "КЪ")
    /// - capsLock = false → только первая буква ("къ" → "Къ")
    static func applyCase(_ s: String, capsLock: Bool) -> String {
        capsLock ? s.uppercased() : capitalizedFirst(s)
    }

    // MARK: - Подписи на клавишах
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

    // MARK: - Вес (относительная ширина) клавиши
    static func weight(_ cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                    return 1.0
        case .shift, .backspace:            return 1.0   // одинаковые с буквами, как на iOS
        case .globe, .emoji:                return 1.2
        case .numbers, .symbols, .letters:  return 1.4
        case .return:                       return 1.8
        case .space:                        return 4.5
        }
    }

    // MARK: - Размер шрифта подписи
    static func fontSize(for cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                   return 22
        case .shift, .backspace,
             .globe, .emoji:               return 20
        case .space:                       return 13   // мелко, как «пробел»
        case .return:                      return 13   // мелко, как «ввод»
        case .numbers, .symbols, .letters: return 15
        }
    }
}

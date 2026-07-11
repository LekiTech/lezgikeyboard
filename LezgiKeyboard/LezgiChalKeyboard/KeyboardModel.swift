//
//  KeyboardModel.swift
//  LezgiChalKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import UIKit
import Combine

enum ShiftState {
    case off, once, capsLock
}

final class KeyboardModel: ObservableObject {

    @Published var page: KeyboardPage = .letters
    @Published var shiftState: ShiftState = .once
    @Published var suggestions: [String] = []
    @Published var returnKeyType: UIReturnKeyType = .default
    @Published var needsGlobe: Bool = false

    var isShifted: Bool { shiftState != .off }
    var isCapsLock: Bool { shiftState == .capsLock }

    private let wordDB = WordSuggestions()

    func updateSuggestions(proxy: UITextDocumentProxy) {
        let prefix = wordPrefix(proxy: proxy)
        suggestions = prefix.isEmpty ? [] : (wordDB?.suggestions(for: prefix) ?? [])
    }

    func wordPrefix(proxy: UITextDocumentProxy) -> String {
        guard let ctx = proxy.documentContextBeforeInput, !ctx.isEmpty else { return "" }
        let seps = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ".,!?;:\"'()[]{}—–-"))
        return ctx.components(separatedBy: seps).last(where: { !$0.isEmpty }) ?? ""
    }

    // MARK: - Key handling

    func handleKey(_ cap: KeyCap, proxy: UITextDocumentProxy) {
        switch cap {

        case .character(let s):
            let text = isShifted ? LezgiLayout.applyCase(s, capsLock: isCapsLock) : s
            proxy.insertText(text)
            if shiftState == .once { shiftState = .off }
            // Punctuation on the numbers/symbols pages returns to the letters page,
            // like the native keyboard; sentence-ending marks capitalize the next letter
            if (page == .numbers || page == .symbols),
               [".", ",", "?", "!", "'"].contains(s) {
                page = .letters
                if [".", "?", "!"].contains(s), shiftState != .capsLock {
                    shiftState = .once
                }
            }

        case .space:
            proxy.insertText(" ")

        case .return:
            proxy.insertText("\n")

        case .backspace:
            proxy.deleteBackward()

        case .shift:
            // off → once (single shift) → capsLock (double tap) → off
            switch shiftState {
            case .off:      shiftState = .once
            case .once:     shiftState = .capsLock
            case .capsLock: shiftState = .off
            }

        case .numbers:  page = .numbers
        case .symbols:  page = .symbols
        case .letters:  page = .letters
        case .emoji:    page = .emoji
        case .globe:    break
        }
    }

    func autoCapitalizeIfNeeded(proxy: UITextDocumentProxy) {
        guard shiftState != .capsLock else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let after  = proxy.documentContextAfterInput  ?? ""
        if before.isEmpty && after.isEmpty { shiftState = .once }
    }

    // MARK: - Emoji

    @Published var recentEmojis: [String] =
        UserDefaults.standard.stringArray(forKey: KeyboardModel.recentEmojisKey) ?? []

    private static let recentEmojisKey = "recentEmojis"
    private static let recentEmojisLimit = 24

    func recordRecentEmoji(_ emoji: String) {
        var recents = recentEmojis
        recents.removeAll { $0 == emoji }
        recents.insert(emoji, at: 0)
        if recents.count > Self.recentEmojisLimit {
            recents.removeLast(recents.count - Self.recentEmojisLimit)
        }
        recentEmojis = recents
        UserDefaults.standard.set(recents, forKey: Self.recentEmojisKey)
    }

    // MARK: - Layout

    func rows(needsGlobe: Bool) -> [[KeyCap]] {
        let main: [[KeyCap]]
        switch page {
        case .letters: main = LezgiLayout.letterRows
        case .numbers: main = LezgiLayout.numberRows
        case .symbols: main = LezgiLayout.symbolRows
        case .emoji:   return []
        }
        return main + [bottomRow(needsGlobe: needsGlobe)]
    }

    private func bottomRow(needsGlobe: Bool) -> [KeyCap] {
        switch page {
        case .letters:
            var row: [KeyCap] = [.numbers, .emoji]
            if needsGlobe { row.append(.globe) }
            row += [.space, .character("ъ"), .return]
            return row
        case .numbers, .symbols:
            var row: [KeyCap] = [.letters]
            if needsGlobe { row.append(.globe) }
            row += [.space, .return]
            return row
        case .emoji:
            return []
        }
    }
}

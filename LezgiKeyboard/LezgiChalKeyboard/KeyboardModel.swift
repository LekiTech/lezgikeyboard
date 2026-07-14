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

/// The keyboard's brain: page and shift state, key handling, composed-word
/// tracking, suggestion generation with shared capitalization, and the
/// on-device learning hooks. Rendering lives in `KeyboardView`, the UIKit
/// bridge in `KeyboardViewController`. See docs/CODEBASE_OVERVIEW.md.
final class KeyboardModel: ObservableObject {

    @Published var page: KeyboardPage = .letters
    @Published var shiftState: ShiftState = .once
    @Published var suggestions: [String] = []
    @Published var returnKeyType: UIReturnKeyType = .default
    @Published var needsGlobe: Bool = false
    /// Space long-press trackpad mode; key labels hide while the cursor is dragged.
    @Published var isSpaceCursorMode: Bool = false
    /// Keyboard name shown centered on the spacebar right after the keyboard appears.
    @Published var showsKeyboardName: Bool = false

    var isShifted: Bool { shiftState != .off }
    var isCapsLock: Bool { shiftState == .capsLock }

    private let wordDB = WordSuggestions()
    private let learned = LearnedWords()
    private var lastSpaceTap: Date? = nil

    /// The word being typed, tracked locally: `documentContextBeforeInput`
    /// lags behind fast typing (it round-trips through the host app), so the
    /// suggestion tap must not rely on it alone to know how many characters
    /// to replace. Resynced from the context on every `textDidChange`.
    private(set) var composedWord = ""

    /// The most recent completed word of the current sentence, tracked
    /// synchronously (the proxy context lags) — the source for Stage 4
    /// next-word suggestions. nil right after `.` `!` `?` or return, so
    /// next-word suggestions never cross a sentence boundary.
    private var lastCompletedWord: String?

    /// Realigns the local buffers once the host has confirmed the document
    /// state (cursor moves, field switches, our own edits landing).
    func syncComposedWord(proxy: UITextDocumentProxy) {
        composedWord = wordPrefix(proxy: proxy)
        lastCompletedWord = previousWord(proxy: proxy)
    }

    /// Display forms of the current suggestions that came from the learned
    /// store — the only ones long-press deletion applies to.
    private(set) var learnedDisplayWords: Set<String> = []

    /// Merges learned words (best first) with the bundled dictionary.
    /// The dictionary stores palochka as Latin `I`, learned words keep it as
    /// typed (`ӏ`), so deduplication normalizes both forms. Both kinds follow
    /// the capitalization context of the word being typed.
    ///
    /// The prefix is the locally composed word, not the proxy context: the
    /// context lags behind our own edits, which used to resurface the just
    /// completed word as if it were still being typed.
    func updateSuggestions(proxy: UITextDocumentProxy) {
        let prefix = composedWord
        // The idle-bar words follow the same capitalization context as real
        // suggestions (start of message, after . ! ?, Caps Lock)
        fallbackSuggestions = fallbackWords.map { displayForm($0, prefix: "", proxy: proxy) }
        guard !prefix.isEmpty else {
            // Stage 4: with no active prefix, suggest likely next words from
            // the learned bigrams of the last completed word. When there is
            // no last word (sentence start) or no confident pairs, the bar
            // falls back to the random dictionary words above.
            let nextWords = lastCompletedWord.flatMap { learned?.nextWords(after: $0) } ?? []
            var display: [String] = []
            var learnedSet: Set<String> = []
            for word in nextWords {
                let form = displayForm(word, prefix: "", proxy: proxy)
                display.append(form)
                learnedSet.insert(form)
            }
            suggestions = display
            learnedDisplayWords = learnedSet
            return
        }
        let learnedWords = learned?.suggestions(for: prefix,
                                                previous: previousWord(proxy: proxy)) ?? []
        var merged = learnedWords
        var seen = Set(merged.map(Self.dedupKey))
        for word in wordDB?.suggestions(for: prefix) ?? []
        where seen.insert(Self.dedupKey(word)).inserted {
            merged.append(word)
        }

        var display: [String] = []
        var learnedSet: Set<String> = []
        for (index, word) in merged.prefix(3).enumerated() {
            let form = displayForm(word, prefix: prefix, proxy: proxy)
            display.append(form)
            if index < learnedWords.count { learnedSet.insert(form) }
        }
        suggestions = display
        learnedDisplayWords = learnedSet
    }

    /// Shared display form for every suggestion type — learned, dictionary,
    /// and idle-bar fallback words all go through here.
    ///
    /// A typed prefix dictates its own case (capitalized prefix → capitalized
    /// word, fully uppercase prefix → uppercase word); with no prefix the
    /// sentence context decides (start of message or after `.` `!` `?` →
    /// capitalized, mid-sentence → as stored); Caps Lock always uppercases.
    private func displayForm(_ word: String, prefix: String, proxy: UITextDocumentProxy) -> String {
        if isCapsLock { return word.uppercased() }
        if prefix.isEmpty {
            let autocapitalizes = (proxy.autocapitalizationType ?? .sentences) != .none
            return autocapitalizes && isCursorAtSentenceStart(proxy: proxy)
                ? word.prefix(1).uppercased() + word.dropFirst()
                : word
        }
        guard prefix.first?.isUppercase == true else { return word }
        let allCaps = prefix.count >= 2 && prefix == prefix.uppercased()
        return allCaps ? word.uppercased()
                       : word.prefix(1).uppercased() + word.dropFirst()
    }

    private static func dedupKey(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "ӏ", with: "i")
    }

    // MARK: - Learning (Stage 1, docs/LOCAL_SUGGESTIONS_ROADMAP.md)

    /// Punctuation that finishes the word before it, like space and return do.
    private static let wordTerminators: Set<String> = [".", ",", "?", "!", ";", ":"]

    /// Records the word before the cursor as completed, together with the
    /// word preceding it in the same sentence. Called before the terminator
    /// (space / return / punctuation) is inserted; the terminator handlers
    /// clear `lastCompletedWord` again when they end the sentence.
    private func learnCompletedWord(proxy: UITextDocumentProxy) {
        let word = wordPrefix(proxy: proxy)
        guard !word.isEmpty else { return }
        learned?.learn(word, previous: previousWord(proxy: proxy), picked: false)
        lastCompletedWord = word
    }

    /// Records a suggestion chosen from the bar — a stronger signal than
    /// typing. `previous` must be captured before the prefix is replaced.
    /// The accepted word is inserted with a trailing space, so it becomes
    /// the completed word the next-word suggestions chain from.
    func recordPickedSuggestion(_ word: String, previous: String?) {
        learned?.learn(word, previous: previous, picked: true)
        composedWord = ""
        lastCompletedWord = word
    }

    /// Random dictionary words shown while the bar has no real suggestions —
    /// display forms, capitalized by the same rules as real suggestions.
    @Published var fallbackSuggestions: [String] = []

    /// The raw fallback words as stored in the dictionary.
    private var fallbackWords: [String] = []

    /// Re-rolls the idle-bar words; called once per keyboard appearance.
    func refreshFallbackSuggestions(proxy: UITextDocumentProxy) {
        fallbackWords = wordDB?.randomWords(3) ?? []
        fallbackSuggestions = fallbackWords.map { displayForm($0, prefix: "", proxy: proxy) }
    }

    /// Whether this displayed suggestion came from the learned store.
    func isLearnedSuggestion(_ display: String) -> Bool {
        learnedDisplayWords.contains(display)
    }

    /// Removes a learned word chosen from the bar; the bundled dictionary
    /// keeps suggesting its own entries as usual.
    func deleteLearnedWord(_ display: String, proxy: UITextDocumentProxy) {
        learned?.delete(display)
        updateSuggestions(proxy: proxy)
    }

    /// Stage 5: wipes the whole learned store (words and pairs) and
    /// refreshes the bar. Triggered from the idle suggestion bar.
    func resetLearnedWords(proxy: UITextDocumentProxy) {
        learned?.reset()
        lastCompletedWord = nil
        updateSuggestions(proxy: proxy)
    }

    private static let wordSeparators = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ".,!?;:\"'()[]{}—–-"))

    func wordPrefix(proxy: UITextDocumentProxy) -> String {
        guard let ctx = proxy.documentContextBeforeInput, !ctx.isEmpty else { return "" }
        // A trailing separator means the last word is already completed:
        // nothing is being composed, and a suggestion tap must never delete
        // or replace that completed word.
        if let scalar = ctx.unicodeScalars.last, Self.wordSeparators.contains(scalar) { return "" }
        return ctx.components(separatedBy: Self.wordSeparators).last(where: { !$0.isEmpty }) ?? ""
    }

    /// The completed word right before the word being typed, within the same
    /// sentence — bigrams never cross a sentence boundary (`.` `!` `?` or a
    /// new line cut the context first). Uses the same tokenizer as
    /// `wordPrefix`. Returns nil when the host truncates the context short.
    func previousWord(proxy: UITextDocumentProxy) -> String? {
        guard let full = proxy.documentContextBeforeInput, !full.isEmpty else { return nil }
        var ctx = Substring(full)
        if let cut = ctx.lastIndex(where: { ".!?\n".contains($0) }) {
            ctx = ctx[ctx.index(after: cut)...]
        }
        let tokens = ctx.components(separatedBy: Self.wordSeparators).filter { !$0.isEmpty }
        // With a trailing separator the last token is already a completed
        // word; while typing, the last token is the current prefix itself.
        let endsWithSeparator = full.unicodeScalars.last.map(Self.wordSeparators.contains) ?? false
        if endsWithSeparator {
            return tokens.last
        }
        return tokens.count >= 2 ? tokens[tokens.count - 2] : nil
    }

    // MARK: - Key handling

    func handleKey(_ cap: KeyCap, proxy: UITextDocumentProxy) {
        // First keystroke dismisses the keyboard name on the spacebar, like native
        showsKeyboardName = false

        switch cap {

        case .character(let s):
            if Self.wordTerminators.contains(s) { learnCompletedWord(proxy: proxy) }
            let text = isShifted ? LezgiLayout.applyCase(s, capsLock: isCapsLock) : s
            proxy.insertText(text)
            if s.count == 1, let scalar = s.unicodeScalars.first,
               Self.wordSeparators.contains(scalar) {
                composedWord = ""
            } else {
                composedWord += text
            }
            // Sentence-ending punctuation cuts the next-word context
            if [".", "?", "!"].contains(s) { lastCompletedWord = nil }
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
            // Quick double space after a word turns into ". " with a capital next
            if let last = lastSpaceTap, Date().timeIntervalSince(last) < 0.35,
               let before = proxy.documentContextBeforeInput,
               before.hasSuffix(" "), before.count >= 2,
               let prev = before.dropLast().last, prev.isLetter || prev.isNumber {
                proxy.deleteBackward()
                proxy.insertText(". ")
                if shiftState != .capsLock { shiftState = .once }
                lastSpaceTap = nil
                lastCompletedWord = nil  // ". " ends the sentence
            } else {
                learnCompletedWord(proxy: proxy)
                proxy.insertText(" ")
                lastSpaceTap = Date()
            }
            composedWord = ""

        case .return:
            learnCompletedWord(proxy: proxy)
            proxy.insertText("\n")
            composedWord = ""
            lastCompletedWord = nil  // a new line starts a new sentence
            // A new paragraph starts a new sentence, like the native keyboard
            if shiftState != .capsLock,
               (proxy.autocapitalizationType ?? .sentences) != .none {
                shiftState = .once
            }

        case .backspace:
            proxy.deleteBackward()
            if !composedWord.isEmpty { composedWord.removeLast() }

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

    // MARK: - Auto-capitalization

    /// Re-evaluates the shift state from the field's autocapitalization trait
    /// and the text before the cursor. Called on every text or cursor change;
    /// Caps Lock always wins over the automatic rules.
    func updateShiftFromContext(proxy: UITextDocumentProxy) {
        guard shiftState != .capsLock else { return }
        let type = proxy.autocapitalizationType ?? .sentences
        let shouldShift: Bool
        switch type {
        case .none:
            shouldShift = false
        case .allCharacters:
            shouldShift = true
        case .words:
            let before = proxy.documentContextBeforeInput ?? ""
            shouldShift = before.isEmpty || before.last?.isWhitespace == true
        default:
            shouldShift = isCursorAtSentenceStart(proxy: proxy)
        }
        shiftState = shouldShift ? .once : .off
    }

    /// Sentence start: empty or whitespace-only context, a fresh new line, or
    /// a sentence delimiter as the last non-whitespace character. A trailing
    /// space is not required, matching the native period behavior.
    private func isCursorAtSentenceStart(proxy: UITextDocumentProxy) -> Bool {
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else { return true }
        if before.last?.isNewline == true { return true }
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return [".", "!", "?"].contains(String(last))
    }

    // MARK: - Cursor line jumps (space trackpad mode)

    /// Moves the cursor to the previous/next `"\n"`-separated line, keeping the
    /// column when the neighbouring line is visible in the document context.
    ///
    /// Many hosts truncate the context at paragraph boundaries, so without a
    /// visible `"\n"` one newline is still crossed blindly: up lands at the end
    /// of the previous line, down at the start of the next (hosts clamp at the
    /// document edges). Visual wraps of long lines are invisible to extensions.
    func moveCursorLine(up: Bool, proxy: UITextDocumentProxy) {
        if up {
            let before = proxy.documentContextBeforeInput ?? ""
            let lines = before.components(separatedBy: "\n")
            let column = lines[lines.count - 1].count
            if lines.count >= 2 {
                let prevLen = lines[lines.count - 2].count
                proxy.adjustTextPosition(byCharacterOffset: -(column + 1 + max(prevLen - column, 0)))
            } else {
                proxy.adjustTextPosition(byCharacterOffset: -(column + 1))
            }
        } else {
            let after = proxy.documentContextAfterInput ?? ""
            let lines = after.components(separatedBy: "\n")
            let restOfCurrent = lines[0].count
            if lines.count >= 2 {
                let nextLen = lines[1].count
                let column = (proxy.documentContextBeforeInput?.components(separatedBy: "\n").last ?? "").count
                proxy.adjustTextPosition(byCharacterOffset: restOfCurrent + 1 + min(column, nextLen))
            } else {
                proxy.adjustTextPosition(byCharacterOffset: restOfCurrent + 1)
            }
        }
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

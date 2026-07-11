//
//  KeyboardView.swift
//  LezgiChalKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI

// MARK: - Dynamic colors matching native iOS keyboard

private extension Color {
    static let kbLetterKey = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1)
            : UIColor.white
    }))
    static let kbLetterKeyPressed = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.36, blue: 0.37, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)
    }))
}

// MARK: - Return key label

private func returnLabel(for type: UIReturnKeyType) -> String {
    switch type {
    case .go:               return "Фин"
    case .search:           return "Жагъурун"
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

// MARK: - Root view

struct KeyboardView: View {

    @ObservedObject var model: KeyboardModel
    let onKey: (KeyCap) -> Void
    var onSuggestion: ((String) -> Void)? = nil
    var onEmojiInsert: ((String) -> Void)? = nil
    var onCursorMove: ((Int) -> Void)? = nil
    var onCursorLineMove: ((Int) -> Void)? = nil

    // Key preview bubble state
    @State private var pressedCap: KeyCap? = nil
    @State private var pressedFrame: CGRect = .zero

    // Suggestion bar press state
    @State private var pressedSuggestionIndex: Int? = nil

    // Emoji page state
    @State private var emojiCurrentSection: Int = 0
    @State private var emojiScrollTarget: Int? = nil
    @State private var emojiBarIsPressed = false
    @State private var emojiBarPressedZone: EmojiBarZone? = nil
    @State private var emojiBarRepeatTimer: Timer? = nil

    private enum EmojiBarZone: Equatable {
        case letters
        case backspace
        case category(Int)
    }

    // Callout state
    @State private var calloutFrame: CGRect = .zero
    @State private var calloutOptions: [String] = []
    @State private var calloutSelectedIndex: Int = 0
    @State private var calloutBubbleLeftX: CGFloat = 0
    @State private var isShowingCallout: Bool = false

    private let calloutOptionWidth: CGFloat = 44

    var body: some View {
        ZStack(alignment: .topLeading) {
            if model.page == .emoji {
                emojiPage
            } else {
                VStack(spacing: 0) {
                    suggestionBar
                    GeometryReader { geo in
                        VStack(spacing: 11) {
                            let allRows = model.rows(needsGlobe: model.needsGlobe)
                            ForEach(Array(allRows.enumerated()), id: \.offset) { i, row in
                                rowView(row: row, totalWidth: geo.size.width - 12,
                                        rowIndex: i, totalRows: allRows.count)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }

            // Key preview bubble (only when no callout)
            if !isShowingCallout, let cap = pressedCap, case .character = cap {
                KeyPreviewBubble(
                    label: LezgiLayout.label(for: cap, shifted: model.isShifted),
                    frame: pressedFrame
                )
                .allowsHitTesting(false)
            }

            // Callout bubble
            if isShowingCallout {
                CalloutBubble(
                    options: calloutOptions,
                    selectedIndex: calloutSelectedIndex,
                    keyFrame: calloutFrame,
                    isShifted: model.isShifted,
                    isCapsLock: model.isCapsLock
                )
                .allowsHitTesting(false)
            }
        }
        .frame(height: 242, alignment: .top)
        .coordinateSpace(name: "keyboard")
        .ignoresSafeArea()
    }

    // MARK: - Suggestion bar

    private var suggestionBar: some View {
        let words = paddedSuggestions()
        return ZStack(alignment: .leading) {
            // Visual layer: highlights + text + dividers, no gestures
            HStack(alignment: .center, spacing: 0) {
                suggestionCellVisual(words[0], index: 0)
                suggestionDivider
                suggestionCellVisual(words[1], index: 1)
                suggestionDivider
                suggestionCellVisual(words[2], index: 2)
            }

            // Gesture layer: single full-width transparent rect, dispatches by x position
            GeometryReader { geo in
                Color.white.opacity(0.001)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let idx = suggestionIndex(x: value.location.x, width: geo.size.width)
                                if pressedSuggestionIndex != idx { pressedSuggestionIndex = idx }
                            }
                            .onEnded { value in
                                let idx = suggestionIndex(x: value.location.x, width: geo.size.width)
                                pressedSuggestionIndex = nil
                                let word = words[idx]
                                guard !word.isEmpty else { return }
                                onSuggestion?(word)
                            }
                    )
            }
        }
        .frame(height: 36)
    }

    private func suggestionIndex(x: CGFloat, width: CGFloat) -> Int {
        let third = width / 3
        if x < third { return 0 }
        if x < third * 2 { return 1 }
        return 2
    }

    private func paddedSuggestions() -> [String] {
        if model.suggestions.isEmpty { return ["Зун", "Вун", "ГьикI"] }
        var s = model.suggestions
        while s.count < 3 { s.append("") }
        return s
    }

    private var suggestionDivider: some View {
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(width: 1, height: 26)
    }

    private func suggestionCellVisual(_ word: String, index: Int) -> some View {
        ZStack {
            if pressedSuggestionIndex == index {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kbLetterKey)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            Text(word)
                .font(.system(size: 16))
                .lineLimit(1)
                .foregroundColor(word.isEmpty ? .clear : Color(UIColor.label))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Emoji page

    private let emojiRecentsID = -1

    // Flat list of small 5-emoji columns. Nested lazy containers (grid inside
    // stack) defeat laziness — every cell gets created for layout and the
    // keyboard extension hits its memory limit on device. Small uniform
    // children keep the LazyHStack truly lazy and scroll jumps precise.
    private struct EmojiColumn: Identifiable {
        let id: Int
        let category: Int      // emojiRecentsID or index into EmojiData.categories
        let endsCategory: Bool
        let emojis: [String]
    }

    private func makeEmojiColumns() -> [EmojiColumn] {
        var groups: [(category: Int, emojis: [String])] = []
        if !model.recentEmojis.isEmpty { groups.append((emojiRecentsID, model.recentEmojis)) }
        for (i, cat) in EmojiData.categories.enumerated() { groups.append((i, cat.emojis)) }

        var columns: [EmojiColumn] = []
        for group in groups {
            let chunks = stride(from: 0, to: group.emojis.count, by: 5).map {
                Array(group.emojis[$0..<min($0 + 5, group.emojis.count)])
            }
            for (ci, chunk) in chunks.enumerated() {
                columns.append(EmojiColumn(id: columns.count,
                                           category: group.category,
                                           endsCategory: ci == chunks.count - 1,
                                           emojis: chunk))
            }
        }
        return columns
    }

    private func emojiSectionTitle(for category: Int) -> String {
        category == emojiRecentsID ? "Эхиримжибур" : EmojiData.categories[category].title
    }

    private var emojiPage: some View {
        let columns = makeEmojiColumns()
        return VStack(alignment: .leading, spacing: 0) {
            // Fixed title strip showing the current category, like native
            Text(emojiSectionTitle(for: emojiCurrentSection))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.leading, 10)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 2) {
                    ForEach(columns) { column in
                        emojiColumn(column)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 6)
                // Transparent areas don't receive touches in SwiftUI; near-zero
                // opacity makes the whole grid area scrollable, not just the glyphs
                .background(Color.white.opacity(0.001))
            }
            .scrollPosition(id: $emojiScrollTarget, anchor: .leading)
            .padding(.top, 4)
            .onChange(of: emojiScrollTarget) { _, newValue in
                if let id = newValue, columns.indices.contains(id) {
                    emojiCurrentSection = columns[id].category
                }
            }
            .onAppear {
                emojiCurrentSection = model.recentEmojis.isEmpty ? 0 : emojiRecentsID
            }

            Spacer(minLength: 0)

            emojiCategoryBar
        }
    }

    private func emojiColumn(_ column: EmojiColumn) -> some View {
        VStack(spacing: 2) {
            ForEach(column.emojis, id: \.self) { emoji in
                Button(action: { onEmojiInsert?(emoji) }) {
                    Text(emoji)
                        .font(.system(size: 26))
                        .frame(width: 38, height: 33)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EmojiKeyButtonStyle())
            }
        }
        // Visual gap between categories
        .padding(.trailing, column.endsCategory ? 10 : 0)
    }

    // Bottom strip like native: АБВ + category icons + delete, no key backgrounds.
    // Visual layer + full-width gesture layer dispatching by x, same as RowView.
    private var emojiCategoryBar: some View {
        ZStack {
            // Visual layer, no gestures
            HStack(spacing: 0) {
                Text("АБВ")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(UIColor.label))
                    .frame(width: 44, height: 36)

                if !model.recentEmojis.isEmpty {
                    emojiCategoryIcon(id: emojiRecentsID, symbol: "clock")
                }
                ForEach(Array(EmojiData.categories.enumerated()), id: \.offset) { i, cat in
                    emojiCategoryIcon(id: i, symbol: cat.icon)
                }

                Image(systemName: "delete.backward")
                    .font(.system(size: 17))
                    .foregroundColor(Color(UIColor.label))
                    .frame(width: 44, height: 36)
            }
            .padding(.horizontal, 4)

            // Gesture layer: covers the bar edge to edge, including gaps around icons
            GeometryReader { geo in
                Color.white.opacity(0.001)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                emojiBarPressBegan(x: value.location.x,
                                                   width: geo.size.width)
                            }
                            .onEnded { _ in
                                emojiBarPressEnded()
                            }
                    )
            }
        }
        .frame(height: 36)
        .padding(.bottom, 4)
    }

    private func emojiCategoryIcon(id: Int, symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15))
            .foregroundColor(Color(emojiCurrentSection == id ? UIColor.label : UIColor.secondaryLabel))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                Circle()
                    .fill(emojiCurrentSection == id
                          ? Color(UIColor.secondarySystemFill) : Color.clear)
                    .frame(width: 30, height: 30)
            )
    }

    private func emojiBarZone(x: CGFloat, width: CGFloat) -> EmojiBarZone? {
        let side: CGFloat = 48   // 4pt edge padding + 44pt АБВ/delete button
        if x < side { return .letters }
        if x > width - side { return .backspace }

        var ids = Array(EmojiData.categories.indices)
        if !model.recentEmojis.isEmpty { ids.insert(emojiRecentsID, at: 0) }
        let iconWidth = (width - side * 2) / CGFloat(ids.count)
        guard iconWidth > 0 else { return nil }
        let idx = max(0, min(ids.count - 1, Int((x - side) / iconWidth)))
        return .category(ids[idx])
    }

    private func emojiBarPressBegan(x: CGFloat, width: CGFloat) {
        guard !emojiBarIsPressed else { return }
        emojiBarIsPressed = true
        let zone = emojiBarZone(x: x, width: width)
        emojiBarPressedZone = zone

        // Delete repeats while held, same as backspace on the letters page
        if zone == .backspace {
            func scheduleRepeat(interval: TimeInterval) {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    guard emojiBarIsPressed else { return }
                    onKey(.backspace)
                    scheduleRepeat(interval: max(0.03, interval * 0.85))
                }
            }
            emojiBarRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                guard emojiBarIsPressed else { return }
                scheduleRepeat(interval: 0.1)
            }
        }
    }

    private func emojiBarPressEnded() {
        emojiBarRepeatTimer?.invalidate()
        emojiBarRepeatTimer = nil
        emojiBarIsPressed = false
        guard let zone = emojiBarPressedZone else { return }
        emojiBarPressedZone = nil

        switch zone {
        case .letters:
            onKey(.letters)
        case .backspace:
            onKey(.backspace)
        case .category(let id):
            emojiCurrentSection = id
            guard let target = makeEmojiColumns().first(where: { $0.category == id })?.id else { return }
            if emojiScrollTarget == target {
                // Binding already holds this id (scrollPosition writes back while the
                // user scrolls) — retrigger so tapping the current category jumps to
                // its start instead of doing nothing
                emojiScrollTarget = nil
                DispatchQueue.main.async { emojiScrollTarget = target }
            } else {
                emojiScrollTarget = target
            }
        }
    }


    // MARK: - Key row

    private func rowView(row: [KeyCap], totalWidth: CGFloat,
                         rowIndex: Int = 0, totalRows: Int = 1) -> some View {
        RowView(
            row: row, totalWidth: totalWidth, rowIndex: rowIndex, totalRows: totalRows,
            model: model,
            onKey: onKey,
            onPress: { cap, frame in
                pressedCap = cap
                pressedFrame = frame
            },
            onRelease: { pressedCap = nil },
            onLongPress: { frame, options in
                pressedCap = nil
                calloutFrame = frame
                calloutOptions = options
                let totalW = calloutOptionWidth * CGFloat(options.count)
                let screenWidth = UIScreen.main.bounds.width
                let bubbleX = min(max(frame.midX, totalW / 2 + 6), screenWidth - totalW / 2 - 6)
                let leftX = bubbleX - totalW / 2
                calloutBubbleLeftX = leftX
                let initialLocal = frame.midX - leftX
                calloutSelectedIndex = max(0, min(options.count - 1, Int(initialLocal / calloutOptionWidth)))
                isShowingCallout = true
            },
            onDragMoved: { dragX in
                let localX = dragX - calloutBubbleLeftX
                let idx = Int(localX / calloutOptionWidth)
                calloutSelectedIndex = max(0, min(calloutOptions.count - 1, idx))
            },
            onLongRelease: {
                if isShowingCallout {
                    let selected = calloutOptions[calloutSelectedIndex]
                    onKey(.character(selected))
                }
                isShowingCallout = false
                calloutOptions = []
            },
            onCursorMove: { steps in onCursorMove?(steps) },
            onCursorLineMove: { lines in onCursorLineMove?(lines) }
        )
    }
}

// MARK: - Emoji key press highlight

// Rounded key-colored flash behind an emoji while touched, like native.
// ButtonStyle gets isPressed for free and plays nice with the ScrollView.
private struct EmojiKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.kbLetterKeyPressed : Color.clear)
            )
    }
}

// MARK: - Row view with expanded hit zones

private struct RowView: View {

    let row: [KeyCap]
    let totalWidth: CGFloat
    let rowIndex: Int
    let totalRows: Int
    @ObservedObject var model: KeyboardModel
    let onKey: (KeyCap) -> Void
    let onPress: (KeyCap, CGRect) -> Void
    let onRelease: () -> Void
    let onLongPress: (CGRect, [String]) -> Void
    let onDragMoved: (CGFloat) -> Void
    let onLongRelease: () -> Void
    let onCursorMove: (Int) -> Void
    let onCursorLineMove: (Int) -> Void

    @State private var rowMinY: CGFloat = 0
    @State private var isPressed = false
    @State private var isLongPressed = false
    @State private var longPressTimer: DispatchWorkItem? = nil
    @State private var repeatTimer: Timer? = nil
    @State private var activeCap: KeyCap? = nil
    @State private var isSpaceCursorMode = false
    @State private var spaceCursorTimer: DispatchWorkItem? = nil
    @State private var spaceLastX: CGFloat = 0
    @State private var spaceLastY: CGFloat = 0

    private let spacing: CGFloat = 6
    private let keyHeight: CGFloat = 43
    private let rowSpacing: CGFloat = 11
    // Row x-origin in keyboard space matches .padding(.horizontal, 6) on the VStack
    private let rowLeadingX: CGFloat = 6

    private var unitWidth: CGFloat {
        let totalWeight = row.map { LezgiLayout.weight($0) }.reduce(0, +)
        let totalSpacingPts = spacing * CGFloat(row.count - 1)
        return (totalWidth - totalSpacingPts) / totalWeight
    }
    private var topExpand:    CGFloat { rowIndex == 0             ? 0 : rowSpacing / 2 }
    private var bottomExpand: CGFloat { rowIndex == totalRows - 1 ? 0 : rowSpacing / 2 }
    private var zoneHeight:   CGFloat { keyHeight + topExpand + bottomExpand }

    // Visual key frames in keyboard coordinate space.
    private var keyFrames: [(cap: KeyCap, frame: CGRect)] {
        var result: [(KeyCap, CGRect)] = []
        var x = rowLeadingX
        for cap in row {
            let kw = unitWidth * LezgiLayout.weight(cap)
            result.append((cap, CGRect(x: x, y: rowMinY, width: kw, height: keyHeight)))
            x += kw + spacing
        }
        return result
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Visual layer
            HStack(spacing: spacing) {
                ForEach(Array(row.enumerated()), id: \.offset) { _, cap in
                    KeyButton(cap: cap, model: model, returnKeyType: model.returnKeyType,
                              isPressed: activeCap == cap)
                        .frame(width: unitWidth * LezgiLayout.weight(cap), height: keyHeight)
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        rowMinY = geo.frame(in: .named("keyboard")).minY
                    }
                }
            )

            // Gesture layer: single transparent rect, expanded to cover vertical gaps.
            // Color.clear does not receive touches in SwiftUI; use near-zero opacity instead.
            Color.white.opacity(0.001)
                .frame(height: zoneHeight)
                .offset(y: -topExpand)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboard"))
                        .onChanged { value in handleChanged(value: value) }
                        .onEnded   { _     in handleEnded() }
                )
        }
        .frame(height: keyHeight)  // keep layout height at 43pt so VStack spacing is unchanged
    }

    // Touch inside a key's visual frame → that key wins; gaps fall back to nearest midX.
    private func nearest(touchX: CGFloat) -> (cap: KeyCap, frame: CGRect)? {
        if let hit = keyFrames.first(where: { $0.frame.minX <= touchX && touchX <= $0.frame.maxX }) {
            return hit
        }
        return keyFrames.min(by: { abs($0.frame.midX - touchX) < abs($1.frame.midX - touchX) })
    }

    private func handleChanged(value: DragGesture.Value) {
        guard !isPressed else {
            if isLongPressed {
                onDragMoved(value.location.x)
            } else if isSpaceCursorMode {
                spaceCursorDragged(to: value.location)
            } else if activeCap == .space {
                // Track the finger before cursor mode kicks in so activation
                // starts from the current position without a jump
                spaceLastX = value.location.x
                spaceLastY = value.location.y
            }
            return
        }
        isPressed = true
        guard let key = nearest(touchX: value.location.x) else { return }
        activeCap = key.cap
        onPress(key.cap, key.frame)

        // Long-press on space enters cursor mode: dragging moves the insertion point
        if case .space = key.cap {
            spaceLastX = value.location.x
            spaceLastY = value.location.y
            let work = DispatchWorkItem {
                guard isPressed else { return }
                isSpaceCursorMode = true
                model.isSpaceCursorMode = true
            }
            spaceCursorTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }

        // Backspace hold-to-repeat with acceleration
        if case .backspace = key.cap {
            func scheduleRepeat(interval: TimeInterval) {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    guard isPressed else { return }
                    onKey(.backspace)
                    scheduleRepeat(interval: max(0.03, interval * 0.85))
                }
            }
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                guard isPressed else { return }
                scheduleRepeat(interval: 0.1)
            }
        }

        // Long-press for character keys that have callout options
        if case .character(let s) = key.cap,
           let extras = LezgiLayout.callouts[s.lowercased()], !extras.isEmpty {
            let base = s.lowercased()
            let opts = [base] + extras.filter { $0.lowercased() != base }
            let frame = key.frame
            let work = DispatchWorkItem {
                isLongPressed = true
                onLongPress(frame, opts)
            }
            longPressTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }

    // 8pt of horizontal movement = one character, 30pt vertically = one line
    private func spaceCursorDragged(to point: CGPoint) {
        let stepWidth: CGFloat = 8
        let steps = Int((point.x - spaceLastX) / stepWidth)
        if steps != 0 {
            onCursorMove(steps)
            spaceLastX += CGFloat(steps) * stepWidth
        }

        let stepHeight: CGFloat = 30
        let lineSteps = Int((point.y - spaceLastY) / stepHeight)
        if lineSteps != 0 {
            onCursorLineMove(lineSteps)
            spaceLastY += CGFloat(lineSteps) * stepHeight
        }
    }

    private func handleEnded() {
        longPressTimer?.cancel()
        longPressTimer = nil
        spaceCursorTimer?.cancel()
        spaceCursorTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        isPressed = false

        if isLongPressed {
            isLongPressed = false
            onLongRelease()
        } else if isSpaceCursorMode {
            // Cursor drag ends without inserting a space
            isSpaceCursorMode = false
            model.isSpaceCursorMode = false
            onRelease()
        } else {
            onRelease()
            if let cap = activeCap { onKey(cap) }
        }
        activeCap = nil
    }
}

// MARK: - Callout bubble

private struct CalloutBubble: View {
    let options: [String]
    let selectedIndex: Int
    let keyFrame: CGRect
    let isShifted: Bool
    let isCapsLock: Bool

    private let optionWidth: CGFloat = 44
    private let bubbleHeight: CGFloat = 54

    var body: some View {
        let totalWidth = optionWidth * CGFloat(options.count)
        // Center bubble over the key
        let bubbleX = min(
            max(keyFrame.midX, totalWidth / 2 + 6),
            UIScreen.main.bounds.width - totalWidth / 2 - 6
        )
        let tailHeight: CGFloat = 16
        let totalHeight = bubbleHeight + tailHeight
        // Neck extends 9pt into the key to cover its rounded top corners
        let desiredY = keyFrame.minY + 9 - totalHeight / 2
        let bubbleY = max(desiredY, totalHeight / 2)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                    let display = isShifted
                        ? LezgiLayout.applyCase(opt, capsLock: isCapsLock)
                        : opt
                    Text(display)
                        .font(.system(size: 24))
                        .foregroundColor(i == selectedIndex ? .white : Color(UIColor.label))
                        .frame(width: optionWidth, height: bubbleHeight)
                        .background(i == selectedIndex ? Color.blue : Color.kbLetterKeyPressed)
                }
            }
            .cornerRadius(10)

            // Key-width neck centered under the pressed key, not under the bubble center
            Rectangle()
                .fill(Color.kbLetterKeyPressed)
                .frame(width: keyFrame.width, height: tailHeight)
                .offset(x: keyFrame.midX - bubbleX)
        }
        // Flatten bubble + neck into one layer so the shadow wraps the combined
        // silhouette instead of drawing a seam where the neck meets the bubble
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        .position(x: bubbleX, y: bubbleY)
    }
}

// MARK: - Key preview bubble

private struct KeyPreviewBubble: View {
    let label: String
    let frame: CGRect

    private let bubbleHeight: CGFloat = 54
    private let neckAboveKey: CGFloat = 11   // gap between bubble bottom and key top

    var body: some View {
        let width = max(frame.width, 44)
        // Neck runs the full key height so the shape replaces the key entirely;
        // capped at frame.maxY so top-row popups stay inside the keyboard view
        let totalHeight = min(bubbleHeight + neckAboveKey + frame.height, frame.maxY)
        ZStack(alignment: .top) {
            KeyPreviewShape(neckWidth: frame.width,
                            bubbleHeight: bubbleHeight,
                            cornerRadius: 8)
                .fill(Color.kbLetterKeyPressed)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            Text(label)
                .font(.system(size: 28))
                .foregroundColor(Color(UIColor.label))
                .frame(width: width, height: bubbleHeight)
        }
        .frame(width: width, height: totalHeight)
        .position(
            x: frame.midX,
            // Bottom edge aligns with the key bottom
            y: frame.maxY - totalHeight / 2
        )
    }
}

// One continuous silhouette for the key preview: rounded bubble on top,
// sides curving inward to a neck matching the pressed key width, flat bottom.
private struct KeyPreviewShape: Shape {
    let neckWidth: CGFloat
    let bubbleHeight: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = max((rect.width - neckWidth) / 2, 0)
        let bubbleBottom = rect.minY + bubbleHeight
        let curveStart = bubbleBottom - 6   // sides begin bending inward
        let curveEnd   = bubbleBottom + 6   // neck sides become vertical

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        // top edge + top-right corner
        p.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        // right side down, then S-curve inward to neck
        p.addLine(to: CGPoint(x: rect.maxX, y: curveStart))
        p.addCurve(to: CGPoint(x: rect.maxX - inset, y: curveEnd),
                   control1: CGPoint(x: rect.maxX, y: bubbleBottom),
                   control2: CGPoint(x: rect.maxX - inset, y: bubbleBottom))
        // neck right side, rounded bottom corners (key-like), neck left side
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - cornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - inset - cornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset + cornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset, y: rect.maxY - cornerRadius),
                       control: CGPoint(x: rect.minX + inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: curveEnd))
        // S-curve outward back to bubble, left side up
        p.addCurve(to: CGPoint(x: rect.minX, y: curveStart),
                   control1: CGPoint(x: rect.minX + inset, y: bubbleBottom),
                   control2: CGPoint(x: rect.minX, y: bubbleBottom))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        // top-left corner
        p.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Single key (visual only — gestures handled by RowView)

private struct KeyButton: View {

    let cap: KeyCap
    @ObservedObject var model: KeyboardModel
    let returnKeyType: UIReturnKeyType
    var isPressed: Bool = false

    var body: some View {
        keyLabel
            // While a character key is pressed its bubble shows the letter,
            // so the key's own label is hidden like on the native keyboard
            .opacity(hidesLabel ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
            .allowsHitTesting(false)
    }

    private var hidesLabel: Bool {
        // Native blanks all key labels while space-drag cursor mode is active
        if model.isSpaceCursorMode { return true }
        if case .character = cap { return isPressed }
        return false
    }

    @ViewBuilder
    private var keyLabel: some View {
        switch cap {

        case .space:
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                Text("ЛЕЗГ")
                    .font(.system(size: 10))
                    .foregroundColor(Color(UIColor.systemGray2))
                    .padding(.trailing, 6)
                    .padding(.bottom, 4)
                    .opacity(model.showsKeyboardName ? 0 : 1)
                if model.showsKeyboardName {
                    // Keyboard name shown centered right after the keyboard appears
                    Text("Лезги чӏал")
                        .font(.system(size: 16))
                        .foregroundColor(Color(UIColor.label))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.showsKeyboardName)

        case .return:
            let text = returnLabel(for: returnKeyType)
            if text.isEmpty {
                Image(systemName: "return")
                    .font(.system(size: 18))
                    .foregroundColor(Color(UIColor.label))
            } else {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.label))
            }

        case .emoji:
            Image(systemName: "face.smiling")
                .font(.system(size: 20))
                .foregroundColor(Color(UIColor.label))

        case .backspace:
            Image(systemName: "delete.backward")
                .font(.system(size: 18))
                .foregroundColor(Color(UIColor.label))

        case .shift:
            Image(systemName: model.isCapsLock ? "capslock.fill" : (model.isShifted ? "shift.fill" : "shift"))
                .font(.system(size: 18))
                .foregroundColor(Color(UIColor.label))

        default:
            Text(LezgiLayout.label(for: cap, shifted: model.isShifted))
                .font(.system(size: LezgiLayout.fontSize(for: cap)))
                .foregroundColor(Color(UIColor.label))
        }
    }

    private var backgroundColor: Color {
        // Spacebar is highlighted while it shows the keyboard name, like native
        if case .space = cap, model.showsKeyboardName { return .kbLetterKeyPressed }
        return isPressed ? .kbLetterKeyPressed : .kbLetterKey
    }
}

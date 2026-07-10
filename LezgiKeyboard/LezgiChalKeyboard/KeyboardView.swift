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
    static let kbFuncKey = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
            : UIColor(red: 0.678, green: 0.702, blue: 0.733, alpha: 1)
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

    // Key preview bubble state
    @State private var pressedCap: KeyCap? = nil
    @State private var pressedFrame: CGRect = .zero

    // Suggestion bar press state
    @State private var pressedSuggestionIndex: Int? = nil

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

    private var emojiPage: some View {
        VStack(spacing: 0) {
            // Header — same height as suggestion bar to keep total keyboard height stable
            Text("Эмодзи")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 36)

            // Scrollable emoji grid
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(KeyboardModel.emojiSections, id: \.title) { section in
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8),
                            spacing: 2
                        ) {
                            ForEach(section.emoji, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 26))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onEmojiInsert?(emoji) }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom bar: ABC + backspace
            HStack(spacing: 6) {
                Button(action: { onKey(.letters) }) {
                    Text("АБВ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(UIColor.label))
                        .frame(maxWidth: .infinity)
                        .frame(height: 43)
                        .background(Color.kbFuncKey)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                }
                Button(action: { onKey(.backspace) }) {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 18))
                        .foregroundColor(Color(UIColor.label))
                        .frame(width: 80)
                        .frame(height: 43)
                        .background(Color.kbFuncKey)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
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
            }
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

    @State private var rowMinY: CGFloat = 0
    @State private var isPressed = false
    @State private var isLongPressed = false
    @State private var longPressTimer: DispatchWorkItem? = nil
    @State private var repeatTimer: Timer? = nil
    @State private var activeCap: KeyCap? = nil

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
                    KeyButton(cap: cap, model: model, returnKeyType: model.returnKeyType)
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
            if isLongPressed { onDragMoved(value.location.x) }
            return
        }
        isPressed = true
        guard let key = nearest(touchX: value.location.x) else { return }
        activeCap = key.cap
        onPress(key.cap, key.frame)

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

    private func handleEnded() {
        longPressTimer?.cancel()
        longPressTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        isPressed = false

        if isLongPressed {
            isLongPressed = false
            onLongRelease()
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
        let tailHeight: CGFloat = 8
        let desiredY = keyFrame.minY - bubbleHeight / 2 - tailHeight - 4
        let bubbleY = max(desiredY, bubbleHeight / 2)

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
                        .background(i == selectedIndex ? Color.blue : Color.kbLetterKey)
                }
            }
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

            Triangle()
                .fill(Color.kbLetterKey)
                .frame(width: 14, height: tailHeight)
        }
        .position(x: bubbleX, y: bubbleY)
    }
}

// MARK: - Key preview bubble

private struct KeyPreviewBubble: View {
    let label: String
    let frame: CGRect

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 28))
                .foregroundColor(Color(UIColor.label))
                .frame(width: max(frame.width, 44), height: 54)
                .background(Color.kbLetterKey)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            Triangle()
                .fill(Color.kbLetterKey)
                .frame(width: 14, height: 8)
        }
        .position(
            x: frame.midX,
            y: max(frame.minY - 36, 31)
        )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Single key (visual only — gestures handled by RowView)

private struct KeyButton: View {

    let cap: KeyCap
    @ObservedObject var model: KeyboardModel
    let returnKeyType: UIReturnKeyType

    var body: some View {
        keyLabel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
            .allowsHitTesting(false)
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
            }

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
        .kbLetterKey
    }
}

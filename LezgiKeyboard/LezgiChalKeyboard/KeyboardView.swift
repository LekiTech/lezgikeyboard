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
    let needsGlobe: Bool
    let returnKeyType: UIReturnKeyType
    let onKey: (KeyCap) -> Void

    // Key preview bubble state
    @State private var pressedCap: KeyCap? = nil
    @State private var pressedFrame: CGRect = .zero

    // Callout state
    @State private var calloutFrame: CGRect = .zero
    @State private var calloutOptions: [String] = []
    @State private var calloutSelectedIndex: Int = 0
    @State private var calloutBubbleLeftX: CGFloat = 0
    @State private var isShowingCallout: Bool = false

    private let calloutOptionWidth: CGFloat = 44

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                suggestionBar
                GeometryReader { geo in
                    VStack(spacing: 11) {
                        ForEach(Array(model.rows(needsGlobe: needsGlobe).enumerated()), id: \.offset) { _, row in
                            rowView(row: row, totalWidth: geo.size.width - 12)
                        }
                    }
                    .padding(.horizontal, 6)
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
        HStack(alignment: .center, spacing: 0) {
            suggestionCell("Зун")
            divider
            suggestionCell("Вун")
            divider
            suggestionCell("ГьикI")
        }
        .frame(height: 36)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(width: 1, height: 26)
            .offset(y: -8)
    }

    private func suggestionCell(_ word: String) -> some View {
        Text(word)
            .font(.system(size: 16))
            .foregroundColor(Color(UIColor.label))
            .frame(maxWidth: .infinity, maxHeight: 36, alignment: .center)
            .offset(y: -8)
    }

    // MARK: - Key row

    private func rowView(row: [KeyCap], totalWidth: CGFloat) -> some View {
        let spacing: CGFloat = 6
        let totalWeight = row.map { LezgiLayout.weight($0) }.reduce(0, +)
        let totalSpacing = spacing * CGFloat(row.count - 1)
        let unitWidth = (totalWidth - totalSpacing) / totalWeight

        return HStack(spacing: spacing) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, cap in
                KeyButton(
                    cap: cap,
                    model: model,
                    returnKeyType: returnKeyType,
                    onKey: { tappedCap in
                        onKey(tappedCap)
                    },
                    onPress: { frame in
                        pressedCap = cap
                        pressedFrame = frame
                    },
                    onRelease: {
                        pressedCap = nil
                    },
                    onLongPress: { frame, options in
                        pressedCap = nil
                        calloutFrame = frame
                        calloutOptions = options
                        // Calculate clamped bubble position (mirrors CalloutBubble layout)
                        let totalWidth = calloutOptionWidth * CGFloat(options.count)
                        let screenWidth = UIScreen.main.bounds.width
                        let bubbleX = min(max(frame.midX, totalWidth / 2 + 6), screenWidth - totalWidth / 2 - 6)
                        let leftX = bubbleX - totalWidth / 2
                        calloutBubbleLeftX = leftX
                        // Initial selection: option under the finger (key center relative to bubble)
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
                            onKey(.character(selected))  // handleKey applies case+shift
                        }
                        isShowingCallout = false
                        calloutOptions = []
                    }
                )
                .frame(width: unitWidth * LezgiLayout.weight(cap), height: 43)
            }
        }
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
        let desiredY = keyFrame.minY - bubbleHeight / 2 - 8
        let bubbleY = max(desiredY, bubbleHeight / 2)

        return ZStack {
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                    let display = isShifted
                        ? LezgiLayout.applyCase(opt, capsLock: isCapsLock)
                        : opt
                    Text(display)
                        .font(.system(size: 24))
                        .foregroundColor(i == selectedIndex ? .white : Color(UIColor.label))
                        .frame(width: optionWidth, height: bubbleHeight)
                        .background(i == selectedIndex ? Color.blue : Color(UIColor.systemBackground))
                }
            }
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
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
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            Triangle()
                .fill(Color(UIColor.systemBackground))
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

// MARK: - Single key

private struct KeyButton: View {

    let cap: KeyCap
    @ObservedObject var model: KeyboardModel
    let returnKeyType: UIReturnKeyType
    let onKey: (KeyCap) -> Void
    let onPress: (CGRect) -> Void
    let onRelease: () -> Void
    let onLongPress: (CGRect, [String]) -> Void
    let onDragMoved: (CGFloat) -> Void
    let onLongRelease: () -> Void

    @State private var isPressed = false
    @State private var isLongPressed = false
    @State private var longPressTimer: DispatchWorkItem? = nil
    @State private var repeatTimer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            keyLabel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboard"))
                        .onChanged { value in
                            if !isPressed {
                                isPressed = true
                                let frame = geo.frame(in: .named("keyboard"))
                                onPress(frame)

                                // Backspace hold-to-repeat, continuously accelerating
                                if case .backspace = cap {
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

                                // Schedule long-press for character keys with callouts
                                if case .character(let s) = cap,
                                   let extras = LezgiLayout.callouts[s.lowercased()], !extras.isEmpty {
                                    let base = s.lowercased()
                                    let opts = [base] + extras.filter { $0.lowercased() != base }
                                    let work = DispatchWorkItem {
                                        isLongPressed = true
                                        let f = geo.frame(in: .named("keyboard"))
                                        onLongPress(f, opts)
                                    }
                                    longPressTimer = work
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
                                }
                            } else if isLongPressed {
                                onDragMoved(value.location.x)
                            }
                        }
                        .onEnded { _ in
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
                                onKey(cap)
                            }
                        }
                )
        }
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

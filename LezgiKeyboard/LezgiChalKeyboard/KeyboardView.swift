//
//  KeyboardView.swift
//  LezgiChalKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI

// MARK: - Dynamic colors matching native iOS keyboard

private extension Color {
    // Letter keys: white in light, dark gray in dark
    static let kbLetterKey = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1)  // #3A3A3C
            : UIColor.white
    }))
    // Function keys (shift, backspace, 123...): medium gray in light, darker in dark
    static let kbFuncKey = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)  // #1C1C1E
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

    // Pressed key state for preview bubble
    @State private var pressedCap: KeyCap? = nil
    @State private var pressedFrame: CGRect = .zero

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
            .coordinateSpace(name: "keyboard")

            // Key preview bubble
            if let cap = pressedCap, case .character = cap {
                KeyPreviewBubble(
                    label: LezgiLayout.label(for: cap, shifted: model.isShifted),
                    frame: pressedFrame
                )
                .allowsHitTesting(false)
            }
        }
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
            .frame(width: 0.5, height: 20)
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
                    onKey: onKey,
                    onPress: { frame in
                        pressedCap = cap
                        pressedFrame = frame
                    },
                    onRelease: {
                        pressedCap = nil
                    }
                )
                .frame(width: unitWidth * LezgiLayout.weight(cap), height: 43)
            }
        }
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

            // Stem pointing down
            Triangle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: 14, height: 8)
        }
        .position(
            x: frame.midX,
            y: frame.minY - 36
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

    @State private var isPressed = false

    var body: some View {
        GeometryReader { geo in
            Button {
                onKey(cap)
            } label: {
                keyLabel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(backgroundColor)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            let frame = geo.frame(in: .named("keyboard"))
                            onPress(frame)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
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

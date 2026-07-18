//
//  SettingsPanelView.swift
//  LezgiChalKeyboard
//
//  Slide-up settings panel inside the keyboard (Phase 1 of the settings
//  plan), opened by the gear key in the bottom row. Pages: home, layout
//  variant, learned-words dictionary, about. Everything stays inside the
//  keyboard extension — no UIKit alerts, no modal presentation; the
//  delete-all confirmation is an in-panel sheet.
//

import SwiftUI

// MARK: - Panel palette (from the design prototype, light/dark)

private extension Color {
    static let spAccent = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.545, green: 0.533, blue: 1.0, alpha: 1)      // #8b88ff
            : UIColor(red: 0.357, green: 0.341, blue: 0.878, alpha: 1)    // #5b57e0
    }))
    static let spAccentTint = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.145, blue: 0.255, alpha: 1)    // #262541
            : UIColor(red: 0.925, green: 0.922, blue: 0.984, alpha: 1)    // #ecebfb
    }))
    static let spPanel = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.082, green: 0.082, blue: 0.090, alpha: 1)    // #151517
            : UIColor(red: 0.957, green: 0.957, blue: 0.973, alpha: 1)    // #f4f4f8
    }))
    static let spRow = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.122, green: 0.122, blue: 0.141, alpha: 1)    // #1f1f24
            : UIColor.white
    }))
    static let spSep = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.173, blue: 0.200, alpha: 1)    // #2c2c33
            : UIColor(red: 0.918, green: 0.918, blue: 0.945, alpha: 1)    // #eaeaf1
    }))
}

// MARK: - Panel

struct SettingsPanelView: View {

    @ObservedObject var model: KeyboardModel
    /// Deletes one learned word (the controller's existing closure).
    var onDeleteWord: ((String) -> Void)? = nil
    /// Wipes all learned data (the controller's existing closure).
    var onResetAll: (() -> Void)? = nil

    private enum Page {
        case home, layout, dictionary, about
    }

    @State private var stack: [Page] = [.home]
    @State private var showsDeleteAllSheet = false
    @State private var words: [String] = []
    @State private var wordCount = 0

    private var page: Page { stack.last ?? .home }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.spSep)
                    .frame(width: 36, height: 5)
                    .padding(.top, 6)

                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch page {
                        case .home:       homePage
                        case .layout:     layoutPage
                        case .dictionary: dictionaryPage
                        case .about:      aboutPage
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }

            if showsDeleteAllSheet { deleteAllSheet }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.spPanel)
        .onAppear(perform: refreshWords)
    }

    // MARK: - Header

    private var title: String {
        switch page {
        case .home:       return ""
        case .layout:     return "Раскладка"
        case .dictionary: return "Гафарган"
        case .about:      return "Клавиатурадикай"
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                if stack.count > 1 {
                    stack.removeLast()
                } else {
                    model.showsSettings = false
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text(verbatim: stack.count > 1 ? "Кьулухъ" : "Клавиатура")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.spAccent)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .frame(minWidth: 110, alignment: .leading)

            Text(verbatim: title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(UIColor.label))
                .frame(maxWidth: .infinity)

            Spacer().frame(minWidth: 110)
        }
        .padding(.horizontal, 4)
        .frame(height: 40)
    }

    // MARK: - Pages

    private var homePage: some View {
        Group {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "ЛЕЗГИ КЛАВИАТУРА")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                Text(verbatim: "Параметрар")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(UIColor.label))
            }
            .padding(.horizontal, 2)

            group {
                navRow(icon: "keyboard", title: "Раскладка",
                       value: model.layoutVariant == .classic ? "Ъ — ара патав" : "Ъ — вини жергеда",
                       page: .layout)
                divider
                navRow(icon: "text.book.closed", title: "Гафарган",
                       value: "\(wordCount)", page: .dictionary)
            }

            group {
                navRow(icon: "info.circle", title: "Клавиатурадикай",
                       value: "1.2.0", page: .about)
            }
        }
    }

    private var layoutPage: some View {
        Group {
            sectionLabel("Кӏеви лишандин («ъ») чка")
            group {
                radioRow(title: "Ара-клавишдин патав",
                         subtitle: "Вини жергеда 11 клавиша",
                         selected: model.layoutVariant == .classic) {
                    model.setLayoutVariant(.classic)
                }
                divider
                radioRow(title: "Вини жергеда",
                         subtitle: "«ъ» — «х»-дин патав",
                         selected: model.layoutVariant == .topRow) {
                    model.setLayoutVariant(.topRow)
                }
            }
        }
    }

    private var dictionaryPage: some View {
        Group {
            VStack(spacing: 2) {
                Text(verbatim: "\(wordCount)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(UIColor.label))
                Text(verbatim: "чирнавай гафар")
                    .font(.system(size: 13))
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            .frame(maxWidth: .infinity)

            if words.isEmpty {
                group {
                    Text(verbatim: "Гьеле гафар авач")
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                }
            } else {
                group {
                    ForEach(Array(words.enumerated()), id: \.element) { index, word in
                        if index > 0 { divider }
                        HStack {
                            Text(verbatim: word)
                                .font(.system(size: 15))
                                .foregroundColor(Color(UIColor.label))
                            Spacer(minLength: 8)
                            Button {
                                onDeleteWord?(word)
                                refreshWords()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.leading, 13)
                        .padding(.trailing, 4)
                        .frame(minHeight: 42)
                    }
                }

                group {
                    Button {
                        showsDeleteAllSheet = true
                    } label: {
                        Text(verbatim: "Вири чирнавай гафар чӏурун")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    private var aboutPage: some View {
        Group {
            VStack(spacing: 8) {
                Text(verbatim: "Л")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [Color(red: 0.49, green: 0.478, blue: 1.0),
                                                Color(red: 0.357, green: 0.341, blue: 0.878)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(spacing: 2) {
                    Text(verbatim: "Лезги клавиатура")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                    Text(verbatim: "Версия 1.2.0 · LekiTech")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    // MARK: - Delete-all sheet (in-panel, no UIKit presentation)

    private var deleteAllSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .contentShape(Rectangle())
                .onTapGesture { showsDeleteAllSheet = false }

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(verbatim: "Вири чирнавай гафар чӏурдани?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                    Text(verbatim: "Клавиатура забудет выученные слова и их сочетания. Отменить нельзя.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(Color.spSep)
                Button {
                    showsDeleteAllSheet = false
                    onResetAll?()
                    refreshWords()
                } label: {
                    Text(verbatim: "Чӏурун")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }

                Divider().background(Color.spSep)
                Button {
                    showsDeleteAllSheet = false
                } label: {
                    Text(verbatim: "Ваъ")
                        .font(.system(size: 16))
                        .foregroundColor(.spAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
            }
            .background(Color.spRow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Building blocks

    private func refreshWords() {
        wordCount = model.learnedWordCount()
        words = model.learnedTopWords()
    }

    private func group(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0, content: content)
            .background(Color.spRow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var divider: some View {
        Rectangle().fill(Color.spSep).frame(height: 1).padding(.leading, 13)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
            .padding(.horizontal, 4)
    }

    private func navRow(icon: String, title: String, value: String?, page: Page) -> some View {
        Button {
            stack.append(page)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.spAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.spAccentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(verbatim: title)
                    .font(.system(size: 15))
                    .foregroundColor(Color(UIColor.label))
                Spacer(minLength: 8)
                if let value {
                    Text(verbatim: value)
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
    }

    private func radioRow(title: String, subtitle: String, selected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title)
                        .font(.system(size: 15, weight: selected ? .medium : .regular))
                        .foregroundColor(selected ? .spAccent : Color(UIColor.label))
                    Text(verbatim: subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.spAccent)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
    }
}

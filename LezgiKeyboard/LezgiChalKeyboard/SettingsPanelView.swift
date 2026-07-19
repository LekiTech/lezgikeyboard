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
        case home, layout, input, theme, dictionary, about
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
                        case .input:      inputPage
                        case .theme:      themePage
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
        case .input:      return "Кхьин"
        case .theme:      return "Тема"
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
                       value: model.layoutVariant == .classic ? "Ъ — арадин къвалаг" : "Ъ — вини жергеда",
                       page: .layout)
                divider
                navRow(icon: "slider.horizontal.3", title: "Кхьин",
                       value: nil, page: .input)
                divider
                navRow(icon: "circle.lefthalf.filled", title: "Тема",
                       value: themeTitle(model.settings.theme), page: .theme)
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
                radioRow(title: "Арадин къвалаг",
                         subtitle: "Вини жергеда 11 клавиша",
                         selected: model.layoutVariant == .classic) {
                    model.setLayoutVariant(.classic)
                }
                divider
                radioRow(title: "Вини жергеда",
                         subtitle: "«ъ» — «х»-дин къвалаг",
                         selected: model.layoutVariant == .topRow) {
                    model.setLayoutVariant(.topRow)
                }
            }
        }
    }

    /// Input behavior (Phase 2): suggestions, key behaviors, learning speed,
    /// and the long-press callout delay. Only features the keyboard already
    /// has — every control maps 1:1 to a `KeyboardSettings` field.
    private var inputPage: some View {
        Group {
            // Lezgi titles stay primary and are never localized; the small
            // explanatory subtitles come from the extension's string catalog
            // and follow the user's system language (en fallback)
            sectionLabel("Теклифар — " + String(localized: "suggestions"))
            group {
                toggleRow(title: "Гафарин теклифар",
                          subtitle: String(localized: "Word suggestions"),
                          binding: binding(\.wordSuggestions))
                divider
                toggleRow(title: "Къведай гафунин теклиф",
                          subtitle: String(localized: "Next-word suggestion"),
                          binding: binding(\.nextWordSuggestions))
                divider
                toggleRow(title: "Теклифдилай гуьгъуьниз ара",
                          subtitle: String(localized: "Space after accepting a suggestion"),
                          binding: binding(\.autoSpaceAfterSuggestion))
            }

            sectionLabel("Клавишар")
            group {
                toggleRow(title: "Кьве ара — нукьта",
                          subtitle: String(localized: "Double space types a period"),
                          binding: binding(\.doubleSpacePeriod))
                divider
                toggleRow(title: "Арадалди курсор",
                          subtitle: String(localized: "Cursor control with the space bar"),
                          binding: binding(\.spaceCursor))
                divider
                toggleRow(title: "Арадал «лезг»",
                          subtitle: String(localized: "Show «лезг» on the space bar"),
                          binding: binding(\.spaceLabel))
            }

            sectionLabel("Чирун — " + String(localized: "learning"))
            group {
                learnSpeedRow(.fast, title: "Фад",
                              subtitle: "1 сефер · " + String(localized: "after 1 use"))
                divider
                learnSpeedRow(.normal, title: "Адетдин",
                              subtitle: "3 сефер · " + String(localized: "after 3 uses"))
                divider
                learnSpeedRow(.conservative, title: "Яваш",
                              subtitle: "5 сефер · " + String(localized: "after 5 uses"))
            }

            sectionLabel("Алава гьарфар (ӏ, кь, къ…) — " + String(localized: "long press"))
            group {
                calloutDelayRow(.short, title: "Куьруь ял",
                                subtitle: "0,2 с · " + String(localized: "short delay"))
                divider
                calloutDelayRow(.normal, title: "Адетдин ял",
                                subtitle: "0,3 с · " + String(localized: "normal delay"))
                divider
                calloutDelayRow(.long, title: "Яргъи ял",
                                subtitle: "0,45 с · " + String(localized: "long delay"))
            }
        }
    }

    private func learnSpeedRow(_ speed: KeyboardSettings.LearnSpeed,
                               title: String, subtitle: String) -> some View {
        radioRow(title: title, subtitle: subtitle,
                 selected: model.settings.learnSpeed == speed) {
            model.updateSettings { $0.learnSpeed = speed }
        }
    }

    private func calloutDelayRow(_ delay: KeyboardSettings.CalloutDelay,
                                 title: String, subtitle: String) -> some View {
        radioRow(title: title, subtitle: subtitle,
                 selected: model.settings.calloutDelay == delay) {
            model.updateSettings { $0.calloutDelay = delay }
        }
    }

    // MARK: - Theme page

    private var themePage: some View {
        Group {
            sectionLabel("Тема — " + String(localized: "theme"))
            group {
                themeRow(.system, title: "Системадин",
                         subtitle: String(localized: "Match the system"))
                divider
                themeRow(.light, title: "Экуь",
                         subtitle: String(localized: "Light theme"))
                divider
                themeRow(.dark, title: "Мичӏи",
                         subtitle: String(localized: "Dark theme"))
            }
        }
    }

    /// A tap applies instantly: the controller observes `settings.theme`
    /// and flips `overrideUserInterfaceStyle`, recoloring the keyboard
    /// (panel included) live, with nothing to close or reopen.
    private func themeRow(_ theme: KeyboardSettings.Theme,
                          title: String, subtitle: String) -> some View {
        radioRow(title: title, subtitle: subtitle,
                 selected: model.settings.theme == theme) {
            model.updateSettings { $0.theme = theme }
        }
    }

    private func themeTitle(_ theme: KeyboardSettings.Theme) -> String {
        switch theme {
        case .system: return "Системадин"
        case .light:  return "Экуь"
        case .dark:   return "Мичӏи"
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
                Text(verbatim: "Вири чирнавай гафар чӏурдани?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(UIColor.label))
                    .multilineTextAlignment(.center)
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

    private func binding(_ keyPath: WritableKeyPath<KeyboardSettings, Bool>) -> Binding<Bool> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } })
    }

    private func toggleRow(title: String, subtitle: String? = nil,
                           binding: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: title)
                    .font(.system(size: 15))
                    .foregroundColor(Color(UIColor.label))
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(.spAccent)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .frame(minHeight: 46)
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

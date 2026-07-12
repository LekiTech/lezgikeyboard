//
//  ContentView.swift
//  LezgiKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(\.openURL) private var openURL
    @State private var stickerError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                installCard
                stickersCard
                features
                footer
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert("Stickers", isPresented: .init(get: { stickerError != nil },
                                              set: { if !$0 { stickerError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stickerError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .indigo],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                )
            Text("Lezgi Keyboard")
                .font(.title.weight(.bold))
            Text("Type in your native language")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Feature cards

    private var features: some View {
        VStack(spacing: 12) {
            FeatureCard(icon: "textformat.abc", tint: .blue,
                        title: "Full Lezgi alphabet",
                        subtitle: "Palochka and digraphs like цӏ, къ, уь are one long press away")
            FeatureCard(icon: "text.book.closed.fill", tint: .orange,
                        title: "Word suggestions",
                        subtitle: "Over 20,000 Lezgi words, fully offline")
            FeatureCard(icon: "keyboard.fill", tint: .green,
                        title: "Feels native",
                        subtitle: "Matches the iOS keyboard down to the details")
            FeatureCard(icon: "lock.shield.fill", tint: .purple,
                        title: "Private by design",
                        subtitle: "Never asks for Full Access and sends nothing anywhere")
        }
    }

    // MARK: - Installation

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to install")
                .font(.title3.weight(.semibold))

            StepRow(number: "1", text: "Tap **Open Settings** below")
            StepRow(number: "2", text: "Tap **Keyboards**")
            StepRow(number: "3", text: "Turn on **Lezgi Keyboard**")
            StepRow(number: "4", text: "Switch languages using the 🌐 key on the keyboard")

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Text("Tip: you can also add the keyboard via **Settings → General → Keyboard → Keyboards**")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Stickers

    private var stickersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Eagle stickers")
                .font(.title3.weight(.semibold))
            Text("Add the Lezgi sticker pack to your favorite messenger. In iMessage the stickers appear automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                MessengerButton(title: "WhatsApp", systemImage: "phone.fill", tint: .green) {
                    share { try StickerSharing.addToWhatsApp() }
                }
                MessengerButton(title: "Telegram", systemImage: "paperplane.fill", tint: .blue) {
                    share { try StickerSharing.addToTelegram() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func share(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            stickerError = error.localizedDescription
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Developed by LekiTech")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
    }
}

// MARK: - Messenger button

private struct MessengerButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

// MARK: - Feature card

private struct FeatureCard: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Installation step

private struct StepRow: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    ContentView()
}

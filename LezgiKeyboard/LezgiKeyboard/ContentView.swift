//
//  ContentView.swift
//  LezgiKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Lezgi Keyboard")
                        .font(.largeTitle.weight(.bold))
                    Text("Keyboard for the Lezgi language on iOS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("How to install")
                        .font(.headline)

                    StepRow(number: "1", text: "Open **Settings** → **General** → **Keyboard**")
                    StepRow(number: "2", text: "Tap **Keyboards** → **Add New Keyboard**")
                    StepRow(number: "3", text: "Select **Lezgi Keyboard** from the list")
                    StepRow(number: "4", text: "Switch languages using the 🌐 key on the keyboard")
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("About the keyboard")
                        .font(.headline)

                    Text("The keyboard supports the Lezgi Cyrillic alphabet. Special letters (цI, уь, кI, кь, къ etc.) are available via long press. The ъ key is placed on the main layout because it is frequently used in Lezgi.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)
            }
            .padding(24)
        }
    }
}

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

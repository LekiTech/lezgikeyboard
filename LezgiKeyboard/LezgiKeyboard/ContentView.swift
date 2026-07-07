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
                    Text("Лезгинская Клавиатура")
                        .font(.largeTitle.weight(.bold))
                    Text("Клавиатура для лезгинского языка на iOS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Как установить")
                        .font(.headline)

                    StepRow(number: "1", text: "Откройте **Настройки** → **Основные** → **Клавиатура**")
                    StepRow(number: "2", text: "Нажмите **Клавиатуры** → **Добавить новую клавиатуру**")
                    StepRow(number: "3", text: "Выберите **Лезгинская Клавиатура** в списке")
                    StepRow(number: "4", text: "Чтобы переключаться между языками — нажимайте кнопку 🌐 на клавиатуре")
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("О клавиатуре")
                        .font(.headline)

                    Text("""
                    Клавиатура поддерживает лезгинский алфавит на кириллической основе. \
                    Особые буквы (цI, уь, кI, кь, къ и др.) доступны через долгое нажатие. \
                    Буква ъ вынесена на основную раскладку — она часто используется в лезгинском языке.
                    """)
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

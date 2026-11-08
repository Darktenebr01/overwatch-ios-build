import SwiftUI

enum Theme {
    static let bg = Color(red: 0.035, green: 0.055, blue: 0.09)
    static let card = Color(red: 0.07, green: 0.10, blue: 0.15)
    static let text = Color(red: 0.93, green: 0.95, blue: 0.98)
    static let muted = Color(red: 0.55, green: 0.62, blue: 0.70)
    static let accent = Color(red: 0.18, green: 0.88, blue: 0.78)
    static let amber = Color(red: 0.96, green: 0.72, blue: 0.25)
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
}

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06)))
    }
}

struct Kicker: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Theme.accent)
    }
}

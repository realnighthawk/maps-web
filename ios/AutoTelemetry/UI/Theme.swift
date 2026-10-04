import SwiftUI

// "Instrument cluster at night" tokens, same as the Android app. One accent; status colors only mean state.
extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum Tok {
    static let background = Color(light: 0xF6F7F9, dark: 0x0B0D10)
    static let surface = Color(light: 0xFFFFFF, dark: 0x14181D)
    static let raised = Color(light: 0xEEF0F3, dark: 0x1B2027)
    static let hairline = Color(light: 0xE1E5EA, dark: 0x262C34)
    static let text = Color(light: 0x0F1318, dark: 0xE8ECF1)
    static let muted = Color(light: 0x5B6674, dark: 0x8A94A1)
    static let accent = Color(light: 0x1B6FB5, dark: 0x7CC4FF)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x06141F)
    static let live = Color(light: 0x0E8F5A, dark: 0x3DDC97)
    static let warn = Color(light: 0x9A6200, dark: 0xFFB020)
    static let critical = Color(light: 0xC42B2B, dark: 0xFF5C5C)
}

/// A floating panel on the map: opaque surface, hairline border.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        // One stack, so a card with several rows is one panel rather than a panel per row.
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tok.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Tok.hairline))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(destructive ? Color.white : Tok.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background((destructive ? Tok.critical : Tok.accent).opacity(enabled ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Tok.accent)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func field() -> some View {
        self.padding(.horizontal, 14).frame(minHeight: 52)
            .background(Tok.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

import SwiftUI
import CoreText

/// Shared visual rules for teaching, templates, sessions and records.
enum AppDesign {
    private static let registerTimerFont: Void = {
        guard let url = Bundle.main.url(forResource: "BarlowCondensed-SemiBold", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func timerFont(compact: Bool) -> Font {
        _ = registerTimerFont
        return .custom("BarlowCondensed-SemiBold", size: compact ? 20 : 48, relativeTo: compact ? .headline : .largeTitle)
    }

    static let surface = Color(.systemGray6)
    static let accent = Color.blue
    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let imageRadius: CGFloat = 14

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .background(isEnabled ? Color.black : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func appCard() -> some View {
        padding(16)
            .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: AppDesign.cardRadius))
    }

    func actionBar() -> some View {
        padding(.horizontal, AppDesign.pagePadding)
            .padding(.top, 12).padding(.bottom, 8)
            .background(.regularMaterial)
    }
}

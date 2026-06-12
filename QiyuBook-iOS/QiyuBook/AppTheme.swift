import SwiftUI
import UIKit

enum AppTheme {
    static let ink = dynamicColor(
        light: UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.97, blue: 0.93, alpha: 1)
    )
    static let secondaryText = dynamicColor(
        light: UIColor(red: 0.39, green: 0.42, blue: 0.39, alpha: 1),
        dark: UIColor(red: 0.76, green: 0.81, blue: 0.76, alpha: 1)
    )
    static let faintText = dynamicColor(
        light: UIColor(red: 0.60, green: 0.63, blue: 0.60, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.68, blue: 0.63, alpha: 1)
    )
    static let paper = dynamicColor(
        light: UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.09, blue: 0.08, alpha: 1)
    )
    static let card = dynamicColor(
        light: UIColor(red: 1.00, green: 1.00, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.14, blue: 0.12, alpha: 1)
    )
    static let line = dynamicColor(
        light: UIColor(red: 0.91, green: 0.88, blue: 0.84, alpha: 1),
        dark: UIColor(red: 0.31, green: 0.38, blue: 0.33, alpha: 1)
    )
    static let seaGlass = dynamicColor(
        light: UIColor(red: 0.50, green: 0.71, blue: 0.69, alpha: 1),
        dark: UIColor(red: 0.39, green: 0.68, blue: 0.65, alpha: 1)
    )
    static let shell = dynamicColor(
        light: UIColor(red: 0.94, green: 0.78, blue: 0.72, alpha: 1),
        dark: UIColor(red: 0.75, green: 0.50, blue: 0.45, alpha: 1)
    )
    static let sand = dynamicColor(
        light: UIColor(red: 0.94, green: 0.89, blue: 0.80, alpha: 1),
        dark: UIColor(red: 0.27, green: 0.25, blue: 0.19, alpha: 1)
    )
    static let kelp = dynamicColor(
        light: UIColor(red: 0.35, green: 0.65, blue: 0.46, alpha: 1),
        dark: UIColor(red: 0.53, green: 0.83, blue: 0.61, alpha: 1)
    )
    static let primaryButtonText = dynamicColor(
        light: UIColor.white,
        dark: UIColor(red: 0.05, green: 0.07, blue: 0.06, alpha: 1)
    )
    static let shadow = dynamicColor(
        light: UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1),
        dark: UIColor.black
    )

    static let appBackground = LinearGradient(
        colors: [
            dynamicColor(
                light: UIColor(red: 0.97, green: 0.94, blue: 0.90, alpha: 1),
                dark: UIColor(red: 0.05, green: 0.07, blue: 0.06, alpha: 1)
            ),
            paper,
            dynamicColor(
                light: UIColor(red: 0.93, green: 0.96, blue: 0.94, alpha: 1),
                dark: UIColor(red: 0.08, green: 0.12, blue: 0.10, alpha: 1)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 28) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.primaryButtonText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppTheme.ink, in: Capsule())
            .opacity(isLoading ? 0.62 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppTheme.card.opacity(configuration.isPressed ? 0.72 : 0.9), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

import SwiftUI

/// Brutalist primary button style with hard edges and bold borders
struct BrutalistPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyStrong)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(ColorTokens.Semantic.foregroundPrimary.color)
            .foregroundStyle(ColorTokens.Semantic.backgroundPrimary.color)
            .overlay(
                RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal)
                    .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: BorderTokens.standard)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AnimationTokens.buttonPress, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Brutalist secondary button style with transparent background
struct BrutalistSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyStrong)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .foregroundStyle(ColorTokens.Semantic.foregroundPrimary.color)
            .overlay(
                RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal)
                    .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: BorderTokens.standard)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AnimationTokens.buttonPress, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == BrutalistPrimaryButtonStyle {
    static var brutalistPrimary: BrutalistPrimaryButtonStyle { BrutalistPrimaryButtonStyle() }
}

extension ButtonStyle where Self == BrutalistSecondaryButtonStyle {
    static var brutalistSecondary: BrutalistSecondaryButtonStyle { BrutalistSecondaryButtonStyle() }
}

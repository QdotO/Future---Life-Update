import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(AppTheme.Typography.body.weight(.semibold))
			.padding(.vertical, AppTheme.Spacing.md)
			.padding(.horizontal, AppTheme.Spacing.lg)
			.frame(maxWidth: .infinity)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(AppTheme.Palette.primary)
			)
			.foregroundStyle(Color.white)
			.opacity(configuration.isPressed ? 0.85 : 1)
			.animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
	}
}

struct SecondaryButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(AppTheme.Typography.body.weight(.semibold))
			.padding(.vertical, AppTheme.Spacing.md)
			.padding(.horizontal, AppTheme.Spacing.lg)
			.frame(maxWidth: .infinity)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(AppTheme.Palette.surface)
					.overlay(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.stroke(AppTheme.Palette.outline, lineWidth: 1)
					)
			)
			.foregroundStyle(AppTheme.Palette.primary)
			.opacity(configuration.isPressed ? 0.85 : 1)
			.animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
	}
}

extension ButtonStyle where Self == PrimaryButtonStyle {
	static var primaryProminent: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
	static var secondaryProminent: SecondaryButtonStyle { SecondaryButtonStyle() }
}

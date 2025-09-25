import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		PrimaryButton(configuration: configuration)
	}

	private struct PrimaryButton: View {
		let configuration: Configuration
		@FocusState private var isFocused: Bool
		@State private var isHovering = false

		var body: some View {
			configuration.label
				.font(AppTheme.Typography.bodyStrong)
				.padding(.vertical, AppTheme.Spacing.md)
				.padding(.horizontal, AppTheme.Spacing.lg)
				.frame(maxWidth: .infinity)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(AppTheme.Palette.primary)
				)
				.foregroundStyle(AppTheme.Palette.accentOnPrimary)
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(AppTheme.Palette.focusRing, lineWidth: isFocused || isHovering ? 2 : 0)
				)
				.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
				.opacity(configuration.isPressed ? 0.85 : 1)
				.animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
				.focused($isFocused)
				.onHover { hovering in
					withAnimation(.easeInOut(duration: 0.1)) {
						isHovering = hovering
					}
				}
		}
	}
}

struct SecondaryButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		SecondaryButton(configuration: configuration)
	}

	private struct SecondaryButton: View {
		let configuration: Configuration
		@FocusState private var isFocused: Bool
		@State private var isHovering = false

		var body: some View {
			configuration.label
				.font(AppTheme.Typography.bodyStrong)
				.padding(.vertical, AppTheme.Spacing.md)
				.padding(.horizontal, AppTheme.Spacing.lg)
				.frame(maxWidth: .infinity)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(AppTheme.Palette.surface)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(AppTheme.Palette.neutralBorder, lineWidth: 1)
						)
				)
				.foregroundStyle(AppTheme.Palette.neutralStrong)
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(AppTheme.Palette.focusRing, lineWidth: isFocused || isHovering ? 2 : 0)
				)
				.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
				.opacity(configuration.isPressed ? 0.88 : 1)
				.animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
				.focused($isFocused)
				.onHover { hovering in
					withAnimation(.easeInOut(duration: 0.1)) {
						isHovering = hovering
					}
				}
		}
	}
}

extension ButtonStyle where Self == PrimaryButtonStyle {
	static var primaryProminent: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
	static var secondaryProminent: SecondaryButtonStyle { SecondaryButtonStyle() }
}

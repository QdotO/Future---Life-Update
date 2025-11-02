import SwiftUI

struct CardBackground<Content: View>: View {
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.designStyle) private var designStyle
	private let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		switch designStyle {
		case .liquid:
			liquidStyle
		case .brutalist:
			brutalistStyle
		}
	}

	private var liquidStyle: some View {
		content
			.padding(AppTheme.Spacing.lg)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(AppTheme.Palette.surface)
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.stroke(
								AppTheme.Palette.outline, lineWidth: colorScheme == .dark ? 0 : 1)
					)
			)
			.appShadow(colorScheme == .dark ? nil : AppTheme.Shadow.card)
	}

	private var brutalistStyle: some View {
		content
			.padding(AppTheme.BrutalistSpacing.md)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(AppTheme.BrutalistPalette.background)
			.overlay(alignment: .topLeading) {
				Rectangle()
					.stroke(
						AppTheme.BrutalistPalette.border,
						lineWidth: AppTheme.BrutalistBorder.standard)
			}
			.overlay(alignment: .bottom) {
				Rectangle()
					.fill(AppTheme.BrutalistPalette.border.opacity(0.25))
					.frame(height: 1)
			}
	}
}

extension View {
	func cardStyle() -> some View {
		CardBackground { self }
	}

	func brutalistCard(padding: CGFloat = AppTheme.BrutalistSpacing.md) -> some View {
		self
			.padding(padding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(AppTheme.BrutalistPalette.background)
			.overlay(
				Rectangle()
					.stroke(
						AppTheme.BrutalistPalette.border,
						lineWidth: AppTheme.BrutalistBorder.standard)
			)
	}

	func brutalistSectionHeader(_ text: String) -> some View {
		VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
			Text(text.uppercased())
				.font(AppTheme.BrutalistTypography.overline)
				.foregroundColor(AppTheme.BrutalistPalette.secondary)
				.tracking(0.1)
		}
	}
}

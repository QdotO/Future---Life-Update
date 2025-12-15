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
			.background(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
					.fill(AppTheme.BrutalistPalette.background)
			)
			.overlay(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
					.stroke(
						AppTheme.BrutalistPalette.border,
						lineWidth: AppTheme.BrutalistBorder.thin)
			)
			.appShadow(colorScheme == .dark ? nil : AppTheme.BrutalistShadow.elevation2)
	}
}

/// A card with a left accent stripe for category indication
struct AccentStripedCard<Content: View>: View {
	@Environment(\.colorScheme) private var colorScheme
	let accentColor: Color
	let content: Content

	init(accent: Color = AppTheme.BrutalistPalette.accent, @ViewBuilder content: () -> Content) {
		self.accentColor = accent
		self.content = content()
	}

	var body: some View {
		HStack(spacing: 0) {
			// Left accent stripe
			RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
				.fill(accentColor)
				.frame(width: 4)

			// Card content
			content
				.padding(AppTheme.BrutalistSpacing.md)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(
			RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
				.fill(AppTheme.BrutalistPalette.background)
		)
		.overlay(
			RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
				.stroke(
					AppTheme.BrutalistPalette.border,
					lineWidth: AppTheme.BrutalistBorder.thin)
		)
		.appShadow(colorScheme == .dark ? nil : AppTheme.BrutalistShadow.elevation2)
	}
}

/// A stat box for displaying metrics
struct StatBox: View {
	let label: String
	let value: String
	let icon: String?
	var accentColor: Color = AppTheme.BrutalistPalette.accent

	init(
		_ label: String, value: String, icon: String? = nil,
		accent: Color = AppTheme.BrutalistPalette.accent
	) {
		self.label = label
		self.value = value
		self.icon = icon
		self.accentColor = accent
	}

	var body: some View {
		VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
			// Label
			Text(label.uppercased())
				.font(AppTheme.BrutalistTypography.overline)
				.foregroundColor(AppTheme.BrutalistPalette.secondary)
				.tracking(0.5)

			// Value with optional icon
			HStack(spacing: AppTheme.BrutalistSpacing.micro) {
				if let icon = icon {
					Image(systemName: icon)
						.font(.system(size: 14, weight: .semibold))
						.foregroundColor(accentColor)
				}

				Text(value)
					.font(AppTheme.BrutalistTypography.dataSmall)
					.foregroundColor(AppTheme.BrutalistPalette.foreground)
			}
		}
		.padding(AppTheme.BrutalistSpacing.sm)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
				.fill(AppTheme.BrutalistPalette.surface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
				.stroke(
					AppTheme.BrutalistPalette.border, lineWidth: AppTheme.BrutalistBorder.hairline)
		)
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
			.background(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
					.fill(AppTheme.BrutalistPalette.background)
			)
			.overlay(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
					.stroke(
						AppTheme.BrutalistPalette.border,
						lineWidth: AppTheme.BrutalistBorder.thin)
			)
	}

	/// A card with subtle shadow for elevation
	func elevatedCard(padding: CGFloat = AppTheme.BrutalistSpacing.md) -> some View {
		self
			.padding(padding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
					.fill(AppTheme.BrutalistPalette.background)
			)
			.overlay(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
					.stroke(
						AppTheme.BrutalistPalette.border,
						lineWidth: AppTheme.BrutalistBorder.thin)
			)
			.appShadow(AppTheme.BrutalistShadow.elevation2)
	}

	/// A surface card (lighter background for nested elements)
	func surfaceCard(padding: CGFloat = AppTheme.BrutalistSpacing.sm) -> some View {
		self
			.padding(padding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
					.fill(AppTheme.BrutalistPalette.surface)
			)
			.overlay(
				RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
					.stroke(
						AppTheme.BrutalistPalette.border,
						lineWidth: AppTheme.BrutalistBorder.hairline)
			)
	}

	func brutalistSectionHeader(_ text: String) -> some View {
		VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
			Text(text.uppercased())
				.font(AppTheme.BrutalistTypography.overline)
				.foregroundColor(AppTheme.BrutalistPalette.secondary)
				.tracking(0.8)
		}
	}

	/// Divider line in brutalist style
	func brutalistDivider() -> some View {
		Rectangle()
			.fill(AppTheme.BrutalistPalette.border)
			.frame(height: AppTheme.BrutalistBorder.hairline)
	}
}

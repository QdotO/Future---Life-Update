import SwiftUI

struct CardBackground<Content: View>: View {
	@Environment(\.colorScheme) private var colorScheme
	private let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		content
			.padding(AppTheme.Spacing.lg)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(AppTheme.Palette.surface)
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.stroke(AppTheme.Palette.outline, lineWidth: colorScheme == .dark ? 0 : 1)
					)
			)
			.appShadow(colorScheme == .dark ? nil : AppTheme.Shadow.card)
	}
}

extension View {
	func cardStyle() -> some View {
		CardBackground { self }
	}
}

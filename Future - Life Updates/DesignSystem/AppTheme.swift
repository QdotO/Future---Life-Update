import SwiftUI

enum AppTheme {
	enum Palette {
		static let primary = Color(hex: 0x4461F2)
		static let secondary = Color(hex: 0x6C8AFA)
		static let background = Color(dynamicLight: Color(.systemGroupedBackground), dynamicDark: Color(.black))
		static let surface = Color(dynamicLight: Color(.secondarySystemBackground), dynamicDark: Color(.secondarySystemBackground))
		static let outline = Color(dynamicLight: .black.opacity(0.1), dynamicDark: .white.opacity(0.2))
		static let accent = Color.accentColor
	}

	enum Typography {
		static let title: Font = .system(.title2, design: .rounded).weight(.semibold)
		static let sectionHeader: Font = .system(.headline, design: .rounded)
		static let body: Font = .system(.body, design: .rounded)
		static let caption: Font = .system(.caption, design: .rounded)
	}

	enum Spacing {
		static let xs: CGFloat = 4
		static let sm: CGFloat = 8
		static let md: CGFloat = 12
		static let lg: CGFloat = 16
		static let xl: CGFloat = 24
	}

	enum Shadow {
		static let card = ShadowStyle(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
	}

	static func backgroundGradient(colorScheme: ColorScheme) -> LinearGradient {
		let top = Color(.systemGroupedBackground)
		let bottom = colorScheme == .dark ? Palette.surface.opacity(0.6) : Color.white
		return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
	}
}

struct ShadowStyle {
	let color: Color
	let radius: CGFloat
	let x: CGFloat
	let y: CGFloat
}

private struct AppShadowModifier: ViewModifier {
	let style: ShadowStyle?

	@ViewBuilder
	func body(content: Content) -> some View {
		if let style {
			content.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
		} else {
			content
		}
	}
}

extension View {
	func appShadow(_ style: ShadowStyle?) -> some View {
		modifier(AppShadowModifier(style: style))
	}
}

private extension Color {
	init(hex: UInt) {
		let red = Double((hex >> 16) & 0xFF) / 255
		let green = Double((hex >> 8) & 0xFF) / 255
		let blue = Double(hex & 0xFF) / 255
		self.init(red: red, green: green, blue: blue)
	}

	init(dynamicLight light: Color, dynamicDark dark: Color) {
		self.init(UIColor { trait in
			trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
		})
	}
}

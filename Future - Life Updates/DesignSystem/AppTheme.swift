import SwiftUI

#if canImport(UIKit)
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

enum AppTheme {
	// MARK: - Design Style Toggle
	enum DesignStyle {
		case liquid
		case brutalist
	}

	enum Palette {
		static let primary = Color(hex: 0x4461F2)
		static let secondary = Color(hex: 0x6C8AFA)
		#if os(iOS)
			static let background = Color(
				dynamicLight: Color(.systemGroupedBackground), dynamicDark: Color(.black))
			static let surface = Color(
				dynamicLight: Color(.secondarySystemBackground),
				dynamicDark: Color(.secondarySystemBackground))
			static let surfaceElevated = Color(
				dynamicLight: Color(.systemBackground),
				dynamicDark: Color(.tertiarySystemBackground))
			static let neutralBorder = Color(
				dynamicLight: Color(.systemGray4), dynamicDark: Color(.systemGray5))
			static let neutralStrong = Color(
				dynamicLight: Color(.label), dynamicDark: Color(.label))
			static let neutralSubdued = Color(
				dynamicLight: Color(.secondaryLabel), dynamicDark: Color(.secondaryLabel))
			static let focusRing = Color(
				dynamicLight: Color(UIColor.systemBlue.withAlphaComponent(0.45)),
				dynamicDark: Color(UIColor.systemBlue.withAlphaComponent(0.6)))
		#elseif os(macOS)
			static let background = Color(
				dynamicLight: Color(nsColor: .windowBackgroundColor), dynamicDark: Color.black)
			static let surface = Color(
				dynamicLight: Color(nsColor: .controlBackgroundColor),
				dynamicDark: Color(nsColor: .controlBackgroundColor))
			static let surfaceElevated = Color(
				dynamicLight: Color.white, dynamicDark: Color(nsColor: .controlColor))
			static let neutralBorder = Color(
				dynamicLight: Color(nsColor: .separatorColor),
				dynamicDark: Color(nsColor: .separatorColor))
			static let neutralStrong = Color(
				dynamicLight: Color(nsColor: .labelColor), dynamicDark: Color(nsColor: .labelColor))
			static let neutralSubdued = Color(
				dynamicLight: Color(nsColor: .secondaryLabelColor),
				dynamicDark: Color(nsColor: .secondaryLabelColor))
			static let focusRing = Color(
				dynamicLight: Color(nsColor: NSColor.controlAccentColor.withAlphaComponent(0.45)),
				dynamicDark: Color(nsColor: NSColor.controlAccentColor.withAlphaComponent(0.6)))
		#endif
		static let outline = Color(
			dynamicLight: .black.opacity(0.1), dynamicDark: .white.opacity(0.2))
		static let accent = Color.accentColor
		static let accentOnPrimary = Color.white
	}

	// MARK: - Brutalist Design System
	enum BrutalistPalette {
		// Light mode - pure black and white
		static let backgroundLight = Color(hex: 0xFFFFFF)
		static let foregroundLight = Color(hex: 0x000000)
		static let borderLight = Color(hex: 0x000000)
		static let secondaryLight = Color(hex: 0x666666)

		// Dark mode - pure black and white
		static let backgroundDark = Color(hex: 0x000000)
		static let foregroundDark = Color(hex: 0xFFFFFF)
		static let borderDark = Color(hex: 0xFFFFFF)
		static let secondaryDark = Color(hex: 0xCCCCCC)

		// Accent - orange (consistent across modes)
		static let accentOrange = Color(hex: 0xFF6600)
		static let accentOrangeDark = Color(hex: 0xFF8533)

		// Dynamic helpers
		static let background = Color(dynamicLight: backgroundLight, dynamicDark: backgroundDark)
		static let foreground = Color(dynamicLight: foregroundLight, dynamicDark: foregroundDark)
		static let border = Color(dynamicLight: borderLight, dynamicDark: borderDark)
		static let secondary = Color(dynamicLight: secondaryLight, dynamicDark: secondaryDark)
		static let accent = Color(dynamicLight: accentOrange, dynamicDark: accentOrangeDark)
	}

	enum BrutalistTypography {
		// Display/Hero - 34pt bold
		static let display = Font.system(size: 34, weight: .bold, design: .default)
		static let displayMono = Font.system(size: 34, weight: .bold, design: .monospaced)

		// Title - 24pt bold
		static let title = Font.system(size: 24, weight: .bold, design: .default)
		static let titleMono = Font.system(size: 24, weight: .bold, design: .monospaced)

		// Headline - 17pt semibold
		static let headline = Font.system(size: 17, weight: .semibold, design: .default)
		static let headlineMono = Font.system(size: 17, weight: .semibold, design: .monospaced)

		// Body - 15pt regular
		static let body = Font.system(size: 15, weight: .regular, design: .default)
		static let bodyMono = Font.system(size: 15, weight: .regular, design: .monospaced)
		static let bodyBold = Font.system(size: 15, weight: .semibold, design: .default)

		// Caption - 12pt regular
		static let caption = Font.system(size: 12, weight: .regular, design: .default)
		static let captionMono = Font.system(size: 12, weight: .regular, design: .monospaced)
		static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)

		// Overline/Label - 11pt bold, uppercase
		static let overline = Font.system(size: 11, weight: .bold, design: .default)
		static let overlineMono = Font.system(size: 11, weight: .bold, design: .monospaced)
	}

	enum BrutalistSpacing {
		static let micro: CGFloat = 4
		static let xs: CGFloat = 8
		static let sm: CGFloat = 12
		static let md: CGFloat = 16
		static let lg: CGFloat = 24
		static let xl: CGFloat = 32
		static let xxl: CGFloat = 48
		static let xxxl: CGFloat = 64
	}

	enum BrutalistBorder {
		static let thin: CGFloat = 1
		static let standard: CGFloat = 2
		static let thick: CGFloat = 3
	}

	enum BrutalistShadow {
		// Hard offset shadow (no blur) - for elevated cards
		static let hardOffset = ShadowStyle(
			color: .black.opacity(0.15),
			radius: 0,
			x: 4,
			y: 4
		)
		// None for pure flat aesthetic
		static let none = ShadowStyle(
			color: .clear,
			radius: 0,
			x: 0,
			y: 0
		)
	}

	enum Typography {
		static let title: Font = .system(.title2, design: .rounded).weight(.semibold)
		static let sectionHeader: Font = .system(.headline, design: .rounded)
		static let body: Font = .system(.body, design: .rounded)
		static let bodyStrong: Font = .system(.body, design: .rounded).weight(.semibold)
		static let caption: Font = .system(.caption, design: .rounded)
	}

	enum Spacing {
		static let xs: CGFloat = 4
		static let sm: CGFloat = 8
		static let md: CGFloat = 12
		static let lg: CGFloat = 16
		static let xl: CGFloat = 24
		static let grid: CGFloat = 12
	}

	enum Shadow {
		static let card = ShadowStyle(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
	}

	static func backgroundGradient(colorScheme: ColorScheme) -> LinearGradient {
		#if os(iOS)
			let top = Color(.systemGroupedBackground)
		#elseif os(macOS)
			let top = Color(nsColor: .windowBackgroundColor)
		#endif
		let bottom =
			colorScheme == .dark ? Palette.surface.opacity(0.6) : Palette.surface.opacity(0.8)
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

extension Color {
	fileprivate init(hex: UInt) {
		let red = Double((hex >> 16) & 0xFF) / 255
		let green = Double((hex >> 8) & 0xFF) / 255
		let blue = Double(hex & 0xFF) / 255
		self.init(red: red, green: green, blue: blue)
	}

	fileprivate init(dynamicLight light: Color, dynamicDark dark: Color) {
		#if os(iOS)
			self.init(
				UIColor { trait in
					trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
				})
		#elseif os(macOS)
			self.init(
				NSColor(name: nil) { appearance in
					appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
						? NSColor(dark) : NSColor(light)
				})
		#endif
	}
}

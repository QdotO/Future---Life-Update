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

	// MARK: - Neo-Brutalist Design System ("Warm Industrial")
	enum BrutalistPalette {
		// Light mode - Warm Industrial (off-white with warm charcoal)
		static let backgroundLight = Color(hex: 0xFAF7F2)  // Warm off-white (aged paper)
		static let foregroundLight = Color(hex: 0x2C2824)  // Warm black with brown undertone
		static let borderLight = Color(hex: 0xD4CDC3)  // Warm gray border
		static let secondaryLight = Color(hex: 0x6B6560)  // Muted warm gray
		static let surfaceLight = Color(hex: 0xFFFCF7)  // Lighter warm white

		// Dark mode - Warm charcoal (not pure black)
		static let backgroundDark = Color(hex: 0x1A1816)  // Warm charcoal
		static let foregroundDark = Color(hex: 0xF5F0E8)  // Warm cream
		static let borderDark = Color(hex: 0x3D3835)  // Warm dark gray
		static let secondaryDark = Color(hex: 0xA39E98)  // Muted light gray
		static let surfaceDark = Color(hex: 0x252220)  // Elevated dark surface

		// Primary accent - Deeper, warmer orange
		static let accentOrange = Color(hex: 0xE85D04)  // Warm burnt orange
		static let accentOrangeDark = Color(hex: 0xF48C06)  // Brighter orange for dark mode

		// Extended accent palette for variety
		static let accentPlum = Color(hex: 0x5F0F40)  // Burgundy plum
		static let accentNavy = Color(hex: 0x0D3B66)  // Deep navy for data
		static let accentForest = Color(hex: 0x386641)  // Forest green (success)
		static let accentTerracotta = Color(hex: 0xD4A373)  // Terracotta (caution)
		static let accentCoral = Color(hex: 0xBC4749)  // Muted coral red (danger)

		// Category accent colors (for goal cards)
		static let categoryHealth = Color(hex: 0x386641)  // Forest green
		static let categoryFitness = Color(hex: 0xE85D04)  // Burnt orange
		static let categoryProductivity = Color(hex: 0x0D3B66)  // Navy
		static let categoryHabits = Color(hex: 0x5F0F40)  // Plum
		static let categoryMood = Color(hex: 0xD4A373)  // Terracotta
		static let categoryLearning = Color(hex: 0x3A86FF)  // Bright blue
		static let categorySocial = Color(hex: 0xF72585)  // Magenta pink
		static let categoryFinance = Color(hex: 0x2D6A4F)  // Deep teal

		// Dynamic helpers
		static let background = Color(dynamicLight: backgroundLight, dynamicDark: backgroundDark)
		static let foreground = Color(dynamicLight: foregroundLight, dynamicDark: foregroundDark)
		static let border = Color(dynamicLight: borderLight, dynamicDark: borderDark)
		static let secondary = Color(dynamicLight: secondaryLight, dynamicDark: secondaryDark)
		static let surface = Color(dynamicLight: surfaceLight, dynamicDark: surfaceDark)
		static let accent = Color(dynamicLight: accentOrange, dynamicDark: accentOrangeDark)

		// Semantic colors
		static let success = accentForest
		static let warning = accentTerracotta
		static let danger = accentCoral
		static let info = accentNavy
	}

	enum BrutalistTypography {
		// Display/Hero - 40pt black weight with tight tracking
		static let display = Font.system(size: 40, weight: .black, design: .default)
		static let displayMono = Font.system(size: 40, weight: .black, design: .monospaced)

		// Title - 28pt bold with slight tracking
		static let title = Font.system(size: 28, weight: .bold, design: .default)
		static let titleMono = Font.system(size: 28, weight: .bold, design: .monospaced)

		// Headline - 18pt semibold
		static let headline = Font.system(size: 18, weight: .semibold, design: .default)
		static let headlineMono = Font.system(size: 18, weight: .semibold, design: .monospaced)

		// Body - 16pt regular with generous line height
		static let body = Font.system(size: 16, weight: .regular, design: .default)
		static let bodyMono = Font.system(size: 16, weight: .regular, design: .monospaced)
		static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)

		// Caption - 13pt regular
		static let caption = Font.system(size: 13, weight: .regular, design: .default)
		static let captionMono = Font.system(size: 13, weight: .regular, design: .monospaced)
		static let captionBold = Font.system(size: 13, weight: .semibold, design: .default)

		// Small - 12pt for metadata
		static let small = Font.system(size: 12, weight: .regular, design: .default)
		static let smallMono = Font.system(size: 12, weight: .medium, design: .monospaced)

		// Overline/Label - 11pt bold, uppercase with wide tracking
		static let overline = Font.system(size: 11, weight: .bold, design: .default)
		static let overlineMono = Font.system(size: 11, weight: .bold, design: .monospaced)

		// Data display - For numbers and stats
		static let dataLarge = Font.system(size: 32, weight: .bold, design: .monospaced)
		static let dataMedium = Font.system(size: 24, weight: .semibold, design: .monospaced)
		static let dataSmall = Font.system(size: 16, weight: .medium, design: .monospaced)
	}

	enum BrutalistSpacing {
		static let nano: CGFloat = 2  // Micro adjustments
		static let micro: CGFloat = 4  // Tight element gaps
		static let xs: CGFloat = 6  // Inner padding adjustments
		static let sm: CGFloat = 12  // Component internal spacing
		static let md: CGFloat = 16  // Standard gaps
		static let lg: CGFloat = 24  // Section spacing
		static let xl: CGFloat = 36  // Major section breaks
		static let xxl: CGFloat = 48  // Hero spacing
		static let xxxl: CGFloat = 72  // Dramatic pauses

		// Asymmetric padding for organic feel
		static let asymStart: CGFloat = 20
		static let asymEnd: CGFloat = 16
	}

	enum BrutalistBorder {
		static let hairline: CGFloat = 0.5  // Subtle dividers
		static let thin: CGFloat = 1  // Default borders
		static let standard: CGFloat = 2  // Interactive elements
		static let thick: CGFloat = 3  // Focus states
		static let heavy: CGFloat = 4  // Hero cards
	}

	enum BrutalistRadius {
		static let sharp: CGFloat = 0  // Pure brutalist
		static let minimal: CGFloat = 2  // Softened (prevents aliasing)
		static let soft: CGFloat = 8  // Interactive elements
		static let round: CGFloat = 12  // Pills, tags
		static let circular: CGFloat = 9999  // Fully round
	}

	enum BrutalistShadow {
		// Subtle elevation for cards
		static let elevation1 = ShadowStyle(
			color: .black.opacity(0.04),
			radius: 2,
			x: 0,
			y: 1
		)
		static let elevation2 = ShadowStyle(
			color: .black.opacity(0.08),
			radius: 6,
			x: 0,
			y: 2
		)
		static let elevation3 = ShadowStyle(
			color: .black.opacity(0.12),
			radius: 12,
			x: 0,
			y: 4
		)
		// Hard offset shadow (no blur) - brutalist option
		static let hardOffset = ShadowStyle(
			color: .black.opacity(0.1),
			radius: 0,
			x: 4,
			y: 4
		)
		static let hardOffset2 = ShadowStyle(
			color: .black.opacity(0.08),
			radius: 0,
			x: 6,
			y: 6
		)
		// None for pure flat aesthetic
		static let none = ShadowStyle(
			color: .clear,
			radius: 0,
			x: 0,
			y: 0
		)
		// Glow for accent elements
		static func accentGlow(opacity: Double = 0.25) -> ShadowStyle {
			ShadowStyle(
				color: BrutalistPalette.accent.opacity(opacity),
				radius: 16,
				x: 0,
				y: 0
			)
		}
	}

	enum BrutalistAnimation {
		static let instant: Double = 0.1
		static let fast: Double = 0.2
		static let normal: Double = 0.3
		static let slow: Double = 0.5
		static let dramatic: Double = 0.8

		static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
		static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.7)
		static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
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

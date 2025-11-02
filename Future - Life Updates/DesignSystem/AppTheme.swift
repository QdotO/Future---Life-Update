import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum AppTheme {
	enum Palette {
		static let primary = Color(hex: 0x4461F2)
		static let secondary = Color(hex: 0x6C8AFA)
		#if os(iOS)
		static let background = Color(dynamicLight: Color(.systemGroupedBackground), dynamicDark: Color(.black))
		static let surface = Color(dynamicLight: Color(.secondarySystemBackground), dynamicDark: Color(.secondarySystemBackground))
		static let surfaceElevated = Color(dynamicLight: Color(.systemBackground), dynamicDark: Color(.tertiarySystemBackground))
		static let neutralBorder = Color(dynamicLight: Color(.systemGray4), dynamicDark: Color(.systemGray5))
		static let neutralStrong = Color(dynamicLight: Color(.label), dynamicDark: Color(.label))
		static let neutralSubdued = Color(dynamicLight: Color(.secondaryLabel), dynamicDark: Color(.secondaryLabel))
		static let focusRing = Color(dynamicLight: Color(UIColor.systemBlue.withAlphaComponent(0.45)), dynamicDark: Color(UIColor.systemBlue.withAlphaComponent(0.6)))
		#elseif os(macOS)
		static let background = Color(dynamicLight: Color(nsColor: .windowBackgroundColor), dynamicDark: Color.black)
		static let surface = Color(dynamicLight: Color(nsColor: .controlBackgroundColor), dynamicDark: Color(nsColor: .controlBackgroundColor))
		static let surfaceElevated = Color(dynamicLight: Color.white, dynamicDark: Color(nsColor: .controlColor))
		static let neutralBorder = Color(dynamicLight: Color(nsColor: .separatorColor), dynamicDark: Color(nsColor: .separatorColor))
		static let neutralStrong = Color(dynamicLight: Color(nsColor: .labelColor), dynamicDark: Color(nsColor: .labelColor))
		static let neutralSubdued = Color(dynamicLight: Color(nsColor: .secondaryLabelColor), dynamicDark: Color(nsColor: .secondaryLabelColor))
		static let focusRing = Color(dynamicLight: Color(nsColor: NSColor.controlAccentColor.withAlphaComponent(0.45)), dynamicDark: Color(nsColor: NSColor.controlAccentColor.withAlphaComponent(0.6)))
		#endif
		static let outline = Color(dynamicLight: .black.opacity(0.1), dynamicDark: .white.opacity(0.2))
		static let accent = Color.accentColor
		static let accentOnPrimary = Color.white
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
		// Brutalist shadows (hard, offset)
		static let brutalistSmall = ShadowStyle(color: .black.opacity(0.8), radius: 0, x: 2, y: 2)
		static let brutalistMedium = ShadowStyle(color: .black.opacity(0.8), radius: 0, x: 4, y: 4)
		static let brutalistLarge = ShadowStyle(color: .black.opacity(0.8), radius: 0, x: 6, y: 6)
	}
	
	// MARK: - Brutalist Extensions
	
	/// Brutalist-specific colors for high contrast design
	enum BrutalistColors {
		static let accentRed = ColorTokens.Accent.red.color
		static let accentBlue = ColorTokens.Accent.blue.color
		static let accentGreen = ColorTokens.Accent.green.color
		static let accentYellow = ColorTokens.Accent.yellow.color
		static let accentOrange = ColorTokens.Accent.orange.color
		
		static let borderDefault = ColorTokens.Semantic.borderDefault.color
		static let borderSubdued = ColorTokens.Semantic.borderSubdued.color
		static let borderFocus = ColorTokens.Semantic.borderFocus.color
	}
	
	/// Border widths for brutalist design
	enum BrutalistBorders {
		static let thin: CGFloat = BorderTokens.thin
		static let standard: CGFloat = BorderTokens.standard
		static let thick: CGFloat = BorderTokens.thick
		
		static let sharp: CGFloat = BorderTokens.CornerRadius.sharp
		static let minimal: CGFloat = BorderTokens.CornerRadius.minimal
	}

	static func backgroundGradient(colorScheme: ColorScheme) -> LinearGradient {
		#if os(iOS)
		let top = Color(.systemGroupedBackground)
	#elseif os(macOS)
		let top = Color(nsColor: .windowBackgroundColor)
	#endif
		let bottom = colorScheme == .dark ? Palette.surface.opacity(0.6) : Palette.surface.opacity(0.8)
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
	init(dynamicLight light: Color, dynamicDark dark: Color) {
		#if os(iOS)
		self.init(UIColor { trait in
			trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
		})
		#elseif os(macOS)
		self.init(NSColor(name: nil) { appearance in
			appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
		})
		#endif
	}
}

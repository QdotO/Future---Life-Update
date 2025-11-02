import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Design tokens for colors following brutalist design specification
public enum ColorTokens {
    // MARK: - Semantic Colors
    public enum Semantic {
        public static let foregroundPrimary = ColorToken(
            "foreground.primary",
            light: .black,
            dark: .white
        )
        public static let foregroundSecondary = ColorToken(
            "foreground.secondary",
            light: Color(hex: 0x333333),
            dark: Color(hex: 0xCCCCCC)
        )
        public static let foregroundTertiary = ColorToken(
            "foreground.tertiary",
            light: Color(hex: 0x666666),
            dark: Color(hex: 0x999999)
        )
        
        public static let backgroundPrimary = ColorToken(
            "background.primary",
            light: .white,
            dark: .black
        )
        public static let backgroundSecondary = ColorToken(
            "background.secondary",
            light: Color(hex: 0xF5F5F5),
            dark: Color(hex: 0x0A0A0A)
        )
        public static let backgroundTertiary = ColorToken(
            "background.tertiary",
            light: Color(hex: 0xEEEEEE),
            dark: Color(hex: 0x1A1A1A)
        )
        
        public static let borderDefault = ColorToken(
            "border.default",
            light: .black,
            dark: .white
        )
        public static let borderSubdued = ColorToken(
            "border.subdued",
            light: Color(hex: 0xCCCCCC),
            dark: Color(hex: 0x333333)
        )
        public static let borderFocus = ColorToken(
            "border.focus",
            light: Color(hex: 0x0000FF),
            dark: Color(hex: 0x00AAFF)
        )
        
        public static let surfaceBase = ColorToken(
            "surface.base",
            light: .white,
            dark: Color(hex: 0x0A0A0A)
        )
        public static let surfaceElevated = ColorToken(
            "surface.elevated",
            light: .white,
            dark: Color(hex: 0x1A1A1A)
        )
    }
    
    // MARK: - Accent Colors
    public enum Accent {
        public static let primary = ColorToken(
            "accent.primary",
            light: Color(hex: 0x4461F2),
            dark: Color(hex: 0x6C8AFA)
        )
        public static let red = ColorToken(
            "accent.red",
            light: Color(hex: 0xFF0000),
            dark: Color(hex: 0xFF3333)
        )
        public static let blue = ColorToken(
            "accent.blue",
            light: Color(hex: 0x0000FF),
            dark: Color(hex: 0x00AAFF)
        )
        public static let green = ColorToken(
            "accent.green",
            light: Color(hex: 0x00DD00),
            dark: Color(hex: 0x00FF00)
        )
        public static let yellow = ColorToken(
            "accent.yellow",
            light: Color(hex: 0xFFCC00),
            dark: Color(hex: 0xFFFF00)
        )
        public static let orange = ColorToken(
            "accent.orange",
            light: Color(hex: 0xFF6600),
            dark: Color(hex: 0xFF7722)
        )
    }
    
    // MARK: - Status Colors
    public enum Status {
        public static let success = ColorToken(
            "status.success",
            light: Color(hex: 0x00DD00),
            dark: Color(hex: 0x00FF00)
        )
        public static let warning = ColorToken(
            "status.warning",
            light: Color(hex: 0xFFCC00),
            dark: Color(hex: 0xFFFF00)
        )
        public static let error = ColorToken(
            "status.error",
            light: Color(hex: 0xFF0000),
            dark: Color(hex: 0xFF3333)
        )
        public static let info = ColorToken(
            "status.info",
            light: Color(hex: 0x0000FF),
            dark: Color(hex: 0x00AAFF)
        )
    }
    
    // MARK: - Glass Surface Colors (preserve from current design)
    public enum Glass {
        public static let border = ColorToken(
            "glass.border",
            light: Color.white.opacity(0.3),
            dark: Color.white.opacity(0.2)
        )
        public static let highlight = ColorToken(
            "glass.highlight",
            light: Color.white.opacity(0.1),
            dark: Color.white.opacity(0.05)
        )
        public static let shadow = ColorToken(
            "glass.shadow",
            light: Color.black.opacity(0.1),
            dark: Color.black.opacity(0.3)
        )
    }
}

// MARK: - ColorToken Helper
public struct ColorToken {
    let name: String
    let light: Color
    let dark: Color
    
    public init(_ name: String, light: Color, dark: Color) {
        self.name = name
        self.light = light
        self.dark = dark
    }
    
    public var color: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        light
        #endif
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

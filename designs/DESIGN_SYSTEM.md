# Future – Life Updates: Design System

## Overview

This design system provides a comprehensive framework for building consistent, accessible, and themeable UI across Future – Life Updates. It enables rapid design iteration and supports multiple aesthetic modes (liquid glass, brutalist, and hybrid).

---

## Design Tokens

Design tokens are the atomic units of the design system—named values that define visual properties across the entire app.

### Color Tokens

```swift
// DesignSystem/Tokens/ColorTokens.swift

import SwiftUI

public enum ColorTokens {
    // MARK: - Semantic Colors
    public enum Semantic {
        public static let foregroundPrimary = ColorToken("foreground.primary", light: .black, dark: .white)
        public static let foregroundSecondary = ColorToken("foreground.secondary", light: Color(hex: 0x333333), dark: Color(hex: 0xCCCCCC))
        public static let foregroundTertiary = ColorToken("foreground.tertiary", light: Color(hex: 0x666666), dark: Color(hex: 0x999999))
        
        public static let backgroundPrimary = ColorToken("background.primary", light: .white, dark: .black)
        public static let backgroundSecondary = ColorToken("background.secondary", light: Color(hex: 0xF5F5F5), dark: Color(hex: 0x0A0A0A))
        public static let backgroundTertiary = ColorToken("background.tertiary", light: Color(hex: 0xEEEEEE), dark: Color(hex: 0x1A1A1A))
        
        public static let borderDefault = ColorToken("border.default", light: .black, dark: .white)
        public static let borderSubdued = ColorToken("border.subdued", light: Color(hex: 0xCCCCCC), dark: Color(hex: 0x333333))
        public static let borderFocus = ColorToken("border.focus", light: Color(hex: 0x0000FF), dark: Color(hex: 0x00AAFF))
        
        public static let surfaceBase = ColorToken("surface.base", light: .white, dark: Color(hex: 0x0A0A0A))
        public static let surfaceElevated = ColorToken("surface.elevated", light: .white, dark: Color(hex: 0x1A1A1A))
    }
    
    // MARK: - Accent Colors
    public enum Accent {
        public static let primary = ColorToken("accent.primary", light: Color(hex: 0x4461F2), dark: Color(hex: 0x6C8AFA))
        public static let red = ColorToken("accent.red", light: Color(hex: 0xFF0000), dark: Color(hex: 0xFF3333))
        public static let blue = ColorToken("accent.blue", light: Color(hex: 0x0000FF), dark: Color(hex: 0x00AAFF))
        public static let green = ColorToken("accent.green", light: Color(hex: 0x00DD00), dark: Color(hex: 0x00FF00))
        public static let yellow = ColorToken("accent.yellow", light: Color(hex: 0xFFCC00), dark: Color(hex: 0xFFFF00))
        public static let orange = ColorToken("accent.orange", light: Color(hex: 0xFF6600), dark: Color(hex: 0xFF7722))
    }
    
    // MARK: - Status Colors
    public enum Status {
        public static let success = ColorToken("status.success", light: Color(hex: 0x00DD00), dark: Color(hex: 0x00FF00))
        public static let warning = ColorToken("status.warning", light: Color(hex: 0xFFCC00), dark: Color(hex: 0xFFFF00))
        public static let error = ColorToken("status.error", light: Color(hex: 0xFF0000), dark: Color(hex: 0xFF3333))
        public static let info = ColorToken("status.info", light: Color(hex: 0x0000FF), dark: Color(hex: 0x00AAFF))
    }
    
    // MARK: - Glass Surface Colors
    public enum Glass {
        public static let border = ColorToken("glass.border", light: Color.white.opacity(0.3), dark: Color.white.opacity(0.2))
        public static let highlight = ColorToken("glass.highlight", light: Color.white.opacity(0.1), dark: Color.white.opacity(0.05))
        public static let shadow = ColorToken("glass.shadow", light: Color.black.opacity(0.1), dark: Color.black.opacity(0.3))
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
    
    @ViewBuilder
    public var color: Color {
        Color(light: light, dark: dark)
    }
}
```

### Typography Tokens

```swift
// DesignSystem/Tokens/TypographyTokens.swift

import SwiftUI

public enum TypographyTokens {
    // MARK: - Font Scales
    public enum Scale {
        // Display - Hero text
        public static let display = FontToken(
            size: 40, weight: .bold, design: .default, lineHeight: 1.1, letterSpacing: -0.5
        )
        
        // Titles
        public static let title1 = FontToken(
            size: 28, weight: .bold, design: .default, lineHeight: 1.2, letterSpacing: -0.3
        )
        public static let title2 = FontToken(
            size: 24, weight: .semibold, design: .rounded, lineHeight: 1.2, letterSpacing: -0.2
        )
        public static let title3 = FontToken(
            size: 20, weight: .semibold, design: .rounded, lineHeight: 1.25, letterSpacing: 0
        )
        
        // Headlines
        public static let headline = FontToken(
            size: 17, weight: .semibold, design: .rounded, lineHeight: 1.3, letterSpacing: 0
        )
        public static let subheadline = FontToken(
            size: 15, weight: .regular, design: .rounded, lineHeight: 1.3, letterSpacing: 0
        )
        
        // Body
        public static let body = FontToken(
            size: 17, weight: .regular, design: .rounded, lineHeight: 1.4, letterSpacing: 0
        )
        public static let bodyStrong = FontToken(
            size: 17, weight: .semibold, design: .rounded, lineHeight: 1.4, letterSpacing: 0
        )
        
        // Caption
        public static let caption = FontToken(
            size: 12, weight: .regular, design: .rounded, lineHeight: 1.35, letterSpacing: 0
        )
        public static let captionStrong = FontToken(
            size: 12, weight: .semibold, design: .rounded, lineHeight: 1.35, letterSpacing: 0
        )
        
        // Overline (labels)
        public static let overline = FontToken(
            size: 11, weight: .bold, design: .default, lineHeight: 1.3, letterSpacing: 0.05
        )
    }
    
    // MARK: - Monospace Variants
    public enum Mono {
        public static let displayMono = FontToken(
            size: 40, weight: .bold, design: .monospaced, lineHeight: 1.1, letterSpacing: 0
        )
        public static let bodyMono = FontToken(
            size: 15, weight: .regular, design: .monospaced, lineHeight: 1.4, letterSpacing: 0
        )
        public static let captionMono = FontToken(
            size: 12, weight: .regular, design: .monospaced, lineHeight: 1.35, letterSpacing: 0
        )
    }
}

// MARK: - FontToken Helper
public struct FontToken {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let lineHeight: CGFloat // Multiplier of font size
    let letterSpacing: CGFloat // In points
    
    public var font: Font {
        .system(size: size, weight: weight, design: design)
    }
    
    public func uiFont() -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        let systemFont = UIFont.systemFont(ofSize: size, weight: uiWeight)
        
        switch design {
        case .monospaced:
            return UIFont.monospacedSystemFont(ofSize: size, weight: uiWeight)
        case .rounded:
            return UIFont(descriptor: descriptor.withDesign(.rounded) ?? descriptor, size: size)
        default:
            return systemFont
        }
    }
    
    private var uiWeight: UIFont.Weight {
        switch weight {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .regular: return .regular
        case .light: return .light
        default: return .regular
        }
    }
}
```

### Spacing Tokens

```swift
// DesignSystem/Tokens/SpacingTokens.swift

import Foundation

public enum SpacingTokens {
    /// Base unit: 8pt grid
    private static let baseUnit: CGFloat = 8
    
    // MARK: - Spacing Scale
    public static let micro: CGFloat = baseUnit * 0.5  // 4pt
    public static let xs: CGFloat = baseUnit           // 8pt
    public static let sm: CGFloat = baseUnit * 1.5     // 12pt
    public static let md: CGFloat = baseUnit * 2       // 16pt
    public static let lg: CGFloat = baseUnit * 3       // 24pt
    public static let xl: CGFloat = baseUnit * 4       // 32pt
    public static let xxl: CGFloat = baseUnit * 6      // 48pt
    public static let xxxl: CGFloat = baseUnit * 8     // 64pt
    
    // MARK: - Semantic Spacing
    public enum Semantic {
        public static let screenEdge: CGFloat = SpacingTokens.md        // 16pt
        public static let cardPadding: CGFloat = SpacingTokens.lg       // 24pt
        public static let sectionSpacing: CGFloat = SpacingTokens.xl    // 32pt
        public static let elementSpacing: CGFloat = SpacingTokens.sm    // 12pt
        public static let tightSpacing: CGFloat = SpacingTokens.xs      // 8pt
        public static let touchTargetMinimum: CGFloat = 44              // iOS HIG minimum
    }
}
```

### Border Tokens

```swift
// DesignSystem/Tokens/BorderTokens.swift

import Foundation

public enum BorderTokens {
    // MARK: - Border Widths
    public static let hairline: CGFloat = 0.5
    public static let thin: CGFloat = 1
    public static let standard: CGFloat = 2
    public static let thick: CGFloat = 3
    public static let extraThick: CGFloat = 4
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        public static let sharp: CGFloat = 0
        public static let minimal: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xlarge: CGFloat = 24
        public static let circular: CGFloat = 999 // Effectively infinite
    }
}
```

### Shadow Tokens

```swift
// DesignSystem/Tokens/ShadowTokens.swift

import SwiftUI

public enum ShadowTokens {
    public struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Brutalist Shadows (Hard, Offset)
    public enum Brutalist {
        public static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        public static let small = Shadow(color: .black.opacity(0.8), radius: 0, x: 2, y: 2)
        public static let medium = Shadow(color: .black.opacity(0.8), radius: 0, x: 4, y: 4)
        public static let large = Shadow(color: .black.opacity(0.8), radius: 0, x: 6, y: 6)
    }
    
    // MARK: - Glass Shadows (Soft, Blurred)
    public enum Glass {
        public static let subtle = Shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        public static let medium = Shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 4)
        public static let strong = Shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 8)
        public static let glow = Shadow(color: Color.white.opacity(0.1), radius: 20, x: 0, y: 0)
    }
}
```

### Animation Tokens

```swift
// DesignSystem/Tokens/AnimationTokens.swift

import SwiftUI

public enum AnimationTokens {
    // MARK: - Duration
    public enum Duration {
        public static let instant: Double = 0.1
        public static let fast: Double = 0.15
        public static let normal: Double = 0.25
        public static let slow: Double = 0.35
        public static let deliberate: Double = 0.5
    }
    
    // MARK: - Easing
    public static let linear = Animation.linear
    public static let easeIn = Animation.easeIn
    public static let easeOut = Animation.easeOut
    public static let easeInOut = Animation.easeInOut
    public static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    // MARK: - Common Animations
    public static let buttonPress = Animation.linear(duration: Duration.fast)
    public static let modalPresent = Animation.easeOut(duration: Duration.normal)
    public static let modalDismiss = Animation.easeIn(duration: Duration.fast)
    public static let stateChange = Animation.easeOut(duration: Duration.normal)
    public static let listItem = Animation.easeOut(duration: Duration.fast)
}
```

---

## Component Library

Components are built on top of tokens and provide ready-to-use UI building blocks.

### Component: DSButton

```swift
// DesignSystem/Components/DSButton.swift

import SwiftUI

public struct DSButton: View {
    public enum Style {
        case primary
        case secondary
        case text
        case glass
    }
    
    public enum Size {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 56
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return SpacingTokens.md
            case .medium: return SpacingTokens.lg
            case .large: return SpacingTokens.xl
            }
        }
        
        var font: Font {
            switch self {
            case .small: return TypographyTokens.Scale.subheadline.font
            case .medium: return TypographyTokens.Scale.headline.font
            case .large: return TypographyTokens.Scale.title3.font
            }
        }
    }
    
    let title: String
    let style: Style
    let size: Size
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.designMode) private var designMode
    
    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(size.font.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .padding(.horizontal, size.horizontalPadding)
        }
        .buttonStyle(buttonStyle)
    }
    
    @ViewBuilder
    private var buttonStyle: some PrimitiveButtonStyle {
        switch (style, designMode) {
        case (.primary, .brutalist):
            DSBrutalistButtonStyle.primary
        case (.secondary, .brutalist):
            DSBrutalistButtonStyle.secondary
        case (.primary, .glass), (.primary, .hybrid):
            DSGlassButtonStyle.primary
        case (.secondary, .glass), (.secondary, .hybrid):
            DSGlassButtonStyle.secondary
        case (.text, _):
            DSTextButtonStyle()
        default:
            DSBrutalistButtonStyle.primary
        }
    }
}

// MARK: - Button Styles
private struct DSBrutalistButtonStyle: PrimitiveButtonStyle {
    let variant: Variant
    
    enum Variant {
        case primary
        case secondary
    }
    
    static let primary = DSBrutalistButtonStyle(variant: .primary)
    static let secondary = DSBrutalistButtonStyle(variant: .secondary)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal)
                    .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: BorderTokens.standard)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AnimationTokens.buttonPress, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return ColorTokens.Semantic.foregroundPrimary.color
        case .secondary:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return ColorTokens.Semantic.backgroundPrimary.color
        case .secondary:
            return ColorTokens.Semantic.foregroundPrimary.color
        }
    }
}

private struct DSGlassButtonStyle: PrimitiveButtonStyle {
    let variant: Variant
    
    enum Variant {
        case primary
        case secondary
    }
    
    static let primary = DSGlassButtonStyle(variant: .primary)
    static let secondary = DSGlassButtonStyle(variant: .secondary)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.medium, style: .continuous)
                    .stroke(ColorTokens.Glass.border.color, lineWidth: BorderTokens.thin)
            )
            .shadow(
                color: ShadowTokens.Glass.subtle.color,
                radius: ShadowTokens.Glass.subtle.radius,
                x: ShadowTokens.Glass.subtle.x,
                y: ShadowTokens.Glass.subtle.y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AnimationTokens.buttonPress, value: configuration.isPressed)
    }
    
    private var backgroundColor: Material {
        switch variant {
        case .primary:
            return .ultraThinMaterial
        case .secondary:
            return .thickMaterial
        }
    }
    
    private var foregroundColor: Color {
        ColorTokens.Semantic.foregroundPrimary.color
    }
}

private struct DSTextButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ColorTokens.Accent.primary.color)
            .underline(configuration.isPressed)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(AnimationTokens.buttonPress, value: configuration.isPressed)
    }
}
```

### Component: DSCard

```swift
// DesignSystem/Components/DSCard.swift

import SwiftUI

public struct DSCard<Content: View>: View {
    public enum Style {
        case brutalist
        case glass
    }
    
    let style: Style
    let padding: CGFloat
    let content: Content
    
    @Environment(\.designMode) private var designMode
    
    public init(
        style: Style? = nil,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        // If style is nil, use environment designMode
        self.style = style ?? (designMode == .brutalist ? .brutalist : .glass)
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(background)
    }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .brutalist:
            RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal)
                .fill(ColorTokens.Semantic.surfaceBase.color)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal)
                        .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: BorderTokens.standard)
                )
        case .glass:
            RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.large, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.large, style: .continuous)
                        .stroke(ColorTokens.Glass.border.color, lineWidth: BorderTokens.thin)
                )
                .shadow(
                    color: ShadowTokens.Glass.glow.color,
                    radius: ShadowTokens.Glass.glow.radius,
                    x: 0,
                    y: 0
                )
        }
    }
}
```

### Component: DSTextField

```swift
// DesignSystem/Components/DSTextField.swift

import SwiftUI

public struct DSTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String?
    let isMonospace: Bool
    
    @FocusState private var isFocused: Bool
    @Environment(\.designMode) private var designMode
    
    public init(
        _ title: String,
        text: Binding<String>,
        prompt: String? = nil,
        isMonospace: Bool = false
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.isMonospace = isMonospace
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if !title.isEmpty {
                Text(title)
                    .font(TypographyTokens.Scale.caption.font.weight(.semibold))
                    .foregroundStyle(ColorTokens.Semantic.foregroundSecondary.color)
            }
            
            TextField(prompt ?? "", text: $text)
                .font(isMonospace ? TypographyTokens.Mono.bodyMono.font : TypographyTokens.Scale.body.font)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Semantic.backgroundSecondary.color)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .focused($isFocused)
        }
    }
    
    private var cornerRadius: CGFloat {
        designMode == .brutalist ? BorderTokens.CornerRadius.minimal : BorderTokens.CornerRadius.small
    }
    
    private var borderWidth: CGFloat {
        isFocused ? BorderTokens.thick : BorderTokens.standard
    }
    
    private var borderColor: Color {
        isFocused ? ColorTokens.Semantic.borderFocus.color : ColorTokens.Semantic.borderSubdued.color
    }
}
```

### Component: DSProgressBar

```swift
// DesignSystem/Components/DSProgressBar.swift

import SwiftUI

public struct DSProgressBar: View {
    let progress: Double // 0.0 to 1.0
    let height: CGFloat
    let showPercentage: Bool
    
    @Environment(\.designMode) private var designMode
    
    public init(
        progress: Double,
        height: CGFloat = 8,
        showPercentage: Bool = false
    ) {
        self.progress = min(max(progress, 0), 1) // Clamp to 0...1
        self.height = height
        self.showPercentage = showPercentage
    }
    
    public var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            progressBar
            
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(TypographyTokens.Mono.bodyMono.font.weight(.bold))
                    .foregroundStyle(ColorTokens.Semantic.foregroundPrimary.color)
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(ColorTokens.Semantic.backgroundSecondary.color)
                
                // Fill
                Rectangle()
                    .fill(ColorTokens.Accent.primary.color)
                    .frame(width: geometry.size.width * progress)
                    .animation(AnimationTokens.stateChange, value: progress)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ColorTokens.Semantic.borderSubdued.color, lineWidth: BorderTokens.thin)
            )
        }
        .frame(height: height)
    }
    
    private var cornerRadius: CGFloat {
        designMode == .brutalist ? BorderTokens.CornerRadius.sharp : BorderTokens.CornerRadius.minimal
    }
}
```

---

## Environment & Theming

### Design Mode Environment

```swift
// DesignSystem/Environment/DesignMode.swift

import SwiftUI

public enum DesignMode {
    case brutalist
    case glass
    case hybrid
}

private struct DesignModeKey: EnvironmentKey {
    static let defaultValue: DesignMode = .glass
}

extension EnvironmentValues {
    public var designMode: DesignMode {
        get { self[DesignModeKey.self] }
        set { self[DesignModeKey.self] = newValue }
    }
}

extension View {
    public func designMode(_ mode: DesignMode) -> some View {
        environment(\.designMode, mode)
    }
}
```

### Theme Switching

```swift
// DesignSystem/ThemeManager.swift

import SwiftUI
import Observation

@MainActor
@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()
    
    public var currentMode: DesignMode = .glass {
        didSet {
            // Save to UserDefaults
            UserDefaults.standard.set(currentMode.rawValue, forKey: "designMode")
        }
    }
    
    private init() {
        // Load from UserDefaults
        if let savedMode = UserDefaults.standard.string(forKey: "designMode"),
           let mode = DesignMode(rawValue: savedMode) {
            self.currentMode = mode
        }
    }
}

// Usage in App root:
// ContentView()
//     .designMode(themeManager.currentMode)
```

---

## View Modifiers

Reusable modifiers for common styling patterns.

```swift
// DesignSystem/Modifiers/StyleModifiers.swift

import SwiftUI

// MARK: - Brutalist Card Modifier
public struct BrutalistCardModifier: ViewModifier {
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    public init(
        borderWidth: CGFloat = BorderTokens.standard,
        cornerRadius: CGFloat = BorderTokens.CornerRadius.minimal,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) {
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ColorTokens.Semantic.surfaceBase.color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: borderWidth)
            )
    }
}

// MARK: - Glass Card Modifier
public struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    public init(
        cornerRadius: CGFloat = BorderTokens.CornerRadius.large,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTokens.Glass.border.color, lineWidth: BorderTokens.thin)
            )
            .shadow(
                color: ShadowTokens.Glass.glow.color,
                radius: ShadowTokens.Glass.glow.radius,
                x: 0,
                y: 0
            )
    }
}

extension View {
    public func brutalistCard(
        borderWidth: CGFloat = BorderTokens.standard,
        cornerRadius: CGFloat = BorderTokens.CornerRadius.minimal,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) -> some View {
        modifier(BrutalistCardModifier(borderWidth: borderWidth, cornerRadius: cornerRadius, padding: padding))
    }
    
    public func glassCard(
        cornerRadius: CGFloat = BorderTokens.CornerRadius.large,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
```

---

## Usage Examples

### Example 1: Button with Design Mode

```swift
DSButton("Save Goal", style: .primary) {
    // Handle save
}
.designMode(.brutalist) // Force brutalist style

// Or inherit from environment:
VStack {
    DSButton("Create", style: .primary, action: handleCreate)
    DSButton("Cancel", style: .secondary, action: handleCancel)
}
.designMode(themeManager.currentMode)
```

### Example 2: Card Layout

```swift
// Auto-detects design mode from environment
DSCard {
    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
        Text("Goal Title")
            .font(TypographyTokens.Scale.title2.font)
        Text("Progress details")
            .font(TypographyTokens.Scale.body.font)
            .foregroundStyle(ColorTokens.Semantic.foregroundSecondary.color)
    }
}

// Or force a specific style:
DSCard(style: .glass) {
    // Content
}
```

### Example 3: Custom View with Design Mode

```swift
struct MyCustomView: View {
    @Environment(\.designMode) var designMode
    
    var body: some View {
        Text("Hello")
            .padding()
            .background(backgroundColor)
            .overlay(border)
    }
    
    private var backgroundColor: Color {
        switch designMode {
        case .brutalist:
            return ColorTokens.Semantic.surfaceBase.color
        case .glass, .hybrid:
            return Color.clear
        }
    }
    
    @ViewBuilder
    private var border: some View {
        if designMode == .brutalist {
            RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal)
                .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: BorderTokens.standard)
        } else {
            RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.large, style: .continuous)
                .stroke(ColorTokens.Glass.border.color, lineWidth: BorderTokens.thin)
        }
    }
}
```

---

## Migration Guide

### Step 1: Audit Existing Components

Identify all views that use hard-coded values:
- Colors: `.blue`, `.black`, `Color(hex: ...)`
- Spacing: `.padding(16)`, `.frame(height: 44)`
- Typography: `.font(.title)`, `.bold()`
- Borders: `.border(Color.gray, width: 1)`

### Step 2: Replace with Tokens

```swift
// Before
Text("Title")
    .font(.system(size: 24, weight: .bold))
    .foregroundColor(.black)
    .padding(16)

// After
Text("Title")
    .font(TypographyTokens.Scale.title2.font)
    .foregroundStyle(ColorTokens.Semantic.foregroundPrimary.color)
    .padding(SpacingTokens.md)
```

### Step 3: Adopt Components

```swift
// Before
Button("Save") { ... }
    .frame(height: 44)
    .background(Color.blue)
    .foregroundColor(.white)
    .cornerRadius(8)

// After
DSButton("Save", style: .primary) { ... }
```

### Step 4: Add Design Mode Support

```swift
// In App entry point:
@main
struct MyApp: App {
    @State private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .designMode(themeManager.currentMode)
        }
    }
}
```

---

## Testing

### Preview with Multiple Modes

```swift
#Preview("Brutalist Mode") {
    MyView()
        .designMode(.brutalist)
}

#Preview("Glass Mode") {
    MyView()
        .designMode(.glass)
}

#Preview("Hybrid Mode") {
    MyView()
        .designMode(.hybrid)
}
```

### Accessibility Testing

```swift
// Verify color contrast
XCTAssertGreaterThan(
    ColorTokens.Semantic.foregroundPrimary.color.contrastRatio(
        with: ColorTokens.Semantic.backgroundPrimary.color
    ),
    7.0 // AAA standard
)

// Verify touch targets
XCTAssertGreaterThanOrEqual(
    buttonHeight,
    SpacingTokens.Semantic.touchTargetMinimum
)
```

---

## Conclusion

This design system provides a scalable, maintainable foundation for Future – Life Updates. By centralizing design decisions into tokens and providing flexible components, we enable rapid iteration between design modes (brutalist, glass, hybrid) while maintaining consistency and accessibility.

Key benefits:
- **Single source of truth** for all design values
- **Easy theme switching** via environment values
- **Reusable components** reduce duplication
- **Future-proof** for new design explorations
- **Accessible by default** with semantic tokens

To adopt this system, start by integrating the token files, then progressively migrate existing views to use DSComponents and modifiers. The hybrid approach allows gradual migration without breaking existing functionality.

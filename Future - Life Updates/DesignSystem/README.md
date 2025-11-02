# Design System Documentation

## Overview

The Future - Life Updates design system provides a flexible, token-based approach to styling that supports multiple aesthetic modes: **Glass** (current design), **Brutalist** (new high-contrast design), and **Hybrid** (combination of both).

## Design Modes

### Glass Mode (Default)
- Soft, rounded corners (16pt+)
- Translucent materials (.ultraThinMaterial)
- Subtle shadows and glows
- Current production aesthetic

### Brutalist Mode
- Hard edges (0-4pt corners)
- Bold borders (2-3pt)
- High contrast colors (pure black/white)
- No or hard shadows
- Raw, honest structure

### Hybrid Mode
- Mix of brutalist structure with glass overlays
- Use brutalist for navigation, forms, data
- Use glass for modals, charts, visualizations

## Usage

### Applying Design Mode

```swift
import SwiftUI

struct MyView: View {
    @Environment(\.designMode) var designMode
    
    var body: some View {
        VStack {
            Text("Content")
        }
        .designMode(.brutalist) // Force brutalist mode
    }
}
```

### Using Design Tokens

#### Colors

```swift
// Semantic colors (adapt to light/dark mode)
ColorTokens.Semantic.foregroundPrimary.color  // Pure black/white
ColorTokens.Semantic.backgroundPrimary.color  // Pure white/black
ColorTokens.Semantic.borderDefault.color      // Bold borders

// Accent colors
ColorTokens.Accent.primary.color  // App primary blue
ColorTokens.Accent.red.color      // Pure red
ColorTokens.Accent.green.color    // Pure green
```

#### Spacing (8pt grid)

```swift
SpacingTokens.micro     // 4pt
SpacingTokens.xs        // 8pt
SpacingTokens.sm        // 12pt
SpacingTokens.md        // 16pt
SpacingTokens.lg        // 24pt
SpacingTokens.xl        // 32pt
SpacingTokens.xxl       // 48pt

// Semantic spacing
SpacingTokens.Semantic.cardPadding     // 24pt
SpacingTokens.Semantic.screenEdge      // 16pt
```

#### Borders

```swift
BorderTokens.thin           // 1pt
BorderTokens.standard       // 2pt
BorderTokens.thick          // 3pt

BorderTokens.CornerRadius.sharp     // 0pt
BorderTokens.CornerRadius.minimal   // 4pt
BorderTokens.CornerRadius.large     // 16pt
```

#### Animations

```swift
AnimationTokens.buttonPress        // Quick scale down
AnimationTokens.modalPresent       // Ease out slide
AnimationTokens.stateChange        // Smooth transition

// Durations
AnimationTokens.Duration.fast      // 0.15s
AnimationTokens.Duration.normal    // 0.25s
```

### Card Styles

#### Brutalist Card

```swift
VStack {
    Text("Title")
    Text("Content")
}
.brutalistCard()
// Hard edges, 2pt border, 24pt padding
```

#### Glass Card

```swift
VStack {
    Text("Title")
    Text("Content")
}
.glassCard()
// 16pt radius, translucent material, subtle glow
```

### Button Styles

#### Brutalist Buttons

```swift
Button("Save") { }
    .buttonStyle(.brutalistPrimary)
// Black background, white text, sharp edges

Button("Cancel") { }
    .buttonStyle(.brutalistSecondary)
// Transparent background, black border
```

#### Glass Buttons (Existing)

```swift
Button("Save") { }
    .buttonStyle(.primaryProminent)
// Blue background, rounded, smooth

Button("Cancel") { }
    .buttonStyle(.secondaryProminent)
// Gray background, rounded, border
```

### Extended AppTheme

The existing `AppTheme` has been extended with brutalist-specific properties while maintaining backward compatibility:

```swift
// Brutalist colors
AppTheme.BrutalistColors.accentRed
AppTheme.BrutalistColors.borderDefault

// Brutalist borders
AppTheme.BrutalistBorders.standard  // 2pt
AppTheme.BrutalistBorders.minimal   // 4pt radius

// Brutalist shadows
AppTheme.Shadow.brutalistMedium  // Hard offset shadow
```

## Architecture

### Token System
- **ColorTokens**: Semantic and accent colors with light/dark variants
- **SpacingTokens**: 8pt grid-based spacing scale
- **BorderTokens**: Border widths and corner radii
- **AnimationTokens**: Timing and easing functions

### Components
- **BrutalistCardModifier**: Apply brutalist card styling
- **GlassCardModifier**: Apply glass card styling
- **BrutalistButtonStyles**: Primary and secondary button styles
- **ViewModifiers**: Reusable style modifiers

### Environment
- **DesignMode**: Environment value for switching modes
- Propagates through view hierarchy
- Can be overridden at any level

## Migration Guide

### For New Views
Use the new token system:

```swift
// ❌ Old way
.padding(16)
.background(Color.blue)
.cornerRadius(8)

// ✅ New way with tokens
.padding(SpacingTokens.md)
.background(ColorTokens.Accent.primary.color)
.cornerRadius(BorderTokens.CornerRadius.small)
```

### For Existing Views
Backward compatibility is maintained:

```swift
// ✅ Still works
.padding(AppTheme.Spacing.md)
.background(AppTheme.Palette.primary)

// ✅ Enhanced with tokens
.padding(SpacingTokens.md)
.background(ColorTokens.Accent.primary.color)
```

## Best Practices

### When to Use Brutalist Style
- Navigation bars and tab bars
- Forms and data input
- Tables and lists
- Action buttons
- Data-heavy screens

### When to Use Glass Style
- Modal sheets and popovers
- Floating toolbars
- Charts and visualizations
- Cards with imagery
- Overlays and notifications

### When to Use Hybrid
- Use brutalist for structure (navigation, forms)
- Use glass for content (charts, cards)
- Transition between modes based on context

## Examples

See `DesignSystemExamples.swift` for a comprehensive showcase of all components and tokens.

### Preview in Different Modes

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

## Performance

- Tokens are compile-time constants (no runtime overhead)
- Color adapts automatically to light/dark mode
- Animations use Metal rendering
- View modifiers are efficient and composable

## Accessibility

- All colors meet WCAG AAA contrast standards (7:1 minimum)
- Touch targets minimum 44x44pt (iOS) or 32x32pt (macOS)
- Supports Dynamic Type
- Respects Reduce Motion preference
- VoiceOver compatible

## Future Enhancements

Potential future additions to the design system:

- [ ] Theme switching UI (settings screen)
- [ ] Per-goal design mode override
- [ ] Custom accent color picker
- [ ] Animation speed control
- [ ] Additional component variants
- [ ] Dark/light mode toggle independent of system

## References

- Design specification: `designs/BRUTALIST_DESIGN_SPEC.md`
- Design system doc: `designs/DESIGN_SYSTEM.md`
- Implementation: `Future - Life Updates/DesignSystem/`

# Future – Life Updates: Brutalist Design Specification

## Overview

This document defines the brutalist aesthetic for Future – Life Updates, providing clear guidelines for implementing raw, honest, and structurally transparent UI design while maintaining the app's liquid glass elements that the user values.

## Core Principles

### 1. Honest Structure
Expose the underlying grid system and functional hierarchy. Every element should communicate its purpose through form and position rather than embellishment.

### 2. Materiality Over Ornament
Prioritize substance and content over decorative flourishes. Interfaces should feel solid, tangible, and direct.

### 3. High Contrast & Clarity
Use stark contrast to establish clear visual hierarchy. Typography and color choices should be unambiguous and immediately legible.

### 4. Functional Beauty
Beauty emerges from utility. Every design decision must serve the user's goal-tracking workflow.

---

## Typography

### Hierarchy

```
Display (Hero Text)
- Font: System Bold or SF Mono Bold
- Size: 34-40pt
- Weight: Bold (700)
- Use: Goal titles, primary metrics, large numbers

Title
- Font: System Bold
- Size: 24-28pt
- Weight: Bold (700)
- Use: Section headers, view titles

Headline
- Font: System Semibold
- Size: 17-20pt
- Weight: Semibold (600)
- Use: Card titles, list items

Body
- Font: System Regular or SF Mono
- Size: 15-17pt
- Weight: Regular (400)
- Use: Main content, descriptions

Caption
- Font: System Regular or SF Mono
- Size: 12-13pt
- Weight: Regular (400)
- Use: Metadata, timestamps, secondary info

Overline (Labels)
- Font: System Bold or SF Mono Bold
- Size: 11-12pt
- Weight: Bold (700)
- Letter Spacing: 0.05em
- Transform: Uppercase
- Use: Category labels, state indicators
```

### Typeface Strategy

**Primary:** San Francisco System Font (Bold/Semibold weights)
- Use for most UI elements
- Maintains platform consistency
- Strong geometric forms

**Accent:** SF Mono (Code-style elements)
- Use for numeric data, timestamps, IDs
- Creates technical aesthetic
- Reinforces data-oriented nature

---

## Color Palette

### Core Colors (Light Mode)

```swift
Background Base: #FFFFFF (pure white)
Background Secondary: #F5F5F5 (off-white)
Foreground Primary: #000000 (pure black)
Foreground Secondary: #333333 (near-black)
Foreground Tertiary: #666666 (medium gray)

Border Default: #000000 (pure black, 1-2pt)
Border Subdued: #CCCCCC (light gray, 1pt)

Accent Primary: #FF0000 (pure red) or #0000FF (pure blue)
Accent Secondary: #00FF00 (pure green) or #FFFF00 (pure yellow)
```

### Core Colors (Dark Mode)

```swift
Background Base: #000000 (pure black)
Background Secondary: #0A0A0A (near-black)
Foreground Primary: #FFFFFF (pure white)
Foreground Secondary: #CCCCCC (light gray)
Foreground Tertiary: #999999 (medium gray)

Border Default: #FFFFFF (pure white, 1-2pt)
Border Subdued: #333333 (dark gray, 1pt)

Accent Primary: #FF0000 (pure red) or #00AAFF (bright blue)
Accent Secondary: #00FF00 (pure green) or #FFFF00 (pure yellow)
```

### Semantic Colors

```swift
Success: #00FF00 (pure green)
Warning: #FFFF00 (pure yellow)
Error: #FF0000 (pure red)
Info: #0000FF (pure blue)

// Streak/Achievement colors
Active Streak: #FF6600 (bright orange)
Completed: #00FF00 (pure green)
Incomplete: #999999 (gray)
```

### Glass Elements (Preserve from Current Design)

```swift
Glass Surface: .ultraThinMaterial or 
               background.opacity(0.7) + blur(radius: 10)

Glass Border: white.opacity(0.3) (light) or
              white.opacity(0.2) (dark)
              
Glass Highlight: white.opacity(0.1) (subtle inner glow)
```

---

## Layout & Spacing

### Grid System

Base unit: **8pt grid**

```
Micro: 4pt   (0.5 units)
Small: 8pt   (1 unit)
Medium: 16pt (2 units)
Large: 24pt  (3 units)
XLarge: 32pt (4 units)
XXLarge: 48pt (6 units)
```

### Margins & Padding

```
Screen Edge Margin: 16pt (2 units) - iOS
                    20pt (2.5 units) - macOS

Card Padding: 16-24pt (2-3 units)
Section Spacing: 32-48pt (4-6 units)
Element Spacing: 8-16pt (1-2 units)
```

### Content Width

```
Maximum Content Width: 800pt (prevents over-expansion on large screens)
Column Layout: Strict alignment to 8pt grid
Asymmetric Layouts: Encouraged when functional
```

---

## Components

### Buttons

**Primary Button**
```
Style: Rectangular, hard edges
Border: 2pt solid black (light) / white (dark)
Background: Black (light) / White (dark)
Text: White (light) / Black (dark)
Font: System Bold, 15-17pt
Padding: 16pt vertical, 24pt horizontal
Corner Radius: 0pt (sharp) OR 4pt (minimal)
Hover: Invert colors
Active: Scale 0.98
```

**Secondary Button**
```
Style: Rectangular, hard edges
Border: 2pt solid black (light) / white (dark)
Background: Transparent
Text: Black (light) / White (dark)
Font: System Bold, 15-17pt
Padding: 16pt vertical, 24pt horizontal
Corner Radius: 0pt (sharp) OR 4pt (minimal)
Hover: Background black.opacity(0.05)
Active: Scale 0.98
```

**Text Button**
```
Style: Underlined text
Text: Black (light) / White (dark)
Font: System Semibold, 15pt
Decoration: 1pt underline
Hover: Underline thickness 2pt
```

### Cards

**Standard Card**
```
Border: 2pt solid black (light) / white (dark)
Background: White (light) / #0A0A0A (dark)
Corner Radius: 0pt (sharp) OR 4pt (minimal)
Padding: 24pt
Shadow: None (flat) OR hard shadow (4pt offset x, 4pt offset y, no blur)
```

**Glass Card (Preserve from Current)**
```
Border: 1pt solid white.opacity(0.3)
Background: .ultraThinMaterial OR background.opacity(0.7) + blur(10)
Corner Radius: 16pt (liquid glass maintains smooth corners)
Padding: 20pt
Shadow: Subtle glow - white.opacity(0.1), radius 20, no offset
```

### Input Fields

**Text Field**
```
Border: 2pt solid black (light) / white (dark)
Background: Transparent OR #F5F5F5 (light) / #0A0A0A (dark)
Corner Radius: 0pt OR 4pt
Padding: 12pt horizontal, 16pt vertical
Font: System Regular OR SF Mono, 15-17pt
Placeholder: #999999
Focus: Border color → Accent Primary, 3pt weight
```

**Picker/Dropdown**
```
Style: Same as text field
Arrow Icon: Bold chevron, aligned right
Options: Full-width list, 2pt borders between items
Selected: Background → Accent Primary, Text → White
```

### Charts & Data Visualization

**Line Chart (Brutalist Style)**
```
Line Weight: 3pt (bold)
Line Color: Black (light) / White (dark) OR Accent Primary
Point Markers: 8pt circles, filled
Grid Lines: 1pt, #CCCCCC (light) / #333333 (dark)
Axis: 2pt solid lines
Labels: SF Mono, 12pt
Background: Transparent or subtle grid
```

**Line Chart (Glass Style - when preserving liquid aesthetic)**
```
Line Weight: 2pt
Line Color: Accent with gradient
Area Fill: Gradient from accent.opacity(0.3) to transparent
Point Markers: Only on hover or for sparse data
Grid Lines: Minimal or none
Axis: Thin lines
Labels: System Regular, 12pt
Background: Glass surface
```

**Bar Chart**
```
Bar Style: Hard rectangles, no rounding
Bar Color: Black (light) / White (dark) OR Accent Primary
Bar Border: Optional 1pt outline
Spacing: 8-16pt between bars
Labels: SF Mono Bold, positioned above bars
```

### Progress Indicators

**Linear Progress**
```
Height: 8pt (thin) OR 16pt (thick)
Border: 1pt solid black/white
Background: #F5F5F5 (light) / #0A0A0A (dark)
Fill: Black (light) / White (dark) OR Accent Primary
Corner Radius: 0pt OR 2pt
```

**Percentage Display**
```
Format: SF Mono Bold, 24pt
Position: Adjacent to progress bar
Color: Black (light) / White (dark)
```

### Labels & Badges

**Status Badge**
```
Style: Rectangular
Border: 1pt solid
Background: Accent color
Text: Uppercase, System Bold, 11pt
Padding: 6pt horizontal, 4pt vertical
Corner Radius: 0pt OR 2pt
```

**Count Badge**
```
Style: Circle OR square
Background: Accent Primary
Text: White, System Bold, 12pt
Size: 24pt diameter minimum
```

---

## Interactions & Animations

### Principles

1. **Direct Response:** Immediate visual feedback
2. **No Flourish:** Animations serve function, not decoration
3. **Snappy Timing:** Fast, decisive (0.15-0.25s)
4. **Linear or Ease-Out:** Avoid overly smooth easing

### Standard Transitions

```swift
Button Press: scale(0.98), duration: 0.15s, easing: linear
Modal Open: slide from bottom, duration: 0.25s, easing: easeOut
Sheet Dismiss: slide to bottom, duration: 0.2s, easing: easeIn
Tab Switch: crossfade, duration: 0.15s, easing: linear
List Item Appear: fadeIn + slideUp(8pt), duration: 0.2s, stagger: 0.03s
```

### Hover States (macOS)

```
Scale: None (no movement)
Border: Increase weight by 1pt
Background: Subtle darken/lighten (5-10% opacity change)
Cursor: Pointer for interactive elements
Transition: 0.1s linear
```

### Loading States

```
Spinner: Minimal circular spinner OR pulsing dot sequence
Skeleton: Hard-edged rectangles, no shimmer, subtle opacity pulse
Progress: Linear bar with percentage (no circular)
```

---

## Iconography

### Style

- **System SF Symbols:** Use bold weights (.semibold, .bold)
- **Geometric Forms:** Prefer simple shapes (circles, squares, lines)
- **Rendering:** .monochrome or .hierarchical (no multicolor)
- **Size:** Align to grid (16pt, 24pt, 32pt)

### Custom Icons

- Stroke Weight: 2-3pt
- Corner Radius: 0-2pt (sharp or minimal)
- Optical Balance: Ensure visual weight matches text

---

## Component States

### Interactive States

```
Default:  Base styles
Hover:    Border weight +1pt OR background opacity +5%
Active:   Scale 0.98 OR border accent color
Focus:    Accent border, 3pt weight
Disabled: Opacity 0.4, cursor: not-allowed
Loading:  Subtle pulse OR spinner
```

### Data States

```
Empty:      Large icon + bold message + CTA button
Error:      Red accent + error icon + retry button
Success:    Green accent + checkmark icon
Warning:    Yellow accent + warning icon
Loading:    Progress indicator + status text (SF Mono)
```

---

## Brutalist + Glass Hybrid Approach

Since the user wants to preserve the liquid glass elements, we adopt a hybrid strategy:

### When to Use Brutalist Style

- **Navigation & Structure:** Tab bars, sidebars, headers
- **Data Input:** Forms, text fields, pickers
- **Data Display:** Tables, lists, raw numbers
- **Actions:** Buttons, CTAs, destructive actions
- **Typography:** Headers, labels, metrics

### When to Use Glass Style

- **Modal Overlays:** Sheets, popovers, alerts
- **Floating Elements:** Toolbars, mini-players, notifications
- **Charts & Insights:** Goal trends, progress visualizations
- **Cards with Visual Hierarchy:** Goal cards with background images
- **Contextual Panels:** Quick actions, summaries

### Transition Strategy

Elements can transition between styles based on context:
- **Collapsed State:** Brutalist (minimal, dense)
- **Expanded State:** Glass (spacious, visual)
- **Active Interaction:** Brutalist (direct, bold)
- **Background/Ambient:** Glass (soft, layered)

---

## Accessibility

### Contrast

- Minimum Contrast Ratio: 7:1 (AAA standard)
- Text on Backgrounds: Pure black on white (or vice versa) for body text
- Accent Colors: Ensure sufficient contrast when used for text

### Touch Targets

- Minimum Size: 44pt × 44pt (iOS), 32pt × 32pt (macOS)
- Spacing: 8pt minimum between interactive elements

### Typography

- Minimum Body Size: 15pt (iOS), 13pt (macOS)
- Support Dynamic Type: Scale font sizes with user preferences
- Avoid all-caps for long text (exception: short labels)

### Motion

- Respect `reduceMotion` preference
- Provide non-animated alternatives
- Keep animations brief (<0.3s)

---

## Implementation Guidelines

### SwiftUI Modifiers

Create reusable view modifiers for common brutalist patterns:

```swift
.brutalistCard() // Hard edges, bold border
.brutalistButton(style: .primary) // Primary/secondary variants
.brutalistTextField() // Bold border, monospace option
.brutalistLabel() // Uppercase, bold, letter-spaced
```

### Design Tokens

Centralize all values in `AppTheme` or `BrutalistTheme`:

```swift
enum BrutalistTheme {
    enum Border {
        static let thin: CGFloat = 1
        static let standard: CGFloat = 2
        static let thick: CGFloat = 3
    }
    
    enum CornerRadius {
        static let sharp: CGFloat = 0
        static let minimal: CGFloat = 4
    }
    
    enum Colors {
        static let foreground = Color.black // Adapts to dark mode
        static let background = Color.white
        static let accentRed = Color(hex: 0xFF0000)
        static let accentBlue = Color(hex: 0x0000FF)
    }
}
```

### Conditional Styling

Use environment values or user preferences to toggle between brutalist and glass modes:

```swift
@Environment(\.designStyle) var designStyle

var cardBackground: some View {
    if designStyle == .brutalist {
        Rectangle()
            .stroke(Color.primary, lineWidth: 2)
    } else {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
    }
}
```

---

## Examples: Before & After

### Goal Card

**Before (Current Liquid Glass):**
- Rounded corners (16pt)
- Soft shadow
- Gradient background
- Smooth animations

**After (Brutalist):**
- Sharp corners (0pt) OR minimal (4pt)
- Hard shadow (4pt offset) OR no shadow
- Solid background with bold border
- Snappy animations

**Hybrid (Best of Both):**
- Sharp corners for card border
- Glass material for background
- Bold typography
- Preserve smooth chart animations

### Data Entry Form

**Before:**
- Rounded text fields
- Subtle borders
- Soft focus rings

**After (Brutalist):**
- Rectangular text fields
- Bold 2pt borders
- Accent-colored focus (3pt)
- Monospace font option for numeric input

### Chart (Insights Tab)

**Before:**
- Smooth gradients
- Point markers on every data point
- Rounded chart area
- Subtle grid lines

**After (Brutalist, >14 days data):**
- Bold line (3pt)
- No point markers (or only on hover)
- Sharp rectangular chart area
- Prominent grid lines (1pt)

**Hybrid (Preserve Glass):**
- Bold accent-colored line
- Area gradient (subtle)
- Aggregate data points (weekly/monthly)
- Minimal grid, focus on data

---

## Conclusion

This brutalist design specification provides a foundation for reimagining Future – Life Updates with raw honesty and functional clarity while respecting the liquid glass elements the user values. The hybrid approach allows us to adopt brutalist principles for structure and data while maintaining the polished, glassy feel for visualizations and immersive moments.

The key is to let content and function drive aesthetics, ensuring every design decision serves the user's goal-tracking workflow with clarity and purpose.

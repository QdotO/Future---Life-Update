import SwiftUI

struct BrutalistButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case compactSecondary
        case destructive
        case ghost  // Text-only with underline
        case accent  // Uses category/accent color
    }

    let variant: Variant
    var accentColor: Color? = nil  // Optional override for accent variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.BrutalistTypography.bodyBold)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderColor(isPressed: configuration.isPressed),
                        lineWidth: borderWidth(isPressed: configuration.isPressed))
            )
            .foregroundColor(foregroundColor)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .appShadow(configuration.isPressed ? pressedShadow : normalShadow)
            .animation(AppTheme.BrutalistAnimation.springSnappy, value: configuration.isPressed)
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .ghost:
            return 0
        default:
            return AppTheme.BrutalistRadius.soft
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .accent:
            return .white
        case .secondary, .compactSecondary:
            return AppTheme.BrutalistPalette.foreground
        case .destructive:
            return .white
        case .ghost:
            return AppTheme.BrutalistPalette.accent
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            let base = AppTheme.BrutalistPalette.accent
            return isPressed ? base.opacity(0.85) : base
        case .accent:
            let base = accentColor ?? AppTheme.BrutalistPalette.accent
            return isPressed ? base.opacity(0.85) : base
        case .secondary, .compactSecondary:
            return isPressed
                ? AppTheme.BrutalistPalette.foreground.opacity(0.06)
                : AppTheme.BrutalistPalette.background
        case .destructive:
            return isPressed
                ? AppTheme.BrutalistPalette.danger.opacity(0.85)
                : AppTheme.BrutalistPalette.danger
        case .ghost:
            return .clear
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary, .accent:
            return .clear  // No border for filled buttons
        case .secondary, .compactSecondary:
            return isPressed
                ? AppTheme.BrutalistPalette.foreground
                : AppTheme.BrutalistPalette.border
        case .destructive:
            return .clear
        case .ghost:
            return .clear
        }
    }

    private func borderWidth(isPressed: Bool) -> CGFloat {
        switch variant {
        case .primary, .accent, .destructive, .ghost:
            return 0
        default:
            return isPressed ? AppTheme.BrutalistBorder.thick : AppTheme.BrutalistBorder.standard
        }
    }

    private var normalShadow: ShadowStyle? {
        switch variant {
        case .primary, .accent:
            return AppTheme.BrutalistShadow.elevation2
        default:
            return nil
        }
    }

    private var pressedShadow: ShadowStyle? {
        switch variant {
        case .primary, .accent:
            return AppTheme.BrutalistShadow.elevation1
        default:
            return nil
        }
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .compactSecondary:
            return 10
        case .ghost:
            return 6
        default:
            return 14
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .compactSecondary:
            return 16
        case .ghost:
            return 4
        default:
            return 24
        }
    }
}

struct BrutalistIconButtonStyle: ButtonStyle {
    enum Variant {
        case accent
        case neutral
        case subtle  // No background, just icon
    }

    let variant: Variant
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .bold))
            .frame(width: size, height: size)
            .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .stroke(
                        borderColor,
                        lineWidth: variant == .subtle
                            ? 0
                            : (configuration.isPressed
                                ? AppTheme.BrutalistBorder.thick
                                : AppTheme.BrutalistBorder.standard)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft))
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(AppTheme.BrutalistAnimation.springSnappy, value: configuration.isPressed)
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .accent:
            return .white
        case .neutral:
            return AppTheme.BrutalistPalette.foreground
        case .subtle:
            return isPressed
                ? AppTheme.BrutalistPalette.accent
                : AppTheme.BrutalistPalette.secondary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .subtle:
            return .clear
        default:
            return AppTheme.BrutalistPalette.border
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .accent:
            return isPressed
                ? AppTheme.BrutalistPalette.accent.opacity(0.85) : AppTheme.BrutalistPalette.accent
        case .neutral:
            return isPressed
                ? AppTheme.BrutalistPalette.foreground.opacity(0.08)
                : AppTheme.BrutalistPalette.background
        case .subtle:
            return isPressed
                ? AppTheme.BrutalistPalette.foreground.opacity(0.06)
                : .clear
        }
    }
}

private struct BrutalistFieldModifier: ViewModifier {
    @Environment(\.designStyle) private var designStyle
    let isFocused: Bool

    func body(content: Content) -> some View {
        if designStyle == .brutalist {
            content
                .textFieldStyle(.plain)
                .font(AppTheme.BrutalistTypography.body)
                .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                        .fill(
                            isFocused
                                ? AppTheme.BrutalistPalette.background
                                : AppTheme.BrutalistPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                        .stroke(
                            isFocused
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.border,
                            lineWidth: isFocused
                                ? AppTheme.BrutalistBorder.thick : AppTheme.BrutalistBorder.thin
                        )
                )
                .overlay(
                    // Focus glow effect
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                        .stroke(
                            AppTheme.BrutalistPalette.accent.opacity(isFocused ? 0.15 : 0),
                            lineWidth: 4
                        )
                        .blur(radius: 2)
                )
                .animation(AppTheme.BrutalistAnimation.springSnappy, value: isFocused)
        } else {
            content
        }
    }
}

extension Button {
    func brutalistButton(style: BrutalistButtonStyle.Variant = .primary) -> some View {
        buttonStyle(BrutalistButtonStyle(variant: style))
    }

    func brutalistIconButton(variant: BrutalistIconButtonStyle.Variant = .accent) -> some View {
        buttonStyle(BrutalistIconButtonStyle(variant: variant))
    }
}

extension View {
    func brutalistField(isFocused: Bool) -> some View {
        modifier(BrutalistFieldModifier(isFocused: isFocused))
    }
}

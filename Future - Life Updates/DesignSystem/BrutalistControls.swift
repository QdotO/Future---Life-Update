import SwiftUI

struct BrutalistButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case compactSecondary
        case destructive
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.BrutalistTypography.bodyBold)
            .textCase(.uppercase)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .overlay(
                Rectangle()
                    .stroke(
                        borderColor(isPressed: configuration.isPressed),
                        lineWidth: borderWidth(isPressed: configuration.isPressed))
            )
            .foregroundColor(foregroundColor)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .compactSecondary:
            return AppTheme.BrutalistPalette.foreground
        case .destructive:
            return .white
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed
                ? AppTheme.BrutalistPalette.accent.opacity(0.8) : AppTheme.BrutalistPalette.accent
        case .secondary, .compactSecondary:
            return isPressed
                ? AppTheme.BrutalistPalette.border.opacity(0.08)
                : AppTheme.BrutalistPalette.background
        case .destructive:
            return isPressed ? Color.red.opacity(0.8) : Color.red
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return AppTheme.BrutalistPalette.border
        case .secondary, .compactSecondary:
            return AppTheme.BrutalistPalette.border
        case .destructive:
            return Color.red
        }
    }

    private func borderWidth(isPressed: Bool) -> CGFloat {
        isPressed ? AppTheme.BrutalistBorder.thick : AppTheme.BrutalistBorder.standard
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .compactSecondary:
            return 10
        default:
            return 14
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .compactSecondary:
            return 16
        default:
            return 20
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
                .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                .background(AppTheme.BrutalistPalette.background)
                .overlay(
                    Rectangle()
                        .stroke(
                            isFocused
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.border,
                            lineWidth: isFocused
                                ? AppTheme.BrutalistBorder.thick : AppTheme.BrutalistBorder.standard
                        )
                )
        } else {
            content
        }
    }
}

extension Button {
    func brutalistButton(style: BrutalistButtonStyle.Variant = .primary) -> some View {
        buttonStyle(BrutalistButtonStyle(variant: style))
    }
}

extension View {
    func brutalistField(isFocused: Bool) -> some View {
        modifier(BrutalistFieldModifier(isFocused: isFocused))
    }
}

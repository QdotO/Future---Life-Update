import SwiftUI

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var iconSystemName: String? = nil
    var accessibilityHint: String? = nil
    let action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                if let iconSystemName {
                    Image(systemName: iconSystemName)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(AppTheme.Typography.bodyStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .background(
            backgroundShape
                .fill(isSelected ? AppTheme.Palette.primary : AppTheme.Palette.surface)
        )
        .overlay(
            backgroundShape
                .stroke(isSelected ? Color.clear : AppTheme.Palette.neutralBorder, lineWidth: 1)
        )
        .overlay(
            backgroundShape
                .stroke(AppTheme.Palette.focusRing, lineWidth: isFocused || isHovering ? 2 : 0)
        )
        .foregroundStyle(isSelected ? AppTheme.Palette.accentOnPrimary : AppTheme.Palette.neutralStrong)
        .contentShape(backgroundShape)
        .focused($isFocused)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    .accessibilityElement()
    .accessibilityLabel(title)
    .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

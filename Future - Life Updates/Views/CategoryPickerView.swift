import SwiftUI
import UIKit

struct CategoryPickerView: View {
    let title: String
    let primaryOptions: [GoalCreationViewModel.CategoryOption]
    let overflowOptions: [GoalCreationViewModel.CategoryOption]
    @Binding var selectedCategory: TrackingCategory?
    @Binding var customCategoryLabel: String
    var onSelectOption: (GoalCreationViewModel.CategoryOption) -> Void
    var onUpdateCustomLabel: (String) -> Void

    @State private var isShowingOverflow = false
    @FocusState private var isCustomFieldFocused: Bool

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: AppTheme.Spacing.grid)]
    }

    private var showOverflowToggle: Bool {
        !overflowOptions.isEmpty
    }

    private var shouldShowCustomField: Bool {
        selectedCategory == .some(.custom)
    }

    private var shouldDisplayCustomField: Bool {
        shouldShowCustomField && isShowingOverflow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(title)
                .font(AppTheme.Typography.sectionHeader)

            if isShowingOverflow && showOverflowToggle {
                    minimizedPrimaryCategories
            } else {
                grid(for: primaryOptions)
            }

            if showOverflowToggle {
                if isShowingOverflow {
                    grid(for: overflowOptions, includeCustomButton: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let willShow = !isShowingOverflow
                        isShowingOverflow = willShow
                        if willShow {
                            if selectedCategory == .some(.custom) && customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isCustomFieldFocused = true
                                }
                            }
                        } else {
                            isCustomFieldFocused = false
                        }
                        Haptics.selection()
                    }
                } label: {
                    Label(isShowingOverflow ? "Hide categories" : "More categories", systemImage: isShowingOverflow ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                }
                .buttonStyle(.secondaryProminent)
                .accessibilityHint(isShowingOverflow ? "Hide additional categories" : "Show additional categories")
            }

            if shouldDisplayCustomField {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Custom category")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Palette.neutralSubdued)
                    TextField("Name your category", text: Binding(
                        get: { customCategoryLabel },
                        set: { newValue in
                            customCategoryLabel = newValue
                            onUpdateCustomLabel(newValue)
                        }
                    ))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(false)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Palette.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.Palette.neutralBorder, lineWidth: 1)
                            )
                    )
                    .focused($isCustomFieldFocused)
                    .accessibilityHint("Enter a custom category name")
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedCategory)
            .onAppear {
                if shouldShowCustomField {
                    isShowingOverflow = true
                }
        }
    }

    private var minimizedPrimaryCategories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(primaryOptions, id: \.id) { option in
                    SelectableChip(
                        title: option.title,
                        isSelected: isSelected(option),
                        iconSystemName: nil,
                        accessibilityHint: option.isCustom ? "Uses your custom category" : nil,
                        action: {
                            onSelect(option)
                        }
                    )
                    .accessibilityValue(isSelected(option) ? "Selected" : "Not selected")
                    .accessibilityIdentifier("categoryChip-\(option.id)")
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xs)
        }
        .frame(maxHeight: 60)
        .transition(.opacity)
    }

    private func grid(for options: [GoalCreationViewModel.CategoryOption], includeCustomButton: Bool = false) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.grid) {
            ForEach(options, id: \.id) { option in
                SelectableChip(
                    title: option.title,
                    isSelected: isSelected(option),
                    iconSystemName: nil,
                    accessibilityHint: option.isCustom ? "Uses your custom category" : nil,
                    action: {
                        onSelect(option)
                    }
                )
                .accessibilityValue(isSelected(option) ? "Selected" : "Not selected")
                .accessibilityIdentifier("categoryChip-\(option.id)")
            }

            if includeCustomButton {
                addCustomButton
            }
        }
    }

    private var addCustomButton: some View {
        SelectableChip(
            title: shouldShowCustomField ? "Custom selected" : "Add custom category",
            isSelected: shouldShowCustomField,
            iconSystemName: shouldShowCustomField ? "checkmark" : "plus",
            accessibilityHint: shouldShowCustomField ? "Custom category is active" : "Create your own category",
            action: {
                onSelect(.custom(customCategoryLabel.isEmpty ? "" : customCategoryLabel))
                if customCategoryLabel.isEmpty {
                    isCustomFieldFocused = true
                }
            }
        )
        .accessibilityValue(shouldShowCustomField ? "Selected" : "Not selected")
    }

    private func onSelect(_ option: GoalCreationViewModel.CategoryOption) {
        Haptics.selection()
        onSelectOption(option)
        announceSelection(for: option)
        if option.isCustom {
            if !isShowingOverflow {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingOverflow = true
                }
            }
            if customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isCustomFieldFocused = true
                }
            }
        }
    }

    private func announceSelection(for option: GoalCreationViewModel.CategoryOption) {
        UIAccessibility.post(notification: .announcement, argument: "\(option.title) selected")
    }

    private func isSelected(_ option: GoalCreationViewModel.CategoryOption) -> Bool {
        switch option {
        case .system(let category):
            return selectedCategory == .some(category)
        case .custom(let label):
            guard selectedCategory == .some(.custom) else { return false }
            let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
            let current = customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return !current.isEmpty && current.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }
}

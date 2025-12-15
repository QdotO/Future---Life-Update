import SwiftData
import SwiftUI

struct GoalCreationView: View {
    private enum FlowStep: Int, CaseIterable, Identifiable {
        case intent
        case prompts
        case rhythm
        case commitment
        case review

        var id: Int { rawValue }

        var key: String {
            switch self {
            case .intent: return "intent"
            case .prompts: return "prompts"
            case .rhythm: return "rhythm"
            case .commitment: return "commitment"
            case .review: return "review"
            }
        }

        var title: String {
            switch self {
            case .intent: return "Clarify your goal"
            case .prompts: return "Track the right things"
            case .rhythm: return "Choose your rhythm"
            case .commitment: return "Boost commitment"
            case .review: return "Review & create"
            }
        }

        var subtitle: String {
            switch self {
            case .intent:
                return "Give your goal a name and choose the focus area."
            case .prompts:
                return "Select the questions Life Updates will ask."
            case .rhythm:
                return "Decide when reminders should arrive."
            case .commitment:
                return "Add encouragement to keep future-you motivated."
            case .review:
                return "Double-check everything before saving."
            }
        }

        var isFinal: Bool { self == .review }

        func next() -> FlowStep? { FlowStep(rawValue: rawValue + 1) }
        func previous() -> FlowStep? { FlowStep(rawValue: rawValue - 1) }
    }

    private enum FocusField: Hashable {
        case title
        case motivation
        case customCategory
        case questionPrompt
        case questionOption
        case celebration
    }

    private struct RangePreset: Identifiable {
        let id: String
        let label: String
        let minimum: Double
        let maximum: Double
    }

    private let maxReminderCount = 3
    private let featuredCategories: [TrackingCategory] = [
        .fitness, .health, .productivity, .habits, .mood,
    ]
    private let primaryResponseTypes: [ResponseType] = [.boolean, .numeric, .scale, .text]
    private let advancedResponseTypes: [ResponseType] = [
        .waterIntake, .multipleChoice, .slider, .time,
    ]
    private let rangePresets: [RangePreset] = [
        RangePreset(id: "0-10", label: "0 – 10", minimum: 0, maximum: 10),
        RangePreset(id: "1-5", label: "1 – 5", minimum: 1, maximum: 5),
        RangePreset(id: "1-10", label: "1 – 10", minimum: 1, maximum: 10),
    ]
    private let chipColumns = [GridItem(.adaptive(minimum: 140), spacing: AppTheme.Spacing.sm)]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.designStyle) private var designStyle

    @State private var step: FlowStep = .intent
    @State private var composerDraft = GoalQuestionDraft()
    @State private var editingQuestionID: UUID?
    @State private var composerError: String?
    @State private var newOptionText: String = ""
    @State private var showAdvancedResponseTypes = false
    @State private var showCustomComposer = false
    @State private var showCustomTimeSheet = false
    @State private var customReminderDate: Date
    @State private var scheduleError: String?
    @State private var showingErrorAlert = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: FocusField?

    @State private var viewModel: GoalCreationFlowViewModel

    init(viewModel: GoalCreationViewModel) {
        let flowViewModel = GoalCreationFlowViewModel(legacyViewModel: viewModel)
        _viewModel = State(initialValue: flowViewModel)
        _customReminderDate = State(initialValue: flowViewModel.suggestedReminderDate())
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xl) {
                        WizardStepHeader(
                            title: step.title,
                            subtitle: step.subtitle,
                            stepIndex: step.rawValue,
                            totalSteps: FlowStep.allCases.count
                        )
                        .accessibilityIdentifier("wizardStep-\(step.key)")

                        stepContent
                    }
                    .padding(.horizontal, AppTheme.BrutalistSpacing.xl)
                    .padding(.bottom, AppTheme.BrutalistSpacing.xl * 2)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .accessibilityIdentifier("goalCreationScroll")
            }
            .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
            .navigationTitle("New Tracking Goal")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .environment(\.designStyle, .brutalist)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    if step == .rhythm, let conflict = viewModel.conflictMessage {
                        ConflictBanner(message: conflict)
                    }
                    WizardNavigationButtons(
                        canGoBack: step.previous() != nil,
                        isFinalStep: step.isFinal,
                        isForwardEnabled: canAdvance(step),
                        guidance: forwardHint(for: step),
                        onBack: moveBackward,
                        onNext: moveForward
                    )
                    .padding(.horizontal, AppTheme.BrutalistSpacing.xl)
                    .padding(.vertical, AppTheme.BrutalistSpacing.md)
                    .background(AppTheme.BrutalistPalette.background)
                    .overlay(
                        Rectangle()
                            .fill(AppTheme.BrutalistPalette.border)
                            .frame(height: 2),
                        alignment: .top
                    )
                }
            }
            .sheet(isPresented: $showCustomTimeSheet) {
                customReminderSheet
            }
            .alert(
                "Unable to Create Goal",
                isPresented: $showingErrorAlert,
                actions: {
                    Button("OK", role: .cancel) {
                        showingErrorAlert = false
                    }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
            .onChange(of: step) { _, newStep in
                updateFocus(for: newStep)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intent:
            intentStep
        case .prompts:
            promptsStep
        case .rhythm:
            rhythmStep
        case .commitment:
            commitmentStep
        case .review:
            reviewStep
        }
    }

    private var intentStep: some View {
        Group {
            if designStyle == .brutalist {
                brutalistIntentStep
            } else {
                legacyIntentStep
            }
        }
    }

    // MARK: - Brutalist redesign for "Clarify your goal"

    private var brutalistIntentStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
            // Goal details card
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.BrutalistPalette.accent)
                    Text("Goal Details")
                        .font(AppTheme.BrutalistTypography.bodyBold)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                }

                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                        Text("Name")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)

                        TextField("What do you want to track?", text: titleBinding)
                            .platformAdaptiveTextField()
                            .font(AppTheme.BrutalistTypography.title)
                            .focused($focusedField, equals: .title)
                            .padding(AppTheme.BrutalistSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                    .fill(AppTheme.BrutalistPalette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                    .stroke(
                                        focusedField == .title
                                            ? AppTheme.BrutalistPalette.accent
                                            : AppTheme.BrutalistPalette.border.opacity(0.5),
                                        lineWidth: focusedField == .title ? 2 : 1
                                    )
                            )
                            .accessibilityIdentifier("goalTitleField")
                    }

                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                        Text("Motivation (optional)")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)

                        TextField(
                            "Why does this matter to you?",
                            text: motivationBinding,
                            axis: .vertical
                        )
                        .platformAdaptiveTextField()
                        .lineLimit(3, reservesSpace: true)
                        .font(AppTheme.BrutalistTypography.body)
                        .focused($focusedField, equals: .motivation)
                        .padding(AppTheme.BrutalistSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .fill(AppTheme.BrutalistPalette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .stroke(
                                    focusedField == .motivation
                                        ? AppTheme.BrutalistPalette.accent
                                        : AppTheme.BrutalistPalette.border.opacity(0.5),
                                    lineWidth: focusedField == .motivation ? 2 : 1
                                )
                        )

                        Text("A short 'why' can boost your follow-through by 40%")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                            .padding(.top, AppTheme.BrutalistSpacing.xs)
                    }
                }
            }
            .padding(AppTheme.BrutalistSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .fill(AppTheme.BrutalistPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .stroke(AppTheme.BrutalistPalette.border.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

            // Focus area card
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.BrutalistPalette.accent)
                    Text("Focus Area")
                        .font(AppTheme.BrutalistTypography.bodyBold)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                }

                LazyVGrid(
                    columns: chipColumns,
                    alignment: .leading,
                    spacing: AppTheme.BrutalistSpacing.sm
                ) {
                    ForEach(featuredCategories, id: \.self) { category in
                        categoryChip(for: category)
                    }

                    // Custom category chip
                    let customSelected = viewModel.draft.category == .custom
                    Button {
                        viewModel.selectCategory(.custom)
                        focusedField = .customCategory
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                                .fill(
                                    customSelected
                                        ? AppTheme.BrutalistPalette.accent
                                        : AppTheme.BrutalistPalette.accent.opacity(0.4)
                                )
                                .frame(width: 4)

                            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(
                                            customSelected
                                                ? AppTheme.BrutalistPalette.accent
                                                : AppTheme.BrutalistPalette.secondary)

                                    Spacer()

                                    if customSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(AppTheme.BrutalistPalette.accent)
                                    }
                                }

                                Text("Something else…")
                                    .font(AppTheme.BrutalistTypography.bodyBold)
                                Text("Name your own area")
                                    .font(AppTheme.BrutalistTypography.caption)
                                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                            }
                            .padding(AppTheme.BrutalistSpacing.md)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .fill(
                                    customSelected
                                        ? AppTheme.BrutalistPalette.accent.opacity(0.08)
                                        : AppTheme.BrutalistPalette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .stroke(
                                    customSelected
                                        ? AppTheme.BrutalistPalette.accent
                                        : AppTheme.BrutalistPalette.border.opacity(0.5),
                                    lineWidth: customSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: customSelected
                                ? AppTheme.BrutalistPalette.accent.opacity(0.15) : .clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: customSelected)
                }

                if viewModel.draft.category == .custom {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                        Text("Custom Category Name")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)

                        TextField(
                            "Give it a name",
                            text: Binding(
                                get: { viewModel.draft.customCategoryLabel },
                                set: { viewModel.updateCustomCategoryLabel($0) }
                            )
                        )
                        .platformMinimalTextField()
                        #if os(iOS)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .customCategory)
                        #else
                            .focused($focusedField, equals: .customCategory)
                        #endif
                        .font(AppTheme.BrutalistTypography.body)
                        .padding(AppTheme.BrutalistSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .fill(AppTheme.BrutalistPalette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .stroke(
                                    focusedField == .customCategory
                                        ? AppTheme.BrutalistPalette.accent
                                        : AppTheme.BrutalistPalette.border.opacity(0.5),
                                    lineWidth: focusedField == .customCategory ? 2 : 1
                                )
                        )
                    }
                    .padding(.top, AppTheme.BrutalistSpacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(AppTheme.BrutalistSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .fill(AppTheme.BrutalistPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .stroke(AppTheme.BrutalistPalette.border.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .animation(.spring(response: 0.3), value: viewModel.draft.category)
    }

    // Original (liquid) layout preserved for non-brutalist mode
    private var legacyIntentStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    TextField("Name your goal", text: titleBinding)
                        .platformAdaptiveTextField()
                        .font(AppTheme.Typography.title)
                        .focused($focusedField, equals: .title)
                        .brutalistField(isFocused: focusedField == .title)
                        .accessibilityIdentifier("goalTitleField")

                    TextField(
                        "Why does this matter to you?",
                        text: motivationBinding,
                        axis: .vertical
                    )
                    .platformAdaptiveTextField()
                    .lineLimit(3, reservesSpace: true)
                    .font(AppTheme.Typography.body)
                    .focused($focusedField, equals: .motivation)
                    .brutalistField(isFocused: focusedField == .motivation)
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Pick a focus area")
                        .font(AppTheme.Typography.sectionHeader)

                    LazyVGrid(
                        columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm
                    ) {
                        ForEach(featuredCategories, id: \.self) { category in
                            categoryChip(for: category)
                        }

                        let customSelected = viewModel.draft.category == .custom
                        Button {
                            viewModel.selectCategory(.custom)
                            focusedField = .customCategory
                            Haptics.selection()
                        } label: {
                            VStack(
                                alignment: .leading,
                                spacing: designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
                            ) {
                                Text("Something else…")
                                    .font(
                                        designStyle == .brutalist
                                            ? AppTheme.BrutalistTypography.bodyBold
                                            : AppTheme.Typography.bodyStrong
                                    )
                                Text("Name your own area.")
                                    .font(
                                        designStyle == .brutalist
                                            ? AppTheme.BrutalistTypography.caption
                                            : AppTheme.Typography.caption
                                    )
                                    .foregroundStyle(
                                        designStyle == .brutalist
                                            ? AppTheme.BrutalistPalette.secondary : Color.secondary
                                    )
                            }
                            .padding(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
                            )
                            .frame(
                                maxWidth: .infinity,
                                minHeight: designStyle == .brutalist ? 96 : 92, alignment: .leading
                            )
                            .background(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistPalette.background
                                    : AppTheme.Palette.surface
                            )
                            .overlay(
                                Group {
                                    if designStyle == .brutalist {
                                        Rectangle()
                                            .stroke(
                                                customSelected
                                                    ? AppTheme.BrutalistPalette.accent
                                                    : AppTheme.BrutalistPalette.border,
                                                lineWidth: AppTheme.BrutalistBorder.standard
                                            )
                                    } else {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                AppTheme.Palette.primary.opacity(0.2), lineWidth: 1
                                            )
                                            .background(
                                                RoundedRectangle(
                                                    cornerRadius: 16, style: .continuous
                                                )
                                                .fill(AppTheme.Palette.surface)
                                            )
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? (customSelected
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.foreground)
                                : .primary
                        )
                    }

                    if viewModel.draft.category == .custom {
                        TextField(
                            "Give it a name",
                            text: Binding(
                                get: { viewModel.draft.customCategoryLabel },
                                set: { viewModel.updateCustomCategoryLabel($0) }
                            )
                        )
                        .platformMinimalTextField()
                        #if os(iOS)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .customCategory)
                        #else
                            .focused($focusedField, equals: .customCategory)
                        #endif
                        .font(AppTheme.Typography.body)
                        .brutalistField(isFocused: focusedField == .customCategory)
                    }
                }
            }

            // Removed step checklist per design direction
        }
    }

    private var promptsStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
            // MARK: - Your Questions (Show saved questions first for immediate feedback)
            if !viewModel.draft.questionDrafts.isEmpty {
                CardBackground {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                        HStack {
                            HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.BrutalistPalette.accent)
                                Text("Your Questions")
                                    .font(AppTheme.BrutalistTypography.bodyBold)
                            }
                            Spacer()
                            Text("\(viewModel.draft.questionDrafts.count) added")
                                .font(AppTheme.BrutalistTypography.caption)
                                .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                        }

                        LazyVStack(spacing: AppTheme.BrutalistSpacing.sm) {
                            ForEach(
                                Array(viewModel.draft.questionDrafts.enumerated()), id: \.element.id
                            ) { index, question in
                                questionSummaryCard(for: question, index: index)
                            }
                        }
                    }
                }
            }

            // MARK: - Quick Add Section (One-tap question patterns)
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(AppTheme.BrutalistPalette.accent)
                        Text("Quick Add")
                            .font(AppTheme.BrutalistTypography.bodyBold)
                    }

                    Text("Tap to instantly add a tracking question.")
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundStyle(AppTheme.BrutalistPalette.secondary)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppTheme.BrutalistSpacing.sm
                    ) {
                        QuickAddButton(
                            icon: "checkmark.circle",
                            title: "Yes / No",
                            subtitle: "Did I do it?"
                        ) {
                            addQuickQuestion(
                                type: .boolean, prompt: "Did you \(goalActionPhrase) today?")
                        }

                        QuickAddButton(
                            icon: "number",
                            title: "Count",
                            subtitle: "How many?"
                        ) {
                            addQuickQuestion(
                                type: .numeric,
                                prompt: "How many times did you \(goalActionPhrase)?", min: 0,
                                max: 100)
                        }

                        QuickAddButton(
                            icon: "chart.bar.fill",
                            title: "1-10 Scale",
                            subtitle: "Rate it"
                        ) {
                            addQuickQuestion(
                                type: .scale,
                                prompt: "How would you rate your \(goalNounPhrase) today?", min: 1,
                                max: 10)
                        }

                        QuickAddButton(
                            icon: "text.alignleft",
                            title: "Reflection",
                            subtitle: "Write notes"
                        ) {
                            addQuickQuestion(
                                type: .text,
                                prompt: "What did you notice about your \(goalNounPhrase) today?")
                        }
                    }
                }
            }

            // MARK: - Suggested Templates (Streamlined)
            let suggested = viewModel.recommendedTemplates()
            if !suggested.isEmpty {
                CardBackground {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                        HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(AppTheme.BrutalistPalette.accent)
                            Text(
                                "Suggested for \(viewModel.draft.category?.displayName ?? "your goal")"
                            )
                            .font(AppTheme.BrutalistTypography.bodyBold)
                        }

                        VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                            ForEach(suggested) { template in
                                CompactTemplateCard(
                                    template: template,
                                    isApplied: viewModel.appliedTemplateIDs.contains(template.id)
                                ) {
                                    viewModel.applyTemplate(template)
                                    Haptics.success()
                                }
                            }
                        }

                        let additional = viewModel.additionalTemplates(
                            excluding: Set(suggested.map(\.id)))
                        if !additional.isEmpty {
                            DisclosureGroup {
                                VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                                    ForEach(additional) { template in
                                        CompactTemplateCard(
                                            template: template,
                                            isApplied: viewModel.appliedTemplateIDs.contains(
                                                template.id)
                                        ) {
                                            viewModel.applyTemplate(template)
                                            Haptics.success()
                                        }
                                    }
                                }
                                .padding(.top, AppTheme.BrutalistSpacing.sm)
                            } label: {
                                Text("More suggestions")
                                    .font(AppTheme.BrutalistTypography.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }

            // MARK: - AI Suggestions (Collapsed by default)
            aiSuggestionsSection

            // MARK: - Custom Question Composer (Progressive disclosure)
            DisclosureGroup(isExpanded: $showCustomComposer) {
                questionComposer
                    .padding(.top, AppTheme.BrutalistSpacing.md)
            } label: {
                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.BrutalistPalette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create custom question")
                            .font(AppTheme.BrutalistTypography.bodyBold)
                        Text("Build your own tracking prompt with custom options")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                    }
                }
            }
            .padding(AppTheme.BrutalistSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .fill(AppTheme.BrutalistPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .stroke(AppTheme.BrutalistPalette.border.opacity(0.3), lineWidth: 1)
            )

            // MARK: - Empty State (Only if no questions)
            if viewModel.draft.questionDrafts.isEmpty {
                CardBackground {
                    VStack(spacing: AppTheme.BrutalistSpacing.md) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.BrutalistPalette.secondary)

                        Text("Add at least one question")
                            .font(AppTheme.BrutalistTypography.bodyBold)

                        Text("Use Quick Add above or tap a suggestion to get started quickly.")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.BrutalistSpacing.lg)
                }
            }
        }
        .onAppear {
            triggerSuggestionsIfNeeded()
        }
    }

    // MARK: - Quick Add Helpers

    private var goalActionPhrase: String {
        let title = viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if title.isEmpty { return "complete your goal" }
        // Remove common prefixes for natural phrasing
        let prefixes = ["track ", "log ", "record ", "measure "]
        for prefix in prefixes {
            if title.hasPrefix(prefix) {
                return String(title.dropFirst(prefix.count))
            }
        }
        return title
    }

    private var goalNounPhrase: String {
        let title = viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if title.isEmpty { return "progress" }
        return title
    }

    private func addQuickQuestion(
        type: ResponseType, prompt: String, min: Double? = nil, max: Double? = nil
    ) {
        var rules: ValidationRules? = nil
        if let min = min, let max = max {
            rules = ValidationRules(minimumValue: min, maximumValue: max, allowsEmpty: false)
        } else {
            rules = ValidationRules(allowsEmpty: false)
        }

        let question = GoalQuestionDraft(
            text: prompt,
            responseType: type,
            options: [],
            validationRules: rules,
            isActive: true,
            templateID: nil,
            suggestionID: nil
        )
        viewModel.addCustomQuestion(question)
        Haptics.success()
    }

    private var questionComposer: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            // Header with cancel button when editing
            if editingQuestionID != nil {
                HStack {
                    Text("Editing question")
                        .font(AppTheme.BrutalistTypography.bodyBold)
                    Spacer()
                    Button {
                        resetComposer()
                        Haptics.selection()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Question text input
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                Text("Your question")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundStyle(AppTheme.BrutalistPalette.secondary)

                TextField(
                    "What do you want to track?",
                    text: $composerDraft.text,
                    axis: .vertical
                )
                .platformAdaptiveTextField()
                .font(AppTheme.BrutalistTypography.body)
                .focused($focusedField, equals: .questionPrompt)
                .lineLimit(2, reservesSpace: true)
                .padding(AppTheme.BrutalistSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .fill(AppTheme.BrutalistPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .stroke(
                            focusedField == .questionPrompt
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.border.opacity(0.5),
                            lineWidth: focusedField == .questionPrompt ? 2 : 1
                        )
                )
            }

            // Response type selection - simplified grid
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Text("Response type")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundStyle(AppTheme.BrutalistPalette.secondary)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: AppTheme.BrutalistSpacing.sm
                ) {
                    ForEach(primaryResponseTypes, id: \.self) { type in
                        responseTypeChip(for: type)
                    }
                }

                // Advanced types in collapsible section
                DisclosureGroup(isExpanded: $showAdvancedResponseTypes) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppTheme.BrutalistSpacing.sm
                    ) {
                        ForEach(advancedResponseTypes, id: \.self) { type in
                            responseTypeChip(for: type)
                        }
                    }
                    .padding(.top, AppTheme.BrutalistSpacing.sm)
                } label: {
                    Text("More response types")
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                }
            }

            // Configuration fields (range, options, etc.)
            configurationFields

            // Optional toggle
            Toggle(
                "Allow skipping this question",
                isOn: Binding(
                    get: { composerAllowsEmpty },
                    set: { updateComposerAllowsEmpty($0) }
                )
            )
            .font(AppTheme.BrutalistTypography.caption)
            .toggleStyle(.switch)
            .tint(AppTheme.BrutalistPalette.accent)

            // Error message
            if let composerError {
                HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                    Text(composerError)
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundStyle(Color.red)
                }
            }

            // Action buttons
            HStack(spacing: AppTheme.BrutalistSpacing.md) {
                if composerHasContent {
                    Button {
                        resetComposer()
                        Haptics.selection()
                    } label: {
                        Text("Clear")
                            .font(AppTheme.BrutalistTypography.bodyBold)
                    }
                    .brutalistButton(style: .secondary)
                }

                Spacer()

                Button(editingQuestionID == nil ? "Add Question" : "Update") {
                    saveQuestionDraft()
                }
                .brutalistButton(style: .primary)
                .disabled(!canSaveQuestion)
                .opacity(canSaveQuestion ? 1 : 0.5)
            }
        }
    }

    @ViewBuilder
    private var configurationFields: some View {
        switch composerDraft.responseType {
        case .numeric, .scale, .slider, .waterIntake:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Range presets")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    ForEach(rangePresets) { preset in
                        let isActive = isPresetActive(preset)
                        Button {
                            applyRangePreset(preset)
                            Haptics.selection()
                        } label: {
                            Text(preset.label)
                                .font(
                                    designStyle == .brutalist
                                        ? AppTheme.BrutalistTypography.caption
                                        : AppTheme.Typography.caption
                                )
                                .fontWeight(.semibold)
                                .padding(
                                    .horizontal,
                                    designStyle == .brutalist
                                        ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
                                )
                                .padding(
                                    .vertical,
                                    designStyle == .brutalist
                                        ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.sm
                                )
                                .background(
                                    designStyle == .brutalist
                                        ? (isActive
                                            ? AppTheme.BrutalistPalette.accent.opacity(0.12)
                                            : AppTheme.BrutalistPalette.background)
                                        : (isActive
                                            ? AppTheme.Palette.primary.opacity(0.12)
                                            : AppTheme.Palette.surface)
                                )
                                .overlay(
                                    Group {
                                        if designStyle == .brutalist {
                                            Rectangle()
                                                .stroke(
                                                    isActive
                                                        ? AppTheme.BrutalistPalette.accent
                                                        : AppTheme.BrutalistPalette.border,
                                                    lineWidth: AppTheme.BrutalistBorder.standard
                                                )
                                        } else {
                                            Capsule()
                                                .stroke(
                                                    isActive
                                                        ? AppTheme.Palette.primary
                                                        : AppTheme.Palette.neutralBorder,
                                                    lineWidth: isActive ? 2 : 1)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? (isActive
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.foreground)
                                : (isActive ? AppTheme.Palette.primary : .primary)
                        )
                    }
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Minimum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            value: Binding(
                                get: { composerMinimumValue },
                                set: { updateComposerMinimum($0) }
                            ), in: -1000...composerMaximumValue, step: 1
                        ) {
                            Text(formattedValue(composerMinimumValue))
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Maximum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            value: Binding(
                                get: { composerMaximumValue },
                                set: { updateComposerMaximum($0) }
                            ), in: composerMinimumValue...1000, step: 1
                        ) {
                            Text(formattedValue(composerMaximumValue))
                        }
                    }
                }
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if !composerDraft.options.isEmpty {
                    LazyVGrid(
                        columns: chipColumns,
                        alignment: .leading,
                        spacing: designStyle == .brutalist
                            ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
                    ) {
                        ForEach(composerDraft.options, id: \.self) { option in
                            HStack(
                                spacing: designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
                            ) {
                                Text(option)
                                    .font(
                                        designStyle == .brutalist
                                            ? AppTheme.BrutalistTypography.caption
                                            : AppTheme.Typography.caption
                                    )
                                    .fontWeight(.semibold)
                                Button {
                                    removeOption(option)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(
                                            designStyle == .brutalist
                                                ? AppTheme.BrutalistTypography.caption
                                                : .caption.bold()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(
                                .horizontal,
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
                            )
                            .padding(
                                .vertical,
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
                            )
                            .background(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistPalette.background
                                    : AppTheme.Palette.surfaceElevated
                            )
                            .overlay(
                                Group {
                                    if designStyle == .brutalist {
                                        Rectangle()
                                            .stroke(
                                                AppTheme.BrutalistPalette.border,
                                                lineWidth: AppTheme.BrutalistBorder.standard)
                                    } else {
                                        Capsule().stroke(
                                            AppTheme.Palette.neutralBorder, lineWidth: 1)
                                    }
                                }
                            )
                        }
                    }
                }

                HStack {
                    TextField("Add option", text: $newOptionText)
                        .platformMinimalTextField()
                        .focused($focusedField, equals: .questionOption)
                    secondaryActionButton("Add") {
                        appendCurrentOption()
                    }
                    .disabled(newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        case .text:
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(AppTheme.BrutalistPalette.accent)
                Text("Open-ended text response for notes and reflections.")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundStyle(AppTheme.BrutalistPalette.secondary)
            }
            .padding(AppTheme.BrutalistSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .fill(AppTheme.BrutalistPalette.accent.opacity(0.05))
            )
        case .boolean:
            Text("We’ll use a simple yes or no prompt.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .time:
            Text("Great for logging a bedtime or start time.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rhythmStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Reminder cadence")
                        .font(AppTheme.Typography.sectionHeader)

                    Picker(
                        "Frequency",
                        selection: Binding(
                            get: { selectedCadenceTag },
                            set: { updateCadence(with: $0) }
                        )
                    ) {
                        ForEach(viewModel.cadencePresets()) { preset in
                            Text(preset.title).tag(preset.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch viewModel.draft.schedule.cadence {
                    case .weekly(let weekday):
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(
                                spacing: designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
                            ) {
                                ForEach(Weekday.allCases) { day in
                                    let isSelected = day == weekday
                                    Button {
                                        viewModel.selectCadence(.weekly(day))
                                        Haptics.selection()
                                    } label: {
                                        Text(day.shortDisplayName)
                                            .font(
                                                designStyle == .brutalist
                                                    ? AppTheme.BrutalistTypography.caption
                                                    : AppTheme.Typography.caption
                                            )
                                            .fontWeight(.semibold)
                                            .padding(
                                                .horizontal,
                                                designStyle == .brutalist
                                                    ? AppTheme.BrutalistSpacing.md
                                                    : AppTheme.Spacing.md
                                            )
                                            .padding(
                                                .vertical,
                                                designStyle == .brutalist
                                                    ? AppTheme.BrutalistSpacing.xs
                                                    : AppTheme.Spacing.sm
                                            )
                                            .background(
                                                designStyle == .brutalist
                                                    ? (isSelected
                                                        ? AppTheme.BrutalistPalette.accent.opacity(
                                                            0.12)
                                                        : AppTheme.BrutalistPalette.background)
                                                    : (isSelected
                                                        ? AppTheme.Palette.primary.opacity(0.12)
                                                        : AppTheme.Palette.surface)
                                            )
                                            .overlay(
                                                Group {
                                                    if designStyle == .brutalist {
                                                        Rectangle()
                                                            .stroke(
                                                                isSelected
                                                                    ? AppTheme.BrutalistPalette
                                                                        .accent
                                                                    : AppTheme.BrutalistPalette
                                                                        .border,
                                                                lineWidth: AppTheme.BrutalistBorder
                                                                    .standard
                                                            )
                                                    } else {
                                                        Capsule()
                                                            .stroke(
                                                                isSelected
                                                                    ? AppTheme.Palette.primary
                                                                    : AppTheme.Palette
                                                                        .neutralBorder,
                                                                lineWidth: isSelected ? 2 : 1)
                                                    }
                                                }
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(
                                        designStyle == .brutalist
                                            ? (isSelected
                                                ? AppTheme.BrutalistPalette.accent
                                                : AppTheme.BrutalistPalette.foreground)
                                            : (isSelected ? AppTheme.Palette.primary : .primary)
                                    )
                                }
                            }
                        }
                    case .custom(let interval):
                        Stepper(
                            value: Binding(
                                get: { interval },
                                set: { viewModel.updateCustomInterval(days: $0) }
                            ), in: 2...30
                        ) {
                            Text("Every \(interval) days")
                                .font(AppTheme.Typography.body)
                        }
                    default:
                        EmptyView()
                    }
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack {
                        Text("Reminder times")
                            .font(AppTheme.Typography.sectionHeader)
                        Spacer()
                        if !viewModel.draft.schedule.reminderTimes.isEmpty {
                            Text(
                                "\(viewModel.draft.schedule.reminderTimes.count)/\(maxReminderCount)"
                            )
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    statusPill(
                        message: viewModel.canAdvanceFromSchedule()
                            ? "Reminders ready" : "Add at least one reminder",
                        isComplete: viewModel.canAdvanceFromSchedule()
                    )

                    let recommended = viewModel.recommendedReminderTimes()
                    if !recommended.isEmpty {
                        LazyVGrid(
                            columns: chipColumns,
                            alignment: .leading,
                            spacing: designStyle == .brutalist
                                ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
                        ) {
                            ForEach(recommended, id: \.self) { time in
                                let isSelected = viewModel.draft.schedule.reminderTimes.contains(
                                    time)
                                Button {
                                    let succeeded = viewModel.toggleReminderTime(time)
                                    if succeeded {
                                        scheduleError = nil
                                        Haptics.selection()
                                    } else {
                                        scheduleError =
                                            "Reminders need to be at least five minutes apart or fewer than \(maxReminderCount)."
                                        Haptics.warning()
                                    }
                                } label: {
                                    Text(time.formattedTime(in: viewModel.draft.schedule.timezone))
                                        .font(
                                            designStyle == .brutalist
                                                ? AppTheme.BrutalistTypography.caption
                                                : AppTheme.Typography.caption
                                        )
                                        .fontWeight(.semibold)
                                        .padding(
                                            .horizontal,
                                            designStyle == .brutalist
                                                ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
                                        )
                                        .padding(
                                            .vertical,
                                            designStyle == .brutalist
                                                ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.sm
                                        )
                                        .background(
                                            designStyle == .brutalist
                                                ? (isSelected
                                                    ? AppTheme.BrutalistPalette.accent.opacity(0.12)
                                                    : AppTheme.BrutalistPalette.background)
                                                : (isSelected
                                                    ? AppTheme.Palette.primary.opacity(0.12)
                                                    : AppTheme.Palette.surface)
                                        )
                                        .overlay(
                                            Group {
                                                if designStyle == .brutalist {
                                                    Rectangle()
                                                        .stroke(
                                                            isSelected
                                                                ? AppTheme.BrutalistPalette.accent
                                                                : AppTheme.BrutalistPalette.border,
                                                            lineWidth: AppTheme.BrutalistBorder
                                                                .standard
                                                        )
                                                } else {
                                                    Capsule()
                                                        .stroke(
                                                            isSelected
                                                                ? AppTheme.Palette.primary
                                                                : AppTheme.Palette.neutralBorder,
                                                            lineWidth: isSelected ? 2 : 1)
                                                }
                                            }
                                        )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(
                                    designStyle == .brutalist
                                        ? (isSelected
                                            ? AppTheme.BrutalistPalette.accent
                                            : AppTheme.BrutalistPalette.foreground)
                                        : (isSelected ? AppTheme.Palette.primary : .primary)
                                )
                            }
                        }
                    }

                    if viewModel.draft.schedule.reminderTimes.isEmpty {
                        Text("Add at least one reminder so we can nudge you.")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            ForEach(viewModel.draft.schedule.reminderTimes, id: \.self) { time in
                                HStack {
                                    Text(time.formattedTime(in: viewModel.draft.schedule.timezone))
                                        .font(AppTheme.Typography.body)
                                    Spacer()
                                    Button(role: .destructive) {
                                        viewModel.removeReminderTime(time)
                                        Haptics.selection()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.body)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, AppTheme.Spacing.xs)
                            }
                        }
                    }

                    Group {
                        if designStyle == .brutalist {
                            Button {
                                showCustomTimeSheet = true
                                customReminderDate = viewModel.suggestedReminderDate(
                                    startingAt: customReminderDate)
                                Haptics.selection()
                            } label: {
                                Label("Custom time…", systemImage: "plus.circle.fill")
                                    .font(AppTheme.BrutalistTypography.bodyBold)
                                    .textCase(.uppercase)
                            }
                            .brutalistButton(style: .secondary)
                        } else {
                            Button {
                                showCustomTimeSheet = true
                                customReminderDate = viewModel.suggestedReminderDate(
                                    startingAt: customReminderDate)
                                Haptics.selection()
                            } label: {
                                Label("Custom time…", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.secondaryProminent)
                        }
                    }

                    if let scheduleError {
                        Text(scheduleError)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.red)
                    }
                }
            }

            CardBackground {
                DisclosureGroup("Advanced scheduling") {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Timezone")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker(
                            "Timezone",
                            selection: Binding(
                                get: { viewModel.draft.schedule.timezone },
                                set: { timezone in
                                    viewModel.updateTimezone(timezone)
                                    Haptics.selection()
                                }
                            )
                        ) {
                            ForEach(TimeZone.pickerOptions, id: \.identifier) { timezone in
                                Text(timezone.localizedDisplayName())
                                    .tag(timezone)
                            }
                        }
                    }
                    .padding(.top, AppTheme.Spacing.sm)
                }
                .font(AppTheme.Typography.bodyStrong)
            }
        }
    }

    private var commitmentStep: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Give future-you a boost")
                    .font(AppTheme.Typography.sectionHeader)
                Text(
                    "Add an optional encouragement or celebration message we'll surface when you log progress."
                )
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)

                TextField(
                    "How will you celebrate showing up?",
                    text: Binding(
                        get: { viewModel.draft.celebrationMessage },
                        set: { viewModel.draft.celebrationMessage = $0 }
                    ),
                    axis: .vertical
                )
                .platformAdaptiveTextField()
                .lineLimit(3, reservesSpace: true)
                .font(AppTheme.Typography.body)
                .focused($focusedField, equals: .celebration)
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text(viewModel.draft.title)
                            .font(AppTheme.Typography.title)
                        Spacer()
                        Button("Edit", action: { step = .intent })
                            .font(AppTheme.Typography.caption.weight(.semibold))
                    }
                    if let category = viewModel.draft.category {
                        Text(
                            category == .custom
                                ? (viewModel.draft.normalizedCustomCategoryLabel
                                    ?? category.displayName) : category.displayName
                        )
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    }
                    if !viewModel.draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                    {
                        Text(
                            viewModel.draft.motivation.trimmingCharacters(
                                in: .whitespacesAndNewlines)
                        )
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, AppTheme.Spacing.sm)
                    }
                    if !viewModel.draft.celebrationMessage.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty {
                        Text(
                            "Encouragement: \(viewModel.draft.celebrationMessage.trimmingCharacters(in: .whitespacesAndNewlines))"
                        )
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, AppTheme.Spacing.sm)
                    }
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Questions")
                            .font(AppTheme.Typography.sectionHeader)
                        Spacer()
                        Button("Edit", action: { step = .prompts })
                            .font(AppTheme.Typography.caption.weight(.semibold))
                    }
                    ForEach(viewModel.draft.questionDrafts) { question in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(question.trimmedText)
                                .font(AppTheme.Typography.body.weight(.semibold))
                            Text(question.responseType.displayName)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                            if question.templateID != nil || question.suggestionID != nil {
                                HStack(spacing: AppTheme.Spacing.xs) {
                                    if question.templateID != nil {
                                        sourceBadge(
                                            label: "Template", systemImage: "text.book.closed",
                                            tint: Color.secondary)
                                    }
                                    if question.suggestionID != nil {
                                        sourceBadge(
                                            label: "AI suggestion", systemImage: "sparkles",
                                            tint: AppTheme.Palette.primary)
                                    }
                                }
                            }
                            if let detail = detail(for: question) {
                                Text(detail)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.xs)
                    }
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("Reminders")
                            .font(AppTheme.Typography.sectionHeader)
                        Spacer()
                        Button("Edit", action: { step = .rhythm })
                            .font(AppTheme.Typography.caption.weight(.semibold))
                    }

                    switch viewModel.draft.schedule.cadence {
                    case .daily:
                        Text("Daily")
                            .font(AppTheme.Typography.body)
                    case .weekdays:
                        Text("Weekdays (Mon–Fri)")
                            .font(AppTheme.Typography.body)
                    case .weekly(let weekday):
                        Text("Weekly on \(weekday.displayName)")
                            .font(AppTheme.Typography.body)
                    case .custom(let interval):
                        Text("Every \(interval) days")
                            .font(AppTheme.Typography.body)
                    }

                    if viewModel.draft.schedule.reminderTimes.isEmpty {
                        Text("No reminder times selected")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.draft.schedule.reminderTimes, id: \.self) { time in
                            Text(time.formattedTime(in: viewModel.draft.schedule.timezone))
                                .font(AppTheme.Typography.body)
                        }
                    }
                }
            }
        }
    }

    private var customReminderSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                DatePicker(
                    "Reminder time",
                    selection: $customReminderDate,
                    displayedComponents: .hourAndMinute
                )
                #if os(iOS)
                    .datePickerStyle(.wheel)
                #else
                    .datePickerStyle(.graphical)
                #endif
                .labelsHidden()

                Text(
                    "Times are saved in \(viewModel.draft.schedule.timezone.localizedDisplayName())."
                )
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(AppTheme.Spacing.xl)
            .navigationTitle("Custom reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomTimeSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if viewModel.addReminderDate(customReminderDate) {
                            scheduleError = nil
                            showCustomTimeSheet = false
                            customReminderDate = viewModel.suggestedReminderDate(
                                startingAt: customReminderDate.addingTimeInterval(30 * 60))
                            Haptics.success()
                        } else {
                            scheduleError =
                                "Reminders need to be at least five minutes apart or fewer than \(maxReminderCount)."
                            Haptics.warning()
                        }
                    }
                    .disabled(viewModel.draft.schedule.reminderTimes.count >= maxReminderCount)
                }
            }
        }
    }

    private func categoryChip(for category: TrackingCategory) -> some View {
        let isSelected = viewModel.draft.category == category
        let categoryColor = categoryColorForChip(category)

        return Button {
            viewModel.selectCategory(category)
            Haptics.selection()
        } label: {
            if designStyle == .brutalist {
                HStack(spacing: 0) {
                    // Left color stripe
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                        .fill(isSelected ? categoryColor : categoryColor.opacity(0.4))
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                        HStack {
                            Image(systemName: categoryIcon(for: category))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(
                                    isSelected ? categoryColor : AppTheme.BrutalistPalette.secondary
                                )

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(categoryColor)
                            }
                        }

                        Text(category.displayName)
                            .font(AppTheme.BrutalistTypography.bodyBold)
                            .foregroundColor(
                                isSelected
                                    ? AppTheme.BrutalistPalette.foreground
                                    : AppTheme.BrutalistPalette.foreground)

                        Text(categorySubtitle(for: category))
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                            .lineLimit(1)
                    }
                    .padding(AppTheme.BrutalistSpacing.md)
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .fill(
                            isSelected
                                ? categoryColor.opacity(0.08)
                                : AppTheme.BrutalistPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .stroke(
                            isSelected
                                ? categoryColor : AppTheme.BrutalistPalette.border.opacity(0.5),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected ? categoryColor.opacity(0.15) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            } else {
                // Legacy liquid design
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(category.displayName)
                        .font(AppTheme.Typography.bodyStrong)
                    Text(categorySubtitle(for: category))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color.secondary)
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                .background(
                    isSelected ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder,
                            lineWidth: isSelected ? 2 : 1)
                )
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private func categoryColorForChip(_ category: TrackingCategory) -> Color {
        switch category {
        case .health: return AppTheme.BrutalistPalette.categoryHealth
        case .fitness: return AppTheme.BrutalistPalette.categoryFitness
        case .productivity: return AppTheme.BrutalistPalette.categoryProductivity
        case .habits: return AppTheme.BrutalistPalette.categoryHabits
        case .mood: return AppTheme.BrutalistPalette.categoryMood
        case .learning: return AppTheme.BrutalistPalette.categoryLearning
        case .social: return AppTheme.BrutalistPalette.categorySocial
        case .finance: return AppTheme.BrutalistPalette.categoryFinance
        case .custom: return AppTheme.BrutalistPalette.accent
        }
    }

    private func categoryIcon(for category: TrackingCategory) -> String {
        switch category {
        case .health: return "heart.fill"
        case .fitness: return "figure.run"
        case .productivity: return "chart.bar.fill"
        case .habits: return "repeat"
        case .mood: return "face.smiling"
        case .learning: return "book.fill"
        case .social: return "person.2.fill"
        case .finance: return "dollarsign.circle.fill"
        case .custom: return "star.fill"
        }
    }

    private func categorySubtitle(for category: TrackingCategory) -> String {
        switch category {
        case .fitness: return "Movement, workouts, energy"
        case .health: return "Sleep, nutrition, recovery"
        case .productivity: return "Work, focus, planning"
        case .habits: return "Routines, streaks, daily wins"
        case .mood: return "Feelings, resilience, reflection"
        case .learning: return "Skill building, study reps"
        case .social: return "Relationships, outreach"
        case .finance: return "Spending, saving, investing"
        case .custom: return "Define your own"
        }
    }

    @ViewBuilder
    private func primaryActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        if designStyle == .brutalist {
            Button(title, action: action)
                .brutalistButton(style: .primary)
        } else {
            Button(title, action: action)
                .buttonStyle(.primaryProminent)
        }
    }

    @ViewBuilder
    private func secondaryActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        if designStyle == .brutalist {
            Button(title, action: action)
                .brutalistButton(style: .secondary)
        } else {
            Button(title, action: action)
                .buttonStyle(.secondaryProminent)
        }
    }

    private func responseTypeChip(for type: ResponseType) -> some View {
        let isSelected = composerDraft.responseType == type
        let horizontalPadding =
            designStyle == .brutalist
            ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
        let verticalPadding =
            designStyle == .brutalist
            ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.sm
        let background =
            designStyle == .brutalist
            ? (isSelected
                ? AppTheme.BrutalistPalette.accent.opacity(0.12)
                : AppTheme.BrutalistPalette.background)
            : (isSelected ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
        let strokeColor =
            designStyle == .brutalist
            ? (isSelected ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.border)
            : (isSelected ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder)
        let strokeWidth =
            designStyle == .brutalist
            ? AppTheme.BrutalistBorder.standard : (isSelected ? 2 : 1)

        return Button {
            selectComposerResponseType(type)
            Haptics.selection()
        } label: {
            HStack(
                spacing: designStyle == .brutalist
                    ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
            ) {
                Image(systemName: iconName(for: type))
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.caption.weight(.semibold)
                            : AppTheme.Typography.caption.weight(.semibold)
                    )
                Text(type.displayName)
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.caption
                            : AppTheme.Typography.caption
                    )
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .overlay(
                Group {
                    if designStyle == .brutalist {
                        Rectangle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    } else {
                        Capsule()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            designStyle == .brutalist
                ? (isSelected
                    ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.foreground)
                : (isSelected ? AppTheme.Palette.primary : .primary)
        )
    }

    private func iconName(for type: ResponseType) -> String {
        switch type {
        case .numeric: return "number"
        case .scale: return "chart.bar"
        case .slider: return "slider.horizontal.3"
        case .multipleChoice: return "list.bullet"
        case .boolean: return "checkmark.circle"
        case .text: return "text.alignleft"
        case .time: return "clock"
        case .waterIntake: return "drop.fill"
        }
    }

    private var hasGoalTitle: Bool {
        !viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasCategory: Bool {
        guard let category = viewModel.draft.category else { return false }
        if category == .custom {
            return viewModel.draft.normalizedCustomCategoryLabel != nil
        }
        return true
    }

    private var hasCustomCategory: Bool {
        viewModel.draft.category == .custom
    }

    private var hasMotivation: Bool {
        !viewModel.draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var composerIsReady: Bool {
        questionIsComplete(composerDraft)
    }

    private func statusPill(message: String, isComplete: Bool) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle")
        }
        .font(
            designStyle == .brutalist
                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
        )
        .fontWeight(.semibold)
        .padding(
            .horizontal,
            designStyle == .brutalist ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
        )
        .padding(
            .vertical,
            designStyle == .brutalist ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
        )
        .background(
            designStyle == .brutalist
                ? AppTheme.BrutalistPalette.background
                : (isComplete ? AppTheme.Palette.primary.opacity(0.12) : Color.orange.opacity(0.12))
        )
        .overlay(
            Group {
                if designStyle == .brutalist {
                    Rectangle()
                        .stroke(
                            isComplete
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.standard
                        )
                } else {
                    Capsule()
                        .stroke(
                            isComplete ? AppTheme.Palette.primary : Color.orange, lineWidth: 1
                        )
                }
            }
        )
        .foregroundStyle(
            designStyle == .brutalist
                ? (isComplete
                    ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.foreground)
                : (isComplete ? AppTheme.Palette.primary : Color.orange)
        )
        .accessibilityLabel(message)
    }

    @ViewBuilder
    private func checklistRow(
        title: String,
        subtitle: String,
        isComplete: Bool,
        isRequired: Bool
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
        ) {
            Image(systemName: iconNameForChecklist(isComplete: isComplete, isRequired: isRequired))
                .font(
                    designStyle == .brutalist
                        ? AppTheme.BrutalistTypography.headline : .title3.weight(.semibold)
                )
                .foregroundStyle(
                    designStyle == .brutalist
                        ? AppTheme.BrutalistPalette.accent
                        : colorForChecklist(isComplete: isComplete, isRequired: isRequired)
                )
            VStack(
                alignment: .leading,
                spacing: designStyle == .brutalist
                    ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
            ) {
                Text(title)
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.bodyBold : AppTheme.Typography.bodyStrong
                    )
                Text(subtitle)
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                    )
                    .foregroundStyle(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistPalette.secondary : Color.secondary
                    )
            }
        }
        .padding(
            .vertical,
            designStyle == .brutalist ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs)
    }

    private func questionIsComplete(_ question: GoalQuestionDraft) -> Bool {
        guard question.hasContent else { return false }
        switch question.responseType {
        case .multipleChoice:
            return !question.options.isEmpty
        case .numeric, .scale, .slider, .waterIntake:
            guard let rules = question.validationRules else { return false }
            return rules.minimumValue != nil && rules.maximumValue != nil
        default:
            return true
        }
    }

    private func triggerSuggestionsIfNeeded(force: Bool = false) {
        guard viewModel.supportsSuggestions else { return }
        guard !viewModel.isLoadingSuggestions else { return }
        if !force, !viewModel.suggestions.isEmpty { return }
        let trimmedTitle = viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = viewModel.draft.motivation.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedDescription.isEmpty else { return }
        viewModel.loadSuggestions(force: force)
    }

    private func sourceBadge(label: String, systemImage: String, tint: Color) -> some View {
        Label(label, systemImage: systemImage)
            .font(
                designStyle == .brutalist
                    ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
            )
            .fontWeight(.semibold)
            .padding(
                .horizontal,
                designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
            )
            .padding(
                .vertical,
                designStyle == .brutalist ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
            )
            .background(
                designStyle == .brutalist
                    ? AppTheme.BrutalistPalette.background
                    : tint.opacity(0.12)
            )
            .overlay(
                Group {
                    if designStyle == .brutalist {
                        Rectangle()
                            .stroke(
                                AppTheme.BrutalistPalette.border,
                                lineWidth: AppTheme.BrutalistBorder.standard)
                    } else {
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.9), lineWidth: 1)
                    }
                }
            )
            .foregroundStyle(
                designStyle == .brutalist
                    ? AppTheme.BrutalistPalette.accent : tint
            )
    }

    private func questionSummaryCard(for question: GoalQuestionDraft, index: Int) -> some View {
        CardBackground {
            VStack(
                alignment: .leading,
                spacing: designStyle == .brutalist
                    ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
            ) {
                HStack(
                    alignment: .top,
                    spacing: designStyle == .brutalist
                        ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
                ) {
                    Image(
                        systemName: questionIsComplete(question)
                            ? "checkmark.circle.fill" : "exclamationmark.circle"
                    )
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.headline : .title3.weight(.semibold)
                    )
                    .foregroundStyle(
                        designStyle == .brutalist
                            ? (questionIsComplete(question)
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.secondary)
                            : (questionIsComplete(question)
                                ? AppTheme.Palette.primary : Color.orange)
                    )

                    VStack(
                        alignment: .leading,
                        spacing: designStyle == .brutalist
                            ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
                    ) {
                        Text(question.trimmedText)
                            .font(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistTypography.bodyBold
                                    : AppTheme.Typography.body.weight(.semibold)
                            )
                        Text(question.responseType.displayName)
                            .font(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistTypography.caption
                                    : AppTheme.Typography.caption
                            )
                            .foregroundStyle(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistPalette.secondary : Color.secondary
                            )
                        if question.templateID != nil || question.suggestionID != nil {
                            HStack(
                                spacing: designStyle == .brutalist
                                    ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
                            ) {
                                if question.templateID != nil {
                                    sourceBadge(
                                        label: "Template", systemImage: "text.book.closed",
                                        tint: Color.secondary)
                                }
                                if question.suggestionID != nil {
                                    sourceBadge(
                                        label: "AI suggestion", systemImage: "sparkles",
                                        tint: AppTheme.Palette.primary)
                                }
                            }
                        }
                        if let detail = detail(for: question) {
                            Text(detail)
                                .font(
                                    designStyle == .brutalist
                                        ? AppTheme.BrutalistTypography.caption
                                        : AppTheme.Typography.caption
                                )
                                .foregroundStyle(
                                    designStyle == .brutalist
                                        ? AppTheme.BrutalistPalette.secondary : Color.secondary
                                )
                        }
                    }

                    Spacer()

                    Menu {
                        Button("Edit") {
                            beginEditing(question)
                        }
                        Button("Move up", action: { moveQuestion(from: index, direction: -1) })
                            .disabled(index == 0)
                        Button("Move down", action: { moveQuestion(from: index, direction: 1) })
                            .disabled(index == viewModel.draft.questionDrafts.count - 1)
                        Button(role: .destructive) {
                            viewModel.removeQuestion(question.id)
                            Haptics.warning()
                            if editingQuestionID == question.id {
                                resetComposer()
                            }
                        } label: {
                            Text("Delete")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func iconNameForChecklist(isComplete: Bool, isRequired: Bool) -> String {
        if isComplete { return "checkmark.circle.fill" }
        return isRequired ? "exclamationmark.circle" : "circle"
    }

    private func colorForChecklist(isComplete: Bool, isRequired: Bool) -> Color {
        if designStyle == .brutalist {
            if isComplete { return AppTheme.BrutalistPalette.accent }
            return isRequired
                ? AppTheme.BrutalistPalette.secondary
                : AppTheme.BrutalistPalette.foreground.opacity(0.6)
        }
        if isComplete { return .green }
        return isRequired ? Color.orange : .secondary
    }

    private func detail(for question: GoalQuestionDraft) -> String? {
        var parts: [String] = []
        switch question.responseType {
        case .numeric, .scale, .slider:
            if let min = question.validationRules?.minimumValue,
                let max = question.validationRules?.maximumValue
            {
                parts.append("Range: \(formattedValue(min)) – \(formattedValue(max))")
            }
        case .waterIntake:
            if let min = question.validationRules?.minimumValue,
                let max = question.validationRules?.maximumValue
            {
                parts.append(
                    "Range: \(HydrationFormatter.ouncesString(min)) – \(HydrationFormatter.ouncesString(max))"
                )
            }
        case .multipleChoice:
            if !question.options.isEmpty {
                let preview = question.options.prefix(3).joined(separator: ", ")
                let suffix = question.options.count > 3 ? "…" : ""
                parts.append("Options: \(preview)\(suffix)")
            }
        default:
            break
        }

        if question.validationRules?.allowsEmpty == true {
            parts.append("Optional")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func formattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func selectComposerResponseType(_ type: ResponseType) {
        if composerDraft.responseType != type {
            showAdvancedResponseTypes = advancedResponseTypes.contains(type)
            composerDraft.responseType = type
            applyDefaults(for: type, resetOptions: true)
        }
    }

    private func applyDefaults(for type: ResponseType, resetOptions: Bool) {
        switch type {
        case .numeric, .slider:
            composerDraft.validationRules = ValidationRules(
                minimumValue: 0, maximumValue: 100, allowsEmpty: composerAllowsEmpty)
        case .waterIntake:
            composerDraft.validationRules = ValidationRules(
                minimumValue: 0, maximumValue: 128, allowsEmpty: composerAllowsEmpty)
        case .scale:
            composerDraft.validationRules = ValidationRules(
                minimumValue: 1, maximumValue: 5, allowsEmpty: composerAllowsEmpty)
        case .multipleChoice:
            if resetOptions {
                composerDraft.options = []
            }
            updateComposerAllowsEmpty(false)
        case .boolean, .text, .time:
            composerDraft.validationRules = ValidationRules(allowsEmpty: composerAllowsEmpty)
        }
        if resetOptions {
            newOptionText = ""
        }
    }

    private func applyRangePreset(_ preset: RangePreset) {
        composerDraft.validationRules =
            composerDraft.validationRules ?? ValidationRules(allowsEmpty: false)
        composerDraft.validationRules?.minimumValue = preset.minimum
        composerDraft.validationRules?.maximumValue = preset.maximum
    }

    private func isPresetActive(_ preset: RangePreset) -> Bool {
        composerDraft.validationRules?.minimumValue == preset.minimum
            && composerDraft.validationRules?.maximumValue == preset.maximum
    }

    private var composerMinimumValue: Double {
        composerDraft.validationRules?.minimumValue ?? 0
    }

    private var composerMaximumValue: Double {
        composerDraft.validationRules?.maximumValue ?? 100
    }

    private func updateComposerMinimum(_ value: Double) {
        composerDraft.validationRules =
            composerDraft.validationRules ?? ValidationRules(allowsEmpty: composerAllowsEmpty)
        composerDraft.validationRules?.minimumValue = min(value, composerMaximumValue)
    }

    private func updateComposerMaximum(_ value: Double) {
        composerDraft.validationRules =
            composerDraft.validationRules ?? ValidationRules(allowsEmpty: composerAllowsEmpty)
        composerDraft.validationRules?.maximumValue = max(value, composerMinimumValue)
    }

    private var composerAllowsEmpty: Bool {
        composerDraft.validationRules?.allowsEmpty ?? false
    }

    private func updateComposerAllowsEmpty(_ value: Bool) {
        composerDraft.validationRules =
            composerDraft.validationRules ?? ValidationRules(allowsEmpty: value)
        composerDraft.validationRules?.allowsEmpty = value
    }

    private var canSaveQuestion: Bool {
        !composerDraft.trimmedText.isEmpty && (!requiresOptions || !composerDraft.options.isEmpty)
            && (!requiresRange || composerMinimumValue <= composerMaximumValue)
    }

    private var composerHasContent: Bool {
        !composerDraft.trimmedText.isEmpty || !composerDraft.options.isEmpty
            || editingQuestionID != nil
    }

    private var requiresOptions: Bool {
        composerDraft.responseType == .multipleChoice
    }

    private var requiresRange: Bool {
        switch composerDraft.responseType {
        case .numeric, .scale, .slider, .waterIntake:
            return true
        default:
            return false
        }
    }

    private func appendCurrentOption() {
        let trimmed = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = trimmed.lowercased()
        if !composerDraft.options.contains(where: { $0.lowercased() == key }) {
            composerDraft.options.append(trimmed)
        }
        newOptionText = ""
        focusedField = .questionOption
    }

    private func removeOption(_ option: String) {
        composerDraft.options.removeAll { $0.caseInsensitiveCompare(option) == .orderedSame }
    }

    private func saveQuestionDraft() {
        guard canSaveQuestion else {
            composerError = "Finish the prompt before saving."
            Haptics.warning()
            return
        }
        composerError = nil

        if let editingQuestionID {
            composerDraft.id = editingQuestionID
            viewModel.updateQuestion(composerDraft)
        } else {
            viewModel.addCustomQuestion(composerDraft)
        }
        Haptics.success()
        resetComposer()
    }

    private func beginEditing(_ question: GoalQuestionDraft) {
        editingQuestionID = question.id
        composerDraft = question
        showAdvancedResponseTypes = advancedResponseTypes.contains(question.responseType)
        newOptionText = ""
        focusedField = .questionPrompt
    }

    private func resetComposer() {
        composerDraft = GoalQuestionDraft()
        editingQuestionID = nil
        composerError = nil
        newOptionText = ""
        focusedField = .questionPrompt
    }

    private func moveQuestion(from index: Int, direction: Int) {
        let destination = max(0, min(viewModel.draft.questionDrafts.count, index + direction))
        guard destination != index else { return }
        viewModel.reorderQuestions(
            fromOffsets: IndexSet(integer: index),
            toOffset: destination > index ? destination + 1 : destination)
        Haptics.selection()
    }

    private var selectedCadenceTag: String {
        let cadence = viewModel.draft.schedule.cadence
        if case .weekly = cadence {
            return viewModel.cadencePresets().first(where: { preset in
                if case .weekly = preset.cadence { return true }
                return false
            })?.id ?? viewModel.cadencePresets().first?.id ?? ""
        }
        return viewModel.cadencePresets().first(where: { preset in
            cadencesEqual(preset.cadence, cadence)
        })?.id ?? viewModel.cadencePresets().first?.id ?? ""
    }

    private func updateCadence(with tag: String) {
        guard let preset = viewModel.cadencePresets().first(where: { $0.id == tag }) else { return }
        viewModel.selectCadence(preset.cadence)
        Haptics.selection()
    }

    private func cadencesEqual(_ lhs: GoalCadence, _ rhs: GoalCadence) -> Bool {
        switch (lhs, rhs) {
        case (.daily, .daily), (.weekdays, .weekdays):
            return true
        case (.weekly(let a), .weekly(let b)):
            return a == b
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }

    private func moveForward() {
        if step.isFinal {
            handleSave()
            return
        }

        if let next = step.next(), canAdvance(step) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                step = next
            }
            Haptics.selection()
        }
    }

    private func moveBackward() {
        guard let previous = step.previous() else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            step = previous
        }
        Haptics.selection()
    }

    private func canAdvance(_ step: FlowStep) -> Bool {
        switch step {
        case .intent:
            return viewModel.canAdvanceFromDetails()
        case .prompts:
            return viewModel.canAdvanceFromQuestions()
        case .rhythm:
            return viewModel.canAdvanceFromSchedule()
        case .commitment, .review:
            return true
        }
    }

    private func forwardHint(for step: FlowStep) -> String? {
        guard !canAdvance(step) else { return nil }
        switch step {
        case .intent:
            if !hasGoalTitle {
                return "Add a goal title to continue."
            }
            if !hasCategory {
                return hasCustomCategory
                    ? "Name your custom focus area." : "Pick a focus area to continue."
            }
            return "Complete the checklist above before moving on."
        case .prompts:
            return "Add at least one question to continue."
        case .rhythm:
            return "Add at least one reminder time to continue."
        case .commitment, .review:
            return nil
        }
    }

    private func handleSave() {
        do {
            let goal = try viewModel.saveGoal()
            Haptics.success()
            NotificationScheduler.shared.scheduleNotifications(for: goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            Haptics.error()
        }
    }

    private func updateFocus(for step: FlowStep) {
        switch step {
        case .intent:
            focusedField = .title
        case .prompts:
            focusedField = .questionPrompt
        case .commitment:
            focusedField = .celebration
        default:
            focusedField = nil
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.title },
            set: { viewModel.updateTitle($0) }
        )
    }

    private var motivationBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.motivation },
            set: { viewModel.updateMotivation($0) }
        )
    }

    @ViewBuilder
    private var aiSuggestionsSection: some View {
        if let message = viewModel.suggestionAvailabilityMessage {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Smart suggestions")
                        .font(AppTheme.Typography.sectionHeader)
                    Text(message)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if viewModel.supportsSuggestions {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Generate with Apple Intelligence")
                                .font(AppTheme.Typography.sectionHeader)
                            if let provider = viewModel.suggestionProviderName {
                                Text(provider)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Get tailored questions based on your goal context.")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.isLoadingSuggestions {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }

                    Group {
                        if designStyle == .brutalist {
                            Button {
                                Haptics.selection()
                                let forceRegeneration = !viewModel.suggestions.isEmpty
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    viewModel.loadSuggestions(force: forceRegeneration)
                                }
                            } label: {
                                Label(
                                    viewModel.suggestions.isEmpty
                                        ? "Generate suggestions" : "Regenerate suggestions",
                                    systemImage: "sparkles"
                                )
                                .font(AppTheme.BrutalistTypography.bodyBold)
                                .textCase(.uppercase)
                            }
                            .brutalistButton(style: .primary)
                        } else {
                            Button {
                                Haptics.selection()
                                let forceRegeneration = !viewModel.suggestions.isEmpty
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    viewModel.loadSuggestions(force: forceRegeneration)
                                }
                            } label: {
                                Label(
                                    viewModel.suggestions.isEmpty
                                        ? "Generate suggestions" : "Regenerate suggestions",
                                    systemImage: "sparkles"
                                )
                                .font(AppTheme.Typography.bodyStrong)
                            }
                            .buttonStyle(.primaryProminent)
                        }
                    }
                    .disabled(viewModel.isLoadingSuggestions)

                    if let error = viewModel.suggestionError, !error.isEmpty {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.red)
                    } else if viewModel.suggestions.isEmpty && !viewModel.isLoadingSuggestions {
                        Text(
                            "Add a goal title or description, then generate suggestions to jump-start tracking questions."
                        )
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    }

                    if !viewModel.suggestions.isEmpty {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(viewModel.suggestions) { suggestion in
                                AISuggestionCard(suggestion: suggestion) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                        viewModel.applySuggestion(suggestion)
                                    }
                                    Haptics.success()
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: PromptTemplate
    let isApplied: Bool
    let action: () -> Void
    @Environment(\.designStyle) private var designStyle

    var body: some View {
        Button(action: action) {
            HStack(
                alignment: .top,
                spacing: designStyle == .brutalist
                    ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md
            ) {
                Image(systemName: template.iconName)
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.headline : .title2.weight(.semibold)
                    )
                    .foregroundStyle(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistPalette.accent : AppTheme.Palette.primary
                    )
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(template.title)
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.bodyBold
                                : AppTheme.Typography.bodyStrong
                        )
                    Text(template.subtitle)
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                        )
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistPalette.secondary : Color.secondary
                        )
                }

                Spacer()

                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistPalette.accent : AppTheme.Palette.primary
                        )
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.headline : .title2)
                }
            }
            .padding(designStyle == .brutalist ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md)
            .background(
                designStyle == .brutalist
                    ? AppTheme.BrutalistPalette.background
                    : AppTheme.Palette.surface
            )
            .overlay(
                Group {
                    if designStyle == .brutalist {
                        Rectangle()
                            .stroke(
                                isApplied
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.border,
                                lineWidth: AppTheme.BrutalistBorder.standard
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Palette.neutralBorder, lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplied)
        .opacity(isApplied ? 0.6 : 1)
    }
}

private struct AISuggestionCard: View {
    let suggestion: GoalSuggestion
    let action: () -> Void
    @Environment(\.designStyle) private var designStyle

    var body: some View {
        Button(action: action) {
            VStack(
                alignment: .leading,
                spacing: designStyle == .brutalist
                    ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
            ) {
                Text(suggestion.prompt)
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.bodyBold : AppTheme.Typography.bodyStrong
                    )
                    .multilineTextAlignment(.leading)

                HStack(
                    spacing: designStyle == .brutalist
                        ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
                ) {
                    responseTypeBadge
                    if !suggestion.options.isEmpty {
                        Text(optionSummary)
                            .font(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistTypography.caption
                                    : AppTheme.Typography.caption
                            )
                            .foregroundStyle(
                                designStyle == .brutalist
                                    ? AppTheme.BrutalistPalette.secondary : Color.secondary
                            )
                    }
                }

                if !suggestion.options.isEmpty {
                    Text("Options: \(suggestion.options.joined(separator: ", "))")
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                        )
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistPalette.secondary : Color.secondary
                        )
                }

                if let rationale = suggestion.rationale, !rationale.isEmpty {
                    Text(rationale)
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                        )
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistPalette.secondary : Color.secondary
                        )
                }

                HStack(
                    spacing: designStyle == .brutalist
                        ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
                ) {
                    Label("Add to goal", systemImage: "plus.circle.fill")
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                        )
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                        )
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistPalette.secondary : Color.secondary
                        )
                }
            }
            .padding(designStyle == .brutalist ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                designStyle == .brutalist
                    ? AppTheme.BrutalistPalette.background
                    : AppTheme.Palette.surface
            )
            .overlay(
                Group {
                    if designStyle == .brutalist {
                        Rectangle()
                            .stroke(
                                AppTheme.BrutalistPalette.border,
                                lineWidth: AppTheme.BrutalistBorder.standard)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Palette.neutralBorder, lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Adds this suggested question to your goal")
    }

    private var responseTypeBadge: some View {
        Text(suggestion.responseType.displayName)
            .font(
                designStyle == .brutalist
                    ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
            )
            .fontWeight(.semibold)
            .padding(
                .horizontal,
                designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
            )
            .padding(
                .vertical,
                designStyle == .brutalist ? AppTheme.BrutalistSpacing.xs : AppTheme.Spacing.xs
            )
            .background(
                designStyle == .brutalist
                    ? AppTheme.BrutalistPalette.background
                    : AppTheme.Palette.primary.opacity(0.12)
            )
            .overlay(
                Group {
                    if designStyle == .brutalist {
                        Rectangle()
                            .stroke(
                                AppTheme.BrutalistPalette.accent,
                                lineWidth: AppTheme.BrutalistBorder.standard)
                    } else {
                        Capsule(style: .continuous)
                            .stroke(AppTheme.Palette.primary, lineWidth: 1)
                    }
                }
            )
            .foregroundStyle(
                designStyle == .brutalist
                    ? AppTheme.BrutalistPalette.accent : AppTheme.Palette.primary
            )
    }

    private var optionSummary: String {
        suggestion.options.count == 1 ? "1 option" : "\(suggestion.options.count) options"
    }
}

struct ConflictBanner: View {
    let message: String
    @Environment(\.designStyle) private var designStyle

    var body: some View {
        HStack(
            spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
        ) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(
                    designStyle == .brutalist
                        ? AppTheme.BrutalistPalette.accent : Color.orange
                )
            Text(message)
                .font(
                    designStyle == .brutalist
                        ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                )
        }
        .padding(designStyle == .brutalist ? AppTheme.BrutalistSpacing.md : AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            designStyle == .brutalist
                ? AppTheme.BrutalistPalette.background
                : Color.orange.opacity(0.12)
        )
        .overlay(
            Group {
                if designStyle == .brutalist {
                    Rectangle()
                        .stroke(
                            AppTheme.BrutalistPalette.accent,
                            lineWidth: AppTheme.BrutalistBorder.standard)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                }
            }
        )
        .padding(
            .horizontal,
            designStyle == .brutalist ? AppTheme.BrutalistSpacing.xl : AppTheme.Spacing.xl)
    }
}

struct WeekdaySelector: View {
    @Binding var selectedWeekdays: Set<Weekday>
    @Environment(\.designStyle) private var designStyle

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm), count: 4),
            spacing: AppTheme.Spacing.sm
        ) {
            ForEach(Weekday.allCases) { weekday in
                let isSelected = selectedWeekdays.contains(weekday)
                Button {
                    if isSelected {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                    Haptics.selection()
                } label: {
                    Text(weekday.shortDisplayName)
                        .font(
                            designStyle == .brutalist
                                ? AppTheme.BrutalistTypography.caption : AppTheme.Typography.caption
                        )
                        .fontWeight(.semibold)
                        .padding(
                            .vertical,
                            designStyle == .brutalist
                                ? AppTheme.BrutalistSpacing.sm : AppTheme.Spacing.sm
                        )
                        .frame(maxWidth: .infinity)
                        .background(
                            designStyle == .brutalist
                                ? (isSelected
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.background)
                                : AppTheme.Palette.surface
                        )
                        .overlay(
                            Group {
                                if designStyle == .brutalist {
                                    Rectangle()
                                        .stroke(
                                            isSelected
                                                ? AppTheme.BrutalistPalette.border
                                                : AppTheme.BrutalistPalette.border.opacity(0.6),
                                            lineWidth: AppTheme.BrutalistBorder.standard
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            AppTheme.Palette.outline, lineWidth: isSelected ? 0 : 1)
                                }
                            }
                        )
                        .foregroundStyle(
                            designStyle == .brutalist
                                ? (isSelected
                                    ? AppTheme.BrutalistPalette.background
                                    : AppTheme.BrutalistPalette.foreground)
                                : (isSelected ? Color.white : .primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct IntervalPicker: View {
    @Binding var interval: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Every \(interval) days")
                .font(AppTheme.Typography.body)
            Stepper(value: $interval, in: 2...30, step: 1) {
                Text("Adjust interval")
            }
        }
    }
}

// MARK: - Quick Add Button Component

private struct QuickAddButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @Environment(\.designStyle) private var designStyle

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.BrutalistPalette.accent)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                }

                Text(title)
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundStyle(AppTheme.BrutalistPalette.foreground)

                Text(subtitle)
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundStyle(AppTheme.BrutalistPalette.secondary)
            }
            .padding(AppTheme.BrutalistSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .fill(AppTheme.BrutalistPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .stroke(AppTheme.BrutalistPalette.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Template Card Component

private struct CompactTemplateCard: View {
    let template: PromptTemplate
    let isApplied: Bool
    let action: () -> Void

    @Environment(\.designStyle) private var designStyle

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.BrutalistSpacing.md) {
                Image(systemName: template.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isApplied
                            ? AppTheme.BrutalistPalette.secondary : AppTheme.BrutalistPalette.accent
                    )
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.blueprint.text)
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundStyle(
                            isApplied
                                ? AppTheme.BrutalistPalette.secondary
                                : AppTheme.BrutalistPalette.foreground
                        )
                        .lineLimit(2)

                    Text(template.blueprint.responseType.displayName)
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundStyle(AppTheme.BrutalistPalette.secondary)
                }

                Spacer()

                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.BrutalistPalette.accent)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(AppTheme.BrutalistPalette.accent)
                        .font(.system(size: 20))
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .fill(
                        isApplied
                            ? AppTheme.BrutalistPalette.accent.opacity(0.05)
                            : AppTheme.BrutalistPalette.surface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .stroke(
                        isApplied
                            ? AppTheme.BrutalistPalette.accent.opacity(0.3)
                            : AppTheme.BrutalistPalette.border.opacity(0.5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplied)
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        let legacyViewModel = GoalCreationViewModel(modelContext: context)
        return GoalCreationView(viewModel: legacyViewModel)
            .modelContainer(container)
    } else {
        return Text("Preview unavailable")
    }
}

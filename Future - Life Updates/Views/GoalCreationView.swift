import SwiftUI
import SwiftData

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
    private let featuredCategories: [TrackingCategory] = [.fitness, .health, .productivity, .habits, .mood]
    private let primaryResponseTypes: [ResponseType] = [.boolean, .numeric, .scale, .text]
    private let advancedResponseTypes: [ResponseType] = [.multipleChoice, .slider, .time]
    private let rangePresets: [RangePreset] = [
        RangePreset(id: "0-10", label: "0 – 10", minimum: 0, maximum: 10),
        RangePreset(id: "1-5", label: "1 – 5", minimum: 1, maximum: 5),
        RangePreset(id: "1-10", label: "1 – 10", minimum: 1, maximum: 10)
    ]
    private let chipColumns = [GridItem(.adaptive(minimum: 140), spacing: AppTheme.Spacing.sm)]

    @Environment(\.dismiss) private var dismiss

    @State private var step: FlowStep = .intent
    @State private var composerDraft = GoalQuestionDraft()
    @State private var editingQuestionID: UUID?
    @State private var composerError: String?
    @State private var newOptionText: String = ""
    @State private var showAdvancedResponseTypes = false
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
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                        WizardStepHeader(
                            title: step.title,
                            subtitle: step.subtitle,
                            stepIndex: step.rawValue,
                            totalSteps: FlowStep.allCases.count
                        )
                        .accessibilityIdentifier("wizardStep-\(step.key)")

                        stepContent
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.bottom, AppTheme.Spacing.xl * 2)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .accessibilityIdentifier("goalCreationScroll")
            }
            .background(AppTheme.Palette.background.ignoresSafeArea())
            .navigationTitle("New Tracking Goal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
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
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.lg)
                    .background(.thinMaterial)
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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    TextField("Name your goal", text: titleBinding)
                        .font(AppTheme.Typography.title)
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier("goalTitleField")

                    TextField(
                        "Why does this matter to you?",
                        text: motivationBinding,
                        axis: .vertical
                    )
                        .lineLimit(3, reservesSpace: true)
                        .font(AppTheme.Typography.body)
                        .focused($focusedField, equals: .motivation)
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Pick a focus area")
                        .font(AppTheme.Typography.sectionHeader)

                    LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ForEach(featuredCategories, id: \.self) { category in
                            categoryChip(for: category)
                        }

                        Button {
                            viewModel.selectCategory(.custom)
                            focusedField = .customCategory
                            Haptics.selection()
                        } label: {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text("Something else…")
                                    .font(AppTheme.Typography.bodyStrong)
                                Text("Name your own area.")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(AppTheme.Spacing.md)
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(AppTheme.Palette.primary.opacity(0.2), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(AppTheme.Palette.surface)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.draft.category == .custom {
                        TextField(
                            "Give it a name",
                            text: Binding(
                                get: { viewModel.draft.customCategoryLabel },
                                set: { viewModel.updateCustomCategoryLabel($0) }
                            )
                        )
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .customCategory)
                        #else
                        .focused($focusedField, equals: .customCategory)
                        #endif
                        .font(AppTheme.Typography.body)
                    }
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Step checklist")
                        .font(AppTheme.Typography.sectionHeader)
                    checklistRow(
                        title: "Add a goal title",
                        subtitle: "Required",
                        isComplete: hasGoalTitle,
                        isRequired: true
                    )
                    checklistRow(
                        title: "Pick a focus area",
                        subtitle: hasCustomCategory ? "Custom label required" : "Required",
                        isComplete: hasCategory,
                        isRequired: true
                    )
                    checklistRow(
                        title: "Share why this matters",
                        subtitle: "Optional, but boosts commitment",
                        isComplete: hasMotivation,
                        isRequired: false
                    )
                }
            }
        }
    }

    private var promptsStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            aiSuggestionsSection

            let suggested = viewModel.recommendedTemplates()
            if !suggested.isEmpty {
                CardBackground {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        Text("Suggested prompts")
                            .font(AppTheme.Typography.sectionHeader)
                        Text("Tap to add ready-made questions tailored to your goal.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(suggested) { template in
                                TemplateCard(
                                    template: template,
                                    isApplied: viewModel.appliedTemplateIDs.contains(template.id)
                                ) {
                                    viewModel.applyTemplate(template)
                                    Haptics.success()
                                }
                            }
                        }
                        let additional = viewModel.additionalTemplates(excluding: Set(suggested.map(\.id)))
                        if !additional.isEmpty {
                            DisclosureGroup("More ideas") {
                                VStack(spacing: AppTheme.Spacing.sm) {
                                    ForEach(additional) { template in
                                        TemplateCard(
                                            template: template,
                                            isApplied: viewModel.appliedTemplateIDs.contains(template.id)
                                        ) {
                                            viewModel.applyTemplate(template)
                                            Haptics.success()
                                        }
                                    }
                                }
                                .padding(.top, AppTheme.Spacing.sm)
                            }
                            .font(AppTheme.Typography.bodyStrong)
                        }
                    }
                }
            }

            CardBackground {
                questionComposer
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack {
                        statusPill(
                            message: viewModel.canAdvanceFromQuestions() ? "Questions ready" : "Add at least one question",
                            isComplete: viewModel.canAdvanceFromQuestions()
                        )
                        Spacer()
                        Text("\(viewModel.draft.questionDrafts.count) saved")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.draft.questionDrafts.isEmpty {
                        ContentUnavailableView(
                            "Add a question to start tracking",
                            systemImage: "text.badge.plus",
                            description: Text("Use a suggestion above or create your own prompt.")
                        )
                    } else {
                        LazyVStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(Array(viewModel.draft.questionDrafts.enumerated()), id: \.element.id) { index, question in
                                questionSummaryCard(for: question, index: index)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if focusedField == nil {
                focusedField = .questionPrompt
            }
            triggerSuggestionsIfNeeded()
        }
    }

    private var questionComposer: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(editingQuestionID == nil ? "Create your own prompt" : "Edit prompt")
                        .font(AppTheme.Typography.sectionHeader)
                    Text("Pick a response style and fine-tune the details.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if editingQuestionID != nil {
                    Button {
                        resetComposer()
                        Haptics.selection()
                    } label: {
                        Label("Cancel edit", systemImage: "xmark.circle.fill")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if composerHasContent {
                statusPill(
                    message: composerIsReady ? "Prompt ready to save" : "Finish configuring before saving",
                    isComplete: composerIsReady
                )
            }

            TextField(
                "What should Life Updates ask?",
                text: $composerDraft.text,
                axis: .vertical
            )
            .font(AppTheme.Typography.body)
            .focused($focusedField, equals: .questionPrompt)
            .lineLimit(2, reservesSpace: true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Response type")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    ForEach(primaryResponseTypes, id: \.self) { type in
                        responseTypeChip(for: type)
                    }
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            showAdvancedResponseTypes.toggle()
                        }
                        Haptics.selection()
                    } label: {
                        Label(
                            showAdvancedResponseTypes ? "Hide advanced" : "More types",
                            systemImage: showAdvancedResponseTypes ? "chevron.up" : "chevron.down"
                        )
                        .labelStyle(.titleAndIcon)
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule().fill(AppTheme.Palette.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if showAdvancedResponseTypes {
                    LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ForEach(advancedResponseTypes, id: \.self) { type in
                            responseTypeChip(for: type)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            configurationFields

            Toggle("Allow skipping this question", isOn: Binding(
                get: { composerAllowsEmpty },
                set: { updateComposerAllowsEmpty($0) }
            ))
            .toggleStyle(.switch)

            if let composerError {
                Text(composerError)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.red)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                if composerHasContent {
                    Button {
                        resetComposer()
                        Haptics.selection()
                    } label: {
                        Label("Clear", systemImage: "arrow.uturn.left")
                            .font(AppTheme.Typography.bodyStrong)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Palette.neutralSubdued)
                }

                Spacer()

                Button(editingQuestionID == nil ? "Add question" : "Update question") {
                    saveQuestionDraft()
                }
                .buttonStyle(.primaryProminent)
                .disabled(!canSaveQuestion)
            }
        }
    }

    @ViewBuilder
    private var configurationFields: some View {
        switch composerDraft.responseType {
        case .numeric, .scale, .slider:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Range presets")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    ForEach(rangePresets) { preset in
                        Button {
                            applyRangePreset(preset)
                            Haptics.selection()
                        } label: {
                            Text(preset.label)
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(isPresetActive(preset) ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isPresetActive(preset) ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder, lineWidth: isPresetActive(preset) ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isPresetActive(preset) ? AppTheme.Palette.primary : .primary)
                    }
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Minimum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: Binding(
                            get: { composerMinimumValue },
                            set: { updateComposerMinimum($0) }
                        ), in: -1000...composerMaximumValue, step: 1) {
                            Text(formattedValue(composerMinimumValue))
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Maximum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: Binding(
                            get: { composerMaximumValue },
                            set: { updateComposerMaximum($0) }
                        ), in: composerMinimumValue...1000, step: 1) {
                            Text(formattedValue(composerMaximumValue))
                        }
                    }
                }
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if !composerDraft.options.isEmpty {
                    LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ForEach(composerDraft.options, id: \.self) { option in
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Text(option)
                                    .font(AppTheme.Typography.caption.weight(.semibold))
                                Button {
                                    removeOption(option)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.xs)
                            .background(
                                Capsule().fill(AppTheme.Palette.surfaceElevated)
                            )
                        }
                    }
                }

                HStack {
                    TextField("Add option", text: $newOptionText)
                        .focused($focusedField, equals: .questionOption)
                    Button("Add") {
                        appendCurrentOption()
                    }
                    .buttonStyle(.secondaryProminent)
                    .disabled(newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        case .text:
            Text("Open-ended responses let people share notes or reflections.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
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

                    Picker("Frequency", selection: Binding(
                        get: { selectedCadenceTag },
                        set: { updateCadence(with: $0) }
                    )) {
                        ForEach(viewModel.cadencePresets()) { preset in
                            Text(preset.title).tag(preset.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch viewModel.draft.schedule.cadence {
                    case .weekly(let weekday):
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(Weekday.allCases) { day in
                                    Button {
                                        viewModel.selectCadence(.weekly(day))
                                        Haptics.selection()
                                    } label: {
                                        Text(day.shortDisplayName)
                                            .font(AppTheme.Typography.caption.weight(.semibold))
                                            .padding(.horizontal, AppTheme.Spacing.md)
                                            .padding(.vertical, AppTheme.Spacing.sm)
                                            .background(
                                                Capsule().fill(day == weekday ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(day == weekday ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder, lineWidth: day == weekday ? 2 : 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(day == weekday ? AppTheme.Palette.primary : .primary)
                                }
                            }
                        }
                    case .custom(let interval):
                        Stepper(value: Binding(
                            get: { interval },
                            set: { viewModel.updateCustomInterval(days: $0) }
                        ), in: 2...30) {
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
                            Text("\(viewModel.draft.schedule.reminderTimes.count)/\(maxReminderCount)")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    statusPill(
                        message: viewModel.canAdvanceFromSchedule() ? "Reminders ready" : "Add at least one reminder",
                        isComplete: viewModel.canAdvanceFromSchedule()
                    )

                    let recommended = viewModel.recommendedReminderTimes()
                    if !recommended.isEmpty {
                        LazyVGrid(columns: chipColumns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            ForEach(recommended, id: \.self) { time in
                                Button {
                                    let succeeded = viewModel.toggleReminderTime(time)
                                    if succeeded {
                                        scheduleError = nil
                                        Haptics.selection()
                                    } else {
                                        scheduleError = "Reminders need to be at least five minutes apart or fewer than \(maxReminderCount)."
                                        Haptics.warning()
                                    }
                                } label: {
                                    Text(time.formattedTime(in: viewModel.draft.schedule.timezone))
                                        .font(AppTheme.Typography.caption.weight(.semibold))
                                        .padding(.horizontal, AppTheme.Spacing.md)
                                        .padding(.vertical, AppTheme.Spacing.sm)
                                        .background(
                                            Capsule().fill(viewModel.draft.schedule.reminderTimes.contains(time) ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(viewModel.draft.schedule.reminderTimes.contains(time) ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder, lineWidth: viewModel.draft.schedule.reminderTimes.contains(time) ? 2 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(viewModel.draft.schedule.reminderTimes.contains(time) ? AppTheme.Palette.primary : .primary)
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

                    Button {
                        showCustomTimeSheet = true
                        customReminderDate = viewModel.suggestedReminderDate(startingAt: customReminderDate)
                        Haptics.selection()
                    } label: {
                        Label("Custom time…", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.secondaryProminent)

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
                        Picker("Timezone", selection: Binding(
                            get: { viewModel.draft.schedule.timezone },
                            set: { timezone in
                                viewModel.updateTimezone(timezone)
                                Haptics.selection()
                            }
                        )) {
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
                Text("Add an optional encouragement or celebration message we'll surface when you log progress.")
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
                        Text(category == .custom ? (viewModel.draft.normalizedCustomCategoryLabel ?? category.displayName) : category.displayName)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !viewModel.draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(viewModel.draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, AppTheme.Spacing.sm)
                    }
                    if !viewModel.draft.celebrationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Encouragement: \(viewModel.draft.celebrationMessage.trimmingCharacters(in: .whitespacesAndNewlines))")
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
                                        sourceBadge(label: "Template", systemImage: "text.book.closed", tint: Color.secondary)
                                    }
                                    if question.suggestionID != nil {
                                        sourceBadge(label: "AI suggestion", systemImage: "sparkles", tint: AppTheme.Palette.primary)
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

                Text("Times are saved in \(viewModel.draft.schedule.timezone.localizedDisplayName()).")
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
                            customReminderDate = viewModel.suggestedReminderDate(startingAt: customReminderDate.addingTimeInterval(30 * 60))
                            Haptics.success()
                        } else {
                            scheduleError = "Reminders need to be at least five minutes apart or fewer than \(maxReminderCount)."
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
        return Button {
            viewModel.selectCategory(category)
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(category.displayName)
                    .font(AppTheme.Typography.bodyStrong)
                Text(categorySubtitle(for: category))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AppTheme.Palette.primary : .primary)
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

    private func responseTypeChip(for type: ResponseType) -> some View {
        Button {
            selectComposerResponseType(type)
            Haptics.selection()
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: iconName(for: type))
                    .font(.caption.weight(.semibold))
                Text(type.displayName)
                    .font(AppTheme.Typography.caption.weight(.semibold))
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                Capsule()
                    .fill(composerDraft.responseType == type ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
            )
            .overlay(
                Capsule()
                    .stroke(composerDraft.responseType == type ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder, lineWidth: composerDraft.responseType == type ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(composerDraft.responseType == type ? AppTheme.Palette.primary : .primary)
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
        .font(AppTheme.Typography.caption.weight(.semibold))
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(isComplete ? AppTheme.Palette.primary.opacity(0.12) : Color.orange.opacity(0.12))
        )
        .foregroundStyle(isComplete ? AppTheme.Palette.primary : Color.orange)
        .accessibilityLabel(message)
    }

    @ViewBuilder
    private func checklistRow(
        title: String,
        subtitle: String,
        isComplete: Bool,
        isRequired: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
            Image(systemName: iconNameForChecklist(isComplete: isComplete, isRequired: isRequired))
                .font(.title3.weight(.semibold))
                .foregroundStyle(colorForChecklist(isComplete: isComplete, isRequired: isRequired))
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.bodyStrong)
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private func questionIsComplete(_ question: GoalQuestionDraft) -> Bool {
        guard question.hasContent else { return false }
        switch question.responseType {
        case .multipleChoice:
            return !question.options.isEmpty
        case .numeric, .scale, .slider:
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
        let trimmedDescription = viewModel.draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedDescription.isEmpty else { return }
        viewModel.loadSuggestions(force: force)
    }

    private func sourceBadge(label: String, systemImage: String, tint: Color) -> some View {
        Label(label, systemImage: systemImage)
            .font(AppTheme.Typography.caption.weight(.semibold))
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    private func questionSummaryCard(for question: GoalQuestionDraft, index: Int) -> some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: questionIsComplete(question) ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(questionIsComplete(question) ? AppTheme.Palette.primary : Color.orange)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(question.trimmedText)
                            .font(AppTheme.Typography.body.weight(.semibold))
                        Text(question.responseType.displayName)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        if question.templateID != nil || question.suggestionID != nil {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                if question.templateID != nil {
                                    sourceBadge(label: "Template", systemImage: "text.book.closed", tint: Color.secondary)
                                }
                                if question.suggestionID != nil {
                                    sourceBadge(label: "AI suggestion", systemImage: "sparkles", tint: AppTheme.Palette.primary)
                                }
                            }
                        }
                        if let detail = detail(for: question) {
                            Text(detail)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
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
        if isComplete { return .green }
        return isRequired ? Color.orange : .secondary
    }

    private func detail(for question: GoalQuestionDraft) -> String? {
        var parts: [String] = []
        switch question.responseType {
        case .numeric, .scale, .slider:
            if let min = question.validationRules?.minimumValue, let max = question.validationRules?.maximumValue {
                parts.append("Range: \(formattedValue(min)) – \(formattedValue(max))")
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
            composerDraft.validationRules = ValidationRules(minimumValue: 0, maximumValue: 100, allowsEmpty: composerAllowsEmpty)
        case .scale:
            composerDraft.validationRules = ValidationRules(minimumValue: 1, maximumValue: 5, allowsEmpty: composerAllowsEmpty)
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
        composerDraft.validationRules = composerDraft.validationRules ?? ValidationRules(allowsEmpty: false)
        composerDraft.validationRules?.minimumValue = preset.minimum
        composerDraft.validationRules?.maximumValue = preset.maximum
    }

    private func isPresetActive(_ preset: RangePreset) -> Bool {
        composerDraft.validationRules?.minimumValue == preset.minimum &&
        composerDraft.validationRules?.maximumValue == preset.maximum
    }

    private var composerMinimumValue: Double {
        composerDraft.validationRules?.minimumValue ?? 0
    }

    private var composerMaximumValue: Double {
        composerDraft.validationRules?.maximumValue ?? 100
    }

    private func updateComposerMinimum(_ value: Double) {
        composerDraft.validationRules = composerDraft.validationRules ?? ValidationRules(allowsEmpty: composerAllowsEmpty)
        composerDraft.validationRules?.minimumValue = min(value, composerMaximumValue)
    }

    private func updateComposerMaximum(_ value: Double) {
        composerDraft.validationRules = composerDraft.validationRules ?? ValidationRules(allowsEmpty: composerAllowsEmpty)
        composerDraft.validationRules?.maximumValue = max(value, composerMinimumValue)
    }

    private var composerAllowsEmpty: Bool {
        composerDraft.validationRules?.allowsEmpty ?? false
    }

    private func updateComposerAllowsEmpty(_ value: Bool) {
        composerDraft.validationRules = composerDraft.validationRules ?? ValidationRules(allowsEmpty: value)
        composerDraft.validationRules?.allowsEmpty = value
    }

    private var canSaveQuestion: Bool {
        !composerDraft.trimmedText.isEmpty && (!requiresOptions || !composerDraft.options.isEmpty) && (!requiresRange || composerMinimumValue <= composerMaximumValue)
    }

    private var composerHasContent: Bool {
        !composerDraft.trimmedText.isEmpty || !composerDraft.options.isEmpty || editingQuestionID != nil
    }

    private var requiresOptions: Bool {
        composerDraft.responseType == .multipleChoice
    }

    private var requiresRange: Bool {
        switch composerDraft.responseType {
        case .numeric, .scale, .slider:
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
        viewModel.reorderQuestions(fromOffsets: IndexSet(integer: index), toOffset: destination > index ? destination + 1 : destination)
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
                return hasCustomCategory ? "Name your custom focus area." : "Pick a focus area to continue."
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

                    Button {
                        Haptics.selection()
                        let forceRegeneration = !viewModel.suggestions.isEmpty
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            viewModel.loadSuggestions(force: forceRegeneration)
                        }
                    } label: {
                        Label(
                            viewModel.suggestions.isEmpty ? "Generate suggestions" : "Regenerate suggestions",
                            systemImage: "sparkles"
                        )
                        .font(AppTheme.Typography.bodyStrong)
                    }
                    .buttonStyle(.primaryProminent)
                    .disabled(viewModel.isLoadingSuggestions)

                    if let error = viewModel.suggestionError, !error.isEmpty {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color.red)
                    } else if viewModel.suggestions.isEmpty && !viewModel.isLoadingSuggestions {
                        Text("Add a goal title or description, then generate suggestions to jump-start tracking questions.")
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

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: template.iconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.primary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(template.title)
                        .font(AppTheme.Typography.bodyStrong)
                    Text(template.subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Palette.primary)
                        .font(.title2)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Palette.surface)
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

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(suggestion.prompt)
                    .font(AppTheme.Typography.bodyStrong)
                    .multilineTextAlignment(.leading)

                HStack(spacing: AppTheme.Spacing.sm) {
                    responseTypeBadge
                    if !suggestion.options.isEmpty {
                        Text(optionSummary)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !suggestion.options.isEmpty {
                    Text("Options: \(suggestion.options.joined(separator: ", "))")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                if let rationale = suggestion.rationale, !rationale.isEmpty {
                    Text(rationale)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppTheme.Spacing.xs) {
                    Label("Add to goal", systemImage: "plus.circle.fill")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Palette.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Adds this suggested question to your goal")
    }

    private var responseTypeBadge: some View {
        Text(suggestion.responseType.displayName)
            .font(AppTheme.Typography.caption.weight(.semibold))
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.Palette.primary.opacity(0.12))
            )
            .foregroundStyle(AppTheme.Palette.primary)
    }

    private var optionSummary: String {
        suggestion.options.count == 1 ? "1 option" : "\(suggestion.options.count) options"
    }
}

struct ConflictBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(message)
                .font(AppTheme.Typography.caption)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .padding(.horizontal, AppTheme.Spacing.xl)
    }
}

struct WeekdaySelector: View {
    @Binding var selectedWeekdays: Set<Weekday>

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm), count: 4), spacing: AppTheme.Spacing.sm) {
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
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? AppTheme.Palette.primary : AppTheme.Palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.Palette.outline, lineWidth: isSelected ? 0 : 1)
                                )
                        )
                        .foregroundStyle(isSelected ? Color.white : .primary)
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

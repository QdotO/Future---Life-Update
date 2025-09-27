import SwiftUI
import SwiftData

struct GoalCreationView: View {
    private enum Step: Int, CaseIterable, Identifiable {
        case details
        case questions
        case schedule
        case review

        var id: Int { rawValue }

        var key: String {
            switch self {
            case .details: return "details"
            case .questions: return "questions"
            case .schedule: return "schedule"
            case .review: return "review"
            }
        }

        var title: String {
            switch self {
            case .details: return "Goal basics"
            case .questions: return "Questions to track"
            case .schedule: return "Reminder schedule"
            case .review: return "Review & create"
            }
        }

        var subtitle: String {
            switch self {
            case .details: return "Name your goal and give it context."
            case .questions: return "Add the prompts you want to answer."
            case .schedule: return "Choose when Life Updates should nudge you."
            case .review: return "Double-check everything before saving."
            }
        }

        var isFinal: Bool { self == .review }

        func next() -> Step? {
            Step(rawValue: rawValue + 1)
        }

        func previous() -> Step? {
            Step(rawValue: rawValue - 1)
        }
    }

    private enum DetailsField: Hashable {
        case title
        case description
    }

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .details
    @State private var composerQuestionText: String = ""
    @State private var composerSelectedType: ResponseType?
    @State private var composerMinimumValue: Double = 0
    @State private var composerMaximumValue: Double = 100
    @State private var composerAllowsEmpty: Bool = false
    @State private var composerOptionsText: String = ""
    @State private var composerEditingID: UUID?
    @State private var composerErrorMessage: String?
    @State private var newReminderTime: Date
    @State private var conflictMessage: String?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @FocusState private var activeDetailsField: DetailsField?
    @FocusState private var isComposerQuestionFocused: Bool

    @Bindable private var viewModel: GoalCreationViewModel

    init(viewModel: GoalCreationViewModel) {
        self._viewModel = Bindable(viewModel)
        self._newReminderTime = State(initialValue: viewModel.suggestedReminderDate())
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
                            totalSteps: Step.allCases.count
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if conflictMessage != nil || !shouldHideWizardNavigation {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        if let conflictMessage {
                            ConflictBanner(message: conflictMessage)
                        }
                        if !shouldHideWizardNavigation {
                            WizardNavigationButtons(
                                canGoBack: step.previous() != nil,
                                isFinalStep: step.isFinal,
                                isForwardEnabled: canAdvance(step),
                                onBack: moveBackward,
                                onNext: moveForward
                            )
                            .padding(.horizontal, AppTheme.Spacing.xl)
                            .padding(.vertical, AppTheme.Spacing.lg)
                            .background(.thinMaterial)
                        }
                    }
                }
            }
            .alert("Unable to Create Goal", isPresented: $showingErrorAlert, actions: {
                Button("OK", role: .cancel) {
                    showingErrorAlert = false
                }
            }, message: {
                Text(errorMessage ?? "")
            })
            .onChange(of: step) { newStep in
                switch newStep {
                case .questions:
                    DispatchQueue.main.async {
                        isComposerQuestionFocused = true
                    }
                case .schedule:
                    isComposerQuestionFocused = false
                    if viewModel.scheduleDraft.times.isEmpty {
                        newReminderTime = viewModel.suggestedReminderDate(startingAt: newReminderTime)
                    }
                default:
                    isComposerQuestionFocused = false
                }
            }
            .onChange(of: viewModel.scheduleDraft.times) { times in
                if step == .schedule, times.isEmpty {
                    newReminderTime = viewModel.suggestedReminderDate(startingAt: newReminderTime)
                }
            }
            .onChange(of: viewModel.scheduleDraft.timezone) { _ in
                if step == .schedule, viewModel.scheduleDraft.times.isEmpty {
                    newReminderTime = viewModel.suggestedReminderDate(startingAt: newReminderTime)
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .details:
            detailsStep
        case .questions:
            questionsStep
        case .schedule:
            scheduleStep
        case .review:
            reviewStep
        }
    }

    private var detailsStep: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                TextField("Goal title", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                    .font(AppTheme.Typography.title)
                    .focused($activeDetailsField, equals: .title)
                    .accessibilityIdentifier("goalTitleField")

                TextField("What are you tracking?", text: $viewModel.goalDescription, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .font(AppTheme.Typography.body)
                    .focused($activeDetailsField, equals: .description)

                CategoryPickerView(
                    title: "Category",
                    primaryOptions: viewModel.primaryCategoryOptions,
                    overflowOptions: viewModel.overflowCategoryOptions,
                    selectedCategory: $viewModel.selectedCategory,
                    customCategoryLabel: $viewModel.customCategoryLabel,
                    onSelectOption: { option in
                        viewModel.selectCategory(option)
                    },
                    onUpdateCustomLabel: { label in
                        viewModel.updateCustomCategoryLabel(label)
                    }
                )
            }
        }
        .onAppear {
            if step == .details,
               viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeDetailsField = .title
            }
        }
    }

    private var questionsStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("What would you like to track?")
                    .font(AppTheme.Typography.sectionHeader)
                Text("Add prompts so the app knows what to ask when it reminds you.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.secondary)
            }

            CardBackground {
                questionComposerCard
            }
            .padding(.bottom, AppTheme.Spacing.sm)

            if viewModel.hasDraftQuestions {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Questions ready (\(viewModel.draftQuestions.count))")
                        .font(AppTheme.Typography.sectionHeader)
                    LazyVStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(viewModel.draftQuestions, id: \.id) { question in
                            questionSummaryCard(for: question)
                        }
                    }
                }
            }
        }
    }

    private var questionComposerCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(composerEditingID == nil ? "Add a question" : "Edit question")
                        .font(AppTheme.Typography.sectionHeader)
                    Text("Fill in the prompt and the responses people will give.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if composerEditingID != nil {
                    Button {
                        resetComposer()
                    } label: {
                        Label("Cancel edit", systemImage: "xmark.circle.fill")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel editing question")
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                TextField("Ask a question to track", text: $composerQuestionText, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(2, reservesSpace: true)
                    .focused($isComposerQuestionFocused)
                    .accessibilityIdentifier("questionPromptField")

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Response type")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: responseTypeGridColumns, spacing: AppTheme.Spacing.sm) {
                        ForEach(responseTypeOptions) { option in
                            responseTypeButton(for: option)
                        }
                    }
                }

                if let selectedType = composerSelectedType {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Text("Configure responses")
                                .font(AppTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            let option = responseTypeOption(for: selectedType)
                            Label(option.title, systemImage: option.icon)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                                .accessibilityHidden(true)
                        }

                        configurationFields(for: selectedType)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("Choose a response type to unlock configuration details.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let composerErrorMessage {
                Text(composerErrorMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color.red)
                    .accessibilityHint("Fix the issue before saving.")
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                if composerHasContent {
                    Button(role: .destructive) {
                        resetComposer()
                    } label: {
                        Label("Clear", systemImage: "arrow.uturn.left")
                            .font(AppTheme.Typography.bodyStrong)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Palette.neutralSubdued)
                    .accessibilityLabel("Clear question builder")
                }

                Spacer()

                Button(composerEditingID == nil ? "Save question" : "Update question") {
                    saveComposedQuestion()
                }
                .buttonStyle(.primaryProminent)
                .frame(maxWidth: 260)
                .disabled(!canSaveComposedQuestion)
                .accessibilityIdentifier("saveQuestionButton")
            }
        }
    }

    private let responseTypeCardMinHeight: CGFloat = 128

    private var responseTypeGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
            GridItem(.flexible(), spacing: AppTheme.Spacing.sm)
        ]
    }

    private func responseTypeButton(for option: ResponseTypeOption) -> some View {
        let isSelected = composerSelectedType == option.type
        return Button {
            handleResponseTypeSelection(option.type)
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: option.icon)
                        .font(.body.weight(.semibold))
                    Text(option.title)
                        .font(AppTheme.Typography.bodyStrong)
                }
                Text(option.subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: responseTypeCardMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppTheme.Palette.primary.opacity(0.12) : AppTheme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? AppTheme.Palette.primary : AppTheme.Palette.neutralBorder, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .foregroundStyle(isSelected ? AppTheme.Palette.primary : AppTheme.Palette.neutralStrong)
        }
    .buttonStyle(.plain)
    .accessibilityHint(option.subtitle)
    .accessibilityIdentifier("responseType-\(option.type.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func configurationFields(for responseType: ResponseType) -> some View {
        switch responseType {
        case .numeric, .scale, .slider:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Minimum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("Minimum", value: $composerMinimumValue, format: .number)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Maximum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("Maximum", value: $composerMaximumValue, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                Text("People will respond within this range.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                Toggle("Allow empty response", isOn: $composerAllowsEmpty)
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                TextField("Options (comma separated)", text: $composerOptionsText, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
                Text("We’ll show these as selectable choices.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                Toggle("Allow empty response", isOn: $composerAllowsEmpty)
            }
        case .text, .boolean, .time:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Toggle("Allow empty response", isOn: $composerAllowsEmpty)
                Text("Optional responses can be skipped when logging.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func questionSummaryCard(for question: Question) -> some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Text(question.text)
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Button {
                            loadQuestionForEditing(question)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.body.bold())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit question")

                        Button(role: .destructive) {
                            Haptics.warning()
                            viewModel.removeQuestion(question)
                            if composerEditingID == question.id {
                                resetComposer()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.bold())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove question")
                    }
                }

                Text(question.responseType.displayName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                if let detail = questionDetail(for: question) {
                    Text(detail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            loadQuestionForEditing(question)
        }
    }

    private func questionDetail(for question: Question) -> String? {
        var parts: [String] = []

        switch question.responseType {
        case .numeric, .scale, .slider:
            let defaults = defaultRange(for: question.responseType)
            let minimum = question.validationRules?.minimumValue ?? defaults.min
            let maximum = question.validationRules?.maximumValue ?? defaults.max
            parts.append("Range: \(formattedValue(minimum)) – \(formattedValue(maximum))")
        case .multipleChoice:
            if let options = question.options, !options.isEmpty {
                let preview = options.prefix(3).joined(separator: ", ")
                let suffix = options.count > 3 ? "…" : ""
                parts.append("Options: \(preview)\(suffix)")
            }
        case .text, .boolean, .time:
            break
        }

        if question.validationRules?.allowsEmpty == true {
            parts.append("Optional response")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func formattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func handleResponseTypeSelection(_ responseType: ResponseType) {
        composerErrorMessage = nil
        let shouldReset = composerSelectedType != responseType
        composerSelectedType = responseType
        if composerEditingID == nil || shouldReset {
            applyComposerDefaults(for: responseType, resetOptions: shouldReset || composerEditingID == nil)
        }
    }

    private func saveComposedQuestion() {
        composerErrorMessage = nil
        let trimmed = composerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            composerErrorMessage = "Enter a question prompt before saving."
            Haptics.warning()
            return
        }

        guard let selectedType = composerSelectedType else {
            composerErrorMessage = "Choose a response type before saving."
            Haptics.warning()
            return
        }

        var options: [String]? = nil
        var validation: ValidationRules? = nil

        switch selectedType {
        case .multipleChoice:
            let uniqueOptions = currentOptions()
            guard !uniqueOptions.isEmpty else {
                composerErrorMessage = "Add at least one option."
                Haptics.warning()
                return
            }
            options = uniqueOptions
            validation = ValidationRules(allowsEmpty: composerAllowsEmpty)
        case .numeric, .scale, .slider:
            let minimum = min(composerMinimumValue, composerMaximumValue)
            let maximum = max(composerMinimumValue, composerMaximumValue)
            guard minimum <= maximum else {
                composerErrorMessage = "Minimum should be less than maximum."
                Haptics.warning()
                return
            }
            validation = ValidationRules(minimumValue: minimum, maximumValue: maximum, allowsEmpty: composerAllowsEmpty)
        case .text, .boolean, .time:
            if composerAllowsEmpty {
                validation = ValidationRules(allowsEmpty: true)
            }
        }

        viewModel.upsertQuestion(
            id: composerEditingID,
            text: trimmed,
            responseType: selectedType,
            options: options,
            validationRules: validation
        )

        Haptics.selection()
        resetComposer()
    }

    private func resetComposer() {
        composerQuestionText = ""
        composerSelectedType = nil
        composerMinimumValue = 0
        composerMaximumValue = 100
        composerAllowsEmpty = false
        composerOptionsText = ""
        composerEditingID = nil
        composerErrorMessage = nil
        DispatchQueue.main.async {
            isComposerQuestionFocused = true
        }
    }

    private func applyComposerDefaults(for responseType: ResponseType, resetOptions: Bool = true) {
        switch responseType {
        case .numeric, .slider:
            composerMinimumValue = 0
            composerMaximumValue = 100
            composerAllowsEmpty = false
            if resetOptions {
                composerOptionsText = ""
            }
        case .scale:
            composerMinimumValue = 1
            composerMaximumValue = 10
            composerAllowsEmpty = false
            if resetOptions {
                composerOptionsText = ""
            }
        case .multipleChoice:
            composerAllowsEmpty = false
            if resetOptions {
                composerOptionsText = ""
            }
        case .text, .boolean, .time:
            composerAllowsEmpty = false
            if resetOptions {
                composerOptionsText = ""
            }
        }
    }

    private func loadQuestionForEditing(_ question: Question) {
        Haptics.selection()
        composerQuestionText = question.text
        composerSelectedType = question.responseType
        composerEditingID = question.id
        composerErrorMessage = nil

        let defaults = defaultRange(for: question.responseType)
        composerMinimumValue = question.validationRules?.minimumValue ?? defaults.min
        composerMaximumValue = question.validationRules?.maximumValue ?? defaults.max
        composerAllowsEmpty = question.validationRules?.allowsEmpty ?? false
        composerOptionsText = question.options?.joined(separator: ", ") ?? ""
        DispatchQueue.main.async {
            isComposerQuestionFocused = true
        }
    }

    private func currentOptions() -> [String] {
        let rawOptions = composerOptionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var unique: [String] = []
        var seen: Set<String> = []
        for option in rawOptions {
            let key = option.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(option)
            }
        }
        return unique
    }

    private func defaultRange(for responseType: ResponseType) -> (min: Double, max: Double) {
        switch responseType {
        case .scale:
            return (1, 10)
        case .numeric, .slider:
            return (0, 100)
        default:
            return (0, 100)
        }
    }

    private var composerHasContent: Bool {
        !composerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || composerSelectedType != nil || composerEditingID != nil
    }

    private var shouldHideWizardNavigation: Bool {
        step == .questions && !composerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveComposedQuestion: Bool {
        guard let selectedType = composerSelectedType else { return false }
        let trimmed = composerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch selectedType {
        case .multipleChoice:
            return !currentOptions().isEmpty
        case .numeric, .scale, .slider:
            return composerMinimumValue <= composerMaximumValue
        case .text, .boolean, .time:
            return true
        }
    }

    private var responseTypeOptions: [ResponseTypeOption] {
        [
            ResponseTypeOption(type: .numeric, icon: "chart.bar", title: ResponseType.numeric.displayName, subtitle: "Track counts or totals."),
            ResponseTypeOption(type: .scale, icon: "line.3.horizontal.decrease.circle", title: ResponseType.scale.displayName, subtitle: "Capture ratings on a fixed scale."),
            ResponseTypeOption(type: .slider, icon: "slider.horizontal.3", title: ResponseType.slider.displayName, subtitle: "Quickly drag a value between two numbers."),
            ResponseTypeOption(type: .multipleChoice, icon: "list.bullet", title: ResponseType.multipleChoice.displayName, subtitle: "Present a short list of options."),
            ResponseTypeOption(type: .boolean, icon: "checkmark.circle", title: ResponseType.boolean.displayName, subtitle: "Simple yes or no questions."),
            ResponseTypeOption(type: .text, icon: "text.alignleft", title: ResponseType.text.displayName, subtitle: "Let people answer in their own words."),
            ResponseTypeOption(type: .time, icon: "clock", title: ResponseType.time.displayName, subtitle: "Capture a time of day.")
        ]
    }

    private func responseTypeOption(for type: ResponseType) -> ResponseTypeOption {
        responseTypeOptions.first { $0.type == type } ?? responseTypeOptions[0]
    }

    private var scheduleStep: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Frequency")
                        .font(AppTheme.Typography.sectionHeader)
                    Picker("Frequency", selection: Binding(
                        get: { viewModel.scheduleDraft.frequency },
                        set: { newValue in
                            viewModel.setFrequency(newValue)
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                        }
                    )) {
                        ForEach(Frequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch viewModel.scheduleDraft.frequency {
                    case .weekly:
                        WeekdaySelector(selectedWeekdays: Binding(
                            get: { viewModel.scheduleDraft.selectedWeekdays },
                            set: {
                                viewModel.updateSelectedWeekdays($0)
                                let conflict = viewModel.conflictDescription()
                                conflictMessage = conflict
                                if conflict != nil {
                                    Haptics.warning()
                                }
                            }
                        ))
                        if viewModel.scheduleDraft.selectedWeekdays.isEmpty {
                            Text("Select at least one day to send reminders.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .custom:
                        IntervalPicker(interval: Binding(
                            get: { viewModel.normalizedInterval ?? 3 },
                            set: { newValue in
                                viewModel.updateIntervalDayCount(newValue)
                                let conflict = viewModel.conflictDescription()
                                conflictMessage = conflict
                                if conflict != nil {
                                    Haptics.warning()
                                } else {
                                    Haptics.selection()
                                }
                            }
                        ))
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
                        DatePicker("Reminder time", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }

                    if !viewModel.scheduleDraft.times.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            ForEach(Array(viewModel.scheduleDraft.times.enumerated()), id: \.element) { index, scheduleTime in
                                HStack {
                                    Text(scheduleTime.formattedTime(in: viewModel.scheduleDraft.timezone))
                                        .font(AppTheme.Typography.body)
                                    Spacer()
                                    Button(role: .destructive) {
                                        viewModel.removeScheduleTime(scheduleTime)
                                        let updatedConflict = viewModel.conflictDescription()
                                        conflictMessage = updatedConflict
                                        if updatedConflict != nil {
                                            Haptics.warning()
                                        } else {
                                            Haptics.selection()
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .accessibilityLabel("Remove reminder")
                                    .accessibilityIdentifier("removeReminder-\(index)")
                                }
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .accessibilityIdentifier("reminderRow-\(scheduleTime.hour)-\(String(format: "%02d", scheduleTime.minute))")
                            }
                        }
                    } else {
                        Text("Add at least one reminder time.")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        if viewModel.addScheduleTime(from: newReminderTime) {
                            let updatedConflict = viewModel.conflictDescription()
                            conflictMessage = updatedConflict
                            if updatedConflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                            let nextBaseline = Calendar.current.date(byAdding: .minute, value: 30, to: newReminderTime) ?? newReminderTime
                            newReminderTime = viewModel.suggestedReminderDate(startingAt: nextBaseline)
                        } else {
                            conflictMessage = "Reminders must be at least 5 minutes apart."
                            Haptics.warning()
                        }
                    } label: {
                        Label("Add Reminder", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.secondaryProminent)
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Timezone")
                        .font(AppTheme.Typography.sectionHeader)
                    Picker("Timezone", selection: Binding(
                        get: { viewModel.scheduleDraft.timezone },
                        set: {
                            viewModel.setTimezone($0)
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                        }
                    )) {
                        ForEach(TimeZone.pickerOptions, id: \.identifier) { timezone in
                            Text(timezone.localizedDisplayName())
                                .tag(timezone)
                        }
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text(viewModel.title)
                        .font(AppTheme.Typography.title)
                    if !viewModel.goalDescription.isEmpty {
                        Text(viewModel.goalDescription)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    Text(selectedCategoryDisplayName)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Questions")
                        .font(AppTheme.Typography.sectionHeader)
                    ForEach(viewModel.draftQuestions, id: \.id) { question in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(question.text)
                                .font(AppTheme.Typography.body.weight(.semibold))
                            Text(question.responseType.displayName)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                            if let detail = questionDetail(for: question) {
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
                    Text("Reminders")
                        .font(AppTheme.Typography.sectionHeader)
                    if viewModel.scheduleDraft.times.isEmpty {
                        Text("No reminder times configured")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.scheduleDraft.times, id: \.self) { scheduleTime in
                            Text(scheduleTime.formattedTime(in: viewModel.scheduleDraft.timezone))
                                .font(AppTheme.Typography.body)
                        }
                    }

                    if viewModel.scheduleDraft.frequency == .weekly,
                       !viewModel.scheduleDraft.selectedWeekdays.isEmpty {
                        let names = viewModel.scheduleDraft.selectedWeekdays
                            .sorted(by: { $0.rawValue < $1.rawValue })
                            .map { $0.shortDisplayName }
                            .joined(separator: ", ")
                        Text("Remind on: \(names)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let interval = viewModel.normalizedInterval,
                       viewModel.scheduleDraft.frequency == .custom {
                        Text("Every \(interval) days")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func canAdvance(_ step: Step) -> Bool {
        switch step {
        case .details:
            let hasTitle = !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard hasTitle, let category = viewModel.selectedCategory else { return false }
            if category == .custom {
                return !viewModel.customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        case .questions:
            return viewModel.hasDraftQuestions
        case .schedule:
            guard viewModel.hasScheduleTimes else { return false }
            switch viewModel.scheduleDraft.frequency {
            case .weekly:
                return !viewModel.scheduleDraft.selectedWeekdays.isEmpty
            case .custom:
                return viewModel.normalizedInterval != nil
            default:
                return true
            }
        case .review:
            return true
        }
    }

    private func moveForward() {
        if step.isFinal {
            handleSave()
            return
        }

        if let next = step.next(), canAdvance(step) {
            Haptics.selection()
            withAnimation(.spring) {
                step = next
                conflictMessage = next == .schedule ? viewModel.conflictDescription() : nil
            }
        }
    }

    private func moveBackward() {
        guard let previous = step.previous() else { return }
        Haptics.selection()
        withAnimation(.spring) {
            step = previous
            conflictMessage = previous == .schedule ? viewModel.conflictDescription() : nil
        }
    }

    private func handleSave() {
        do {
            let goal = try viewModel.createGoal()
            Haptics.success()
            NotificationScheduler.shared.scheduleNotifications(for: goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            Haptics.error()
        }
    }
}

private extension GoalCreationView {
    var selectedCategoryDisplayName: String {
        guard let category = viewModel.selectedCategory else {
            return "Select a category"
        }

        if category == .custom {
            let trimmed = viewModel.customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return category.displayName
    }

    struct ResponseTypeOption: Identifiable {
        let type: ResponseType
        let icon: String
        let title: String
        let subtitle: String

        var id: ResponseType { type }
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
        let viewModel = GoalCreationViewModel(modelContext: context)
        return GoalCreationView(viewModel: viewModel)
            .modelContainer(container)
    } else {
        return Text("Preview unavailable")
    }
}

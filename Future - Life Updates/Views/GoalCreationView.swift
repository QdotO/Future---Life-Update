import SwiftUI
import SwiftData

struct GoalCreationView: View {
    private enum Step: Int, CaseIterable, Identifiable {
        case details
        case questions
        case schedule
        case review

        var id: Int { rawValue }

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

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .details
    @State private var newQuestionText: String = ""
    @State private var newQuestionOptionsText: String = ""
    @State private var newQuestionMinimum: Double = 0
    @State private var newQuestionMaximum: Double = 100
    @State private var newQuestionAllowsEmpty: Bool = false
    @State private var newQuestionResponseType: ResponseType = .numeric
    @State private var newReminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var conflictMessage: String?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var didSeedQuestionDefaults = false

    @Bindable private var viewModel: GoalCreationViewModel

    init(viewModel: GoalCreationViewModel) {
        self._viewModel = Bindable(viewModel)
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

                        stepContent
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.bottom, AppTheme.Spacing.xl * 2)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(
                LinearGradient(
                    colors: [AppTheme.Palette.background, AppTheme.Palette.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("New Tracking Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    if let conflictMessage {
                        ConflictBanner(message: conflictMessage)
                    }
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
            .alert("Unable to Create Goal", isPresented: $showingErrorAlert, actions: {
                Button("OK", role: .cancel) {
                    showingErrorAlert = false
                }
            }, message: {
                Text(errorMessage ?? "")
            })
            .task {
                if !didSeedQuestionDefaults {
                    didSeedQuestionDefaults = true
                    applyQuestionDefaults(for: newQuestionResponseType)
                }
            }
            .onChange(of: newQuestionResponseType) { _, newValue in
                applyQuestionDefaults(for: newValue)
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

                TextField("What are you tracking?", text: $viewModel.goalDescription, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .font(AppTheme.Typography.body)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Category")
                        .font(AppTheme.Typography.sectionHeader)
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(TrackingCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var questionsStep: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if viewModel.draftQuestions.isEmpty {
                CardBackground {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("No questions yet")
                            .font(AppTheme.Typography.sectionHeader)
                        Text("Add prompts so the app knows what to ask when it reminds you.")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                LazyVStack(spacing: AppTheme.Spacing.md) {
                    ForEach(viewModel.draftQuestions, id: \.id) { question in
                        CardBackground {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                HStack {
                                    Text(question.text)
                                        .font(AppTheme.Typography.sectionHeader)
                                    Spacer()
                                    Button(role: .destructive) {
                                        Haptics.warning()
                                        viewModel.removeQuestion(question)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.body.bold())
                                    }
                                    .accessibilityLabel("Remove question")
                                }
                                Text(question.responseType.displayName)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                                if let options = question.options, !options.isEmpty {
                                    Text(options.joined(separator: ", "))
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            CardBackground {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Add a question")
                        .font(AppTheme.Typography.sectionHeader)

                    TextField("Ask a question to track", text: $newQuestionText)

                    Picker("Response Type", selection: $newQuestionResponseType) {
                        ForEach(ResponseType.allCases, id: \.self) { response in
                            Text(response.displayName).tag(response)
                        }
                    }
                    .pickerStyle(.segmented)

                    questionConfigurationFields

                    Button {
                        addQuestion()
                    } label: {
                        Label("Add Question", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.primaryProminent)
                    .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var questionConfigurationFields: some View {
        switch newQuestionResponseType {
        case .numeric, .scale, .slider:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Minimum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("Minimum", value: $newQuestionMinimum, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Maximum")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("Maximum", value: $newQuestionMaximum, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                TextField("Options (comma separated)", text: $newQuestionOptionsText)
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .text, .boolean, .time:
            Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
        }
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
                            ForEach(viewModel.scheduleDraft.times, id: \.self) { scheduleTime in
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
                                }
                                .padding(.vertical, AppTheme.Spacing.xs)
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
                            newReminderTime = Calendar.current.date(byAdding: .minute, value: 30, to: newReminderTime) ?? newReminderTime
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
                        ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                            if let timezone = TimeZone(identifier: identifier) {
                                Text(timezone.localizedName(for: .shortGeneric, locale: .current) ?? identifier)
                                    .tag(timezone)
                            }
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
                    Text(viewModel.selectedCategory.displayName)
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

    private func addQuestion() {
        let trimmed = newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var options: [String]? = nil
        var validation: ValidationRules? = nil

        switch newQuestionResponseType {
        case .multipleChoice:
            let parsedOptions = newQuestionOptionsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var unique: [String] = []
            var seen: Set<String> = []
            for option in parsedOptions where !seen.contains(option.lowercased()) {
                seen.insert(option.lowercased())
                unique.append(option)
            }
            guard !unique.isEmpty else {
                conflictMessage = "Add at least one option before saving."
                Haptics.warning()
                return
            }
            options = unique
            validation = ValidationRules(allowsEmpty: newQuestionAllowsEmpty)
        case .numeric, .scale, .slider:
            let minimum = min(newQuestionMinimum, newQuestionMaximum)
            let maximum = max(newQuestionMinimum, newQuestionMaximum)
            validation = ValidationRules(minimumValue: minimum, maximumValue: maximum, allowsEmpty: newQuestionAllowsEmpty)
        case .text, .boolean, .time:
            if newQuestionAllowsEmpty {
                validation = ValidationRules(allowsEmpty: true)
            }
        }

        viewModel.addManualQuestion(
            text: trimmed,
            responseType: newQuestionResponseType,
            options: options,
            validationRules: validation
        )

        Haptics.selection()
        resetNewQuestionFields()
        conflictMessage = nil
    }

    private func resetNewQuestionFields() {
        newQuestionText = ""
        newQuestionOptionsText = ""
        newQuestionMinimum = newQuestionResponseType == .scale ? 1 : 0
        newQuestionMaximum = newQuestionResponseType == .scale ? 10 : 100
        newQuestionAllowsEmpty = false
        applyQuestionDefaults(for: newQuestionResponseType)
    }

    private func applyQuestionDefaults(for responseType: ResponseType) {
        switch responseType {
        case .numeric, .slider:
            newQuestionMinimum = 0
            newQuestionMaximum = 100
            newQuestionAllowsEmpty = false
        case .scale:
            newQuestionMinimum = 1
            newQuestionMaximum = 10
            newQuestionAllowsEmpty = false
            newQuestionOptionsText = ""
        case .multipleChoice, .text, .boolean, .time:
            newQuestionOptionsText = ""
            newQuestionAllowsEmpty = false
        }
    }

    private func canAdvance(_ step: Step) -> Bool {
        switch step {
        case .details:
            return !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .questions:
            return !viewModel.draftQuestions.isEmpty
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

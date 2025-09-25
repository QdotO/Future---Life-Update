import SwiftUI
import SwiftData

struct GoalEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var newQuestionText: String = ""
    @State private var newQuestionOptionsText: String = ""
    @State private var newQuestionMinimum: Double = 0
    @State private var newQuestionMaximum: Double = 100
    @State private var newQuestionAllowsEmpty: Bool = false
    @State private var newResponseType: ResponseType = .numeric
    @State private var newReminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var errorMessage: String?
    @State private var didSeedNewQuestionDefaults = false
    @State private var conflictMessage: String?
    @State private var scheduleError: String?

    @Bindable private var viewModel: GoalEditorViewModel

    init(viewModel: GoalEditorViewModel) {
        self._viewModel = Bindable(viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                goalDetailsSection
                questionsSection
                scheduleSection
            }
            .navigationTitle("Edit Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(viewModel.questionDrafts.isEmpty || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(
                "Unable to Save Goal",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                if !didSeedNewQuestionDefaults {
                    didSeedNewQuestionDefaults = true
                    seedNewQuestionDefaults(for: newResponseType)
                }
                conflictMessage = viewModel.conflictDescription()
            }
            .onChange(of: newResponseType) { _, newType in
                seedNewQuestionDefaults(for: newType)
            }
        }
    }

    private var goalDetailsSection: some View {
        Section("Goal Details") {
            TextField("Title", text: $viewModel.title)
                .textContentType(.nickname)
                .font(.title3)

            TextField("Description", text: $viewModel.goalDescription, axis: .vertical)
                .lineLimit(3, reservesSpace: true)

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

    private var questionsSection: some View {
        Section("Questions") {
            if viewModel.questionDrafts.isEmpty {
                ContentUnavailableView("Add a question to keep tracking", systemImage: "text.badge.plus")
            } else {
                ForEach($viewModel.questionDrafts) { $draft in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Prompt", text: $draft.text)
                        Picker("Response", selection: $draft.responseType) {
                            ForEach(ResponseType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Active", isOn: $draft.isActive)
                        configurationFields(for: $draft)
                    }
                    .onChange(of: draft.responseType) { _, newType in
                        seedDraftDefaults(for: $draft, responseType: newType)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Haptics.warning()
                            viewModel.removeDraft(draft)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Ask a new question", text: $newQuestionText)
                Picker("Response Type", selection: $newResponseType) {
                    ForEach(ResponseType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                newQuestionConfigurationFields
                Button {
                    addQuestion()
                } label: {
                    Label("Add Question", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func configurationFields(for draft: Binding<GoalEditorViewModel.QuestionDraft>) -> some View {
        switch draft.responseType.wrappedValue {
        case .numeric, .scale, .slider:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "Minimum",
                            value: minimumBinding(for: draft, defaultValue: defaultMinimum(for: draft.responseType.wrappedValue)),
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "Maximum",
                            value: maximumBinding(for: draft, defaultValue: defaultMaximum(for: draft.responseType.wrappedValue)),
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    }
                }
                Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Options (comma separated)", text: optionsBinding(for: draft))
                Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
            }
        case .text:
            Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
        case .boolean, .time:
            Toggle("Allow empty response", isOn: allowsEmptyBinding(for: draft))
        }
    }

    private func minimumBinding(for draft: Binding<GoalEditorViewModel.QuestionDraft>, defaultValue: Double) -> Binding<Double> {
        Binding<Double>(
            get: { draft.validationRules.wrappedValue?.minimumValue ?? defaultValue },
            set: { newValue in
                var rules = draft.validationRules.wrappedValue ?? ValidationRules(allowsEmpty: draft.validationRules.wrappedValue?.allowsEmpty ?? false)
                rules.minimumValue = newValue
                if let maximum = rules.maximumValue, maximum < newValue {
                    rules.maximumValue = newValue
                }
                draft.validationRules.wrappedValue = rules
            }
        )
    }

    private func maximumBinding(for draft: Binding<GoalEditorViewModel.QuestionDraft>, defaultValue: Double) -> Binding<Double> {
        Binding<Double>(
            get: { draft.validationRules.wrappedValue?.maximumValue ?? defaultValue },
            set: { newValue in
                var rules = draft.validationRules.wrappedValue ?? ValidationRules(allowsEmpty: draft.validationRules.wrappedValue?.allowsEmpty ?? false)
                let minimum = rules.minimumValue ?? defaultValue
                rules.maximumValue = max(newValue, minimum)
                draft.validationRules.wrappedValue = rules
            }
        )
    }

    private func allowsEmptyBinding(for draft: Binding<GoalEditorViewModel.QuestionDraft>) -> Binding<Bool> {
        Binding<Bool>(
            get: { draft.validationRules.wrappedValue?.allowsEmpty ?? false },
            set: { newValue in
                var rules = draft.validationRules.wrappedValue ?? ValidationRules(allowsEmpty: newValue)
                rules.allowsEmpty = newValue
                draft.validationRules.wrappedValue = rules
            }
        )
    }

    @ViewBuilder
    private var newQuestionConfigurationFields: some View {
        switch newResponseType {
        case .numeric, .scale, .slider:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Minimum", value: $newQuestionMinimum, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Maximum", value: $newQuestionMaximum, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Options (comma separated)", text: $newQuestionOptionsText)
                Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
            }
        case .text:
            Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
        case .boolean, .time:
            Toggle("Allow empty response", isOn: $newQuestionAllowsEmpty)
        }
    }

    private func optionsBinding(for draft: Binding<GoalEditorViewModel.QuestionDraft>) -> Binding<String> {
        Binding<String>(
            get: { draft.options.wrappedValue.joined(separator: ", ") },
            set: { newValue in
                draft.options.wrappedValue = parseOptions(from: newValue)
            }
        )
    }

    private func defaultMinimum(for responseType: ResponseType) -> Double {
        switch responseType {
        case .scale:
            return 1
        default:
            return 0
        }
    }

    private func defaultMaximum(for responseType: ResponseType) -> Double {
        switch responseType {
        case .scale:
            return 10
        default:
            return 100
        }
    }

    private func seedDraftDefaults(for draft: Binding<GoalEditorViewModel.QuestionDraft>, responseType: ResponseType) {
        let allowsEmpty = draft.validationRules.wrappedValue?.allowsEmpty ?? false
        switch responseType {
        case .numeric:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(minimumValue: 0, maximumValue: 100, allowsEmpty: allowsEmpty)
        case .scale:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(minimumValue: 1, maximumValue: 10, allowsEmpty: allowsEmpty)
        case .slider:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(minimumValue: 0, maximumValue: 100, allowsEmpty: allowsEmpty)
        case .multipleChoice:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(allowsEmpty: allowsEmpty)
        case .text:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = ValidationRules(allowsEmpty: allowsEmpty)
        case .boolean, .time:
            draft.options.wrappedValue = []
            draft.validationRules.wrappedValue = allowsEmpty ? ValidationRules(allowsEmpty: true) : nil
        }
    }

    private func parseOptions(from text: String) -> [String] {
        let candidates = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        var seen: Set<String> = []
        for item in candidates where !seen.contains(item.lowercased()) {
            seen.insert(item.lowercased())
            unique.append(item)
        }
        return unique
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Frequency", selection: Binding(
                get: { viewModel.scheduleDraft.frequency },
                set: { newValue in
                    viewModel.setFrequency(newValue)
                    scheduleError = nil
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

            switch viewModel.scheduleDraft.frequency {
            case .weekly:
                WeekdaySelector(
                    selectedWeekdays: Binding(
                        get: { viewModel.scheduleDraft.selectedWeekdays },
                        set: { newValue in
                            viewModel.updateSelectedWeekdays(newValue)
                            scheduleError = nil
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            }
                        }
                    )
                )
                .padding(.vertical, 4)
                if viewModel.scheduleDraft.selectedWeekdays.isEmpty {
                    Text("Select at least one day to send reminders.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .custom:
                IntervalPicker(
                    interval: Binding(
                        get: { viewModel.scheduleDraft.intervalDayCount ?? 3 },
                        set: { newValue in
                            viewModel.updateIntervalDayCount(newValue)
                            scheduleError = nil
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                        }
                    )
                )
            default:
                EmptyView()
            }

            Picker("Timezone", selection: Binding(
                get: { viewModel.scheduleDraft.timezone },
                set: {
                    viewModel.setTimezone($0)
                    scheduleError = nil
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

            if let conflictMessage {
                Text(conflictMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let scheduleError {
                Text(scheduleError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if viewModel.scheduleDraft.times.isEmpty {
                ContentUnavailableView("Add at least one reminder", systemImage: "alarm")
            } else {
                ForEach(Array(viewModel.scheduleDraft.times.enumerated()), id: \.offset) { index, scheduleTime in
                    HStack {
                        DatePicker(
                            "Reminder \(index + 1)",
                            selection: Binding(
                                get: { viewModel.reminderDate(for: scheduleTime) },
                                set: { newValue in
                                    if viewModel.updateScheduleTime(at: index, to: newValue) {
                                        Haptics.selection()
                                        scheduleError = nil
                                        conflictMessage = viewModel.conflictDescription()
                                    } else {
                                        scheduleError = "Reminders must be at least 5 minutes apart."
                                        Haptics.warning()
                                    }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        Button(role: .destructive) {
                            viewModel.removeScheduleTime(at: index)
                            scheduleError = nil
                            let conflict = viewModel.conflictDescription()
                            conflictMessage = conflict
                            if conflict != nil {
                                Haptics.warning()
                            } else {
                                Haptics.selection()
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                if viewModel.addScheduleTime(from: newReminderTime) {
                    Haptics.selection()
                    scheduleError = nil
                    conflictMessage = viewModel.conflictDescription()
                    newReminderTime = Calendar.current.date(byAdding: .minute, value: 30, to: newReminderTime) ?? newReminderTime
                } else {
                    scheduleError = "Reminders must be at least 5 minutes apart."
                    Haptics.warning()
                }
            } label: {
                Label("Add Reminder Time", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            DatePicker("New Reminder", selection: $newReminderTime, displayedComponents: .hourAndMinute)
        }
    }

    private func seedNewQuestionDefaults(for responseType: ResponseType) {
        newQuestionAllowsEmpty = false
        newQuestionOptionsText = ""
        switch responseType {
        case .numeric:
            newQuestionMinimum = 0
            newQuestionMaximum = 100
        case .scale:
            newQuestionMinimum = 1
            newQuestionMaximum = 10
        case .slider:
            newQuestionMinimum = 0
            newQuestionMaximum = 100
        case .multipleChoice:
            break
        case .text, .boolean, .time:
            break
        }
    }

    private func resetNewQuestionFields() {
        newQuestionText = ""
        newResponseType = .numeric
        seedNewQuestionDefaults(for: .numeric)
    }

    private func addQuestion() {
        let trimmed = newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var options: [String]? = nil
        var validation: ValidationRules? = nil

        switch newResponseType {
        case .multipleChoice:
            let parsed = parseOptions(from: newQuestionOptionsText)
            if parsed.isEmpty {
                errorMessage = "Add at least one option before saving."
                Haptics.warning()
                return
            }
            options = parsed
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

        viewModel.addQuestion(
            text: trimmed,
            responseType: newResponseType,
            options: options,
            validationRules: validation
        )

        Haptics.selection()
        resetNewQuestionFields()
    }

    private func handleSave() {
        do {
            let goal = try viewModel.saveChanges()
            Haptics.success()
            NotificationScheduler.shared.scheduleNotifications(for: goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
           let goal = goals.first {
            let viewModel = GoalEditorViewModel(goal: goal, modelContext: context)
            GoalEditView(viewModel: viewModel)
                .modelContainer(container)
        } else {
            Text("No Sample Goal")
        }
    } else {
        Text("Preview Error Loading Sample Data")
    }
}

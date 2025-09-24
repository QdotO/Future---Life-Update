import SwiftUI
import SwiftData

struct GoalCreationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var newQuestionText: String = ""
    @State private var newQuestionOptionsText: String = ""
    @State private var newQuestionMinimum: Double = 0
    @State private var newQuestionMaximum: Double = 100
    @State private var newQuestionAllowsEmpty: Bool = false
    @State private var selectedResponseType: ResponseType = .numeric
    @State private var selectedFrequency: Frequency
    @State private var selectedTimezone: TimeZone
    @State private var selectedTime: Date
    @State private var errorMessage: String?
    @State private var didSeedSchedule = false
    @State private var didSeedQuestionDefaults = false

    @Bindable private var viewModel: GoalCreationViewModel

    init(viewModel: GoalCreationViewModel) {
        self._viewModel = Bindable(viewModel)
        self._selectedFrequency = State(initialValue: viewModel.scheduleDraft.frequency)
        self._selectedTimezone = State(initialValue: viewModel.scheduleDraft.timezone)
        let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        self._selectedTime = State(initialValue: defaultTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                goalDetailsSection
                questionsSection
                scheduleSection
            }
            .navigationTitle("New Tracking Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.draftQuestions.isEmpty)
                }
            }
            .alert(
                "Unable to Create Goal",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: selectedFrequency) { _, newValue in
                updateSchedule(frequency: newValue)
            }
            .onChange(of: selectedTime) { _, _ in
                updateSchedule(frequency: selectedFrequency)
            }
            .onChange(of: selectedTimezone) { _, newValue in
                updateSchedule(frequency: selectedFrequency, timezone: newValue)
            }
            .task {
                if !didSeedSchedule {
                    didSeedSchedule = true
                    updateSchedule(frequency: selectedFrequency)
                }
                if !didSeedQuestionDefaults {
                    didSeedQuestionDefaults = true
                    seedQuestionDefaults(for: selectedResponseType)
                }
            }
            .onChange(of: selectedResponseType) { _, newType in
                seedQuestionDefaults(for: newType)
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

            Picker("Category", selection: $viewModel.selectedCategory) {
                ForEach(TrackingCategory.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
        }
    }

    private var questionsSection: some View {
        Section("Questions") {
            if viewModel.draftQuestions.isEmpty {
                ContentUnavailableView("Add the first question", systemImage: "text.badge.plus")
            } else {
                ForEach(viewModel.draftQuestions, id: \.id) { question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.text)
                            .font(.headline)
                        Text(question.responseType.displayName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let options = question.options, !options.isEmpty {
                            Text("Options: \(options.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let rules = question.validationRules {
                            if let min = rules.minimumValue, let max = rules.maximumValue {
                                Text("Range: \(min.formatted()) – \(max.formatted())")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else if let min = rules.minimumValue {
                                Text("Minimum: \(min.formatted())")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else if let max = rules.maximumValue {
                                Text("Maximum: \(max.formatted())")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if rules.allowsEmpty {
                                Text("Allows empty response")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.removeQuestion(question)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Ask a question to track", text: $newQuestionText)
                Picker("Response Type", selection: $selectedResponseType) {
                    ForEach(ResponseType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                questionConfigurationFields
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
    private var questionConfigurationFields: some View {
        switch selectedResponseType {
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

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Frequency", selection: $selectedFrequency) {
                ForEach(Frequency.allCases, id: \.self) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }

            DatePicker("Reminder Time", selection: $selectedTime, displayedComponents: .hourAndMinute)

            Picker("Timezone", selection: $selectedTimezone) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                    if let timezone = TimeZone(identifier: identifier) {
                        Text(timezone.localizedName(for: .shortGeneric, locale: .current) ?? identifier)
                            .tag(timezone)
                    }
                }
            }

            if !viewModel.scheduleDraft.times.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reminder Times")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.scheduleDraft.times, id: \.self) { scheduleTime in
                        Text(scheduleTime.formattedTime(in: viewModel.scheduleDraft.timezone))
                    }
                }
            }
        }
    }

    private func seedQuestionDefaults(for responseType: ResponseType) {
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
        selectedResponseType = .numeric
        seedQuestionDefaults(for: .numeric)
    }

    private func addQuestion() {
        let trimmed = newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var options: [String]? = nil
        var validation: ValidationRules? = nil

        switch selectedResponseType {
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
            if unique.isEmpty {
                errorMessage = "Add at least one option before saving."
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
            responseType: selectedResponseType,
            options: options,
            validationRules: validation
        )

        resetNewQuestionFields()
    }

    private func updateSchedule(frequency: Frequency, timezone: TimeZone? = nil) {
        let timezone = timezone ?? selectedTimezone
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        viewModel.updateSchedule(
            frequency: frequency,
            times: [components],
            timezone: timezone
        )
    }

    private func handleSave() {
        do {
            let goal = try viewModel.createGoal()
            NotificationScheduler.shared.scheduleNotifications(for: goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        let context = container.mainContext
        let viewModel = GoalCreationViewModel(modelContext: context)
        return GoalCreationView(viewModel: viewModel)
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

import SwiftUI
import SwiftData

struct GoalCreationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var newQuestionText: String = ""
    @State private var selectedResponseType: ResponseType = .numeric
    @State private var selectedFrequency: Frequency
    @State private var selectedTimezone: TimeZone
    @State private var selectedTime: Date
    @State private var errorMessage: String?
    @State private var didSeedSchedule = false

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.text)
                            .font(.headline)
                        Text(question.responseType.displayName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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

            VStack(alignment: .leading) {
                TextField("Ask a question to track", text: $newQuestionText)
                Picker("Response Type", selection: $selectedResponseType) {
                    ForEach(ResponseType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
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

    private func addQuestion() {
        let trimmed = newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addManualQuestion(text: trimmed, responseType: selectedResponseType)
        newQuestionText = ""
        selectedResponseType = .numeric
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

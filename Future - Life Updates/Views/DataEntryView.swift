import SwiftUI
import SwiftData

struct DataEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DataEntryViewModel
    @State private var numericResponses: [UUID: Double]
    private let goal: TrackingGoal

    init(goal: TrackingGoal, modelContext: ModelContext, dateProvider: @escaping () -> Date = Date.init) {
        self.goal = goal
        let viewModel = DataEntryViewModel(goal: goal, modelContext: modelContext, dateProvider: dateProvider)
        self._viewModel = State(initialValue: viewModel)
        var defaults: [UUID: Double] = [:]
        for question in goal.questions where question.responseType == .numeric {
            let baseline = question.validationRules?.minimumValue ?? 0
            defaults[question.id] = baseline
            viewModel.setNumericResponse(baseline, for: question)
        }
        self._numericResponses = State(initialValue: defaults)
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(goal.questions) { question in
                    switch question.responseType {
                    case .numeric:
                        numericEntryRow(for: question)
                    case .boolean:
                        toggleEntryRow(for: question)
                    case .text:
                        textEntryRow(for: question)
                    default:
                        unsupportedRow(for: question)
                    }
                }
            }
            .navigationTitle("Log Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveEntries() }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !numericResponses.isEmpty
    }

    private func numericEntryRow(for question: Question) -> some View {
        HStack {
            Text(question.text)
            Spacer()
            let minimum = question.validationRules?.minimumValue ?? 0
            let maximum = question.validationRules?.maximumValue ?? 1000
            let upperBound = max(maximum, minimum)
            Stepper(value: binding(for: question), in: minimum...upperBound, step: 1) {
                Text("\(numericResponses[question.id] ?? minimum, format: .number)")
                    .monospacedDigit()
                    .frame(width: 60)
            }
            .labelsHidden()
        }
    }

    private func binding(for question: Question) -> Binding<Double> {
        Binding<Double>(
            get: { numericResponses[question.id] ?? 0 },
            set: { numericResponses[question.id] = $0; viewModel.setNumericResponse($0, for: question) }
        )
    }

    private func toggleEntryRow(for question: Question) -> some View {
        Toggle(isOn: .constant(false)) {
            VStack(alignment: .leading) {
                Text(question.text)
                Text("Boolean input coming soon")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(true)
    }

    private func textEntryRow(for question: Question) -> some View {
        VStack(alignment: .leading) {
            Text(question.text)
            Text("Text input coming soon")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func unsupportedRow(for question: Question) -> some View {
        VStack(alignment: .leading) {
            Text(question.text)
            Text("Response type not yet supported in this prototype")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private func saveEntries() async {
        do {
            try viewModel.saveEntries()
            dismiss()
        } catch {
            print("Failed to save entries: \(error)")
        }
    }
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        let context = container.mainContext
        guard let goal = try context.fetch(FetchDescriptor<TrackingGoal>()).first else {
            return Text("No sample goal")
        }
        return DataEntryView(goal: goal, modelContext: context)
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

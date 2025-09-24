import SwiftUI
import SwiftData

struct DataEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DataEntryViewModel
    private let goal: TrackingGoal

    init(goal: TrackingGoal, modelContext: ModelContext, dateProvider: @escaping () -> Date = Date.init) {
        self.goal = goal
        let viewModel = DataEntryViewModel(goal: goal, modelContext: modelContext, dateProvider: dateProvider)
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                let activeQuestions = goal.questions.filter { $0.isActive }
                if activeQuestions.isEmpty {
                    ContentUnavailableView("No active questions", systemImage: "checkmark.circle")
                } else {
                    ForEach(activeQuestions) { question in
                        questionRow(for: question)
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
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }

    @ViewBuilder
    private func questionRow(for question: Question) -> some View {
        switch question.responseType {
        case .numeric:
            numericRow(for: question)
        case .scale:
            scaleRow(for: question)
        case .slider:
            sliderRow(for: question)
        case .boolean:
            booleanRow(for: question)
        case .text:
            textRow(for: question)
        case .multipleChoice:
            multipleChoiceRow(for: question)
        case .time:
            timeRow(for: question)
        }
    }

    private func numericRow(for question: Question) -> some View {
        let bounds = numericBounds(for: question)
        let valueBinding = Binding<Double>(
            get: { viewModel.numericValue(for: question, default: bounds.lowerBound) },
            set: { viewModel.updateNumericResponse($0, for: question) }
        )
        let currentValue = valueBinding.wrappedValue

        return HStack(spacing: 12) {
            Text(question.text)
            Spacer()
            Text(currentValue, format: .number)
                .monospacedDigit()
                .frame(width: 60, alignment: .trailing)
            Stepper("", value: valueBinding, in: bounds, step: 1)
                .labelsHidden()
                .accessibilityLabel(Text(question.text))
                .accessibilityValue(Text(currentValue, format: .number))
        }
    }

    private func scaleRow(for question: Question) -> some View {
        let bounds = scaleBounds(for: question)
        let binding = Binding<Int>(
            get: { Int(viewModel.numericValue(for: question, default: Double(bounds.lowerBound))) },
            set: { viewModel.updateNumericResponse(Double($0), for: question) }
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
            Stepper(value: binding, in: bounds) {
                Text("\(binding.wrappedValue)")
                    .font(.headline)
            }
        }
    }

    private func sliderRow(for question: Question) -> some View {
        let bounds = sliderBounds(for: question)
        let intBinding = Binding<Int>(
            get: {
                let value = Int(round(viewModel.numericValue(for: question, default: Double(bounds.lowerBound))))
                return min(max(value, bounds.lowerBound), bounds.upperBound)
            },
            set: { newValue in
                let clamped = min(max(newValue, bounds.lowerBound), bounds.upperBound)
                viewModel.updateNumericResponse(Double(clamped), for: question)
            }
        )

        let sliderBinding = Binding<Double>(
            get: { Double(intBinding.wrappedValue) },
            set: { newValue in intBinding.wrappedValue = Int(newValue.rounded()) }
        )

        let doubleBounds = Double(bounds.lowerBound)...Double(bounds.upperBound)

        return VStack(alignment: .leading, spacing: 12) {
            Text(question.text)
            Slider(value: sliderBinding, in: doubleBounds, step: 1)
            Text("\(intBinding.wrappedValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func booleanRow(for question: Question) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.booleanValue(for: question) },
            set: { viewModel.updateBooleanResponse($0, for: question) }
        )) {
            Text(question.text)
        }
    }

    private func textRow(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
            TextField("Enter response", text: Binding(
                get: { viewModel.textValue(for: question) },
                set: { viewModel.updateTextResponse($0, for: question) }
            ), axis: .vertical)
            .lineLimit(3, reservesSpace: true)
        }
    }

    private func multipleChoiceRow(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
            if let options = question.options, !options.isEmpty {
                ForEach(options, id: \.self) { option in
                    Toggle(option, isOn: Binding(
                        get: { viewModel.selectedOptions(for: question).contains(option) },
                        set: { viewModel.setOption(option, isSelected: $0, for: question) }
                    ))
                }
            } else {
                Text("No options configured")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeRow(for question: Question) -> some View {
        DatePicker(
            question.text,
            selection: Binding(
                get: {
                    viewModel.timeValue(for: question, fallback: defaultTime())
                },
                set: { viewModel.updateTimeResponse($0, for: question) }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    private func numericBounds(for question: Question) -> ClosedRange<Double> {
        let minimum = question.validationRules?.minimumValue ?? 0
        let maximum = question.validationRules?.maximumValue ?? max(minimum + 100, minimum + 10)
        let upperBound = max(maximum, minimum + 1)
        return minimum...upperBound
    }

    private func scaleBounds(for question: Question) -> ClosedRange<Int> {
        let minimum = Int(question.validationRules?.minimumValue ?? 1)
        let maximum = Int(question.validationRules?.maximumValue ?? 10)
        return min(minimum, maximum)...max(maximum, minimum)
    }

    private func sliderBounds(for question: Question) -> ClosedRange<Int> {
        let minimum = question.validationRules?.minimumValue ?? 0
        let maximum = question.validationRules?.maximumValue ?? 100
        let lowerBound = Int(floor(min(minimum, maximum)))
        let upperBound = Int(ceil(max(maximum, minimum)))
        return lowerBound...upperBound
    }

    private func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
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
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
           let goal = goals.first {
            DataEntryView(goal: goal, modelContext: context)
                .modelContainer(container)
        } else {
            Text("No sample goal")
        }
    } else {
        Text("Preview Error Loading Sample Data")
    }
}

import SwiftData
import SwiftUI

#if os(iOS)
    import UIKit
#endif

struct DataEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designStyle) private var designStyle

    @State private var viewModel: DataEntryViewModel
    @FocusState private var focusedTextQuestionID: UUID?
    private let goal: TrackingGoal
    private let mode: Mode

    init(
        goal: TrackingGoal,
        modelContext: ModelContext,
        dateProvider: @escaping () -> Date = Date.init,
        mode: Mode = .manual
    ) {
        self.goal = goal
        self.mode = mode
        let viewModel = DataEntryViewModel(
            goal: goal, modelContext: modelContext, dateProvider: dateProvider)
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelButtonTitle, role: .cancel) { dismiss() }
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
    private var content: some View {
        if designStyle == .brutalist {
            brutalistContent
        } else {
            legacyContent
        }
    }

    private var legacyContent: some View {
        Form {
            if case .notification(_, let isTest) = mode {
                notificationIntro(isTest: isTest)
            }

            let activeQuestions = orderedActiveQuestions
            if activeQuestions.isEmpty {
                ContentUnavailableView("No active questions", systemImage: "checkmark.circle")
            } else {
                ForEach(activeQuestions) { question in
                    questionRow(for: question)
                        .listRowBackground(focusHighlight(for: question))
                }
            }
        }
    }

    private var brutalistContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
                if case .notification(_, let isTest) = mode {
                    notificationIntro(isTest: isTest)
                }

                let activeQuestions = orderedActiveQuestions
                if activeQuestions.isEmpty {
                    ContentUnavailableView("No active questions", systemImage: "checkmark.circle")
                        .brutalistCard()
                } else {
                    LazyVStack(
                        alignment: .leading,
                        spacing: AppTheme.BrutalistSpacing.lg,
                        pinnedViews: []
                    ) {
                        ForEach(activeQuestions) { question in
                            questionRow(for: question)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
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
        case .waterIntake:
            waterIntakeRow(for: question)
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

    @ViewBuilder
    private func notificationIntro(isTest: Bool) -> some View {
        if designStyle == .brutalist {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Text("From your reminder".uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                Text(focusQuestion?.text ?? "Log your latest update.")
                    .font(AppTheme.BrutalistTypography.headline)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)

                Text(
                    isTest
                        ? "This test reminder helps confirm your notification setup."
                        : "This reminder jumped you straight into logging—finish your check-in below."
                )
                .font(AppTheme.BrutalistTypography.body)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
            .brutalistCard()
        } else {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(focusQuestion?.text ?? "Log your latest update.")
                        .font(.headline)
                    Text(
                        isTest
                            ? "This test reminder helps confirm your notification setup."
                            : "This reminder jumped you straight into logging—finish your check-in below."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("From your reminder")
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .manual:
            return "Log Entry"
        case .notification:
            return "Quick Log"
        }
    }

    private var cancelButtonTitle: String {
        mode.isNotification ? "Later" : "Cancel"
    }

    private var orderedActiveQuestions: [Question] {
        var active = goal.questions.filter { $0.isActive }
        guard let focus = focusQuestion, let index = active.firstIndex(where: { $0.id == focus.id })
        else {
            return active
        }
        let highlighted = active.remove(at: index)
        active.insert(highlighted, at: 0)
        return active
    }

    private var focusQuestion: Question? {
        guard case .notification(let questionID?, _) = mode else { return nil }
        return goal.questions.first(where: { $0.id == questionID })
    }

    private func isFocusQuestion(_ question: Question) -> Bool {
        focusQuestion?.id == question.id
    }

    private func focusHighlight(for question: Question) -> Color? {
        guard let focusQuestion, focusQuestion.id == question.id else { return nil }
        return Color.accentColor.opacity(0.12)
    }

    @ViewBuilder
    private func numericRow(for question: Question) -> some View {
        let bounds = numericBounds(for: question)
        let valueBinding = Binding<Double>(
            get: { viewModel.numericValue(for: question, default: bounds.lowerBound) },
            set: { viewModel.updateNumericResponse($0, for: question) }
        )
        let currentValue = valueBinding.wrappedValue

        if designStyle == .brutalist {
            brutalistNumericRow(for: question, bounds: bounds, value: currentValue)
        } else {
            legacyNumericRow(
                for: question,
                bounds: bounds,
                valueBinding: valueBinding,
                currentValue: currentValue
            )
        }
    }

    private func legacyNumericRow(
        for question: Question,
        bounds: ClosedRange<Double>,
        valueBinding: Binding<Double>,
        currentValue: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.text)
                        .font(.headline)
                    deltaSummaryView(for: question)
                }
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
    }

    private func brutalistNumericRow(
        for question: Question,
        bounds: ClosedRange<Double>,
        value: Double
    ) -> some View {
        brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    brutalistStepperButton(
                        systemImage: "minus",
                        isDisabled: value <= bounds.lowerBound
                    ) {
                        adjustNumericValue(for: question, by: -1, bounds: bounds)
                    }

                    Text(value, format: .number)
                        .font(AppTheme.BrutalistTypography.bodyMono)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                        .frame(minWidth: 88)
                        .multilineTextAlignment(.center)

                    brutalistStepperButton(
                        systemImage: "plus",
                        isDisabled: value >= bounds.upperBound
                    ) {
                        adjustNumericValue(for: question, by: 1, bounds: bounds)
                    }
                }

                Text(
                    "Range \(formattedValue(bounds.lowerBound, for: question)) – \(formattedValue(bounds.upperBound, for: question))"
                )
                .font(AppTheme.BrutalistTypography.captionMono)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
        }
    }

    private func brutalistQuestionContainer<Content: View>(
        for question: Question,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            brutalistQuestionHeader(for: question)
            content()
        }
        .brutalistCard()
        .overlay(
            Rectangle()
                .stroke(
                    AppTheme.BrutalistPalette.accent,
                    lineWidth: AppTheme.BrutalistBorder.thick
                )
                .opacity(isFocusQuestion(question) ? 1 : 0)
        )
    }

    private func brutalistQuestionHeader(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            Text(question.text)
                .font(AppTheme.BrutalistTypography.headline)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
            deltaSummaryView(for: question)
        }
    }

    private func brutalistStepperButton(
        systemImage: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
        }
        .brutalistIconButton(variant: .neutral)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
    }

    private func adjustWaterIntake(
        by step: Double,
        within range: ClosedRange<Double>,
        for question: Question
    ) {
        let current = viewModel.waterIntakeDelta(for: question)
        let next = min(max(current + step, range.lowerBound), range.upperBound)
        guard next != current else { return }
        Haptics.selection()
        viewModel.setWaterIntake(next, for: question)
    }

    private func adjustNumericValue(
        for question: Question,
        by step: Double,
        bounds: ClosedRange<Double>
    ) {
        let current = viewModel.numericValue(for: question, default: bounds.lowerBound)
        let next = min(max(current + step, bounds.lowerBound), bounds.upperBound)
        guard next != current else { return }
        Haptics.selection()
        viewModel.updateNumericResponse(next, for: question)
    }

    private func setScaleValue(_ value: Int, for question: Question) {
        let current = Int(
            round(viewModel.numericValue(for: question, default: Double(value)))
        )
        guard current != value else { return }
        Haptics.selection()
        viewModel.updateNumericResponse(Double(value), for: question)
    }

    private func setBooleanValue(_ newValue: Bool, for question: Question) {
        let current = viewModel.booleanValue(for: question)
        guard current != newValue else { return }
        Haptics.selection()
        viewModel.updateBooleanResponse(newValue, for: question)
    }

    private func toggleOption(_ option: String, isSelected: Bool, for question: Question) {
        Haptics.selection()
        viewModel.setOption(option, isSelected: !isSelected, for: question)
    }

    @ViewBuilder
    private func scaleRow(for question: Question) -> some View {
        let bounds = scaleBounds(for: question)
        let binding = Binding<Int>(
            get: { Int(viewModel.numericValue(for: question, default: Double(bounds.lowerBound))) },
            set: { viewModel.updateNumericResponse(Double($0), for: question) }
        )
        if designStyle == .brutalist {
            brutalistScaleRow(for: question, bounds: bounds, value: binding.wrappedValue)
        } else {
            legacyScaleRow(for: question, bounds: bounds, binding: binding)
        }
    }

    private func legacyScaleRow(
        for question: Question,
        bounds: ClosedRange<Int>,
        binding: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.text)
                        .font(.headline)
                    deltaSummaryView(for: question)
                }
                Spacer()
                Stepper(value: binding, in: bounds) {
                    Text("\(binding.wrappedValue)")
                        .font(.headline)
                        .monospacedDigit()
                }
                .accessibilityHint("Increase or decrease today's progress")
            }
        }
    }

    private func brutalistScaleRow(
        for question: Question,
        bounds: ClosedRange<Int>,
        value: Int
    ) -> some View {
        let options = Array(bounds)

        return brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Text("Select a value".uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: 56, maximum: 72),
                            spacing: AppTheme.BrutalistSpacing.sm)
                    ],
                    spacing: AppTheme.BrutalistSpacing.sm
                ) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            setScaleValue(option, for: question)
                        } label: {
                            Text("\(option)")
                                .font(AppTheme.BrutalistTypography.bodyBold)
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(
                                    value == option
                                        ? AppTheme.BrutalistPalette.background
                                        : AppTheme.BrutalistPalette.foreground
                                )
                                .background(
                                    value == option
                                        ? AppTheme.BrutalistPalette.accent
                                        : AppTheme.BrutalistPalette.background
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            value == option
                                                ? AppTheme.BrutalistPalette.accent
                                                : AppTheme.BrutalistPalette.border,
                                            lineWidth: AppTheme.BrutalistBorder.standard
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Select \(option)")
                        .accessibilityAddTraits(value == option ? .isSelected : [])
                    }
                }

                Text(
                    "Current selection \(value) of \(options.count)"
                )
                .font(AppTheme.BrutalistTypography.captionMono)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
        }
    }

    @ViewBuilder
    private func sliderRow(for question: Question) -> some View {
        let bounds = sliderBounds(for: question)
        let intBinding = Binding<Int>(
            get: {
                let value = Int(
                    round(viewModel.numericValue(for: question, default: Double(bounds.lowerBound)))
                )
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

        if designStyle == .brutalist {
            brutalistSliderRow(
                for: question,
                bounds: bounds,
                sliderBinding: sliderBinding,
                intBinding: intBinding,
                doubleBounds: doubleBounds
            )
        } else {
            legacySliderRow(
                for: question,
                sliderBinding: sliderBinding,
                intBinding: intBinding,
                doubleBounds: doubleBounds
            )
        }
    }

    private func legacySliderRow(
        for question: Question,
        sliderBinding: Binding<Double>,
        intBinding: Binding<Int>,
        doubleBounds: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(.headline)
                deltaSummaryView(for: question)
            }
            Slider(value: sliderBinding, in: doubleBounds, step: 1)
            HStack {
                Spacer()
                Text("\(intBinding.wrappedValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func brutalistSliderRow(
        for question: Question,
        bounds: ClosedRange<Int>,
        sliderBinding: Binding<Double>,
        intBinding: Binding<Int>,
        doubleBounds: ClosedRange<Double>
    ) -> some View {
        brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    Slider(value: sliderBinding, in: doubleBounds, step: 1)
                        .tint(AppTheme.BrutalistPalette.accent)

                    HStack {
                        Text(formattedValue(Double(bounds.lowerBound), for: question))
                            .font(AppTheme.BrutalistTypography.captionMono)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        Spacer()
                        Text(formattedValue(Double(bounds.upperBound), for: question))
                            .font(AppTheme.BrutalistTypography.captionMono)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Selected".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    Spacer()
                    Text("\(intBinding.wrappedValue)")
                        .font(AppTheme.BrutalistTypography.bodyMono)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                }
            }
        }
    }

    @ViewBuilder
    private func waterIntakeRow(for question: Question) -> some View {
        if designStyle == .brutalist {
            brutalistWaterIntakeRow(for: question)
        } else {
            legacyWaterIntakeRow(for: question)
        }
    }

    private func legacyWaterIntakeRow(for question: Question) -> some View {
        let quickActions = HydrationQuickAddAction.presets
        let pending = viewModel.waterIntakeDelta(for: question)
        let deltaBinding = Binding<Double>(
            get: { viewModel.waterIntakeDelta(for: question) },
            set: { viewModel.setWaterIntake($0, for: question) }
        )
        let total = viewModel.waterIntakeTotal(for: question)
        let actionsPerRow = 2
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: actionsPerRow)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .font(.headline)
                deltaSummaryView(for: question)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Pending add \(formattedOunces(deltaBinding.wrappedValue))")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()

                Stepper(
                    value: deltaBinding,
                    in: waterIntakeDeltaRange(for: question),
                    step: 1
                ) {
                    Text("Adjust pending amount")
                        .font(.subheadline)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Today's total \(formattedOunces(total))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset amount") {
                        Haptics.selection()
                        viewModel.resetWaterIntake(for: question)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.pink)
                    .disabled(pending == 0)
                }
            }

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                ForEach(quickActions) { action in
                    Button {
                        Haptics.selection()
                        viewModel.incrementWaterIntake(by: action.ounces, for: question)
                    } label: {
                        HydrationQuickAddCard(action: action)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "Add \(formattedOunces(action.ounces)) via \(action.label)"
                    )
                }
            }
        }

    }

    private func brutalistWaterIntakeRow(for question: Question) -> some View {
        let quickActions = HydrationQuickAddAction.presets
        let range = waterIntakeDeltaRange(for: question)
        let pending = viewModel.waterIntakeDelta(for: question)
        let total = viewModel.waterIntakeTotal(for: question)

        return brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    Text("Pending amount".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)

                    HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                        brutalistStepperButton(
                            systemImage: "minus",
                            isDisabled: pending <= range.lowerBound
                        ) {
                            adjustWaterIntake(by: -1, within: range, for: question)
                        }

                        Text(HydrationFormatter.signedDelta(pending))
                            .font(AppTheme.BrutalistTypography.bodyMono)
                            .foregroundColor(AppTheme.BrutalistPalette.foreground)
                            .frame(minWidth: 96)
                            .multilineTextAlignment(.center)

                        brutalistStepperButton(
                            systemImage: "plus",
                            isDisabled: pending >= range.upperBound
                        ) {
                            adjustWaterIntake(by: 1, within: range, for: question)
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        Text("Today's total".uppercased())
                            .font(AppTheme.BrutalistTypography.overline)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        Text(HydrationFormatter.ouncesString(total))
                            .font(AppTheme.BrutalistTypography.bodyBold)
                            .foregroundColor(AppTheme.BrutalistPalette.foreground)
                    }
                    Spacer()
                    Button("Reset") {
                        Haptics.selection()
                        viewModel.resetWaterIntake(for: question)
                    }
                    .brutalistButton(style: .compactSecondary)
                    .disabled(pending == 0)
                    .opacity(pending == 0 ? 0.4 : 1)
                }

                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    Text("Quick add".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)

                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: AppTheme.BrutalistSpacing.sm),
                            count: 2
                        ),
                        spacing: AppTheme.BrutalistSpacing.sm
                    ) {
                        ForEach(quickActions) { action in
                            Button {
                                Haptics.selection()
                                viewModel.incrementWaterIntake(by: action.ounces, for: question)
                            } label: {
                                HydrationQuickAddCard(action: action)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "Add \(formattedOunces(action.ounces)) via \(action.label)"
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func booleanRow(for question: Question) -> some View {
        let binding = Binding(
            get: { viewModel.booleanValue(for: question) },
            set: { viewModel.updateBooleanResponse($0, for: question) }
        )

        if designStyle == .brutalist {
            brutalistBooleanRow(for: question, value: binding.wrappedValue)
        } else {
            legacyBooleanRow(for: question, binding: binding)
        }
    }

    private func legacyBooleanRow(
        for question: Question,
        binding: Binding<Bool>
    ) -> some View {
        Toggle(isOn: binding) {
            Text(question.text)
        }
    }

    private func brutalistBooleanRow(for question: Question, value: Bool) -> some View {
        brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Text("Choose an option".uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    brutalistBooleanOption(label: "Yes", isSelected: value) {
                        setBooleanValue(true, for: question)
                    }

                    brutalistBooleanOption(label: "No", isSelected: !value) {
                        setBooleanValue(false, for: question)
                    }
                }

                Text(value ? "Marked as YES" : "Marked as NO")
                    .font(AppTheme.BrutalistTypography.captionMono)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
        }
    }

    private func brutalistBooleanOption(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(AppTheme.BrutalistTypography.captionMono)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundColor(
                    isSelected
                        ? AppTheme.BrutalistPalette.background
                        : AppTheme.BrutalistPalette.foreground
                )
                .background(
                    isSelected
                        ? AppTheme.BrutalistPalette.accent
                        : AppTheme.BrutalistPalette.background
                )
                .overlay(
                    Rectangle()
                        .stroke(
                            isSelected
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.standard
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func textRow(for question: Question) -> some View {
        let binding = Binding(
            get: { viewModel.textValue(for: question) },
            set: { viewModel.updateTextResponse($0, for: question) }
        )

        if designStyle == .brutalist {
            brutalistTextRow(for: question, binding: binding)
        } else {
            legacyTextRow(for: question, binding: binding)
        }
    }

    private func legacyTextRow(
        for question: Question,
        binding: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
            TextField(
                "Enter response",
                text: binding,
                axis: .vertical
            )
            .platformAdaptiveTextField()
            .lineLimit(3, reservesSpace: true)
        }
    }

    private func brutalistTextRow(
        for question: Question,
        binding: Binding<String>
    ) -> some View {
        brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Text("Your response".uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                TextField(
                    "Enter response",
                    text: binding,
                    axis: .vertical
                )
                .lineLimit(3, reservesSpace: true)
                .brutalistField(isFocused: focusedTextQuestionID == question.id)
                .focused($focusedTextQuestionID, equals: question.id)
            }
        }
    }

    @ViewBuilder
    private func multipleChoiceRow(for question: Question) -> some View {
        if designStyle == .brutalist {
            brutalistMultipleChoiceRow(for: question)
        } else {
            legacyMultipleChoiceRow(for: question)
        }
    }

    private func legacyMultipleChoiceRow(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
            if let options = question.options, !options.isEmpty {
                ForEach(options, id: \.self) { option in
                    Toggle(
                        option,
                        isOn: Binding(
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

    @ViewBuilder
    private func brutalistMultipleChoiceRow(for question: Question) -> some View {
        if let options = question.options, !options.isEmpty {
            let selections = Set(viewModel.selectedOptions(for: question))

            brutalistQuestionContainer(for: question) {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    Text("Select all that apply".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)

                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                        ForEach(options, id: \.self) { option in
                            let isSelected = selections.contains(option)
                            Button {
                                toggleOption(option, isSelected: isSelected, for: question)
                            } label: {
                                HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                                    Image(
                                        systemName: isSelected ? "checkmark.square.fill" : "square"
                                    )
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(
                                        isSelected
                                            ? AppTheme.BrutalistPalette.accent
                                            : AppTheme.BrutalistPalette.foreground
                                    )

                                    Text(option)
                                        .font(AppTheme.BrutalistTypography.body)
                                        .foregroundColor(AppTheme.BrutalistPalette.foreground)

                                    Spacer()
                                }
                                .padding(.vertical, AppTheme.BrutalistSpacing.xs)
                                .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
                                .background(AppTheme.BrutalistPalette.background)
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            isSelected
                                                ? AppTheme.BrutalistPalette.accent
                                                : AppTheme.BrutalistPalette.border,
                                            lineWidth: AppTheme.BrutalistBorder.standard
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "\(option), \(isSelected ? "selected" : "not selected")"
                            )
                        }
                    }
                }
            }
        } else {
            brutalistQuestionContainer(for: question) {
                Text("No options configured")
                    .font(AppTheme.BrutalistTypography.captionMono)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
        }
    }

    @ViewBuilder
    private func timeRow(for question: Question) -> some View {
        let binding = Binding(
            get: {
                viewModel.timeValue(for: question, fallback: defaultTime())
            },
            set: { viewModel.updateTimeResponse($0, for: question) }
        )

        if designStyle == .brutalist {
            brutalistTimeRow(for: question, binding: binding)
        } else {
            legacyTimeRow(for: question, binding: binding)
        }
    }

    private func legacyTimeRow(
        for question: Question,
        binding: Binding<Date>
    ) -> some View {
        DatePicker(
            question.text,
            selection: binding,
            displayedComponents: .hourAndMinute
        )
    }

    private func brutalistTimeRow(
        for question: Question,
        binding: Binding<Date>
    ) -> some View {
        let selected = binding.wrappedValue
        return brutalistQuestionContainer(for: question) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Text("Select time".uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(AppTheme.BrutalistPalette.accent)

                Text(Self.timeFormatter.string(from: selected))
                    .font(AppTheme.BrutalistTypography.bodyMono)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    @ViewBuilder
    private func deltaSummaryView(for question: Question) -> some View {
        let summaryFont: Font =
            designStyle == .brutalist
            ? AppTheme.BrutalistTypography.captionMono : .caption
        let secondaryColor: Color =
            designStyle == .brutalist
            ? AppTheme.BrutalistPalette.secondary : Color.secondary
        let positiveDeltaColor: Color =
            designStyle == .brutalist ? AppTheme.BrutalistPalette.accent : .green
        let negativeDeltaColor: Color = designStyle == .brutalist ? .red : .pink

        if let preview = viewModel.numericChangePreview(for: question) {
            if let previous = preview.previousValue {
                let delta = preview.delta ?? (preview.resultingValue - previous)
                HStack(spacing: 6) {
                    Text(
                        "\(formattedValue(previous, for: question)) → \(formattedValue(preview.resultingValue, for: question))"
                    )
                    Text(formattedSignedDelta(delta, for: question))
                        .fontWeight(.semibold)
                        .foregroundColor(delta >= 0 ? positiveDeltaColor : negativeDeltaColor)
                }
                .font(summaryFont)
                .foregroundColor(secondaryColor)
            } else if preview.isDeltaBaseline {
                let delta = preview.delta ?? 0
                HStack(spacing: 6) {
                    Text("Add \(formattedAbsolute(delta, for: question))")
                    Text("Total \(formattedValue(preview.resultingValue, for: question))")
                }
                .font(summaryFont)
                .foregroundColor(secondaryColor)
            } else {
                Text("Will set to \(formattedValue(preview.resultingValue, for: question))")
                    .font(summaryFont)
                    .foregroundColor(secondaryColor)
            }
        } else {
            Text("Set today's value")
                .font(summaryFont)
                .foregroundColor(secondaryColor)
        }
    }

    private func formattedValue(_ value: Double, for question: Question) -> String {
        switch question.responseType {
        case .scale:
            return String(Int(value.rounded()))
        case .slider:
            return String(Int(value.rounded()))
        case .waterIntake:
            return formattedOunces(value)
        default:
            return value.formatted(.number.precision(.fractionLength(0...2)))
        }
    }

    private func formattedAbsolute(_ value: Double, for question: Question) -> String {
        switch question.responseType {
        case .waterIntake:
            return formattedOunces(abs(value))
        default:
            return formattedValue(abs(value), for: question)
        }
    }

    private func formattedSignedDelta(_ delta: Double, for question: Question) -> String {
        guard delta != 0 else { return "±0" }
        let sign = delta >= 0 ? "+" : "−"
        switch question.responseType {
        case .waterIntake:
            return HydrationFormatter.signedDelta(delta)
        default:
            return "\(sign)\(formattedAbsolute(delta, for: question))"
        }
    }

    private func waterIntakeDeltaRange(for question: Question) -> ClosedRange<Double> {
        viewModel.waterIntakeDeltaRange(for: question)
    }

    private func formattedOunces(_ value: Double) -> String {
        HydrationFormatter.ouncesString(value)
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

extension DataEntryView {
    enum Mode {
        case manual
        case notification(questionID: UUID?, isTest: Bool)

        var isNotification: Bool {
            if case .notification = self { return true }
            return false
        }
    }
}

private struct HydrationQuickAddAction: Identifiable {
    enum IconStyle {
        case bottle
        case tallGlass
        case shortGlass
        case largeCup

        var accentColor: Color {
            switch self {
            case .bottle:
                return .teal
            case .tallGlass:
                return .blue
            case .shortGlass:
                return .cyan
            case .largeCup:
                return .indigo
            }
        }

        var systemImage: String {
            switch self {
            case .bottle:
                return "drop.fill"
            case .tallGlass:
                return "drop.triangle.fill"
            case .shortGlass:
                return "drop.circle.fill"
            case .largeCup:
                return "humidity.fill"
            }
        }
    }

    let id: String
    let label: String
    let ounces: Double
    let iconStyle: IconStyle

    var accent: Color { iconStyle.accentColor }
    var systemImage: String { iconStyle.systemImage }
    var accessibilityLabel: String {
        "Add \(HydrationFormatter.ouncesString(ounces))"
    }

    static let presets: [HydrationQuickAddAction] = [
        .init(id: "hydration-bottle-17", label: "Bottle", ounces: 17, iconStyle: .bottle),
        .init(id: "hydration-tall-glass-15", label: "Tall", ounces: 15, iconStyle: .tallGlass),
        .init(id: "hydration-glass-19", label: "Glass", ounces: 19, iconStyle: .shortGlass),
        .init(id: "hydration-carafe-32", label: "Carafe", ounces: 32, iconStyle: .largeCup),
    ]
}

private struct HydrationQuickAddCard: View {
    let action: HydrationQuickAddAction

    var body: some View {
        if designStyle == .brutalist {
            brutalistBody
        } else {
            legacyBody
        }
    }

    @Environment(\.designStyle) private var designStyle

    private var legacyBody: some View {
        VStack(spacing: 8) {
            Image(systemName: action.systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(action.accent.gradient)
                .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text(action.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(HydrationFormatter.ouncesString(action.ounces))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(legacyBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(action.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private var brutalistBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(action.accent)

                Spacer()

                Text(HydrationFormatter.ouncesString(action.ounces))
                    .font(AppTheme.BrutalistTypography.bodyMono)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }

            Text(action.label.uppercased())
                .font(AppTheme.BrutalistTypography.captionBold)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(AppTheme.BrutalistSpacing.sm)
        .background(AppTheme.BrutalistPalette.background)
        .overlay(
            Rectangle()
                .stroke(action.accent, lineWidth: AppTheme.BrutalistBorder.standard)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private var legacyBackgroundColor: Color {
        #if os(iOS)
            Color(UIColor.secondarySystemBackground)
        #else
            Color.gray.opacity(0.12)
        #endif
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
            let goal = goals.first
        {
            DataEntryView(goal: goal, modelContext: context)
                .modelContainer(container)
        } else {
            Text("No sample goal")
        }
    } else {
        Text("Preview Error Loading Sample Data")
    }
}

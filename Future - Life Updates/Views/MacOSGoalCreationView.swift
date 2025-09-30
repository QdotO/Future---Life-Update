//
//  MacOSGoalCreationView.swift
//  Future - Life Updates
//
//  macOS-native goal creation flow with proper sheet sizing, text field styling,
//  and action button placement following macOS Human Interface Guidelines.
//

#if os(macOS)
    import SwiftUI
    import SwiftData

    struct MacOSGoalCreationView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var viewModel: GoalCreationFlowViewModel

        init(viewModel: GoalCreationViewModel) {
            let flowViewModel = GoalCreationFlowViewModel(legacyViewModel: viewModel)
            _viewModel = State(initialValue: flowViewModel)
        }

        var body: some View {
            MacOSGoalCreationSheet(viewModel: viewModel, dismiss: dismiss)
                .frame(width: 750, height: 650)
        }
    }

    private struct MacOSGoalCreationSheet: View {
        @Bindable var viewModel: GoalCreationFlowViewModel
        let dismiss: DismissAction

        @State private var step: FlowStep = .intent
        @FocusState private var focusedField: FocusField?
        @State private var showingErrorAlert = false
        @State private var errorMessage: String?

        // Question composer state
        @State private var editingQuestionID: UUID?
        @State private var composerText: String = ""
        @State private var composerResponseType: ResponseType = .boolean
        @State private var composerMinimum: Double = 0
        @State private var composerMaximum: Double = 10
        @State private var composerOptions: [String] = []
        @State private var newOptionText: String = ""
        @State private var composerAllowsEmpty: Bool = false
        @State private var composerError: String?
        @State private var showAdvancedTypes: Bool = false

        // Rhythm step state
        @State private var customReminderDate: Date = Date()
        @State private var scheduleError: String?
        @State private var conflictMessage: String?
        @State private var showAdvancedScheduling: Bool = false

        private enum FlowStep: Int, CaseIterable, Identifiable {
            case intent, prompts, rhythm, commitment, review

            var id: Int { rawValue }

            var title: String {
                switch self {
                case .intent: return "Goal Details"
                case .prompts: return "Tracking Questions"
                case .rhythm: return "Reminder Schedule"
                case .commitment: return "Motivation"
                case .review: return "Review"
                }
            }

            func previous() -> FlowStep? {
                guard rawValue > 0 else { return nil }
                return FlowStep(rawValue: rawValue - 1)
            }

            func next() -> FlowStep? {
                guard rawValue < FlowStep.allCases.count - 1 else { return nil }
                return FlowStep(rawValue: rawValue + 1)
            }

            var isFinal: Bool { self == .review }
        }

        private enum FocusField: Hashable {
            case title, motivation, customCategory, questionPrompt, newOption, customReminderTime,
                celebration
        }

        var body: some View {
            VStack(spacing: 0) {
                // Title bar with progress
                titleBar

                Divider()

                // Main content area
                ScrollView {
                    stepContent
                        .padding(24)
                }
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Action buttons at bottom
                actionBar
            }
            .alert("Unable to Create Goal", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }

        private var titleBar: some View {
            HStack(spacing: 16) {
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(FlowStep.allCases) { flowStep in
                        Circle()
                            .fill(
                                flowStep.rawValue <= step.rawValue
                                    ? Color.accentColor : Color.secondary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.leading, 24)

                Spacer()

                // Step title
                Text(step.title)
                    .font(.headline)

                Spacer()

                // Cancel button
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .padding(.trailing, 24)
            }
            .frame(height: 52)
            .background(.regularMaterial)
        }

        @ViewBuilder
        private var stepContent: some View {
            switch step {
            case .intent:
                intentStepContent
            case .prompts:
                promptsStepContent
            case .rhythm:
                rhythmStepContent
            case .commitment:
                commitmentStepContent
            case .review:
                reviewStepContent
            }
        }

        // MARK: - Prompts Step Content

        private var promptsStepContent: some View {
            HStack(alignment: .top, spacing: 20) {
                // Left panel: AI suggestions and templates (400pt)
                leftPanel
                    .frame(width: 400)

                // Right panel: Question composer and saved questions (330pt)
                rightPanel
                    .frame(width: 330)
            }
            .onAppear {
                focusedField = .questionPrompt
                if viewModel.supportsSuggestions && viewModel.suggestions.isEmpty {
                    viewModel.loadSuggestions()
                }
            }
        }

        private var leftPanel: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // AI Suggestions section
                    if let message = viewModel.suggestionAvailabilityMessage {
                        macOSCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Smart suggestions")
                                    .font(.headline)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if viewModel.supportsSuggestions {
                        macOSCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Generate with Apple Intelligence")
                                            .font(.headline)
                                        if let provider = viewModel.suggestionProviderName {
                                            Text(provider)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(
                                                "Get tailored questions based on your goal context."
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if viewModel.isLoadingSuggestions {
                                        ProgressView()
                                            .controlSize(.small)
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
                                        viewModel.suggestions.isEmpty
                                            ? "Generate suggestions" : "Regenerate suggestions",
                                        systemImage: "sparkles"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isLoadingSuggestions)
                                .controlSize(.large)

                                if let error = viewModel.suggestionError, !error.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.red)
                                        Text(error)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.red)
                                }

                                if !viewModel.suggestions.isEmpty {
                                    VStack(spacing: 12) {
                                        ForEach(viewModel.suggestions) { suggestion in
                                            macOSAISuggestionCard(suggestion: suggestion)
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }

                    // Template cards
                    let suggested = viewModel.recommendedTemplates(limit: 3)
                    if !suggested.isEmpty {
                        macOSCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested prompts")
                                    .font(.headline)
                                Text("Click to add ready-made questions tailored to your goal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 10) {
                                    ForEach(suggested, id: \.id) { template in
                                        macOSTemplateCard(
                                            template: template,
                                            isApplied: viewModel.appliedTemplateIDs.contains(
                                                template.id)
                                        )
                                    }
                                }

                                // More ideas section
                                let additional = viewModel.additionalTemplates(
                                    excluding: Set(suggested.map(\.id)))
                                if !additional.isEmpty {
                                    Divider()
                                        .padding(.vertical, 8)

                                    DisclosureGroup("More ideas (\(additional.count))") {
                                        VStack(spacing: 10) {
                                            ForEach(additional, id: \.id) { template in
                                                macOSTemplateCard(
                                                    template: template,
                                                    isApplied: viewModel.appliedTemplateIDs
                                                        .contains(template.id)
                                                )
                                            }
                                        }
                                        .padding(.top, 10)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }

        private var rightPanel: some View {
            VStack(spacing: 20) {
                // Question composer
                ScrollView {
                    macOSCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(
                                    editingQuestionID == nil
                                        ? "Create your own prompt" : "Edit prompt"
                                )
                                .font(.headline)
                                Spacer()
                                if editingQuestionID != nil {
                                    Button("Cancel") {
                                        resetComposer()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            // Question text field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Question")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                TextField(
                                    "What should Life Updates ask?", text: $composerText,
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                                .focused($focusedField, equals: .questionPrompt)
                            }

                            // Response type selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Response Type")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 8
                                ) {
                                    responseTypeButton(.boolean, icon: "checkmark.circle")
                                    responseTypeButton(.numeric, icon: "number")
                                    responseTypeButton(.scale, icon: "slider.horizontal.3")
                                    responseTypeButton(.text, icon: "text.alignleft")
                                }

                                Button {
                                    withAnimation {
                                        showAdvancedTypes.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(showAdvancedTypes ? "Hide advanced" : "More types")
                                            .font(.caption)
                                        Image(
                                            systemName: showAdvancedTypes
                                                ? "chevron.up" : "chevron.down"
                                        )
                                        .font(.caption)
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)

                                if showAdvancedTypes {
                                    LazyVGrid(
                                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                                        spacing: 8
                                    ) {
                                        responseTypeButton(.multipleChoice, icon: "list.bullet")
                                        responseTypeButton(.slider, icon: "dial.medium")
                                        responseTypeButton(.time, icon: "clock")
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }

                            // Configuration fields
                            configurationFields

                            // Toggle for optional
                            Toggle("Allow skipping this question", isOn: $composerAllowsEmpty)
                                .font(.subheadline)

                            // Error display
                            if let error = composerError {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(error)
                                        .font(.caption)
                                }
                                .foregroundStyle(.red)
                            }

                            // Actions
                            HStack(spacing: 12) {
                                if composerHasContent {
                                    Button("Clear") {
                                        resetComposer()
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Spacer()

                                Button(
                                    editingQuestionID == nil ? "Add question" : "Update question"
                                ) {
                                    saveQuestion()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canSaveQuestion)
                            }
                        }
                    }
                }

                // Saved questions list
                macOSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            let count = viewModel.draft.questionDrafts.count
                            let isReady = !viewModel.draft.questionDrafts.isEmpty

                            HStack(spacing: 8) {
                                Image(
                                    systemName: isReady
                                        ? "checkmark.circle.fill" : "exclamationmark.circle"
                                )
                                .foregroundStyle(isReady ? .green : .orange)
                                Text(isReady ? "Questions ready" : "Add at least one question")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        isReady
                                            ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            )
                            .foregroundStyle(isReady ? .green : .orange)

                            if count > 0 {
                                Text("\(count) saved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if viewModel.draft.questionDrafts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "text.badge.plus")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("Add a question to start tracking")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(
                                        Array(viewModel.draft.questionDrafts.enumerated()),
                                        id: \.element.id
                                    ) { index, question in
                                        macOSQuestionSummaryCard(question: question, index: index)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private var configurationFields: some View {
            switch composerResponseType {
            case .numeric, .scale, .slider:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Range")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    // Range presets
                    HStack(spacing: 8) {
                        rangePresetButton(min: 0, max: 10)
                        rangePresetButton(min: 1, max: 5)
                        rangePresetButton(min: 1, max: 10)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Minimum")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Stepper(
                                "\(Int(composerMinimum))", value: $composerMinimum,
                                in: -1000...composerMaximum
                            )
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Maximum")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Stepper(
                                "\(Int(composerMaximum))", value: $composerMaximum,
                                in: composerMinimum...1000
                            )
                            .labelsHidden()
                        }
                    }
                }

            case .multipleChoice:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Options")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if !composerOptions.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(composerOptions, id: \.self) { option in
                                HStack(spacing: 4) {
                                    Text(option)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Button {
                                        composerOptions.removeAll { $0 == option }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Add option", text: $newOptionText)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .newOption)
                            .onSubmit {
                                appendCurrentOption()
                            }

                        Button("Add") {
                            appendCurrentOption()
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

            default:
                EmptyView()
            }
        }

        private func responseTypeButton(_ type: ResponseType, icon: String) -> some View {
            Button {
                composerResponseType = type
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title3)
                    Text(type.displayName)
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            composerResponseType == type
                                ? Color.accentColor.opacity(0.1)
                                : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            composerResponseType == type
                                ? .accentColor : Color(nsColor: .separatorColor),
                            lineWidth: composerResponseType == type ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private func rangePresetButton(min: Double, max: Double) -> some View {
            Button("\(Int(min))–\(Int(max))") {
                composerMinimum = min
                composerMaximum = max
                Haptics.selection()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        private func macOSAISuggestionCard(suggestion: GoalSuggestion) -> some View {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    viewModel.applySuggestion(suggestion)
                }
                Haptics.success()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(suggestion.prompt)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(suggestion.responseType.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)

                        if !suggestion.options.isEmpty {
                            Text(
                                "\(suggestion.options.count) option\(suggestion.options.count == 1 ? "" : "s")"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let rationale = suggestion.rationale, !rationale.isEmpty {
                        Text(rationale)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Label("Add to goal", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }

        private func macOSTemplateCard(template: PromptTemplate, isApplied: Bool) -> some View {
            Button {
                viewModel.applyTemplate(template)
                Haptics.success()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: template.iconName)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(template.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(isApplied)
            .opacity(isApplied ? 0.6 : 1)
        }

        private func macOSQuestionSummaryCard(question: GoalQuestionDraft, index: Int) -> some View
        {
            HStack(spacing: 12) {
                // Number badge
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.accentColor))

                VStack(alignment: .leading, spacing: 4) {
                    Text(question.trimmedText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(question.responseType.displayName)
                            .font(.caption2)

                        if let detail = questionDetail(for: question) {
                            Text("•")
                                .font(.caption2)
                            Text(detail)
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)

                    // Source badges
                    if question.templateID != nil || question.suggestionID != nil {
                        HStack(spacing: 6) {
                            if question.templateID != nil {
                                Label("Template", systemImage: "text.book.closed")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                                    .foregroundStyle(.secondary)
                            }
                            if question.suggestionID != nil {
                                Label("AI", systemImage: "sparkles")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                Spacer()

                Menu {
                    Button("Edit") {
                        beginEditing(question)
                    }
                    Button("Move up") {
                        viewModel.reorderQuestions(
                            fromOffsets: IndexSet([index]), toOffset: max(0, index - 1))
                    }
                    .disabled(index == 0)
                    Button("Move down") {
                        viewModel.reorderQuestions(
                            fromOffsets: IndexSet([index]),
                            toOffset: min(viewModel.draft.questionDrafts.count, index + 2))
                    }
                    .disabled(index == viewModel.draft.questionDrafts.count - 1)
                    Divider()
                    Button("Delete", role: .destructive) {
                        viewModel.removeQuestion(question.id)
                        Haptics.warning()
                        if editingQuestionID == question.id {
                            resetComposer()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }

        private func macOSCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            content()
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        }

        // MARK: - Question Composer Helpers

        private var composerHasContent: Bool {
            !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private var canSaveQuestion: Bool {
            let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }

            if composerResponseType == .multipleChoice && composerOptions.count < 2 {
                return false
            }

            return true
        }

        private func resetComposer() {
            editingQuestionID = nil
            composerText = ""
            composerResponseType = .boolean
            composerMinimum = 0
            composerMaximum = 10
            composerOptions = []
            newOptionText = ""
            composerAllowsEmpty = false
            composerError = nil
            showAdvancedTypes = false
        }

        private func beginEditing(_ question: GoalQuestionDraft) {
            editingQuestionID = question.id
            composerText = question.text
            composerResponseType = question.responseType
            composerMinimum = question.validationRules?.minimumValue ?? 0
            composerMaximum = question.validationRules?.maximumValue ?? 10
            composerOptions = question.options
            composerAllowsEmpty = question.validationRules?.allowsEmpty ?? false
            composerError = nil

            // Show advanced types if needed
            if [ResponseType.multipleChoice, .slider, .time].contains(question.responseType) {
                showAdvancedTypes = true
            }

            focusedField = .questionPrompt
        }

        private func saveQuestion() {
            composerError = nil

            let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                composerError = "Question text is required"
                return
            }

            if composerResponseType == .multipleChoice && composerOptions.count < 2 {
                composerError = "Multiple choice requires at least 2 options"
                return
            }

            var validationRules: ValidationRules?
            if [ResponseType.numeric, .scale, .slider].contains(composerResponseType) {
                validationRules = ValidationRules(
                    minimumValue: composerMinimum,
                    maximumValue: composerMaximum,
                    allowsEmpty: composerAllowsEmpty
                )
            } else if composerAllowsEmpty {
                validationRules = ValidationRules(allowsEmpty: true)
            }

            let draft = GoalQuestionDraft(
                id: editingQuestionID ?? UUID(),
                text: trimmed,
                responseType: composerResponseType,
                options: composerResponseType == .multipleChoice ? composerOptions : [],
                validationRules: validationRules,
                isActive: true,
                templateID: nil,
                suggestionID: nil
            )

            if editingQuestionID != nil {
                viewModel.updateQuestion(draft)
            } else {
                viewModel.addCustomQuestion(draft)
            }

            Haptics.success()
            resetComposer()
        }

        private func appendCurrentOption() {
            let trimmed = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard !composerOptions.contains(trimmed) else {
                newOptionText = ""
                return
            }
            composerOptions.append(trimmed)
            newOptionText = ""
            Haptics.selection()
        }

        private func questionDetail(for question: GoalQuestionDraft) -> String? {
            var parts: [String] = []

            switch question.responseType {
            case .numeric, .scale, .slider:
                if let min = question.validationRules?.minimumValue,
                    let max = question.validationRules?.maximumValue
                {
                    parts.append("\(Int(min))–\(Int(max))")
                }
            case .multipleChoice:
                if !question.options.isEmpty {
                    parts.append("\(question.options.count) options")
                }
            default:
                break
            }

            if question.validationRules?.allowsEmpty == true {
                parts.append("Optional")
            }

            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        }

        // MARK: - Rhythm Step Content

        private var rhythmStepContent: some View {
            HStack(alignment: .top, spacing: 20) {
                // Left panel: Frequency selector and configuration (400pt)
                leftSchedulePanel
                    .frame(width: 400)

                // Right panel: Reminder times and timezone (330pt)
                rightSchedulePanel
                    .frame(width: 330)
            }
            .onAppear {
                customReminderDate = viewModel.suggestedReminderDate(startingAt: Date())
            }
        }

        private var leftSchedulePanel: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Conflict banner at top (if any)
                    if let conflictMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)

                            Text(conflictMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.orange.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Frequency selector card
                    macOSCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reminder Cadence")
                                .font(.headline)

                            // Frequency buttons (radio button style)
                            VStack(spacing: 6) {
                                ForEach(viewModel.cadencePresets()) { preset in
                                    frequencyButton(preset: preset)
                                }
                            }
                        }
                    }

                    // Configuration based on selected frequency
                    if case .weekly(let weekday) = viewModel.draft.schedule.cadence {
                        macOSCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select Weekday")
                                    .font(.headline)

                                // 7 weekday buttons in grid
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8),
                                    ],
                                    spacing: 8
                                ) {
                                    ForEach(Weekday.allCases) { day in
                                        weekdayButton(day: day, selectedWeekday: weekday)
                                    }
                                }
                            }
                        }
                    } else if case .custom(let interval) = viewModel.draft.schedule.cadence {
                        macOSCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Custom Interval")
                                    .font(.headline)

                                Stepper(
                                    value: Binding(
                                        get: { interval },
                                        set: { viewModel.updateCustomInterval(days: $0) }
                                    ), in: 2...30, step: 1
                                ) {
                                    HStack {
                                        Text("Every")
                                        Text("\(interval)")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.accentColor)
                                        Text("days")
                                    }
                                    .font(.body)
                                }
                                .controlSize(.large)

                                Text(
                                    "Reminders will repeat every \(interval) days from the start date."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Advanced scheduling options
                    DisclosureGroup(isExpanded: $showAdvancedScheduling) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Date")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                DatePicker(
                                    "Start Date",
                                    selection: Binding(
                                        get: { viewModel.draft.schedule.startDate },
                                        set: { newDate in
                                            viewModel.draft.schedule.startDate = newDate
                                            // TODO: Check for conflicts with other goals
                                        }
                                    ),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.field)
                                .labelsHidden()

                                Text("This is when your goal reminders will begin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Text("Advanced Scheduling")
                                .font(.headline)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .disclosureGroupStyle(.automatic)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                }
                .padding(16)
            }
        }

        private var rightSchedulePanel: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Reminder times card
                macOSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Reminder Times")
                                .font(.headline)
                            Spacer()
                            if !viewModel.draft.schedule.reminderTimes.isEmpty {
                                Text("\(viewModel.draft.schedule.reminderTimes.count)/3")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Status pill
                        HStack(spacing: 6) {
                            Image(
                                systemName: viewModel.canAdvanceFromSchedule()
                                    ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                            )
                            .foregroundStyle(viewModel.canAdvanceFromSchedule() ? .green : .orange)

                            Text(
                                viewModel.canAdvanceFromSchedule()
                                    ? "Reminders ready" : "Add at least one reminder"
                            )
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    viewModel.canAdvanceFromSchedule()
                                        ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                        )

                        Divider()

                        // Recommended times (if available)
                        let recommended = viewModel.recommendedReminderTimes()
                        if !recommended.isEmpty {
                            Text("Suggested Times")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8),
                                ],
                                spacing: 8
                            ) {
                                ForEach(recommended, id: \.self) { time in
                                    reminderTimeChip(
                                        time: time,
                                        isSelected: viewModel.draft.schedule.reminderTimes.contains(
                                            time))
                                }
                            }
                        }

                        // Added reminder times
                        if !viewModel.draft.schedule.reminderTimes.isEmpty {
                            Text("Active Reminders")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            ScrollView {
                                VStack(spacing: 6) {
                                    ForEach(viewModel.draft.schedule.reminderTimes, id: \.self) {
                                        time in
                                        HStack {
                                            Text(
                                                time.formattedTime(
                                                    in: viewModel.draft.schedule.timezone)
                                            )
                                            .font(.body)

                                            Spacer()

                                            Button {
                                                viewModel.removeReminderTime(time)
                                                Haptics.selection()
                                                scheduleError = nil
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        } else {
                            Text("Add at least one reminder time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }

                        Divider()

                        // Custom time picker (inline on macOS)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Custom Time")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                DatePicker(
                                    "Custom Time",
                                    selection: $customReminderDate,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.field)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)

                                Button {
                                    let succeeded = viewModel.addReminderDate(customReminderDate)
                                    if succeeded {
                                        scheduleError = nil
                                        Haptics.selection()
                                        // Advance to next suggestion
                                        customReminderDate = viewModel.suggestedReminderDate(
                                            startingAt: Calendar.current.date(
                                                byAdding: .minute, value: 30, to: customReminderDate
                                            ) ?? customReminderDate)
                                    } else {
                                        scheduleError =
                                            "Reminders must be at least 5 minutes apart and limited to 3."
                                        Haptics.warning()
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.large)
                                .disabled(viewModel.draft.schedule.reminderTimes.count >= 3)
                            }

                            if let scheduleError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(scheduleError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }

                // Timezone card
                macOSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timezone")
                            .font(.headline)

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
                        .labelsHidden()

                        Text(
                            "Times are saved in \(viewModel.draft.schedule.timezone.localizedDisplayName())."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(16)
        }

        // Helper: Frequency button (radio button style)
        private func frequencyButton(preset: CadencePreset) -> some View {
            let isSelected = selectedCadenceTag == preset.id

            return Button {
                updateCadence(with: preset.id)
                Haptics.selection()
            } label: {
                HStack {
                    Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .font(.body)

                    Text(preset.title)
                        .font(.body)
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isSelected ? 2 : 0.5)
                )
            }
            .buttonStyle(.plain)
        }

        // Helper: Weekday button
        private func weekdayButton(day: Weekday, selectedWeekday: Weekday) -> some View {
            let isSelected = day == selectedWeekday

            return Button {
                viewModel.selectCadence(.weekly(day))
                Haptics.selection()
            } label: {
                Text(day.shortDisplayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelected
                                    ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 2 : 1)
                    )
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .buttonStyle(.plain)
        }

        // Helper: Reminder time chip
        private func reminderTimeChip(time: ScheduleTime, isSelected: Bool) -> some View {
            Button {
                let succeeded = viewModel.toggleReminderTime(time)
                if succeeded {
                    scheduleError = nil
                    Haptics.selection()
                } else {
                    scheduleError = "Reminders must be at least 5 minutes apart or limited to 3."
                    Haptics.warning()
                }
            } label: {
                Text(time.formattedTime(in: viewModel.draft.schedule.timezone))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelected
                                    ? Color.accentColor.opacity(0.12)
                                    : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 2 : 1)
                    )
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .buttonStyle(.plain)
        }

        // Cadence helper
        private var selectedCadenceTag: String {
            switch viewModel.draft.schedule.cadence {
            case .daily: return "daily"
            case .weekdays: return "weekdays"
            case .weekly: return "weekly"
            case .custom: return "custom"
            }
        }

        private func updateCadence(with tag: String) {
            switch tag {
            case "daily":
                viewModel.selectCadence(.daily)
            case "weekdays":
                viewModel.selectCadence(.weekdays)
            case "weekly":
                // Default to Monday if switching to weekly
                viewModel.selectCadence(.weekly(.monday))
            case "custom":
                viewModel.selectCadence(.custom(intervalDays: 3))
            default:
                break
            }
        }

        // MARK: - Review Step Content

        private var reviewStepContent: some View {
            ScrollView {
                VStack(spacing: 16) {
                    // Goal summary card
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            VStack(alignment: .leading, spacing: 12) {
                                // Title and category
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(
                                        viewModel.draft.title.isEmpty
                                            ? "Untitled Goal" : viewModel.draft.title
                                    )
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)

                                    if let category = viewModel.draft.category {
                                        Text(
                                            category == .custom
                                                ? (viewModel.draft.normalizedCustomCategoryLabel
                                                    ?? category.displayName) : category.displayName
                                        )
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                // Motivation
                                if !viewModel.draft.motivation.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty {
                                    Text(
                                        viewModel.draft.motivation.trimmingCharacters(
                                            in: .whitespacesAndNewlines)
                                    )
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                }

                                // Celebration message
                                if !viewModel.draft.celebrationMessage.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "party.popper")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                        Text(
                                            viewModel.draft.celebrationMessage.trimmingCharacters(
                                                in: .whitespacesAndNewlines)
                                        )
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Edit button
                            Button(action: { step = .intent }) {
                                Text("Edit")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .padding([.top, .trailing], 20)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .cornerRadius(8)

                    // Questions card
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("Questions")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Button(action: { step = .prompts }) {
                                Text("Edit")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .padding(.bottom, 0)

                        // Questions list
                        if viewModel.draft.questionDrafts.isEmpty {
                            Text("No questions added yet")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(viewModel.draft.questionDrafts.enumerated()),
                                    id: \.element.id
                                ) { index, question in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Question text
                                        Text(question.trimmedText)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)

                                        // Response type
                                        Text(question.responseType.displayName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)

                                        // Source badges (AI suggestion / Template)
                                        if question.templateID != nil
                                            || question.suggestionID != nil
                                        {
                                            HStack(spacing: 8) {
                                                if question.templateID != nil {
                                                    sourceBadge(
                                                        label: "Template",
                                                        systemImage: "text.book.closed",
                                                        tint: Color.secondary)
                                                }
                                                if question.suggestionID != nil {
                                                    sourceBadge(
                                                        label: "AI suggestion",
                                                        systemImage: "sparkles",
                                                        tint: Color.accentColor)
                                                }
                                            }
                                        }

                                        // Question details (range, options, etc.)
                                        if let detail = questionDetail(for: question) {
                                            Text(detail)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)

                                    if index < viewModel.draft.questionDrafts.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .cornerRadius(8)

                    // Schedule/Reminders card
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("Reminders")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Button(action: { step = .rhythm }) {
                                Text("Edit")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            // Cadence
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(cadenceDescription)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                            }

                            // Reminder times
                            if viewModel.draft.schedule.reminderTimes.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.slash")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                    Text("No reminder times selected")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bell")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Text("Reminder times:")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }

                                    ForEach(viewModel.draft.schedule.reminderTimes, id: \.self) {
                                        time in
                                        Text(
                                            "• \(time.formattedTime(in: viewModel.draft.schedule.timezone))"
                                        )
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .padding(.leading, 19)
                                    }
                                }
                            }

                            // Timezone
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(viewModel.draft.schedule.timezone.localizedDisplayName())
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .padding(24)
            }
        }

        // MARK: - Review Step Helpers

        private var cadenceDescription: String {
            switch viewModel.draft.schedule.cadence {
            case .daily:
                return "Daily"
            case .weekdays:
                return "Weekdays (Mon–Fri)"
            case .weekly(let weekday):
                return "Weekly on \(weekday.displayName)"
            case .custom(let interval):
                return "Every \(interval) days"
            }
        }

        private func sourceBadge(label: String, systemImage: String, tint: Color) -> some View {
            Label(label, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                )
                .foregroundStyle(tint)
        }

        // MARK: - Commitment Step Content

        private var commitmentStepContent: some View {
            VStack(alignment: .leading, spacing: 24) {
                // Main card with celebration message
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Give future-you a boost")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(
                            "Add an optional encouragement or celebration message we'll surface when you log progress."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Encouragement (Optional)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        TextField(
                            "How will you celebrate showing up?",
                            text: Binding(
                                get: { viewModel.draft.celebrationMessage },
                                set: { viewModel.draft.celebrationMessage = $0 }
                            ),
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                        .font(.body)
                        .focused($focusedField, equals: .celebration)

                        // Character counter
                        let characterCount = viewModel.draft.celebrationMessage.count
                        let maxCharacters = 200
                        HStack {
                            Spacer()
                            Text("\(characterCount)/\(maxCharacters)")
                                .font(.caption2)
                                .foregroundStyle(characterCount > maxCharacters ? .red : .secondary)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                // Helper examples card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.body)

                        Text("Examples")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        exampleChip(text: "You did it! One step closer to your goal.")
                        exampleChip(text: "Keep going! You're building momentum.")
                        exampleChip(text: "Progress! Future-you will thank you.")
                        exampleChip(text: "Yes! Another day of showing up.")
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 0.5)
                )

                Spacer()
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .onAppear {
                focusedField = .celebration
            }
        }

        // Helper: Example chip button
        private func exampleChip(text: String) -> some View {
            Button {
                viewModel.draft.celebrationMessage = text
                Haptics.selection()
            } label: {
                HStack {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }

        // MARK: - Intent Step Content

        private var intentStepContent: some View {
            VStack(alignment: .leading, spacing: 24) {
                // Goal name and motivation
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Name")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        TextField(
                            "Name your goal",
                            text: Binding(
                                get: { viewModel.draft.title },
                                set: { viewModel.updateTitle($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .focused($focusedField, equals: .title)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Motivation (Optional)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        TextField(
                            "Why does this matter to you?",
                            text: Binding(
                                get: { viewModel.draft.motivation },
                                set: { viewModel.draft.motivation = $0 }
                            ),
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                        .font(.body)
                        .focused($focusedField, equals: .motivation)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                // Focus area selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Focus Area")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 12
                    ) {
                        ForEach(
                            [TrackingCategory.fitness, .health, .productivity, .habits, .mood],
                            id: \.self
                        ) { category in
                            macOSCategoryButton(category: category)
                        }

                        Button {
                            viewModel.selectCategory(.custom)
                            focusedField = .customCategory
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Something else…")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text("Name your own")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        viewModel.draft.category == .custom
                                            ? Color.accentColor.opacity(0.1)
                                            : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        viewModel.draft.category == .custom
                                            ? Color.accentColor : Color(nsColor: .separatorColor),
                                        lineWidth: viewModel.draft.category == .custom ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.draft.category == .custom {
                        TextField(
                            "Custom category name",
                            text: Binding(
                                get: { viewModel.draft.customCategoryLabel },
                                set: { viewModel.updateCustomCategoryLabel($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .customCategory)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                // Requirements checklist
                VStack(alignment: .leading, spacing: 12) {
                    Text("Requirements")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    macOSChecklistRow(
                        title: "Goal name",
                        isComplete: !viewModel.draft.title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty,
                        isRequired: true
                    )

                    macOSChecklistRow(
                        title: "Focus area",
                        isComplete: viewModel.draft.category != nil
                            && (viewModel.draft.category != .custom
                                || !viewModel.draft.customCategoryLabel.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty),
                        isRequired: true
                    )

                    macOSChecklistRow(
                        title: "Motivation",
                        isComplete: !viewModel.draft.motivation.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty,
                        isRequired: false
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
        }

        private func macOSCategoryButton(category: TrackingCategory) -> some View {
            let isSelected = viewModel.draft.category == category

            return Button {
                viewModel.selectCategory(category)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.displayName)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(categorySubtitle(for: category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(0.1)
                                : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private func categorySubtitle(for category: TrackingCategory) -> String {
            switch category {
            case .fitness: return "Exercise & activity"
            case .health: return "Wellness & care"
            case .productivity: return "Focus & output"
            case .habits: return "Daily routines"
            case .mood: return "Emotional state"
            default: return ""
            }
        }

        private func macOSChecklistRow(title: String, isComplete: Bool, isRequired: Bool)
            -> some View
        {
            HStack(spacing: 12) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isComplete ? .green : .secondary)
                    .font(.title3)

                Text(title)
                    .font(.body)

                Spacer()

                if !isRequired {
                    Text("Optional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        private var actionBar: some View {
            HStack(spacing: 12) {
                // Help text on left
                if let hint = forwardHint() {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Navigation buttons on right
                if let previousStep = step.previous() {
                    Button("Back") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            step = previousStep
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("[", modifiers: .command)
                }

                Button(step.isFinal ? "Create Goal" : "Next") {
                    if step.isFinal {
                        handleSave()
                    } else {
                        moveForward()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdvance())
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(.regularMaterial)
        }

        private func canAdvance() -> Bool {
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

        private func forwardHint() -> String? {
            guard !canAdvance() else { return nil }

            let trimmedTitle = viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasCategory = viewModel.draft.category != nil
            let hasValidCustom =
                viewModel.draft.category != .custom
                || !viewModel.draft.customCategoryLabel.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty

            switch step {
            case .intent:
                if trimmedTitle.isEmpty {
                    return "Add a goal name to continue"
                }
                if !hasCategory || !hasValidCustom {
                    return "Select a focus area to continue"
                }
                return nil
            case .prompts:
                return "Add at least one tracking question"
            case .rhythm:
                return "Add at least one reminder time"
            default:
                return nil
            }
        }

        private func moveForward() {
            guard let next = step.next() else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                step = next
            }
        }

        private func handleSave() {
            do {
                let goal = try viewModel.saveGoal()
                NotificationScheduler.shared.scheduleNotifications(for: goal)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }

    #Preview {
        if let container = try? PreviewSampleData.makePreviewContainer() {
            let context = container.mainContext
            let viewModel = GoalCreationViewModel(modelContext: context)
            return MacOSGoalCreationView(viewModel: viewModel)
                .modelContainer(container)
        } else {
            return Text("Preview unavailable")
        }
    }
#endif

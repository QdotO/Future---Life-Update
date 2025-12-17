import SwiftData
import SwiftUI

// MARK: - Conversation Message Model

private struct ConversationMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromCoach: Bool
    let timestamp: Date
    var isTyping: Bool = false

    static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Flow State (Replaces scripted steps)

private enum FlowState: Equatable {
    case greeting
    case awaitingGoalInput
    case inferring
    case reviewingInference
    case editingDetail(DetailType)
    case confirmAndCreate
    case complete

    enum DetailType: String, Equatable {
        case category
        case trackingMethod
        case frequency
        case reminderTime
    }
}

// MARK: - Conversational Goal Creation View (Intelligent)

/// A conversational goal creation experience powered by Apple's on-device Foundation Models.
/// The LLM intelligently infers goal configuration from natural language, minimizing questions.
struct ConversationalGoalCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - State
    @State private var messages: [ConversationMessage] = []
    @State private var isCoachTyping = false
    @State private var userInput = ""
    @FocusState private var isInputFocused: Bool

    // Goal inference service (on-device LLM)
    @State private var inferenceService = GoalInferenceService()
    @State private var inferredConfig: InferredGoalConfiguration?
    @State private var isInferring = false

    // Goal data (populated by inference or user override)
    @State private var goalTitle = ""
    @State private var goalDescription = ""
    @State private var selectedCategory: TrackingCategory?
    @State private var trackingMethod: ResponseType = .boolean
    @State private var frequency: Frequency = .daily
    @State private var reminderTime: ScheduleTime?
    @State private var trackingQuestion: String = ""

    // Flow state
    @State private var flowState: FlowState = .greeting
    @State private var isCreatingGoal = false
    @State private var showSuccessAnimation = false

    private let coachTypingDelay: TimeInterval = 0.8

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.BrutalistPalette.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // AI availability indicator
                    if !inferenceService.isAvailable {
                        aiUnavailableBanner
                    }

                    // Conversation area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                if isCoachTyping || isInferring {
                                    TypingIndicator(isThinking: isInferring)
                                        .id("typing")
                                }

                                // Inline inference result card
                                if let config = inferredConfig, flowState == .reviewingInference {
                                    InferenceResultCard(
                                        config: config,
                                        onConfirm: confirmInference,
                                        onEdit: { detail in
                                            flowState = .editingDetail(detail)
                                        }
                                    )
                                    .id("inference-card")
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .bottom).combined(
                                                with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .padding(.horizontal, AppTheme.BrutalistSpacing.lg)
                            .padding(.vertical, AppTheme.BrutalistSpacing.md)
                        }
                        .onChange(of: messages.count) { _, _ in
                            withAnimation(.spring(response: 0.3)) {
                                proxy.scrollTo(messages.last?.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: isCoachTyping) { _, isTyping in
                            if isTyping {
                                withAnimation(.spring(response: 0.3)) {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: inferredConfig) { _, _ in
                            withAnimation(.spring(response: 0.3)) {
                                proxy.scrollTo("inference-card", anchor: .bottom)
                            }
                        }
                    }

                    // Input area
                    inputArea
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                inferenceService.prewarm()
                startConversation()
            }
        }
    }

    // MARK: - AI Unavailable Banner

    private var aiUnavailableBanner: some View {
        HStack(spacing: AppTheme.BrutalistSpacing.sm) {
            Image(systemName: "cpu")
                .foregroundColor(AppTheme.BrutalistPalette.warning)
            Text("Using simplified mode – Apple Intelligence not available")
                .font(AppTheme.BrutalistTypography.caption)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .padding(.horizontal, AppTheme.BrutalistSpacing.md)
        .padding(.vertical, AppTheme.BrutalistSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppTheme.BrutalistPalette.surface)
    }

    // MARK: - Input Area

    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(AppTheme.BrutalistPalette.border)
                .frame(height: 1)

            VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                // Show quick replies for editing states
                if case .editingDetail(let detail) = flowState {
                    editingQuickReplies(for: detail)
                } else if flowState == .greeting || flowState == .awaitingGoalInput {
                    // Suggestion chips for getting started
                    goalSuggestionChips
                    textInputField
                }
            }
            .padding(.horizontal, AppTheme.BrutalistSpacing.lg)
            .padding(.vertical, AppTheme.BrutalistSpacing.md)
            .background(AppTheme.BrutalistPalette.surface)
        }
    }

    private var goalSuggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                ForEach(
                    [
                        ("💧", "Drink more water"),
                        ("🏃", "Exercise daily"),
                        ("📚", "Read every day"),
                        ("🧘", "Meditate"),
                        ("😴", "Sleep better"),
                        ("✍️", "Journal"),
                    ], id: \.1
                ) { emoji, text in
                    Button {
                        handleGoalInput("\(emoji) \(text)")
                    } label: {
                        Text("\(emoji) \(text)")
                            .font(AppTheme.BrutalistTypography.caption)
                            .fontWeight(.semibold)
                            .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                            .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                                    .stroke(AppTheme.BrutalistPalette.accent, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                }
            }
        }
    }

    private var textInputField: some View {
        HStack(spacing: AppTheme.BrutalistSpacing.sm) {
            TextField("What do you want to track?", text: $userInput, axis: .vertical)
                .focused($isInputFocused)
                .font(AppTheme.BrutalistTypography.body)
                .lineLimit(1...3)
                .padding(AppTheme.BrutalistSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .fill(AppTheme.BrutalistPalette.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .stroke(
                            isInputFocused
                                ? AppTheme.BrutalistPalette.accent
                                : AppTheme.BrutalistPalette.border,
                            lineWidth: isInputFocused ? 2 : 1
                        )
                )
                .onSubmit {
                    handleGoalInput(userInput)
                }

            Button {
                handleGoalInput(userInput)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.BrutalistPalette.secondary
                            : AppTheme.BrutalistPalette.accent
                    )
            }
            .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private func editingQuickReplies(for detail: FlowState.DetailType) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            switch detail {
            case .category:
                Text("Pick a different category:")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                QuickReplyChips(
                    options: TrackingCategory.allCases.filter { $0 != .custom },
                    labelProvider: { $0.displayName },
                    iconProvider: { categoryIcon(for: $0) },
                    colorProvider: { categoryColor(for: $0) }
                ) { category in
                    selectedCategory = category
                    updateInferenceWith(category: category)
                }

            case .trackingMethod:
                Text("Change tracking style:")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                QuickReplyChips(
                    options: [ResponseType.boolean, .numeric, .scale, .text],
                    labelProvider: { trackingMethodLabel(for: $0) },
                    iconProvider: { trackingMethodIcon(for: $0) },
                    colorProvider: { _ in AppTheme.BrutalistPalette.accent }
                ) { method in
                    trackingMethod = method
                    updateInferenceWith(trackingMethod: method)
                }

            case .frequency:
                Text("Change frequency:")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                QuickReplyChips(
                    options: [Frequency.daily, .weekly],
                    labelProvider: { frequencyLabel(for: $0) },
                    iconProvider: { frequencyIcon(for: $0) },
                    colorProvider: { _ in AppTheme.BrutalistPalette.accent }
                ) { freq in
                    frequency = freq
                    updateInferenceWith(frequency: freq)
                }

            case .reminderTime:
                Text("Change reminder time:")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                QuickReplyChips(
                    options: InferredTimeSlot.allCases,
                    labelProvider: { $0.displayName },
                    iconProvider: { timeSlotIcon(for: $0) },
                    colorProvider: { _ in AppTheme.BrutalistPalette.accent }
                ) { slot in
                    reminderTime = slot.toScheduleTime()
                    updateInferenceWith(timeSlot: slot)
                }
            }

            Button {
                flowState = .reviewingInference
            } label: {
                Text("Done")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                            .fill(AppTheme.BrutalistPalette.accent)
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
    }

    private func timeSlotIcon(for slot: InferredTimeSlot) -> String {
        switch slot {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.fill"
        }
    }

    // MARK: - Conversation Logic

    private func startConversation() {
        flowState = .greeting
        Task {
            await simulateTypingAndSend("Hey! 👋 What would you like to track?")
            flowState = .awaitingGoalInput
        }
    }

    private func addCoachMessage(_ text: String) {
        let message = ConversationMessage(
            content: text,
            isFromCoach: true,
            timestamp: Date()
        )
        withAnimation(.spring(response: 0.3)) {
            messages.append(message)
        }
        Haptics.selection()
    }

    private func addUserMessage(_ text: String) {
        let message = ConversationMessage(
            content: text,
            isFromCoach: false,
            timestamp: Date()
        )
        withAnimation(.spring(response: 0.3)) {
            messages.append(message)
        }
    }

    private func simulateTypingAndSend(_ text: String) async {
        isCoachTyping = true

        // Simulate typing delay based on message length
        let delay = min(1.2, max(0.5, Double(text.count) / 80.0))
        try? await Task.sleep(for: .seconds(delay))

        isCoachTyping = false
        addCoachMessage(text)
    }

    // MARK: - Goal Input Handling (Intelligent Inference)

    private func handleGoalInput(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        addUserMessage(trimmed)
        userInput = ""
        goalDescription = trimmed

        flowState = .inferring
        isInferring = true

        Task {
            await inferGoalFromInput(trimmed)
        }
    }

    private func inferGoalFromInput(_ input: String) async {
        // Try on-device LLM first
        if inferenceService.isAvailable {
            do {
                let config = try await inferenceService.inferGoalConfiguration(from: input)
                applyInferredConfiguration(config)

                isInferring = false

                // Show what we inferred
                let responseText = buildInferenceResponseMessage(config)
                await simulateTypingAndSend(responseText)

                flowState = .reviewingInference

            } catch {
                // Fall back to keyword-based inference
                isInferring = false
                let fallbackConfig = FallbackGoalInference.infer(from: input)
                applyInferredConfiguration(fallbackConfig)

                let responseText = buildInferenceResponseMessage(fallbackConfig)
                await simulateTypingAndSend(responseText)

                flowState = .reviewingInference
            }
        } else {
            // Use fallback inference (device doesn't support Foundation Models)
            isInferring = false
            let fallbackConfig = FallbackGoalInference.infer(from: input)
            applyInferredConfiguration(fallbackConfig)

            let responseText = buildInferenceResponseMessage(fallbackConfig)
            await simulateTypingAndSend(responseText)

            flowState = .reviewingInference
        }
    }

    private func applyInferredConfiguration(_ config: InferredGoalConfiguration) {
        inferredConfig = config
        goalTitle = config.title
        selectedCategory = config.category.toTrackingCategory()
        trackingMethod = config.trackingMethod.toResponseType()
        frequency = config.frequency.toFrequency()
        reminderTime = config.suggestedReminderSlot.toScheduleTime()
        trackingQuestion = config.trackingQuestion
    }

    private func buildInferenceResponseMessage(_ config: InferredGoalConfiguration) -> String {
        let categoryEmoji = categoryEmoji(for: config.category.toTrackingCategory())
        let timeEmoji = timeSlotEmoji(for: config.suggestedReminderSlot)

        return """
            Got it! Here's what I set up for you:

            \(categoryEmoji) **\(config.title)** (\(config.category.rawValue.capitalized))
            📊 \(trackingMethodLabel(for: config.trackingMethod.toResponseType()))
            🔄 \(frequencyLabel(for: config.frequency.toFrequency()))
            \(timeEmoji) \(config.suggestedReminderSlot.displayName)

            \(config.motivationalMessage)
            """
    }

    private func updateInferenceWith(
        category: TrackingCategory? = nil, trackingMethod: ResponseType? = nil,
        frequency: Frequency? = nil, timeSlot: InferredTimeSlot? = nil
    ) {
        // Update the inferred config with user's override
        if var config = inferredConfig {
            if let cat = category {
                config = InferredGoalConfiguration(
                    title: config.title,
                    category: InferredCategory(rawValue: cat.rawValue.lowercased())
                        ?? config.category,
                    trackingMethod: config.trackingMethod,
                    frequency: config.frequency,
                    trackingQuestion: config.trackingQuestion,
                    suggestedReminderSlot: config.suggestedReminderSlot,
                    motivationalMessage: config.motivationalMessage,
                    confidenceScore: config.confidenceScore
                )
            }
            inferredConfig = config
        }

        addCoachMessage("Updated! ✓")
        Haptics.success()
    }

    // MARK: - Confirmation & Goal Creation

    private func confirmInference() {
        flowState = .confirmAndCreate

        Task {
            await simulateTypingAndSend("Perfect! Creating your goal now... 🚀")
            await createGoal()
        }
    }

    private func createGoal() async {
        isCreatingGoal = true

        do {
            // Build schedule
            let schedule = Schedule(
                startDate: Date(),
                frequency: frequency,
                times: reminderTime != nil ? [reminderTime!] : [],
                timezoneIdentifier: TimeZone.current.identifier
            )

            // Create the goal
            let goal = TrackingGoal(
                title: goalTitle,
                description: goalDescription,
                category: selectedCategory ?? .habits,
                schedule: schedule
            )

            // Create question
            let question = Question(
                text: trackingQuestion.isEmpty ? "How did it go today?" : trackingQuestion,
                responseType: trackingMethod,
                validationRules: validationRules(for: trackingMethod)
            )
            question.goal = goal
            goal.questions = [question]
            schedule.goal = goal

            // Insert and save
            modelContext.insert(goal)
            try modelContext.save()

            flowState = .complete
            addCoachMessage("🎉 Done! Your goal \"\(goalTitle)\" is ready. You've got this!")

            Haptics.success()
            showSuccessAnimation = true

            try? await Task.sleep(for: .seconds(1.5))
            dismiss()

        } catch {
            addCoachMessage("Oops, something went wrong. Let's try again!")
            flowState = .reviewingInference
            isCreatingGoal = false
        }
    }

    private func validationRules(for type: ResponseType) -> ValidationRules? {
        switch type {
        case .numeric:
            return ValidationRules(minimumValue: 0, maximumValue: 100, allowsEmpty: false)
        case .scale:
            return ValidationRules(minimumValue: 1, maximumValue: 10, allowsEmpty: false)
        default:
            return nil
        }
    }

    private func categoryEmoji(for category: TrackingCategory) -> String {
        switch category {
        case .health: return "💚"
        case .fitness: return "💪"
        case .productivity: return "🎯"
        case .habits: return "🔄"
        case .mood: return "🧘"
        case .learning: return "📚"
        case .social: return "👥"
        case .finance: return "💰"
        case .custom: return "⭐"
        }
    }

    private func timeSlotEmoji(for slot: InferredTimeSlot) -> String {
        switch slot {
        case .morning: return "🌅"
        case .midday: return "☀️"
        case .evening: return "🌆"
        case .night: return "🌙"
        }
    }

    // MARK: - Helpers

    private func categoryIcon(for category: TrackingCategory) -> String {
        switch category {
        case .health: return "heart.fill"
        case .fitness: return "figure.run"
        case .productivity: return "chart.bar.fill"
        case .habits: return "repeat"
        case .mood: return "face.smiling"
        case .learning: return "book.fill"
        case .social: return "person.2.fill"
        case .finance: return "dollarsign.circle.fill"
        case .custom: return "star.fill"
        }
    }

    private func categoryColor(for category: TrackingCategory) -> Color {
        switch category {
        case .health: return AppTheme.BrutalistPalette.categoryHealth
        case .fitness: return AppTheme.BrutalistPalette.categoryFitness
        case .productivity: return AppTheme.BrutalistPalette.categoryProductivity
        case .habits: return AppTheme.BrutalistPalette.categoryHabits
        case .mood: return AppTheme.BrutalistPalette.categoryMood
        case .learning: return AppTheme.BrutalistPalette.categoryLearning
        case .social: return AppTheme.BrutalistPalette.categorySocial
        case .finance: return AppTheme.BrutalistPalette.categoryFinance
        case .custom: return AppTheme.BrutalistPalette.accent
        }
    }

    private func trackingMethodLabel(for type: ResponseType) -> String {
        switch type {
        case .boolean: return "Yes / No"
        case .numeric: return "Count it"
        case .scale: return "Rate 1-10"
        case .text: return "Write about it"
        case .slider: return "Slider"
        case .multipleChoice: return "Multiple choice"
        case .time: return "Log a time"
        case .waterIntake: return "Water intake"
        }
    }

    private func trackingMethodIcon(for type: ResponseType) -> String {
        switch type {
        case .boolean: return "checkmark.circle"
        case .numeric: return "number"
        case .scale: return "chart.bar"
        case .text: return "text.alignleft"
        case .slider: return "slider.horizontal.3"
        case .multipleChoice: return "list.bullet"
        case .time: return "clock"
        case .waterIntake: return "drop.fill"
        }
    }

    private func frequencyLabel(for freq: Frequency) -> String {
        switch freq {
        case .once: return "Just once"
        case .daily: return "Every day"
        case .weekly: return "Once a week"
        case .monthly: return "Monthly"
        case .custom: return "Custom schedule"
        }
    }

    private func frequencyIcon(for freq: Frequency) -> String {
        switch freq {
        case .once: return "1.circle"
        case .daily: return "sun.max"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Message Bubble Component

private struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.BrutalistSpacing.sm) {
            if message.isFromCoach {
                // Coach avatar
                Circle()
                    .fill(AppTheme.BrutalistPalette.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("🌱")
                            .font(.system(size: 18))
                    )

                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                    Text(message.content)
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                        .padding(AppTheme.BrutalistSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                                .fill(AppTheme.BrutalistPalette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                                .stroke(AppTheme.BrutalistPalette.border, lineWidth: 1)
                        )
                }

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 60)

                Text(message.content)
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(.white)
                    .padding(AppTheme.BrutalistSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                            .fill(AppTheme.BrutalistPalette.accent)
                    )
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: message.isFromCoach ? .leading : .trailing)
                    .combined(with: .opacity),
                removal: .opacity
            ))
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    var isThinking: Bool = false
    @State private var animationPhase = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.BrutalistSpacing.sm) {
            // Coach avatar
            Circle()
                .fill(AppTheme.BrutalistPalette.accent.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(isThinking ? "🤔" : "🌱")
                        .font(.system(size: 18))
                )

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(
                                isThinking
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.secondary
                            )
                            .frame(width: 8, height: 8)
                            .offset(y: animationOffset(for: index))
                    }
                }
                .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                        .fill(AppTheme.BrutalistPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                        .stroke(AppTheme.BrutalistPalette.border, lineWidth: 1)
                )

                if isThinking {
                    Text("Analyzing your goal...")
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationPhase = 1.0
            }
        }
    }

    private func animationOffset(for index: Int) -> CGFloat {
        let phase = animationPhase + Double(index) * 0.2
        return sin(phase * .pi * 2) * 4
    }
}

// MARK: - Inference Result Card

private struct InferenceResultCard: View {
    let config: InferredGoalConfiguration
    let onConfirm: () -> Void
    let onEdit: (FlowState.DetailType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppTheme.BrutalistPalette.accent)
                Text("Here's what I set up")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                Spacer()

                // Confidence indicator
                if config.confidenceScore > 0.8 {
                    Label("High confidence", systemImage: "checkmark.seal.fill")
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundColor(AppTheme.BrutalistPalette.success)
                }
            }

            // Configuration rows
            VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                editableRow(
                    icon: "folder",
                    label: "Category",
                    value: config.category.rawValue.capitalized,
                    detail: .category
                )

                editableRow(
                    icon: "chart.bar",
                    label: "Tracking",
                    value: trackingLabel(for: config.trackingMethod),
                    detail: .trackingMethod
                )

                editableRow(
                    icon: "repeat",
                    label: "Frequency",
                    value: frequencyLabel(for: config.frequency),
                    detail: .frequency
                )

                editableRow(
                    icon: "bell",
                    label: "Reminder",
                    value: config.suggestedReminderSlot.displayName,
                    detail: .reminderTime
                )
            }

            // Question preview
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                Text("Daily question:")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                Text(config.trackingQuestion)
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                    .padding(AppTheme.BrutalistSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                            .fill(AppTheme.BrutalistPalette.background)
                    )
            }

            // Action button
            Button {
                Haptics.success()
                onConfirm()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Looks good!")
                }
                .font(AppTheme.BrutalistTypography.bodyBold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .fill(AppTheme.BrutalistPalette.accent)
                )
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
        .padding(AppTheme.BrutalistSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .fill(AppTheme.BrutalistPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .stroke(AppTheme.BrutalistPalette.accent.opacity(0.3), lineWidth: 2)
        )
    }

    private func editableRow(
        icon: String, label: String, value: String, detail: FlowState.DetailType
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.BrutalistPalette.accent)
                .frame(width: 24)

            Text(label)
                .font(AppTheme.BrutalistTypography.caption)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)

            Spacer()

            Button {
                Haptics.selection()
                onEdit(detail)
            } label: {
                HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                    Text(value)
                        .font(AppTheme.BrutalistTypography.bodyBold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.BrutalistPalette.foreground)
        }
        .padding(.vertical, AppTheme.BrutalistSpacing.xs)
    }

    private func trackingLabel(for method: InferredTrackingMethod) -> String {
        switch method {
        case .yesNo: return "Yes/No"
        case .count: return "Count"
        case .scale: return "Scale 1-10"
        case .journal: return "Journal"
        }
    }

    private func frequencyLabel(for freq: InferredFrequency) -> String {
        switch freq {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Quick Reply Components

private struct QuickReplyGrid: View {
    let options: [(String, String)]
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.BrutalistSpacing.sm
        ) {
            ForEach(options, id: \.1) { option in
                Button {
                    Haptics.selection()
                    onSelect(option.1)
                } label: {
                    Text(option.0)
                        .font(AppTheme.BrutalistTypography.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                        .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .fill(AppTheme.BrutalistPalette.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .stroke(AppTheme.BrutalistPalette.accent, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }
        }
    }
}

private struct QuickReplyChips<T: Hashable>: View {
    let options: [T]
    let labelProvider: (T) -> String
    let iconProvider: (T) -> String
    let colorProvider: (T) -> Color
    let onSelect: (T) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    Button {
                        Haptics.selection()
                        onSelect(option)
                    } label: {
                        HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                            Image(systemName: iconProvider(option))
                                .font(.system(size: 14, weight: .semibold))
                            Text(labelProvider(option))
                                .font(AppTheme.BrutalistTypography.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                        .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                                .fill(colorProvider(option).opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                                .stroke(colorProvider(option), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(colorProvider(option))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConversationalGoalCreationView()
        .modelContainer(for: [TrackingGoal.self, Question.self, Schedule.self, DataPoint.self])
}

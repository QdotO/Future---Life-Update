import Foundation
import FoundationModels

// MARK: - Goal Inference Output Structure

/// A structured output that the on-device LLM generates to fully configure a goal
/// based on a user's natural language description.
@Generable
struct InferredGoalConfiguration: Equatable {
    @Guide(description: "A concise, action-oriented title for the goal (3-7 words)")
    var title: String

    @Guide(description: "The most appropriate category for this goal")
    var category: InferredCategory

    @Guide(description: "The best way to track progress on this goal")
    var trackingMethod: InferredTrackingMethod

    @Guide(description: "How often the user should check in on this goal")
    var frequency: InferredFrequency

    @Guide(description: "A question to ask the user when they log progress")
    var trackingQuestion: String

    @Guide(description: "The best time of day for a reminder, based on the goal type")
    var suggestedReminderSlot: InferredTimeSlot

    @Guide(description: "A brief motivational message (10-20 words) to encourage the user")
    var motivationalMessage: String

    @Guide(description: "Confidence score from 0.0 to 1.0 indicating how certain the inference is")
    @Guide(.range(0.0...1.0))
    var confidenceScore: Double
}

@Generable
enum InferredCategory: String, CaseIterable {
    case health
    case fitness
    case productivity
    case habits
    case mood
    case learning
    case social
    case finance

    func toTrackingCategory() -> TrackingCategory {
        switch self {
        case .health: return .health
        case .fitness: return .fitness
        case .productivity: return .productivity
        case .habits: return .habits
        case .mood: return .mood
        case .learning: return .learning
        case .social: return .social
        case .finance: return .finance
        }
    }
}

@Generable
enum InferredTrackingMethod: String, CaseIterable {
    case yesNo  // Did you do it?
    case count  // How many times?
    case scale  // Rate 1-10
    case journal  // Write about it

    func toResponseType() -> ResponseType {
        switch self {
        case .yesNo: return .boolean
        case .count: return .numeric
        case .scale: return .scale
        case .journal: return .text
        }
    }
}

@Generable
enum InferredFrequency: String, CaseIterable {
    case daily
    case weekly
    case custom

    func toFrequency() -> Frequency {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .custom: return .custom
        }
    }
}

@Generable
enum InferredTimeSlot: String, CaseIterable {
    case morning  // 8 AM - Good for exercise, meditation, morning routines
    case midday  // 12 PM - Good for lunch habits, midday check-ins
    case evening  // 6 PM - Good for reflection, end-of-day habits
    case night  // 9 PM - Good for journaling, sleep tracking

    func toScheduleTime() -> ScheduleTime {
        switch self {
        case .morning: return ScheduleTime(hour: 8, minute: 0)
        case .midday: return ScheduleTime(hour: 12, minute: 0)
        case .evening: return ScheduleTime(hour: 18, minute: 0)
        case .night: return ScheduleTime(hour: 21, minute: 0)
        }
    }

    var displayName: String {
        switch self {
        case .morning: return "Morning (8 AM)"
        case .midday: return "Midday (12 PM)"
        case .evening: return "Evening (6 PM)"
        case .night: return "Night (9 PM)"
        }
    }
}

// MARK: - Goal Inference Service

/// Service that uses Apple's on-device Foundation Models to intelligently
/// infer goal configuration from natural language input.
@MainActor
@Observable
final class GoalInferenceService {

    enum ServiceState {
        case idle
        case inferring
        case complete(InferredGoalConfiguration)
        case error(Error)
        case unavailable(UnavailabilityReason)
    }

    enum UnavailabilityReason {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case unknown
    }

    enum InferenceError: LocalizedError {
        case modelUnavailable
        case generationFailed(String)
        case lowConfidence

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "On-device AI is not available on this device."
            case .generationFailed(let message):
                return "Failed to analyze goal: \(message)"
            case .lowConfidence:
                return "Could not confidently understand your goal. Please provide more details."
            }
        }
    }

    private(set) var state: ServiceState = .idle
    private(set) var isAvailable: Bool = false

    private var session: LanguageModelSession?
    private let model = SystemLanguageModel.default

    init() {
        checkAvailability()
    }

    // MARK: - Availability Check

    func checkAvailability() {
        switch model.availability {
        case .available:
            isAvailable = true
            initializeSession()
        case .unavailable(.deviceNotEligible):
            isAvailable = false
            state = .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            isAvailable = false
            state = .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            isAvailable = false
            state = .unavailable(.modelNotReady)
        default:
            isAvailable = false
            state = .unavailable(.unknown)
        }
    }

    private func initializeSession() {
        let instructions = Instructions {
            """
            You are a helpful goal-tracking assistant. Your job is to understand what 
            the user wants to track and configure a complete goal for them.

            When analyzing a goal description:
            1. Infer the most appropriate category based on keywords and context
            2. Determine the best tracking method:
               - yesNo: For binary actions (did I do it or not?)
               - count: For countable activities (how many times, glasses of water, etc.)
               - scale: For subjective ratings (energy level, mood, quality)
               - journal: For reflection or detailed tracking
            3. Suggest a frequency that matches the goal type
            4. Choose a reminder time that fits the activity:
               - morning: exercise, meditation, vitamins
               - midday: water intake, lunch habits
               - evening: reflection, workouts, habits
               - night: journaling, sleep prep, gratitude
            5. Create a natural tracking question
            6. Provide an encouraging motivational message

            Be confident in your inferences - the user wants smart suggestions, not questions.
            Common mappings:
            - "drink water" → health, count, daily, midday
            - "exercise" → fitness, yesNo, daily, morning
            - "read" → learning, yesNo or count (pages), daily, evening
            - "meditate" → mood, scale or yesNo, daily, morning
            - "sleep" → health, scale, daily, night
            - "journal" → mood, journal, daily, night
            """
        }

        session = LanguageModelSession(instructions: instructions)
    }

    // MARK: - Prewarm

    func prewarm() {
        session?.prewarm()
    }

    // MARK: - Inference

    /// Analyzes a user's goal description and returns a complete configuration
    func inferGoalConfiguration(from userInput: String) async throws -> InferredGoalConfiguration {
        guard isAvailable, let session = session else {
            throw InferenceError.modelUnavailable
        }

        state = .inferring

        let prompt = Prompt {
            """
            The user wants to track: "\(userInput)"

            Analyze this and create a complete goal configuration.
            Be confident - infer everything you can from the context.
            If it's about water, it's health + count.
            If it's about exercise, it's fitness + yesNo.
            Make smart assumptions like a helpful coach would.
            """
        }

        do {
            let response = try await session.respond(
                to: prompt,
                generating: InferredGoalConfiguration.self
            )

            let configuration = response.content

            // Check confidence threshold
            if configuration.confidenceScore < 0.3 {
                throw InferenceError.lowConfidence
            }

            state = .complete(configuration)
            return configuration

        } catch let error as InferenceError {
            state = .error(error)
            throw error
        } catch {
            let inferenceError = InferenceError.generationFailed(error.localizedDescription)
            state = .error(inferenceError)
            throw inferenceError
        }
    }

    /// Streams the inference for a more responsive UI
    func streamGoalConfiguration(from userInput: String) -> AsyncThrowingStream<
        InferredGoalConfiguration.PartiallyGenerated, Error
    > {
        AsyncThrowingStream { continuation in
            Task {
                guard isAvailable, let session = session else {
                    continuation.finish(throwing: InferenceError.modelUnavailable)
                    return
                }

                state = .inferring

                let prompt = Prompt {
                    """
                    The user wants to track: "\(userInput)"

                    Analyze this and create a complete goal configuration.
                    Be confident - infer everything you can from the context.
                    """
                }

                do {
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: InferredGoalConfiguration.self
                    )

                    for try await partialResponse in stream {
                        continuation.yield(partialResponse.content)
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Reset

    func reset() {
        state = .idle
    }
}

// MARK: - Fallback Inference (Keyword-based)

/// Provides fallback inference when Foundation Models is unavailable
struct FallbackGoalInference {

    static func infer(from input: String) -> InferredGoalConfiguration {
        let lowercased = input.lowercased()

        // Category inference based on keywords
        let category = inferCategory(from: lowercased)

        // Tracking method inference
        let trackingMethod = inferTrackingMethod(from: lowercased, category: category)

        // Frequency inference
        let frequency = inferFrequency(from: lowercased)

        // Time slot inference
        let timeSlot = inferTimeSlot(from: lowercased, category: category)

        // Generate question
        let question = generateQuestion(from: input, trackingMethod: trackingMethod)

        // Clean up title
        let title = cleanTitle(from: input)

        return InferredGoalConfiguration(
            title: title,
            category: category,
            trackingMethod: trackingMethod,
            frequency: frequency,
            trackingQuestion: question,
            suggestedReminderSlot: timeSlot,
            motivationalMessage: generateMotivation(for: category),
            confidenceScore: 0.7  // Lower confidence for fallback
        )
    }

    private static func inferCategory(from input: String) -> InferredCategory {
        let categoryKeywords: [(InferredCategory, [String])] = [
            (
                .health,
                ["water", "hydrat", "sleep", "vitamin", "medicine", "health", "doctor", "weight"]
            ),
            (
                .fitness,
                [
                    "exercise", "workout", "run", "walk", "gym", "steps", "miles", "fitness",
                    "yoga", "stretch",
                ]
            ),
            (
                .productivity,
                ["work", "task", "project", "focus", "productive", "meeting", "deadline"]
            ),
            (.habits, ["habit", "routine", "daily", "morning", "evening", "ritual"]),
            (
                .mood,
                [
                    "mood", "meditat", "mindful", "gratitude", "stress", "anxiety", "happy", "calm",
                    "journal",
                ]
            ),
            (
                .learning,
                ["read", "study", "learn", "book", "course", "practice", "skill", "language"]
            ),
            (.social, ["friend", "family", "call", "connect", "social", "relationship"]),
            (.finance, ["save", "spend", "budget", "money", "invest", "expense", "finance"]),
        ]

        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { input.contains($0) }) {
                return category
            }
        }

        return .habits  // Default
    }

    private static func inferTrackingMethod(from input: String, category: InferredCategory)
        -> InferredTrackingMethod
    {
        // Count keywords
        let countKeywords = [
            "glass", "cup", "hour", "minute", "page", "step", "mile", "time", "many",
        ]
        if countKeywords.contains(where: { input.contains($0) }) {
            return .count
        }

        // Scale keywords
        let scaleKeywords = ["rate", "level", "how well", "quality", "feel", "mood", "energy"]
        if scaleKeywords.contains(where: { input.contains($0) }) {
            return .scale
        }

        // Journal keywords
        let journalKeywords = ["journal", "write", "reflect", "note", "thought"]
        if journalKeywords.contains(where: { input.contains($0) }) {
            return .journal
        }

        // Category-based defaults
        switch category {
        case .mood: return .scale
        case .learning: return .yesNo
        case .fitness: return .yesNo
        case .health: return input.contains("water") ? .count : .yesNo
        default: return .yesNo
        }
    }

    private static func inferFrequency(from input: String) -> InferredFrequency {
        if input.contains("week") {
            return .weekly
        }
        return .daily
    }

    private static func inferTimeSlot(from input: String, category: InferredCategory)
        -> InferredTimeSlot
    {
        // Explicit time mentions
        if input.contains("morning") { return .morning }
        if input.contains("lunch") || input.contains("noon") { return .midday }
        if input.contains("evening") || input.contains("after work") { return .evening }
        if input.contains("night") || input.contains("bed") { return .night }

        // Category-based defaults
        switch category {
        case .fitness: return .morning
        case .health: return input.contains("water") ? .midday : .morning
        case .mood:
            return input.contains("journal") || input.contains("gratitude") ? .night : .morning
        case .learning: return .evening
        case .productivity: return .morning
        case .social: return .evening
        case .finance: return .evening
        default: return .evening
        }
    }

    private static func generateQuestion(from input: String, trackingMethod: InferredTrackingMethod)
        -> String
    {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch trackingMethod {
        case .yesNo:
            return "Did you \(cleanedInput) today?"
        case .count:
            if cleanedInput.contains("water") {
                return "How many glasses of water did you drink?"
            }
            return "How many times did you \(cleanedInput)?"
        case .scale:
            return "Rate your \(cleanedInput) today (1-10)"
        case .journal:
            return "How did your \(cleanedInput) go today?"
        }
    }

    private static func cleanTitle(from input: String) -> String {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        if let first = title.first {
            title = first.uppercased() + title.dropFirst()
        }

        // Truncate if too long
        if title.count > 50 {
            title = String(title.prefix(47)) + "..."
        }

        return title
    }

    private static func generateMotivation(for category: InferredCategory) -> String {
        switch category {
        case .health: return "Taking care of your health is the best investment you can make! 💚"
        case .fitness: return "Every step forward is progress. You've got this! 💪"
        case .productivity: return "Small consistent actions lead to big results. Keep going! 🎯"
        case .habits: return "Habits are the compound interest of self-improvement. 🌟"
        case .mood: return "Checking in with yourself is a powerful act of self-care. 🧘"
        case .learning: return "Every day is a chance to learn something new. 📚"
        case .social: return "Connections make life richer. Nurture your relationships! 💛"
        case .finance: return "Financial awareness is the first step to freedom. 💰"
        }
    }
}

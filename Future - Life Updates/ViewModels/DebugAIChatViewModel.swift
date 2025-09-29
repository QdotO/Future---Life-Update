import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
@MainActor
@Observable
final class DebugAIChatViewModel {
    struct Message: Identifiable, Equatable {
        enum Role {
            case system
            case user
            case assistant
            case error
        }

        let id = UUID()
        let role: Role
        let content: String
        let timestamp: Date
    }

    private var session: LanguageModelSession?
    private let instructions = "You are the Life Updates debug assistant. Keep responses concise and return plain text."

    var messages: [Message] = []
    var availability: GoalSuggestionAvailabilityStatus = .unknown
    var inputText: String = ""
    var isSending = false

    var availabilityMessage: String? {
        GoalSuggestionAvailability.message(for: availability)
    }

    init() {
        refreshAvailability()
        addInitialMessage()
    }

    func refreshAvailability() {
        availability = GoalSuggestionAvailability.currentStatus()
        if case .available = availability {
            _ = ensureSession()
        } else {
            session = nil
        }
    }

    func resetConversation() {
        messages.removeAll()
        session = nil
        refreshAvailability()
        addInitialMessage()
    }

    func sendCurrentMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(Message(role: .user, content: trimmed, timestamp: Date()))
        inputText = ""

        guard case .available = availability else {
            appendErrorMessage(availabilityMessage ?? "Apple Intelligence is unavailable.")
            return
        }

        isSending = true
        let session = ensureSession()
        Task { [weak self] in
            do {
                let response = try await session.respond(to: trimmed)
                let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    guard let self else { return }
                    self.messages.append(Message(role: .assistant, content: cleaned, timestamp: Date()))
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.appendErrorMessage(error.localizedDescription)
                    self.isSending = false
                }
            }
        }
    }

    private func addInitialMessage() {
        let text: String
        if case let .available(providerName) = availability {
            text = "Connected to \(providerName). Send a prompt to test the on-device model."
        } else if let message = availabilityMessage {
            text = message
        } else {
            text = "Apple Intelligence availability is unknown."
        }
        messages.append(Message(role: .system, content: text, timestamp: Date()))
    }

    private func appendErrorMessage(_ text: String) {
        messages.append(Message(role: .error, content: text, timestamp: Date()))
    }

    private func ensureSession() -> LanguageModelSession {
        if let session {
            return session
        }
        let session = LanguageModelSession(instructions: instructions)
        self.session = session
        return session
    }
}
#else
@MainActor
@Observable
final class DebugAIChatViewModel {
    struct Message: Identifiable, Equatable {
        enum Role {
            case system
        }

        let id = UUID()
        let role: Role
        let content: String
        let timestamp: Date
    }

    var messages: [Message] = [
        Message(
            role: .system,
            content: GoalSuggestionAvailability.message(for: .unsupportedPlatform)
                ?? "Apple Intelligence is unavailable on this platform.",
            timestamp: Date()
        )
    ]
    var availability: GoalSuggestionAvailabilityStatus = .unsupportedPlatform
    var inputText: String = ""
    var isSending = false

    var availabilityMessage: String? {
        GoalSuggestionAvailability.message(for: availability)
    }

    func refreshAvailability() {}
    func resetConversation() {}
    func sendCurrentMessage() {}
}
#endif

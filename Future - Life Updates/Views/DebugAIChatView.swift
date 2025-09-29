import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
struct DebugAIChatView: View {
    @State private var viewModel = DebugAIChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            statusBanner
            Divider()
            chatLog
            Divider()
            inputBar
        }
        .navigationTitle("AI Debug Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.refreshAvailability()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh availability")
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.refreshAvailability()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh availability")
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button("Reset") {
                    viewModel.resetConversation()
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
        .background(AppTheme.Palette.background.ignoresSafeArea())
    }

    private var statusBanner: some View {
        let display = statusDisplay(for: viewModel.availability)

        return HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: display.icon)
                .foregroundStyle(display.tint)
            Text(display.text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Palette.neutralStrong)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.Palette.surface)
    }

    private func statusDisplay(for status: GoalSuggestionAvailabilityStatus) -> (icon: String, text: String, tint: Color) {
        switch status {
        case .available(let provider):
            return ("checkmark.circle.fill", "Connected to \(provider)", .green)
        case .deviceNotEligible:
            return ("xmark.octagon.fill", viewModel.availabilityMessage ?? "Device not eligible", .orange)
        case .appleIntelligenceDisabled:
            return ("exclamationmark.triangle.fill", viewModel.availabilityMessage ?? "Apple Intelligence disabled", .orange)
        case .modelNotReady:
            return ("hourglass", viewModel.availabilityMessage ?? "Model is preparing", .yellow)
        case .unsupportedPlatform, .unknown:
            return ("questionmark.circle", viewModel.availabilityMessage ?? "Status unavailable", .gray)
        }
    }

    private var chatLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        messageRow(for: message)
                            .id(message.id)
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(AppTheme.Palette.background)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastID = viewModel.messages.last?.id {
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func messageRow(for message: DebugAIChatViewModel.Message) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
                bubble(for: message)
            } else {
                bubble(for: message)
                Spacer()
            }
        }
    }

    private func bubble(for message: DebugAIChatViewModel.Message) -> some View {
        let alignment: TextAlignment = message.role == .user ? .trailing : .leading
        let background: Color
        let foreground: Color

        switch message.role {
        case .user:
            background = AppTheme.Palette.primary
            foreground = AppTheme.Palette.accentOnPrimary
        case .assistant:
            background = AppTheme.Palette.surfaceElevated
            foreground = AppTheme.Palette.neutralStrong
        case .system:
            background = AppTheme.Palette.surface
            foreground = AppTheme.Palette.neutralSubdued
        case .error:
            background = Color.red.opacity(0.15)
            foreground = .red
        }

        return Text(message.content)
            .font(AppTheme.Typography.body)
            .foregroundStyle(foreground)
            .multilineTextAlignment(alignment)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            #if os(iOS)
            TextField("Type a prompt...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            #else
            TextField("Type a prompt...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
            #endif

            if viewModel.isSending {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            Button {
                viewModel.sendCurrentMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
            }
            .disabled(viewModel.isSending || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.Palette.surface)
    }
}
#else
struct DebugAIChatView: View {
    var body: some View {
        ContentUnavailableView(
            "Unavailable",
            systemImage: "xmark.circle",
            description: Text("Debug chat requires Apple Intelligence APIs.")
        )
    }
}
#endif

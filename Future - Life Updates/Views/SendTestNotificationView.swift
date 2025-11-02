import SwiftData
import SwiftUI

struct SendTestNotificationView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrackingGoal.title, order: .forward)
    private var allGoals: [TrackingGoal]
    @State private var alertInfo: AlertInfo?

    private var activeGoals: [TrackingGoal] {
        allGoals.filter { $0.isActive }
    }

    private var pausedGoals: [TrackingGoal] {
        allGoals.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if allGoals.isEmpty {
                ContentUnavailableView(
                    "No goals yet",
                    systemImage: "target",
                    description: Text(
                        "Create a goal first, then come back here to send yourself a preview reminder."
                    )
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                if !activeGoals.isEmpty {
                    Section("Active goals") {
                        ForEach(activeGoals) { goal in
                            goalRow(goal)
                        }
                    }
                }

                if !pausedGoals.isEmpty {
                    Section("Paused goals") {
                        ForEach(pausedGoals) { goal in
                            goalRow(goal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Test Notifications")
        #if os(iOS)
            .listStyle(.insetGrouped)
        #endif
        .alert(item: $alertInfo) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func goalRow(_ goal: TrackingGoal) -> some View {
        Button {
            NotificationScheduler.shared.sendTestNotification(for: goal)
            alertInfo = AlertInfo(
                title: "Test scheduled",
                message: "We'll send a preview reminder for \(goal.title)."
            )
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                    if let description = goal.goalDescription.nonEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        return NavigationStack {
            SendTestNotificationView()
        }
        .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var goal: TrackingGoal
    @State private var presentingDataEntry = false
    @State private var trendsViewModel: GoalTrendsViewModel?
    @State private var presentingEditor = false
    @State private var showingNotificationTestAlert = false

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Status", value: goal.isActive ? "Active" : "Paused")
                LabeledContent("Category", value: goal.category.displayName)
                LabeledContent("Schedule", value: formattedSchedule)
                Button {
                    NotificationScheduler.shared.sendTestNotification(for: goal)
                    showingNotificationTestAlert = true
                } label: {
                    Label("Send Test Notification", systemImage: "paperplane")
                }
                .buttonStyle(.borderless)
                NavigationLink {
                    GoalHistoryView(goal: goal, modelContext: modelContext)
                } label: {
                    Label("View Full History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Questions") {
                ForEach(goal.questions) { question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.text)
                            .font(.headline)
                        Text(question.responseType.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Trends") {
                if let viewModel = trendsViewModel {
                    GoalTrendsView(viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    ContentUnavailableView("Analytics will appear after logging", systemImage: "chart.line.uptrend.xyaxis")
                }
            }

            if !goal.dataPoints.isEmpty {
                Section("Recent Responses") {
                    ForEach(goal.dataPoints.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5)) { point in
                        VStack(alignment: .leading, spacing: 4) {
                            if let question = point.question {
                                Text(question.text)
                                    .font(.headline)
                            }
                            Text(point.timestamp, style: .date)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(recentResponseSummary(for: point))
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle(goal.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(goal.isActive ? "Pause" : "Activate") {
                    goal.isActive.toggle()
                    goal.bumpUpdatedAt()
                    NotificationScheduler.shared.scheduleNotifications(for: goal)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Failed to update goal state: \(error)")
                    }
                }
                Button("Log Entry") {
                    presentingDataEntry = true
                }
                Button("Edit") {
                    presentingEditor = true
                }
            }
        }
        .sheet(isPresented: $presentingDataEntry) {
            DataEntryView(goal: goal, modelContext: modelContext)
        }
        .sheet(isPresented: $presentingEditor) {
            GoalEditView(viewModel: GoalEditorViewModel(goal: goal, modelContext: modelContext))
        }
        .alert(
            "Test Notification Scheduled",
            isPresented: $showingNotificationTestAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We'll send a preview notification to confirm your settings.")
        }
        .task {
            if let existing = trendsViewModel {
                existing.refresh()
            } else {
                trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
            }
        }
        .onChange(of: goal.updatedAt) { _, _ in
            trendsViewModel?.refresh()
        }
    }

    private var formattedSchedule: String {
        let times = goal.schedule.times
        guard !times.isEmpty else { return "No reminders configured" }
        let timezone = goal.schedule.timezone
        return times
            .map { $0.formattedTime(in: timezone) }
            .joined(separator: ", ")
    }

    private func recentResponseSummary(for dataPoint: DataPoint) -> String {
        if let responseType = dataPoint.question?.responseType {
            switch responseType {
            case .numeric, .slider:
                if let value = dataPoint.numericValue {
                    let formatted = value.formatted(.number.precision(.fractionLength(0...2)))
                    return "Response: \(formatted)"
                }
            case .scale:
                if let value = dataPoint.numericValue {
                    return "Response: \(Int(value.rounded()))"
                }
            case .boolean:
                if let value = dataPoint.boolValue {
                    return value ? "Answered: Yes" : "Answered: No"
                }
            case .text:
                if let text = dataPoint.textValue, !text.isEmpty {
                    return text
                }
            case .multipleChoice:
                if let selections = dataPoint.selectedOptions, !selections.isEmpty {
                    return selections.joined(separator: ", ")
                }
            case .time:
                if let time = dataPoint.timeValue {
                    return "Recorded for \(time.formatted(date: .omitted, time: .shortened))"
                }
            }
        }

        if let value = dataPoint.numericValue {
            let formatted = value.formatted(.number.precision(.fractionLength(0...2)))
            return "Response: \(formatted)"
        }
        if let text = dataPoint.textValue, !text.isEmpty {
            return text
        }
        if let boolValue = dataPoint.boolValue {
            return boolValue ? "Answered: Yes" : "Answered: No"
        }
        if let selections = dataPoint.selectedOptions, !selections.isEmpty {
            return selections.joined(separator: ", ")
        }
        if let time = dataPoint.timeValue {
            return "Recorded for \(time.formatted(date: .omitted, time: .shortened))"
        }
        return "No response recorded"
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
           let goal = goals.first {
            NavigationStack {
                GoalDetailView(goal: goal)
            }
            .modelContainer(container)
        } else {
            Text("No Sample Goals")
        }
    } else {
        Text("Preview Error Loading Sample Data")
    }
}

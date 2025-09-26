import SwiftUI
import SwiftData
import os

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var goal: TrackingGoal
    @State private var presentingDataEntry = false
    @State private var trendsViewModel: GoalTrendsViewModel?
    @State private var presentingEditor = false
    @State private var showingNotificationTestAlert = false
    @State private var recentResponses: [DataPoint] = []

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Status", value: goal.isActive ? "Active" : "Paused")
                LabeledContent("Category", value: goal.categoryDisplayName)
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

            if !recentResponses.isEmpty {
                Section("Recent Responses") {
                    ForEach(recentResponses) { point in
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
            loadRecentResponses()
        }
        .onChange(of: goal.updatedAt) { _, _ in
            trendsViewModel?.refresh()
            loadRecentResponses()
        }
    }

    private var formattedSchedule: String {
        let times = goal.schedule.times
        guard !times.isEmpty else { return "No reminders configured" }
        let timezone = goal.schedule.timezone
        let timeDescription = times
            .map { $0.formattedTime(in: timezone) }
            .joined(separator: ", ")

        let frequencyDescription: String
        switch goal.schedule.frequency {
        case .daily:
            frequencyDescription = "Daily"
        case .weekly:
            let weekdays = goal.schedule.normalizedWeekdays()
            if weekdays.isEmpty {
                frequencyDescription = "Weekly"
            } else {
                let names = weekdays
                    .map { $0.shortDisplayName }
                    .joined(separator: ", ")
                frequencyDescription = "Weekly on \(names)"
            }
        case .monthly:
            let day = Calendar.current.component(.day, from: goal.schedule.startDate)
            frequencyDescription = "Monthly on day \(day)"
        case .custom:
            if let interval = goal.schedule.intervalDayCount {
                frequencyDescription = "Every \(interval) days"
            } else {
                frequencyDescription = "Custom cadence"
            }
        case .once:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.timeZone = timezone
            frequencyDescription = "Once on \(formatter.string(from: goal.schedule.startDate))"
        }

        return "\(frequencyDescription) at \(timeDescription)"
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

    private func loadRecentResponses(limit: Int = 5) {
        let trace = PerformanceMetrics.trace("GoalDetail.loadRecent", metadata: ["goal": goal.id.uuidString])
        let goalIdentifier = goal.persistentModelID
        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = true
        descriptor.propertiesToFetch = [
            \.timestamp,
            \.numericValue,
            \.textValue,
            \.boolValue,
            \.selectedOptions,
            \.timeValue
        ]
        descriptor.relationshipKeyPathsForPrefetching = [\.question]

        do {
            recentResponses = try modelContext.fetch(descriptor)
            trace.end(extraMetadata: ["count": "\(recentResponses.count)"])
        } catch {
            recentResponses = []
            PerformanceMetrics.logger.error("GoalDetail recent fetch failed: \(error.localizedDescription, privacy: .public)")
            trace.end(extraMetadata: ["error": error.localizedDescription])
        }
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

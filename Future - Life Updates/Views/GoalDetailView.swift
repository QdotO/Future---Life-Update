import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var goal: TrackingGoal
    @State private var presentingDataEntry = false
    @State private var trendsViewModel: GoalTrendsViewModel?

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Status", value: goal.isActive ? "Active" : "Paused")
                LabeledContent("Category", value: goal.category.displayName)
                LabeledContent("Schedule", value: formattedSchedule)
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
                            if let value = point.numericValue {
                                Text("Response: \(value, format: .number.precision(.fractionLength(0...2)))")
                            } else if let textValue = point.textValue {
                                Text(textValue)
                            }
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
            }
        }
        .sheet(isPresented: $presentingDataEntry) {
            DataEntryView(goal: goal, modelContext: modelContext)
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
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        let context = container.mainContext
        guard let goal = try context.fetch(FetchDescriptor<TrackingGoal>()).first else {
            return Text("No Sample Goals")
        }
        return NavigationStack {
            GoalDetailView(goal: goal)
        }
        .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

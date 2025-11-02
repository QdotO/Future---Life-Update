import SwiftData
import SwiftUI
import os

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var goal: TrackingGoal
    @State private var presentingDataEntry = false
    @State private var presentingEditor = false
    @State private var showingNotificationTestAlert = false
    @State private var recentResponses: [DataPoint] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                overviewCard
                if !goal.questions.isEmpty {
                    questionsCard
                }
                if !recentResponses.isEmpty {
                    recentResponsesCard
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .background(AppTheme.Palette.background.ignoresSafeArea())
        .navigationTitle(goal.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(goal.isActive ? "Pause" : "Activate") {
                    goal.isActive.toggle()
                    goal.bumpUpdatedAt()

                    // Handle notifications based on new state
                    if goal.isActive {
                        // Goal reactivated - reschedule notifications
                        NotificationScheduler.shared.scheduleNotifications(for: goal)
                    } else {
                        // Goal deactivated - cancel all notifications
                        NotificationScheduler.shared.cancelNotifications(forGoalID: goal.id)
                    }

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
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll send a preview notification to confirm your settings.")
        }
        .task {
            loadRecentResponses()
        }
        .onChange(of: goal.updatedAt) { _, _ in
            loadRecentResponses()
        }
    }

    private var overviewCard: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    statusRow
                    infoRow(title: "Category", value: goal.categoryDisplayName)
                    infoRow(title: "Schedule", value: formattedSchedule)
                }

                Divider()

                VStack(spacing: AppTheme.Spacing.sm) {
                    Button {
                        presentingDataEntry = true
                    } label: {
                        Label("Log Entry", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.brutalistPrimary)

                    Button {
                        NotificationScheduler.shared.sendTestNotification(for: goal)
                        showingNotificationTestAlert = true
                    } label: {
                        Label("Send Test Notification", systemImage: "paperplane")
                    }
                    .buttonStyle(.brutalistSecondary)

                    NavigationLink {
                        GoalHistoryView(goal: goal, modelContext: modelContext)
                    } label: {
                        BrutalistNavigationRow(
                            title: "View full history", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var questionsCard: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Questions")
                    .font(AppTheme.Typography.sectionHeader)

                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(Array(goal.questions.enumerated()), id: \.element.id) {
                        index, question in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(question.text)
                                .font(AppTheme.Typography.bodyStrong)
                            Text(question.responseType.displayName)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Palette.neutralSubdued)
                        }

                        if index < goal.questions.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var recentResponsesCard: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Recent responses")
                    .font(AppTheme.Typography.sectionHeader)

                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(Array(recentResponses.enumerated()), id: \.element.id) { index, point in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            if let question = point.question {
                                Text(question.text)
                                    .font(AppTheme.Typography.bodyStrong)
                            }
                            Text(point.timestamp, style: .date)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Palette.neutralSubdued)
                            Text(recentResponseSummary(for: point))
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Palette.neutralStrong)
                        }

                        if index < recentResponses.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            statusBadge
            if let updatedLabel = lastUpdatedLabel {
                Text(updatedLabel)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Palette.neutralSubdued)
            }
        }
    }

    private var statusBadge: some View {
        Text(goal.isActive ? "Active" : "Paused")
            .font(AppTheme.Typography.caption.weight(.semibold))
            .padding(.vertical, AppTheme.Spacing.xs)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.small, style: .continuous)
                    .fill((goal.isActive ? AppTheme.Palette.primary : Color.orange).opacity(0.12))
            )
            .foregroundStyle(goal.isActive ? AppTheme.Palette.primary : Color.orange)
    }

    private var lastUpdatedLabel: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated " + formatter.localizedString(for: goal.updatedAt, relativeTo: Date())
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title.uppercased())
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.neutralSubdued)
            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Palette.neutralStrong)
        }
    }

    private var formattedSchedule: String {
        let times = goal.schedule.times
        guard !times.isEmpty else { return "No reminders configured" }
        let timezone = goal.schedule.timezone
        let timeDescription =
            times
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
                let names =
                    weekdays
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
            case .waterIntake:
                if let value = dataPoint.numericValue {
                    return "Response: \(HydrationFormatter.ouncesString(value))"
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
            if dataPoint.question?.responseType == .waterIntake {
                return "Response: \(HydrationFormatter.ouncesString(value))"
            }
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
        let trace = PerformanceMetrics.trace(
            "GoalDetail.loadRecent", metadata: ["goal": goal.id.uuidString])
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
            \.timeValue,
        ]
        descriptor.relationshipKeyPathsForPrefetching = [\.question]

        do {
            recentResponses = try modelContext.fetch(descriptor)
            trace.end(extraMetadata: ["count": "\(recentResponses.count)"])
        } catch {
            recentResponses = []
            PerformanceMetrics.logger.error(
                "GoalDetail recent fetch failed: \(error.localizedDescription, privacy: .public)")
            trace.end(extraMetadata: ["error": error.localizedDescription])
        }
    }
}

private struct BrutalistNavigationRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Label(title, systemImage: systemImage)
                .font(AppTheme.Typography.bodyStrong)
                .labelStyle(.titleAndIcon)
            Spacer(minLength: AppTheme.Spacing.lg)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.neutralSubdued)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal, style: .continuous)
                .fill(AppTheme.Palette.surface.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderTokens.CornerRadius.minimal, style: .continuous)
                .stroke(AppTheme.Palette.outline, lineWidth: 1)
        )
        .foregroundStyle(AppTheme.Palette.neutralStrong)
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
            let goal = goals.first
        {
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

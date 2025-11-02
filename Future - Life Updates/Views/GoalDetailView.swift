import SwiftData
import SwiftUI
import os

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.designStyle) private var designStyle

    @Bindable var goal: TrackingGoal
    @State private var presentingDataEntry = false
    @State private var presentingEditor = false
    @State private var recentResponses: [DataPoint] = []
    @State private var trendsViewModel: GoalTrendsViewModel?

    var body: some View {
        Group {
            if designStyle == .brutalist {
                brutalistDetail
            } else {
                legacyDetail
            }
        }
        .navigationTitle(goal.title)
        .toolbar {
            if designStyle != .brutalist {
                ToolbarItemGroup(placement: .primaryAction) {
                    toggleGoalButton
                    Button("Log Entry") { presentLogEntry() }
                    Button("Edit") { presentEditor() }
                }
            }
        }
        .sheet(isPresented: $presentingDataEntry) {
            DataEntryView(goal: goal, modelContext: modelContext)
        }
        .sheet(isPresented: $presentingEditor) {
            GoalEditView(viewModel: GoalEditorViewModel(goal: goal, modelContext: modelContext))
        }
        .task {
            loadRecentResponses()
            refreshTrendsViewModel(forceCreate: trendsViewModel == nil)
        }
        .onChange(of: goal.updatedAt) { _, _ in
            loadRecentResponses()
            trendsViewModel?.refresh()
        }
        .onChange(of: goal.persistentModelID) { _, _ in
            refreshTrendsViewModel(forceCreate: true)
        }
    }

    private var brutalistDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
                brutalistOverviewSection

                if let viewModel = trendsViewModel {
                    brutalistProgressSection(viewModel: viewModel)
                }

                if !goal.questions.isEmpty {
                    brutalistQuestionsSection
                }

                brutalistResponsesSection
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }

    private var brutalistOverviewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            brutalistHeader("Overview")
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.BrutalistSpacing.sm) {
                    statusBadge
                    if let category = goal.categoryDisplayName.nonEmpty {
                        Text(category.uppercased())
                            .font(AppTheme.BrutalistTypography.overline)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }

                if let description = goal.goalDescription.nonEmpty {
                    Text(description)
                        .font(AppTheme.BrutalistTypography.body)
                }

                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    Text("Cadence")
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    Text(formattedSchedule)
                        .font(AppTheme.BrutalistTypography.body)
                }

                if designStyle == .brutalist {
                    brutalistActionRow
                }

                supplementalActions
            }
            .brutalistCard()
        }
    }

    private var brutalistActionRow: some View {
        ViewThatFits {
            HStack(alignment: .center, spacing: AppTheme.BrutalistSpacing.sm) {
                primaryLogButton
                    .frame(maxWidth: .infinity, alignment: .leading)

                secondaryActionCluster
            }

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                primaryLogButton
                secondaryActionCluster
            }
        }
    }

    private var secondaryActionCluster: some View {
        HStack(spacing: AppTheme.BrutalistSpacing.xs) {
            editGoalChip
            toggleGoalChip
        }
    }

    private var supplementalActions: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            Rectangle()
                .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                .frame(height: 1)

            historyLink
        }
    }

    private func brutalistProgressSection(viewModel: GoalTrendsViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            brutalistHeader("Progress")
            Group {
                if hasProgressData(viewModel) {
                    GoalTrendsView(viewModel: viewModel)
                        .brutalistCard()
                } else {
                    GoalTrendsView(viewModel: viewModel)
                }
            }
        }
    }

    private var brutalistQuestionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            brutalistHeader("Questions")
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                ForEach(Array(goal.questions.enumerated()), id: \.element.id) { index, question in
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        Text(question.text)
                            .font(AppTheme.BrutalistTypography.bodyBold)
                        Text(question.responseType.displayName.uppercased())
                            .font(AppTheme.BrutalistTypography.overline)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }

                    if index < goal.questions.count - 1 {
                        Rectangle()
                            .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                            .frame(height: 1)
                    }
                }
            }
            .brutalistCard()
        }
    }

    private var brutalistResponsesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            brutalistHeader("Recent Responses")
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                if recentResponses.isEmpty {
                    Text("Log your first update to see a timeline of entries here.")
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        .padding(.vertical, AppTheme.BrutalistSpacing.sm)
                } else {
                    ForEach(Array(recentResponses.enumerated()), id: \.element.id) { index, point in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                                if goal.questions.count > 1, let question = point.question {
                                    Text(question.text.uppercased())
                                        .font(AppTheme.BrutalistTypography.overline)
                                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                                }

                                Text(naturalLanguageMoment(for: point.timestamp))
                                    .font(AppTheme.BrutalistTypography.body)

                                Text(formattedEntryDate(point.timestamp))
                                    .font(AppTheme.BrutalistTypography.caption)
                                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                            }

                            Spacer(minLength: AppTheme.BrutalistSpacing.sm)

                            if let value = recentResponseValue(for: point) {
                                Text(value)
                                    .font(AppTheme.BrutalistTypography.bodyBold)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text("No response recorded")
                                    .font(AppTheme.BrutalistTypography.caption)
                                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        if index < recentResponses.count - 1 {
                            Rectangle()
                                .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .brutalistCard()
        }
    }

    private var legacyDetail: some View {
        List {
            Section("Overview") {
                LabeledContent("Status", value: goal.isActive ? "Active" : "Paused")
                LabeledContent("Category", value: goal.categoryDisplayName)
                LabeledContent("Schedule", value: formattedSchedule)
                NavigationLink {
                    GoalHistoryView(goal: goal, modelContext: modelContext)
                        .environment(\.designStyle, designStyle)
                } label: {
                    Label("View Full History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Questions") {
                ForEach(Array(goal.questions.enumerated()), id: \.element.id) { _, question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.text)
                            .font(.headline)
                        Text(question.responseType.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !recentResponses.isEmpty {
                Section("Recent Responses") {
                    ForEach(Array(recentResponses.enumerated()), id: \.element.id) { index, point in
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
    }

    private var toggleGoalButton: some View {
        Button(goal.isActive ? "Pause" : "Activate") {
            toggleGoalState()
        }
    }

    private var primaryLogButton: some View {
        Button {
            presentLogEntry()
        } label: {
            Text("Log Update")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .brutalistButton(style: .primary)
        .frame(maxWidth: .infinity)
    }

    private var toggleGoalChip: some View {
        Button(goal.isActive ? "Pause Goal" : "Activate Goal") {
            toggleGoalState()
        }
        .brutalistButton(style: .compactSecondary)
    }

    private var editGoalChip: some View {
        Button("Edit Goal") {
            presentEditor()
        }
        .brutalistButton(style: .compactSecondary)
    }

    private var historyLink: some View {
        NavigationLink {
            GoalHistoryView(goal: goal, modelContext: modelContext)
                .environment(\.designStyle, designStyle)
        } label: {
            Label("View Full History", systemImage: "clock.arrow.circlepath")
                .labelStyle(.titleAndIcon)
                .font(AppTheme.BrutalistTypography.bodyBold)
                .textCase(.uppercase)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(AppTheme.BrutalistPalette.background)
                .overlay(
                    Rectangle()
                        .stroke(
                            AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.standard)
                )
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        Text(goal.isActive ? "Active" : "Paused")
            .font(AppTheme.BrutalistTypography.bodyBold)
            .textCase(.uppercase)
            .padding(.vertical, AppTheme.BrutalistSpacing.xs)
            .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
            .background(
                goal.isActive
                    ? AppTheme.BrutalistPalette.accent
                    : AppTheme.BrutalistPalette.border.opacity(0.15)
            )
            .foregroundColor(goal.isActive ? .white : AppTheme.BrutalistPalette.foreground)
            .overlay(
                Rectangle()
                    .stroke(
                        AppTheme.BrutalistPalette.border,
                        lineWidth: AppTheme.BrutalistBorder.standard)
            )
    }

    private func brutalistHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppTheme.BrutalistTypography.overline)
            .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func presentLogEntry() {
        presentingDataEntry = true
    }

    private func presentEditor() {
        presentingEditor = true
    }

    private func toggleGoalState() {
        goal.isActive.toggle()
        goal.bumpUpdatedAt()

        if goal.isActive {
            NotificationScheduler.shared.scheduleNotifications(for: goal)
        } else {
            NotificationScheduler.shared.cancelNotifications(forGoalID: goal.id)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to update goal state: \(error)")
        }
    }

    private func refreshTrendsViewModel(forceCreate: Bool) {
        if forceCreate {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
            return
        }

        guard let current = trendsViewModel else {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
            return
        }

        if current.goal.persistentModelID == goal.persistentModelID {
            current.refresh()
        } else {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
        }
    }

    private func hasProgressData(_ viewModel: GoalTrendsViewModel) -> Bool {
        !viewModel.dailySeries.isEmpty
            || !viewModel.booleanStreaks.isEmpty
            || !viewModel.responseSnapshots.isEmpty
    }

    private func naturalLanguageMoment(for date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = goal.schedule.timezone

        let hour = calendar.component(.hour, from: date)
        let period: String
        switch hour {
        case 5..<12:
            period = "morning"
        case 12..<17:
            period = "afternoon"
        case 17..<21:
            period = "evening"
        case 21..<24:
            period = "late night"
        default:
            period = "overnight"
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.timeZone = goal.schedule.timezone
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: date)

        return "\(weekday) \(period)"
    }

    private func formattedEntryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = goal.schedule.timezone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var formattedSchedule: String {
        let times = goal.schedule.times
        guard !times.isEmpty else { return "No reminders configured" }
        let timezone = goal.schedule.timezone
        let timeDescription =
            times
            .map { $0.formattedTime(in: timezone) }
            .joined(separator: ", ")
        let abbreviation =
            timezone.abbreviation()
            ?? timezone.localizedName(for: .shortGeneric, locale: .current)
            ?? timezone.identifier

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

        return "\(frequencyDescription) at \(timeDescription) (\(abbreviation))"
    }

    private func recentResponseValue(for dataPoint: DataPoint) -> String? {
        if let responseType = dataPoint.question?.responseType {
            switch responseType {
            case .numeric, .slider:
                if let value = dataPoint.numericValue {
                    return value.formatted(.number.precision(.fractionLength(0...2)))
                }
            case .scale:
                if let value = dataPoint.numericValue {
                    return String(Int(value.rounded()))
                }
            case .waterIntake:
                if let value = dataPoint.numericValue {
                    return HydrationFormatter.ouncesString(value)
                }
            case .boolean:
                if let value = dataPoint.boolValue {
                    return value ? "Yes" : "No"
                }
            case .text:
                if let text = dataPoint.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !text.isEmpty
                {
                    return text
                }
            case .multipleChoice:
                if let selections = dataPoint.selectedOptions?.filter({ !$0.isEmpty }),
                    !selections.isEmpty
                {
                    return selections.joined(separator: ", ")
                }
            case .time:
                if let time = dataPoint.timeValue {
                    return time.formatted(date: .omitted, time: .shortened)
                }
            }
        }

        if let value = dataPoint.numericValue {
            if dataPoint.question?.responseType == .waterIntake {
                return HydrationFormatter.ouncesString(value)
            }
            return value.formatted(.number.precision(.fractionLength(0...2)))
        }
        if let text = dataPoint.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        {
            return text
        }
        if let boolValue = dataPoint.boolValue {
            return boolValue ? "Yes" : "No"
        }
        if let selections = dataPoint.selectedOptions, !selections.isEmpty {
            return selections.joined(separator: ", ")
        }
        if let time = dataPoint.timeValue {
            return time.formatted(date: .omitted, time: .shortened)
        }
        return nil
    }

    private func recentResponseSummary(for dataPoint: DataPoint) -> String {
        guard let valueText = recentResponseValue(for: dataPoint) else {
            return "No response recorded"
        }

        if let responseType = dataPoint.question?.responseType {
            switch responseType {
            case .boolean:
                return "Answered: \(valueText)"
            case .text, .multipleChoice:
                return valueText
            case .time:
                return "Recorded for \(valueText)"
            default:
                return "Response: \(valueText)"
            }
        }

        if dataPoint.boolValue != nil {
            return "Answered: \(valueText)"
        }
        if dataPoint.timeValue != nil {
            return "Recorded for \(valueText)"
        }
        if dataPoint.textValue != nil || !(dataPoint.selectedOptions ?? []).isEmpty {
            return valueText
        }
        return "Response: \(valueText)"
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

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer() {
        let context = container.mainContext
        if let goals = try? context.fetch(FetchDescriptor<TrackingGoal>()),
            let goal = goals.first
        {
            NavigationStack {
                GoalDetailView(goal: goal)
                    .designStyle(.brutalist)
            }
            .modelContainer(container)
        } else {
            Text("No Sample Goals")
        }
    } else {
        Text("Preview Error Loading Sample Data")
    }
}

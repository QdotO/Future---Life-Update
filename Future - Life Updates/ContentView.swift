//
//  ContentView.swift
//  Future - Life Updates
//
//  Created by Quincy Obeng on 9/23/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationRouter: NotificationRoutingController
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingCreateGoal = false
    @State private var notificationRoute: NotificationRoutingController.Route?
    @State private var todayViewModel: TodayDashboardViewModel?
    @State private var selectedTab: Tab = .today
    @State private var sendDailyDigest = true
    @State private var allowNotificationPreviews = true

    @Query(sort: \TrackingGoal.updatedAt, order: .reverse)
    private var allGoals: [TrackingGoal]

    // Computed property to filter active goals for UI display
    private var goals: [TrackingGoal] {
        allGoals.filter { $0.isActive }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                Group {
                    if goals.isEmpty {
                        emptyState
                    } else {
                        goalsList
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("GOALS")
                            .font(AppTheme.BrutalistTypography.title)
                            .fontWeight(.bold)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCreateGoal = true
                        } label: {
                            Image(systemName: "plus")
                                .renderingMode(.template)
                        }
                        .brutalistIconButton()
                        .accessibilityLabel("Create goal")
                    }
                }
                .environment(\.designStyle, .brutalist)
            }
            .tabItem {
                Label {
                    Text("GOALS")
                } icon: {
                    Image(systemName: "target")
                }
            }
            .tag(Tab.goals)

            NavigationStack {
                Group {
                    if let dashboardViewModel = todayViewModel {
                        TodayDashboardView(viewModel: dashboardViewModel)
                    } else {
                        ProgressView("Loading today")
                            .task {
                                initializeDashboard()
                            }
                    }
                }
                .navigationTitle("TODAY")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("TODAY")
                            .font(AppTheme.BrutalistTypography.title)
                            .fontWeight(.bold)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            todayViewModel?.refresh()
                        } label: {
                            Label {
                                Text("REFRESH")
                            } icon: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(todayViewModel == nil)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .environment(\.designStyle, .brutalist)
            }
            .tabItem {
                Label {
                    Text("TODAY")
                } icon: {
                    Image(systemName: "sun.max.fill")
                }
            }
            .tag(Tab.today)

            NavigationStack {
                InsightsOverviewView(goals: goals)
                    .navigationTitle("INSIGHTS")
                    .navigationBarTitleDisplayMode(.inline)
                    .environment(\.designStyle, .brutalist)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("INSIGHTS")
                                .font(AppTheme.BrutalistTypography.title)
                                .fontWeight(.bold)
                        }
                    }
            }
            .tabItem {
                Label {
                    Text("INSIGHTS")
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
            }
            .tag(Tab.insights)

            NavigationStack {
                SettingsRootView(
                    sendDailyDigest: $sendDailyDigest,
                    allowNotificationPreviews: $allowNotificationPreviews
                )
                .navigationTitle("SETTINGS")
                .navigationBarTitleDisplayMode(.inline)
                .environment(\.designStyle, .brutalist)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("SETTINGS")
                            .font(AppTheme.BrutalistTypography.title)
                            .fontWeight(.bold)
                    }
                }
            }
            .tabItem {
                Label {
                    Text("SETTINGS")
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
            .tag(Tab.settings)
        }
        .sheet(isPresented: $showingCreateGoal) {
            GoalCreateView(modelContext: modelContext)
                .environment(\.designStyle, .brutalist)
        }
        .onAppear(perform: initializeDashboard)
        .onReceive(notificationRouter.$activeRoute) { route in
            notificationRoute = route
        }
        .sheet(
            item: $notificationRoute,
            onDismiss: {
                notificationRouter.reset()
            }
        ) { route in
            if let goal = goal(for: route.goalID) {
                if goal.isActive {
                    // Goal exists and is active - show data entry
                    NotificationLogEntryView(
                        goal: goal,
                        questionID: route.questionID,
                        isTest: route.isTest,
                        modelContext: modelContext
                    )
                } else {
                    // Goal exists but is paused - inform user
                    InactiveGoalPlaceholder(goalTitle: goal.title)
                }
            } else {
                // Goal doesn't exist - deleted or corrupted
                MissingGoalPlaceholder()
            }
        }
        .onChange(of: goals) { _, _ in
            todayViewModel?.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                todayViewModel?.refresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.BrutalistSpacing.xl) {
            Spacer()

            // Illustrated empty state with warm aesthetic
            VStack(spacing: AppTheme.BrutalistSpacing.lg) {
                // Icon with accent glow
                ZStack {
                    Circle()
                        .fill(AppTheme.BrutalistPalette.accent.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(AppTheme.BrutalistPalette.surface)
                        .frame(width: 96, height: 96)

                    Image(systemName: "target")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(AppTheme.BrutalistPalette.accent)
                }

                // Title & Description
                VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                    Text("Start Your Journey")
                        .font(AppTheme.BrutalistTypography.title)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)

                    Text("Create your first goal to begin tracking\nwhat matters most to you.")
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            // Call to Action with new style
            VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                Button {
                    showingCreateGoal = true
                } label: {
                    HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Create Goal")
                    }
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft))
                }
                .brutalistButton(style: .primary)

                Text("It only takes a minute")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
            .padding(.horizontal, AppTheme.BrutalistSpacing.lg)
            .padding(.bottom, AppTheme.BrutalistSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.BrutalistPalette.background)
    }

    private var goalsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                ForEach(goals) { goal in
                    BrutalistGoalCardView(goal: goal)
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(AppTheme.BrutalistPalette.background)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func initializeDashboard() {
        if todayViewModel == nil {
            let viewModel = TodayDashboardViewModel(modelContext: modelContext)
            viewModel.refresh()
            todayViewModel = viewModel
        }
    }

    private func deleteGoals(at offsets: IndexSet) {
        let deletionService = GoalDeletionService(modelContext: modelContext)

        for index in offsets {
            let goal = goals[index]
            do {
                try deletionService.moveToTrash(goal)
            } catch {
                print("Failed to delete goal: \(error)")
            }
        }
    }

    private func goal(for id: UUID) -> TrackingGoal? {
        // First: Check all goals (active + inactive)
        if let match = allGoals.first(where: { $0.id == id }) {
            return match
        }

        // Fallback: Fresh fetch from persistence
        var descriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == id },
            sortBy: []
        )
        descriptor.fetchLimit = 1

        // Log if fallback is needed (helps debugging)
        if let goal = try? modelContext.fetch(descriptor).first {
            #if DEBUG
                print("[NotificationRouting] Goal \(id) found via fallback fetch (not in Query)")
            #endif
            return goal
        }

        // Goal truly doesn't exist
        #if DEBUG
            print(
                "[NotificationRouting] Goal \(id) not found anywhere - deleted or corrupt notification"
            )
        #endif
        return nil
    }
}

extension ContentView {
    enum Tab: Hashable {
        case goals
        case today
        case insights
        case settings
    }
}

private struct InsightsOverviewView: View {
    @Environment(\.designStyle) private var designStyle
    let goals: [TrackingGoal]

    var body: some View {
        if designStyle == .brutalist {
            BrutalistInsightsFeed(goals: goals)
        } else {
            LegacyInsightsFeed(goals: goals)
        }
    }
}

private struct LegacyInsightsFeed: View {
    let goals: [TrackingGoal]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header

                if goals.isEmpty {
                    CardBackground {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Add a goal to unlock trends")
                                .font(AppTheme.Typography.bodyStrong)
                            Text(
                                "Create your first goal to see charts, streaks, and insights here."
                            )
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        ForEach(goals) { goal in
                            GoalTrendFeedCard(goal: goal)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .background(AppTheme.Palette.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Your progress")
                .font(AppTheme.Typography.sectionHeader)
            Text("Review trends, streaks, and latest responses for each goal.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BrutalistInsightsFeed: View {
    let goals: [TrackingGoal]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xl) {
                if goals.isEmpty {
                    BrutalistEmptyInsightsState()
                } else {
                    BrutalistRecentActivitySection(entries: recentEntries)
                    BrutalistGoalInsightsSection(goals: goals)
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
    }

    // Former digest helpers removed as the Insights Digest was cut

    private var recentEntries: [RecentLogEntry] {
        guard !goals.isEmpty else { return [] }
        let now = Date()
        return
            allDataPoints
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(6)
            .compactMap { dataPoint in
                guard
                    let goalTitle = dataPoint.goal?.title
                        ?? goals.first(where: {
                            $0.id == dataPoint.goal?.id
                        })?.title
                else {
                    return nil
                }

                let question = dataPoint.question
                let responseType = question?.responseType ?? fallbackResponseType(for: dataPoint)
                let value = formatValue(for: dataPoint, responseType: responseType)
                let relative = Self.relativeFormatter.localizedString(
                    for: dataPoint.timestamp,
                    relativeTo: now
                )

                return RecentLogEntry(
                    id: dataPoint.id,
                    goalTitle: goalTitle,
                    questionTitle: question?.text,
                    valueDescription: value,
                    detail: relative.uppercased(),
                    icon: icon(for: responseType)
                )
            }
    }

    private var allDataPoints: [DataPoint] {
        goals.flatMap(\.dataPoints)
    }

    private func icon(for responseType: ResponseType) -> String {
        switch responseType {
        case .numeric, .scale, .slider:
            return "chart.bar.fill"
        case .waterIntake:
            return "drop.fill"
        case .boolean:
            return "checkmark.seal.fill"
        case .multipleChoice:
            return "square.grid.2x2"
        case .text:
            return "text.alignleft"
        case .time:
            return "clock"
        }
    }

    private func formatValue(for dataPoint: DataPoint, responseType: ResponseType) -> String {
        switch responseType {
        case .numeric, .scale, .slider:
            if let value = dataPoint.numericValue {
                return Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
            }
        case .waterIntake:
            if let value = dataPoint.numericValue {
                return HydrationFormatter.ouncesString(value)
            }
        case .boolean:
            if let value = dataPoint.boolValue {
                return value ? "YES" : "NO"
            }
        case .multipleChoice:
            if let selections = dataPoint.selectedOptions, !selections.isEmpty {
                return selections.joined(separator: ", ").uppercased()
            }
        case .text:
            if let text = dataPoint.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            {
                if text.count > 60 {
                    let prefix = String(text.prefix(57))
                    return prefix + "…"
                }
                return text
            }
        case .time:
            if let date = dataPoint.timeValue {
                let timezone = dataPoint.goal?.schedule.timezone ?? .current
                Self.timeFormatter.timeZone = timezone
                return Self.timeFormatter.string(from: date)
            }
        }

        if let numeric = dataPoint.numericValue {
            return Self.numberFormatter.string(from: NSNumber(value: numeric)) ?? "--"
        }
        if let text = dataPoint.textValue,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return text
        }
        return "--"
    }

    private func fallbackResponseType(for dataPoint: DataPoint) -> ResponseType {
        if dataPoint.numericValue != nil {
            return .numeric
        }
        if dataPoint.boolValue != nil {
            return .boolean
        }
        if let selections = dataPoint.selectedOptions, !selections.isEmpty {
            return .multipleChoice
        }
        if let text = dataPoint.textValue,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return .text
        }
        if dataPoint.timeValue != nil {
            return .time
        }
        return .numeric
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct BrutalistEmptyInsightsState: View {
    var body: some View {
        VStack(spacing: AppTheme.BrutalistSpacing.lg) {
            // Icon with subtle styling
            ZStack {
                Circle()
                    .fill(AppTheme.BrutalistPalette.accent.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppTheme.BrutalistPalette.accent)
            }

            VStack(spacing: AppTheme.BrutalistSpacing.xs) {
                Text("No Insights Yet")
                    .font(AppTheme.BrutalistTypography.headline)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)

                Text("Create your first goal to unlock\nanalytics and track your progress.")
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.BrutalistSpacing.xxl)
    }
}

// Removed Insights Digest types (HeroStat, HeroLayoutStyle, BrutalistInsightsHero,
// BrutalistStatTile, BrutalistStatBand) as the digest was cut from the design

private struct RecentLogEntry: Identifiable, Hashable {
    let id: UUID
    let goalTitle: String
    let questionTitle: String?
    let valueDescription: String
    let detail: String
    let icon: String
}

private struct BrutalistRecentActivitySection: View {
    @Environment(\.colorScheme) private var colorScheme
    let entries: [RecentLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            Text("Recent Activity".uppercased())
                .font(AppTheme.BrutalistTypography.overline)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                .tracking(0.8)

            if entries.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                        Image(systemName: "clock")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)

                        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                            Text("No logs yet")
                                .font(AppTheme.BrutalistTypography.bodyBold)
                                .foregroundColor(AppTheme.BrutalistPalette.foreground)
                            Text("Once you log updates, your most recent entries will appear here.")
                                .font(AppTheme.BrutalistTypography.caption)
                                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        }
                    }
                }
                .padding(AppTheme.BrutalistSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .fill(AppTheme.BrutalistPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .stroke(
                            AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.hairline)
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        BrutalistRecentActivityRow(entry: entry)
                            .padding(.vertical, AppTheme.BrutalistSpacing.sm)

                        if index < entries.count - 1 {
                            Rectangle()
                                .fill(AppTheme.BrutalistPalette.border)
                                .frame(height: AppTheme.BrutalistBorder.hairline)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.BrutalistSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .fill(AppTheme.BrutalistPalette.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                        .stroke(
                            AppTheme.BrutalistPalette.border,
                            lineWidth: AppTheme.BrutalistBorder.thin)
                )
                .appShadow(colorScheme == .dark ? nil : AppTheme.BrutalistShadow.elevation1)
            }
        }
    }
}

private struct BrutalistRecentActivityRow: View {
    let entry: RecentLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.BrutalistSpacing.sm) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                    .fill(AppTheme.BrutalistPalette.accent.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: entry.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.BrutalistPalette.accent)
            }

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                HStack {
                    Text(entry.goalTitle.uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        .tracking(0.3)

                    Spacer()

                    Text(entry.detail)
                        .font(AppTheme.BrutalistTypography.smallMono)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }

                if let question = entry.questionTitle?.nonEmpty {
                    Text(question)
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                        .lineLimit(1)
                }

                Text(entry.valueDescription)
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                    .lineLimit(1)
            }
        }
    }
}

private struct GoalStatistic: Identifiable, Hashable {
    let title: String
    let value: String
    let icon: String

    var id: String { title + value + icon }
}

private struct BrutalistGoalStatsGrid: View {
    let stats: [GoalStatistic]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: AppTheme.BrutalistSpacing.sm
        ) {
            ForEach(stats) { stat in
                BrutalistGoalStatTile(stat: stat)
            }
        }
    }
}

private struct BrutalistGoalStatTile: View {
    let stat: GoalStatistic

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            HStack(spacing: AppTheme.BrutalistSpacing.micro) {
                Image(systemName: stat.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                Text(stat.title.uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    .tracking(0.3)
            }

            Text(stat.value)
                .font(AppTheme.BrutalistTypography.dataSmall)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, AppTheme.BrutalistSpacing.sm)
        .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                .fill(AppTheme.BrutalistPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                .stroke(
                    AppTheme.BrutalistPalette.border, lineWidth: AppTheme.BrutalistBorder.hairline)
        )
    }
}

private func goalStatistics(from viewModel: GoalTrendsViewModel) -> [GoalStatistic] {
    let calendar = Calendar.current
    let now = Date()
    let todayEntry = viewModel.dailySeries.last(where: { calendar.isDateInToday($0.date) })
    let todayValue = todayEntry.map { viewModel.formattedNumber($0.averageValue) } ?? "No log"

    let streak = viewModel.currentStreakDays
    var stats: [GoalStatistic] = [
        GoalStatistic(title: "Today", value: todayValue, icon: "target")
    ]

    if streak > 0 {
        let unit = streak == 1 ? "day" : "days"
        stats.append(GoalStatistic(title: "Streak", value: "\(streak) \(unit)", icon: "flame"))
    }

    let lastLogDate = viewModel.latestLogDate ?? viewModel.dailySeries.last?.date

    if let lastLogDate {
        let lastLogText: String
        if calendar.isDateInToday(lastLogDate) {
            lastLogText = "Today"
        } else {
            lastLogText = goalStatsRelativeFormatter.localizedString(
                for: lastLogDate,
                relativeTo: now
            )
        }
        stats.append(GoalStatistic(title: "Last log", value: lastLogText, icon: "clock"))
    }

    return stats
}

private let goalStatsRelativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter
}()

private struct BrutalistGoalInsightsSection: View {
    let goals: [TrackingGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            Text("Goal Deep Dives".uppercased())
                .font(AppTheme.BrutalistTypography.overline)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                .tracking(0.8)

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                ForEach(sortedGoals) { goal in
                    BrutalistGoalInsightsCard(goal: goal)
                }
            }
        }
    }

    private var sortedGoals: [TrackingGoal] {
        goals.sorted { $0.updatedAt > $1.updatedAt }
    }
}

private struct BrutalistGoalInsightsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let goal: TrackingGoal

    @State private var trendsViewModel: GoalTrendsViewModel?

    // Category color for visual identity
    private var categoryColor: Color {
        switch goal.category {
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

    var body: some View {
        HStack(spacing: 0) {
            // Left accent stripe
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                .fill(categoryColor)
                .frame(width: 4)

            // Card content
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                header

                if let viewModel = trendsViewModel {
                    BrutalistGoalStatsGrid(stats: goalStatistics(from: viewModel))

                    GoalTrendsView(viewModel: viewModel, displayMode: .compact)
                        .environment(\.designStyle, .brutalist)
                } else {
                    loadingState
                }

                NavigationLink {
                    GoalDetailView(goal: goal)
                        .environment(\.designStyle, .brutalist)
                } label: {
                    HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                        Text("View Full Details")
                            .font(AppTheme.BrutalistTypography.captionBold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(categoryColor)
                }
                .buttonStyle(.plain)
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                .fill(AppTheme.BrutalistPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                .stroke(AppTheme.BrutalistPalette.border, lineWidth: AppTheme.BrutalistBorder.thin)
        )
        .appShadow(colorScheme == .dark ? nil : AppTheme.BrutalistShadow.elevation2)
        .task { updateViewModel(forceCreate: trendsViewModel == nil) }
        .onChange(of: goal.persistentModelID) { _, _ in
            updateViewModel(forceCreate: true)
        }
        .onChange(of: goal.updatedAt) { _, _ in
            trendsViewModel?.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                    Text(goal.title)
                        .font(AppTheme.BrutalistTypography.headline)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)

                    if let category = goal.categoryDisplayName.nonEmpty {
                        HStack(spacing: AppTheme.BrutalistSpacing.micro) {
                            Circle()
                                .fill(categoryColor)
                                .frame(width: 6, height: 6)
                            Text(category.uppercased())
                                .font(AppTheme.BrutalistTypography.overline)
                                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                                .tracking(0.3)
                        }
                    }
                }

                Spacer()

                statusBadge
            }

            if let description = goal.goalDescription.nonEmpty {
                Text(description)
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var statusBadge: some View {
        Text(goal.isActive ? "ACTIVE" : "PAUSED")
            .font(AppTheme.BrutalistTypography.overline)
            .tracking(0.3)
            .padding(.horizontal, AppTheme.BrutalistSpacing.xs)
            .padding(.vertical, AppTheme.BrutalistSpacing.micro)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                    .fill(
                        goal.isActive
                            ? categoryColor.opacity(0.15)
                            : AppTheme.BrutalistPalette.border.opacity(0.1))
            )
            .foregroundColor(
                goal.isActive
                    ? categoryColor : AppTheme.BrutalistPalette.secondary)
    }

    private var loadingState: some View {
        HStack(spacing: AppTheme.BrutalistSpacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.BrutalistPalette.secondary)
            Text("Gathering insights…")
                .font(AppTheme.BrutalistTypography.caption)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .padding(.vertical, AppTheme.BrutalistSpacing.md)
    }

    private func updateViewModel(forceCreate: Bool) {
        if forceCreate {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
            return
        }

        guard let current = trendsViewModel else { return }

        if current.goal.persistentModelID == goal.persistentModelID {
            current.refresh()
        } else {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
        }
    }
}

private struct GoalTrendFeedCard: View {
    @Environment(\.modelContext) private var modelContext

    let goal: TrackingGoal

    @State private var trendsViewModel: GoalTrendsViewModel?

    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                header

                if let viewModel = trendsViewModel {
                    GoalTrendsView(viewModel: viewModel)
                } else {
                    ContentUnavailableView(
                        "Gathering insights",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("We are preparing your goal analytics.")
                    )
                    .frame(maxWidth: .infinity)
                }

                NavigationLink {
                    GoalDetailView(goal: goal)
                } label: {
                    Label("Open goal details", systemImage: "chevron.right.circle")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .task { updateViewModel(forceCreate: trendsViewModel == nil) }
        .onChange(of: goal.persistentModelID) { _, _ in
            updateViewModel(forceCreate: true)
        }
        .onChange(of: goal.updatedAt) { _, _ in
            trendsViewModel?.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(goal.title)
                .font(AppTheme.Typography.bodyStrong)
            if let category = goal.categoryDisplayName.nonEmpty {
                Label(category, systemImage: "tag")
                    .font(AppTheme.Typography.caption)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func updateViewModel(forceCreate: Bool) {
        if forceCreate {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
            return
        }

        guard let current = trendsViewModel else { return }

        if current.goal.persistentModelID == goal.persistentModelID {
            current.refresh()
        } else {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
        }
    }
}

private struct BrutalistGoalCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let goal: TrackingGoal

    @State private var trendsViewModel: GoalTrendsViewModel?
    @State private var showingReminderDetails = false
    @State private var presentingDataEntry = false

    // Category color for the accent stripe
    private var categoryColor: Color {
        switch goal.category {
        case .health:
            return AppTheme.BrutalistPalette.categoryHealth
        case .fitness:
            return AppTheme.BrutalistPalette.categoryFitness
        case .productivity:
            return AppTheme.BrutalistPalette.categoryProductivity
        case .habits:
            return AppTheme.BrutalistPalette.categoryHabits
        case .mood:
            return AppTheme.BrutalistPalette.categoryMood
        case .learning:
            return AppTheme.BrutalistPalette.categoryLearning
        case .social:
            return AppTheme.BrutalistPalette.categorySocial
        case .finance:
            return AppTheme.BrutalistPalette.categoryFinance
        case .custom:
            return AppTheme.BrutalistPalette.accent
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent stripe
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                .fill(categoryColor)
                .frame(width: 4)

            // Card content
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                header

                if let viewModel = trendsViewModel {
                    quickStats(using: viewModel)
                }

                actionRow()

                sectionDivider

                if let viewModel = trendsViewModel {
                    GoalTrendsView(viewModel: viewModel, displayMode: .compact)
                        .environment(\.designStyle, .brutalist)
                } else {
                    loadingState
                }

                DisclosureGroup(isExpanded: $showingReminderDetails) {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                        metaRow(label: "Cadence", value: scheduleSummary)
                        if let timezoneLabel = goal.schedule.timezone.identifier.split(
                            separator: "/"
                        )
                        .last {
                            metaRow(label: "Timezone", value: String(timezoneLabel))
                        }
                    }
                    .padding(.top, AppTheme.BrutalistSpacing.sm)
                } label: {
                    HStack {
                        Text("Reminder details".uppercased())
                            .font(AppTheme.BrutalistTypography.overline)
                            .tracking(0.5)
                        Spacer()
                    }
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                .fill(AppTheme.BrutalistPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                .stroke(AppTheme.BrutalistPalette.border, lineWidth: AppTheme.BrutalistBorder.thin)
        )
        .appShadow(colorScheme == .dark ? nil : AppTheme.BrutalistShadow.elevation2)
        .task { updateViewModel(forceCreate: trendsViewModel == nil) }
        .onChange(of: goal.persistentModelID) { _, _ in
            updateViewModel(forceCreate: true)
        }
        .onChange(of: goal.updatedAt) { _, _ in
            trendsViewModel?.refresh()
        }
        .sheet(isPresented: $presentingDataEntry) {
            DataEntryView(goal: goal, modelContext: modelContext)
                .environment(\.designStyle, .brutalist)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                    Text(goal.title)
                        .font(AppTheme.BrutalistTypography.headline)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)

                    if let category = goal.categoryDisplayName.nonEmpty {
                        HStack(spacing: AppTheme.BrutalistSpacing.micro) {
                            Circle()
                                .fill(categoryColor)
                                .frame(width: 8, height: 8)
                            Text(category.uppercased())
                                .font(AppTheme.BrutalistTypography.overline)
                                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                                .tracking(0.5)
                        }
                    }
                }

                Spacer()

                statusBadge
            }

            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var statusBadge: some View {
        Text(goal.isActive ? "ACTIVE" : "PAUSED")
            .font(AppTheme.BrutalistTypography.overline)
            .tracking(0.5)
            .padding(.horizontal, AppTheme.BrutalistSpacing.xs)
            .padding(.vertical, AppTheme.BrutalistSpacing.micro)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.minimal)
                    .fill(
                        goal.isActive
                            ? categoryColor.opacity(0.15)
                            : AppTheme.BrutalistPalette.border.opacity(0.1))
            )
            .foregroundColor(
                goal.isActive
                    ? categoryColor : AppTheme.BrutalistPalette.secondary)
    }

    private func quickStats(using viewModel: GoalTrendsViewModel) -> some View {
        BrutalistGoalStatsGrid(stats: goalStatistics(from: viewModel))
            .padding(.vertical, AppTheme.BrutalistSpacing.xs)
    }

    private func actionRow() -> some View {
        ViewThatFits(in: .horizontal) {
            // Full labels when space allows
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                actionButtons(fullLabels: true)
            }

            // Icon-only fallback to keep actions on one row
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                actionButtons(fullLabels: false)
            }

            // Final fallback stacks vertically
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                actionButtons(fullLabels: true)
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: AppTheme.BrutalistSpacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Gathering insights…")
                .font(AppTheme.BrutalistTypography.caption)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            Text(label.uppercased())
                .font(AppTheme.BrutalistTypography.overline)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
            Text(value)
                .font(AppTheme.BrutalistTypography.bodyMono)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
        }
    }

    private enum ActionChipStyle {
        case primary
        case secondary
    }

    @ViewBuilder
    private func actionButtons(fullLabels: Bool) -> some View {
        Button {
            presentingDataEntry = true
        } label: {
            Group {
                if fullLabels {
                    actionChip(text: "Log", systemImage: "square.and.pencil", style: .primary)
                } else {
                    actionChipIconOnly(systemImage: "square.and.pencil", style: .primary)
                }
            }
        }
        .buttonStyle(.plain)

        NavigationLink {
            GoalDetailView(goal: goal)
                .environment(\.designStyle, .brutalist)
        } label: {
            Group {
                if fullLabels {
                    actionChip(
                        text: "Details", systemImage: "arrow.right.square", style: .secondary)
                } else {
                    actionChipIconOnly(systemImage: "arrow.right.square", style: .secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func actionChip(text: String, systemImage: String, style: ActionChipStyle) -> some View
    {
        let foreground: Color =
            style == .primary
            ? .white : AppTheme.BrutalistPalette.foreground
        let background: Color =
            style == .primary
            ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.background
        let border: Color =
            style == .primary ? .clear : AppTheme.BrutalistPalette.border

        return HStack(spacing: AppTheme.BrutalistSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(text.uppercased())
                .font(AppTheme.BrutalistTypography.overline)
                .tracking(0.5)
        }
        .foregroundColor(foreground)
        .padding(.vertical, AppTheme.BrutalistSpacing.xs)
        .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                .stroke(border, lineWidth: AppTheme.BrutalistBorder.thin)
        )
    }

    private func actionChipIconOnly(systemImage: String, style: ActionChipStyle) -> some View {
        let foreground: Color =
            style == .primary
            ? .white : AppTheme.BrutalistPalette.foreground
        let background: Color =
            style == .primary
            ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.background
        let border: Color =
            style == .primary ? .clear : AppTheme.BrutalistPalette.border

        return Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(foreground)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                    .stroke(border, lineWidth: AppTheme.BrutalistBorder.thin)
            )
    }

    private var scheduleSummary: String {
        let times = goal.schedule.times
        guard !times.isEmpty else { return "No reminders" }
        let timezone = goal.schedule.timezone
        let timeDescription =
            times
            .map { $0.formattedTime(in: timezone) }
            .joined(separator: ", ")

        switch goal.schedule.frequency {
        case .daily:
            return "Daily @ " + timeDescription
        case .weekly:
            let weekdays = goal.schedule.normalizedWeekdays()
            if weekdays.isEmpty {
                return "Weekly @ " + timeDescription
            }
            let names = weekdays.map(\.shortDisplayName).joined(separator: ", ")
            return "Weekly on \(names) @ \(timeDescription)"
        case .monthly:
            let day = Calendar.current.component(.day, from: goal.schedule.startDate)
            return "Monthly on day \(day) @ \(timeDescription)"
        case .custom:
            if let interval = goal.schedule.intervalDayCount {
                return "Every \(interval) days @ \(timeDescription)"
            }
            return "Custom cadence"
        case .once:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.timeZone = timezone
            return formatter.string(from: goal.schedule.startDate)
        }
    }

    private func updateViewModel(forceCreate: Bool) {
        if forceCreate {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
            return
        }

        guard let current = trendsViewModel else { return }

        if current.goal.persistentModelID == goal.persistentModelID {
            current.refresh()
        } else {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppTheme.BrutalistPalette.border)
            .frame(height: AppTheme.BrutalistBorder.hairline)
            .padding(.vertical, AppTheme.BrutalistSpacing.xs)
    }
}

private struct SettingsRootView: View {
    @Binding var sendDailyDigest: Bool
    @Binding var allowNotificationPreviews: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var settingsViewModel: SettingsViewModel?
    @State private var exportDocument = BackupDocument()
    @State private var exportFilename: String = "FutureLifeBackup"
    @State private var isPresentingExporter = false
    @State private var isPresentingImporter = false
    @State private var pendingImportData: Data?
    @State private var showImportConfirmation = false
    @State private var isProcessing = false
    @State private var alertInfo: SettingsAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
                notificationsCard
                dataManagementCard
                supportCard
                aboutCard
                #if DEBUG
                    debugCard
                #endif
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(AppTheme.BrutalistPalette.background)
        .task {
            if settingsViewModel == nil {
                settingsViewModel = SettingsViewModel(modelContext: modelContext)
            }
        }
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                alertInfo = SettingsAlert(
                    title: "Export failed", message: error.localizedDescription)
            } else {
                alertInfo = SettingsAlert(
                    title: "Export ready", message: "Your data backup was created.")
            }
            isProcessing = false
        }
        .fileImporter(
            isPresented: $isPresentingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    alertInfo = SettingsAlert(
                        title: "Import cancelled", message: "No file was selected.")
                    return
                }
                prepareImport(from: url)
            case .failure(let error):
                alertInfo = SettingsAlert(
                    title: "Import failed", message: error.localizedDescription)
            }
        }
        .confirmationDialog(
            "Replace existing data?",
            isPresented: $showImportConfirmation,
            presenting: pendingImportData
        ) { data in
            Button("Replace data", role: .destructive) {
                performImport(with: data)
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
        } message: { _ in
            Text("This will delete your current goals before restoring the backup.")
        }
        .alert(item: $alertInfo) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Brutalist Cards

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            // Header with icon
            HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(AppTheme.BrutalistPalette.accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.BrutalistPalette.accent)
                }

                Text("Notifications")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                Toggle(isOn: $sendDailyDigest) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily summary digest")
                            .font(AppTheme.BrutalistTypography.body)
                            .foregroundColor(AppTheme.BrutalistPalette.foreground)
                        Text("Receive a summary of your progress")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }
                .tint(AppTheme.BrutalistPalette.accent)

                Toggle(isOn: $allowNotificationPreviews) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow reminder previews")
                            .font(AppTheme.BrutalistTypography.body)
                            .foregroundColor(AppTheme.BrutalistPalette.foreground)
                        Text("Show question text in notifications")
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }
                .tint(AppTheme.BrutalistPalette.accent)

                Rectangle()
                    .fill(AppTheme.BrutalistPalette.border.opacity(0.15))
                    .frame(height: 1)

                NavigationLink {
                    SendTestNotificationView()
                        .environment(\.designStyle, .brutalist)
                } label: {
                    HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Send Test Notification")
                            .font(AppTheme.BrutalistTypography.bodyBold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                    .padding(AppTheme.BrutalistSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                            .fill(AppTheme.BrutalistPalette.surface)
                    )
                }
                .buttonStyle(.plain)

                Text("Pick a goal and we'll send a one-off reminder to confirm delivery.")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
        }
        .padding(AppTheme.BrutalistSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .fill(AppTheme.BrutalistPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .stroke(AppTheme.BrutalistPalette.border.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            // Header with icon
            HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(AppTheme.BrutalistPalette.categoryProductivity.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.BrutalistPalette.categoryProductivity)
                }

                Text("Data Management")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                // Export button
                settingsActionRow(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    subtitle: "Save a backup of your goals and history",
                    isDisabled: isProcessing || settingsViewModel == nil,
                    action: handleExport
                )

                settingsDivider

                // Import button
                settingsActionRow(
                    icon: "square.and.arrow.down",
                    title: "Import Data",
                    subtitle: "Restore a previous backup (replaces existing)",
                    isDisabled: isProcessing || settingsViewModel == nil
                ) {
                    isPresentingImporter = true
                }

                settingsDivider

                // Trash navigation
                NavigationLink {
                    TrashInboxView().environment(\.designStyle, .brutalist)
                } label: {
                    settingsNavigationRow(
                        icon: "trash",
                        title: "Trash",
                        subtitle: "Restore deleted goals within 30 days"
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                // Merge backups navigation
                NavigationLink {
                    BackupMergeView().environment(\.designStyle, .brutalist)
                } label: {
                    settingsNavigationRow(
                        icon: "arrow.triangle.merge",
                        title: "Merge Backups",
                        subtitle: "Combine two backup files into one"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.BrutalistSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .fill(AppTheme.BrutalistPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .stroke(AppTheme.BrutalistPalette.border.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(AppTheme.BrutalistPalette.border.opacity(0.1))
            .frame(height: 1)
    }

    private func settingsActionRow(
        icon: String,
        title: String,
        subtitle: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        isDisabled
                            ? AppTheme.BrutalistPalette.secondary : AppTheme.BrutalistPalette.accent
                    )
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundColor(
                            isDisabled
                                ? AppTheme.BrutalistPalette.secondary
                                : AppTheme.BrutalistPalette.foreground)
                    Text(subtitle)
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }

                Spacer()
            }
            .padding(.vertical, AppTheme.BrutalistSpacing.xs)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }

    private func settingsNavigationRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: AppTheme.BrutalistSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.BrutalistPalette.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                Text(subtitle)
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .padding(.vertical, AppTheme.BrutalistSpacing.xs)
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            // Header with icon
            HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(AppTheme.BrutalistPalette.categoryMood.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lifepreserver.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.BrutalistPalette.categoryMood)
                }

                Text("Support")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                Link(destination: URL(string: "https://future.life/support")!) {
                    settingsNavigationRow(
                        icon: "questionmark.circle",
                        title: "Help Center",
                        subtitle: "Get answers to common questions"
                    )
                }

                settingsDivider

                Link(destination: URL(string: "https://future.life/privacy")!) {
                    settingsNavigationRow(
                        icon: "lock.shield",
                        title: "Privacy Policy",
                        subtitle: "How we protect your data"
                    )
                }
            }
        }
        .padding(AppTheme.BrutalistSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .fill(AppTheme.BrutalistPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .stroke(AppTheme.BrutalistPalette.border.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            // Header with icon
            HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(AppTheme.BrutalistPalette.categoryLearning.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.BrutalistPalette.categoryLearning)
                }

                Text("About")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }

            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                Text("Future – Life Updates")
                    .font(AppTheme.BrutalistTypography.title)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)

                HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                    Text("Version 26.0")
                        .font(AppTheme.BrutalistTypography.captionMono)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        .padding(.horizontal, AppTheme.BrutalistSpacing.xs)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
                                .fill(AppTheme.BrutalistPalette.surface)
                        )
                }

                Text("Track your goals, build habits, and see your progress over time.")
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    .padding(.top, AppTheme.BrutalistSpacing.xs)
            }
        }
        .padding(AppTheme.BrutalistSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .fill(AppTheme.BrutalistPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                .stroke(AppTheme.BrutalistPalette.border.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    #if DEBUG
        private var debugCard: some View {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                // Header with icon
                HStack(spacing: AppTheme.BrutalistSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "ant.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    Text("Debug")
                        .font(AppTheme.BrutalistTypography.bodyBold)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)
                }

                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                    NavigationLink {
                        NotificationInspectorView().environment(\.designStyle, .brutalist)
                    } label: {
                        settingsNavigationRow(
                            icon: "bell.badge",
                            title: "Notification Inspector",
                            subtitle: "View and manage scheduled notifications"
                        )
                    }
                    .buttonStyle(.plain)

                    settingsDivider

                    Group {
                        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0,
                        *) {
                            NavigationLink {
                                DebugAIChatView().environment(\.designStyle, .brutalist)
                            } label: {
                                settingsNavigationRow(
                                    icon: "bubble.left.and.bubble.right",
                                    title: "AI Debug Chat",
                                    subtitle: "Inspect Apple Intelligence responses"
                                )
                            }
                        } else {
                            HStack(spacing: AppTheme.BrutalistSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange)
                                Text("AI Debug requires latest OS")
                                    .font(AppTheme.BrutalistTypography.caption)
                                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.BrutalistSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .fill(AppTheme.BrutalistPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.round)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    #endif

    private func handleExport() {
        guard let viewModel = settingsViewModel else { return }
        isProcessing = true
        do {
            let document = try viewModel.createBackupDocument()
            exportDocument = document
            exportFilename = viewModel.makeDefaultFilename()
            isPresentingExporter = true
        } catch {
            alertInfo = SettingsAlert(title: "Export failed", message: error.localizedDescription)
            isProcessing = false
        }
    }

    private func prepareImport(from url: URL) {
        guard let viewModel = settingsViewModel else { return }

        do {
            let data = try accessData(at: url)
            if try viewModel.hasExistingData() {
                pendingImportData = data
                showImportConfirmation = true
            } else {
                performImport(with: data)
            }
        } catch {
            alertInfo = SettingsAlert(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func performImport(with data: Data) {
        guard let viewModel = settingsViewModel else { return }
        isProcessing = true
        do {
            let summary = try viewModel.importBackup(from: data)
            alertInfo = SettingsAlert(
                title: "Import complete",
                message:
                    "Restored \(summary.goalsImported) goals and \(summary.dataPointsImported) entries."
            )
        } catch {
            alertInfo = SettingsAlert(title: "Import failed", message: error.localizedDescription)
        }
        pendingImportData = nil
        isProcessing = false
    }

    private func accessData(at url: URL) throws -> Data {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}

private struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct MissingGoalPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Goal Not Found",
            systemImage: "exclamationmark.triangle",
            description: Text("We couldn't find the goal for this reminder.")
        )
    }
}

private struct InactiveGoalPlaceholder: View {
    let goalTitle: String

    var body: some View {
        ContentUnavailableView {
            Label("Goal is Paused", systemImage: "pause.circle")
        } description: {
            Text(
                "\"\(goalTitle)\" has been paused. Reactivate it from the Goals tab to start tracking again."
            )
        }
    }
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

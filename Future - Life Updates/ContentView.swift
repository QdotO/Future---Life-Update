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
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .brutalistButton(style: .secondary)
                    }
                }
                .environment(\.designStyle, .brutalist)
            }
            .tabItem {
                Label("Goals", systemImage: "target")
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
                .navigationTitle("Today")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            todayViewModel?.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(todayViewModel == nil)
                    }
                }
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }
            .tag(Tab.today)

            NavigationStack {
                InsightsOverviewView(goals: goals)
                    .navigationTitle("Insights")
            }
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(Tab.insights)

            NavigationStack {
                SettingsRootView(
                    sendDailyDigest: $sendDailyDigest,
                    allowNotificationPreviews: $allowNotificationPreviews
                )
                .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .sheet(isPresented: $showingCreateGoal) {
            GoalCreationView(viewModel: GoalCreationViewModel(modelContext: modelContext))
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
        VStack(spacing: AppTheme.BrutalistSpacing.lg) {
            Spacer()

            // Icon
            Image(systemName: "target")
                .font(.system(size: 64, weight: .regular))
                .foregroundColor(AppTheme.BrutalistPalette.secondary)

            // Title & Description
            VStack(spacing: AppTheme.BrutalistSpacing.sm) {
                Text("CREATE YOUR FIRST GOAL")
                    .font(AppTheme.BrutalistTypography.headline)
                    .fontWeight(.bold)
                    .tracking(0.05)

                Text("Set up proactive prompts to stay on track.")
                    .font(AppTheme.BrutalistTypography.body)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Call to Action
            Button {
                showingCreateGoal = true
            } label: {
                Text("+ CREATE GOAL")
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
            }
            .brutalistButton(style: .primary)
            .padding(.horizontal, AppTheme.BrutalistSpacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.BrutalistPalette.background)
        .ignoresSafeArea()
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

    let goal: TrackingGoal

    @State private var trendsViewModel: GoalTrendsViewModel?
    @State private var showingReminderDetails = false
    @State private var presentingDataEntry = false

    var body: some View {
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
                    if let timezoneLabel = goal.schedule.timezone.identifier.split(separator: "/")
                        .last
                    {
                        metaRow(label: "Timezone", value: String(timezoneLabel))
                    }
                }
                .padding(.top, AppTheme.BrutalistSpacing.sm)
            } label: {
                HStack {
                    Text("Reminder details".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                    Spacer()
                }
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
            }
        }
        .brutalistCard()
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
                        .font(AppTheme.BrutalistTypography.title)
                        .foregroundColor(AppTheme.BrutalistPalette.foreground)

                    if let category = goal.categoryDisplayName.nonEmpty {
                        Text(category.uppercased())
                            .font(AppTheme.BrutalistTypography.overline)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
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
            .font(AppTheme.BrutalistTypography.captionMono)
            .padding(.horizontal, AppTheme.BrutalistSpacing.xs)
            .padding(.vertical, AppTheme.BrutalistSpacing.micro)
            .background(
                goal.isActive
                    ? AppTheme.BrutalistPalette.accent
                    : AppTheme.BrutalistPalette.border.opacity(0.2)
            )
            .foregroundColor(
                goal.isActive
                    ? AppTheme.BrutalistPalette.background : AppTheme.BrutalistPalette.foreground)
    }

    private func quickStats(using viewModel: GoalTrendsViewModel) -> some View {
        let stats = statData(from: viewModel)

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: AppTheme.BrutalistSpacing.sm
        ) {
            ForEach(stats, id: \.title) { stat in
                statPill(title: stat.title, value: stat.value, icon: stat.icon)
            }
        }
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

    private func statPill(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
            HStack(spacing: AppTheme.BrutalistSpacing.micro) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                Text(title.uppercased())
                    .font(AppTheme.BrutalistTypography.overline)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }

            Text(value)
                .font(AppTheme.BrutalistTypography.bodyMono)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, AppTheme.BrutalistSpacing.xs)
        .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
        .background(AppTheme.BrutalistPalette.background)
        .border(AppTheme.BrutalistPalette.border, width: AppTheme.BrutalistBorder.thin)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
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
            ? AppTheme.BrutalistPalette.background : AppTheme.BrutalistPalette.foreground
        let background: Color =
            style == .primary
            ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.background
        let border: Color =
            style == .primary ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.border

        return HStack(spacing: AppTheme.BrutalistSpacing.micro) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(text.uppercased())
                .font(AppTheme.BrutalistTypography.captionMono)
        }
        .foregroundColor(foreground)
        .padding(.vertical, AppTheme.BrutalistSpacing.micro)
        .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(border, lineWidth: AppTheme.BrutalistBorder.thin)
        )
    }

    private func actionChipIconOnly(systemImage: String, style: ActionChipStyle) -> some View {
        let foreground: Color =
            style == .primary
            ? AppTheme.BrutalistPalette.background : AppTheme.BrutalistPalette.foreground
        let background: Color =
            style == .primary
            ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.background
        let border: Color =
            style == .primary ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.border

        return Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.vertical, AppTheme.BrutalistSpacing.micro)
            .padding(.horizontal, AppTheme.BrutalistSpacing.sm)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(border, lineWidth: AppTheme.BrutalistBorder.thin)
            )
    }

    private func statData(from viewModel: GoalTrendsViewModel) -> [(
        title: String, value: String, icon: String
    )] {
        let todayEntry = viewModel.dailySeries.last(where: {
            Calendar.current.isDateInToday($0.date)
        })
        let todayValue = todayEntry.map { viewModel.formattedNumber($0.averageValue) } ?? "No log"

        let lastEntry = viewModel.dailySeries.last
        let lastLogText: String
        if let lastEntry {
            if Calendar.current.isDateInToday(lastEntry.date) {
                lastLogText = "Today"
            } else {
                lastLogText = Self.relativeFormatter.localizedString(
                    for: lastEntry.date, relativeTo: Date())
            }
        } else {
            lastLogText = "--"
        }

        let streak = viewModel.currentStreakDays
        let streakText = streak == 0 ? "None" : "\(streak) days"

        return [
            (title: "Today", value: todayValue, icon: "target"),
            (title: "Streak", value: streakText, icon: "flame"),
            (title: "Last log", value: lastLogText, icon: "clock"),
        ]
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

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
            .frame(height: AppTheme.BrutalistBorder.thin)
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
        List {
            Section("Notifications") {
                Toggle(isOn: $sendDailyDigest) {
                    Text("Daily summary digest")
                }
                Toggle(isOn: $allowNotificationPreviews) {
                    Text("Allow reminder previews")
                }
            }

            Section("Data management") {
                Button {
                    handleExport()
                } label: {
                    Label("Export data", systemImage: "square.and.arrow.up")
                }
                .disabled(isProcessing || settingsViewModel == nil)

                Text("Save a backup of your goals and history to Files.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                Button {
                    isPresentingImporter = true
                } label: {
                    Label("Import data", systemImage: "square.and.arrow.down")
                }
                .disabled(isProcessing || settingsViewModel == nil)

                Text("Restore a previous backup. Existing data will be replaced.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    TrashInboxView()
                } label: {
                    Label("Trash", systemImage: "trash")
                }

                Text("Restore deleted goals within 30 days.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    BackupMergeView()
                } label: {
                    Label("Merge Backups (Advanced)", systemImage: "arrow.triangle.merge")
                }

                Text("Combine two backup files into one.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Support") {
                Link(destination: URL(string: "https://future.life/support")!) {
                    Label("Help Center", systemImage: "questionmark.circle")
                }
                Link(destination: URL(string: "https://future.life/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
            }

            Section("About") {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Future – Life Updates")
                        .font(AppTheme.Typography.bodyStrong)
                    Text("Build 26.0")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if DEBUG
                Section("Debug") {
                    NavigationLink {
                        NotificationInspectorView()
                    } label: {
                        Label("Notification Inspector", systemImage: "bell.badge")
                    }
                    Text("View and manage all scheduled notifications.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)

                    if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
                        NavigationLink {
                            DebugAIChatView()
                        } label: {
                            Label("AI Debug Chat", systemImage: "bubble.left.and.bubble.right")
                        }
                        Text("Inspect Apple Intelligence responses in a local conversation.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(
                            "AI Debug Chat requires the latest OS",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            #endif
        }
        #if os(iOS)
            .listStyle(.insetGrouped)
        #else
            .listStyle(.inset)
        #endif
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

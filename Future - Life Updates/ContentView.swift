//
//  ContentView.swift
//  Future - Life Updates
//
//  Created by Quincy Obeng on 9/23/25.
//

import SwiftUI
import SwiftData
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
    private var goals: [TrackingGoal]

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
                .navigationTitle("Goals")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCreateGoal = true
                        } label: {
                            Label("Add Goal", systemImage: "plus")
                        }
                    }
                }
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
                InsightsOverviewView(
                    highlights: insightsHighlights,
                    recentGoals: Array(goals.prefix(3)),
                    allGoals: goals
                )
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
        .sheet(item: $notificationRoute, onDismiss: {
            notificationRouter.reset()
        }) { route in
            if let goal = goal(for: route.goalID) {
                NotificationLogEntryView(
                    goal: goal,
                    questionID: route.questionID,
                    isTest: route.isTest,
                    modelContext: modelContext
                )
            } else {
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
        ContentUnavailableView(
            "Create your first goal",
            systemImage: "target",
            description: Text("Set up proactive prompts to stay on track.")
        )
        .toolbarBackground(.automatic, for: .navigationBar)
    }

    private var goalsList: some View {
        List {
            ForEach(goals) { goal in
                NavigationLink(destination: GoalDetailView(goal: goal)) {
                    GoalCardView(goal: goal)
                }
            }
            .onDelete(perform: deleteGoals)
        }
    }

    private var insightsHighlights: [InsightsOverviewView.Highlight] {
        let activeGoals = goals.filter { $0.isActive }.count
        let todaysMetrics = todayViewModel?.goalQuestionMetrics.reduce(into: 0) { partialResult, summary in
            partialResult += summary.metrics.count
        } ?? 0
        let remindersCount = todayViewModel?.upcomingReminders.count ?? 0

        return [
            .init(
                title: "Active goals",
                value: "\(activeGoals)",
                caption: "Keeping you on track",
                icon: "target",
                tint: AppTheme.Palette.primary
            ),
            .init(
                title: "Logged today",
                value: "\(todaysMetrics)",
                caption: "Questions with fresh entries",
                icon: "checkmark.circle.fill",
                tint: .green
            ),
            .init(
                title: "Upcoming reminders",
                value: remindersCount == 0 ? "None" : "\(remindersCount)",
                caption: remindersCount == 0 ? "You're clear for now" : "Queued before midnight",
                icon: "bell.badge.fill",
                tint: AppTheme.Palette.secondary
            )
        ]
    }

    private func initializeDashboard() {
        if todayViewModel == nil {
            let viewModel = TodayDashboardViewModel(modelContext: modelContext)
            viewModel.refresh()
            todayViewModel = viewModel
        }
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = goals[index]
            modelContext.delete(goal)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete goals: \(error)")
        }
    }

    private func goal(for id: UUID) -> TrackingGoal? {
        if let match = goals.first(where: { $0.id == id }) {
            return match
        }

        var descriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == id },
            sortBy: []
        )
        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
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

private struct GoalCardView: View {
    @Bindable var goal: TrackingGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Label(goal.categoryDisplayName, systemImage: "tag")
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let nextReminder = goal.schedule.times.first {
                Text("Next reminder: \(nextReminder.formattedTime(in: goal.schedule.timezone))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let latestEntry = goal.dataPoints.sorted(by: { $0.timestamp > $1.timestamp }).first,
               let question = latestEntry.question {
                HStack {
                    Text("Last response")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(question.text)
                        .font(.footnote)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct InsightsOverviewView: View {
    struct Highlight: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let caption: String
        let icon: String
        let tint: Color
    }

    let highlights: [Highlight]
    let recentGoals: [TrackingGoal]
    let allGoals: [TrackingGoal]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(highlights) { highlight in
                        CardBackground {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                                    Image(systemName: highlight.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(highlight.tint)
                                        .symbolRenderingMode(.hierarchical)
                                    Text(highlight.title)
                                        .font(AppTheme.Typography.bodyStrong)
                                }

                                Text(highlight.value)
                                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.Palette.neutralStrong)

                                Text(highlight.caption)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !recentGoals.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Recently updated")
                            .font(AppTheme.Typography.sectionHeader)
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(recentGoals) { goal in
                                CardBackground {
                                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                        Text(goal.title)
                                            .font(AppTheme.Typography.bodyStrong)
                                        Label(goal.categoryDisplayName, systemImage: "tag")
                                            .font(AppTheme.Typography.caption)
                                            .labelStyle(.titleAndIcon)
                                            .foregroundStyle(.secondary)
                                        Text(goal.goalDescription.isEmpty ? "Tap to add more details" : goal.goalDescription)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }

                if allGoals.isEmpty {
                    CardBackground {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Add a goal to unlock trends")
                                .font(AppTheme.Typography.bodyStrong)
                            Text("Create your first goal to see charts, streaks, and insights here.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    GoalTrendsInsightsSection(goals: allGoals)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .background(AppTheme.Palette.background.ignoresSafeArea())
    }
}

private struct GoalTrendsInsightsSection: View {
    @Environment(\.modelContext) private var modelContext

    let goals: [TrackingGoal]

    @State private var selectedGoalID: UUID?
    @State private var trendsViewModel: GoalTrendsViewModel?

    private var selectedGoal: TrackingGoal? {
        guard let id = selectedGoalID else { return goals.first }
        return goals.first(where: { $0.id == id }) ?? goals.first
    }

    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Goal trends")
                    .font(AppTheme.Typography.sectionHeader)

                if goals.count > 1 {
                    Picker("Goal", selection: $selectedGoalID) {
                        ForEach(goals) { goal in
                            Text(goal.title)
                                .tag(goal.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let viewModel = trendsViewModel {
                    GoalTrendsView(viewModel: viewModel)
                } else {
                    ContentUnavailableView(
                        "Pick a goal",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Choose a goal to explore your streaks and averages.")
                    )
                    .frame(maxWidth: .infinity)
                }

                if let goal = selectedGoal {
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        Label("Open goal details", systemImage: "chevron.right.circle")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .task {
            if selectedGoalID == nil {
                selectedGoalID = goals.first?.id
            }
            updateTrends()
        }
        .onChange(of: selectedGoalID) { _, _ in
            updateTrends()
        }
        .onChange(of: goals.map(\.id)) { _, _ in
            if let selectedID = selectedGoalID,
               !goals.contains(where: { $0.id == selectedID }) {
                selectedGoalID = goals.first?.id
            }
            updateTrends()
        }
        .onChange(of: selectedGoal?.updatedAt) { _, _ in
            trendsViewModel?.refresh()
        }
    }

    private func updateTrends() {
        guard let goal = selectedGoal else {
            trendsViewModel = nil
            return
        }

        if let current = trendsViewModel,
           current.goal.persistentModelID == goal.persistentModelID {
            current.refresh()
        } else {
            trendsViewModel = GoalTrendsViewModel(goal: goal, modelContext: modelContext)
        }
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
        }
        .listStyle(.insetGrouped)
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
            if case let .failure(error) = result {
                alertInfo = SettingsAlert(title: "Export failed", message: error.localizedDescription)
            } else {
                alertInfo = SettingsAlert(title: "Export ready", message: "Your data backup was created.")
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
                    alertInfo = SettingsAlert(title: "Import cancelled", message: "No file was selected.")
                    return
                }
                prepareImport(from: url)
            case .failure(let error):
                alertInfo = SettingsAlert(title: "Import failed", message: error.localizedDescription)
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
                message: "Restored \(summary.goalsImported) goals and \(summary.dataPointsImported) entries."
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

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

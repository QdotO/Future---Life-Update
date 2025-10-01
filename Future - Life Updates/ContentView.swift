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
        ContentUnavailableView(
            "Create your first goal",
            systemImage: "target",
            description: Text("Set up proactive prompts to stay on track.")
        )
        #if os(iOS)
            .toolbarBackground(.automatic, for: .navigationBar)
        #endif
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
            NotificationScheduler.shared.cancelNotifications(forGoalID: goal.id)
            modelContext.delete(goal)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete goals: \(error)")
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
        }
        .padding(.vertical, 8)
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
            #if DEBUG
                Section("Debug") {
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

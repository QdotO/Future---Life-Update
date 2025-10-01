//
//  MacOSContentView.swift
//  Future - Life Updates
//
//  Created for macOS-native design patterns
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    @MainActor
    struct MacOSContentView: View {
        @Environment(\.modelContext) private var modelContext
        @EnvironmentObject private var notificationRouter: NotificationRoutingController
        @Environment(\.scenePhase) private var scenePhase

        @State private var showingCreateGoal = false
        @State private var notificationRoute: NotificationRoutingController.Route?
        @State private var todayViewModel: TodayDashboardViewModel?
        @State private var selectedSection: NavigationSection = .today
        @State private var sendDailyDigest = true
        @State private var allowNotificationPreviews = true
        @State private var columnVisibility: NavigationSplitViewVisibility = .all

        @Query(sort: \TrackingGoal.updatedAt, order: .reverse)
        private var allGoals: [TrackingGoal]

        // Computed property to filter active goals for UI display
        private var goals: [TrackingGoal] {
            allGoals.filter { $0.isActive }
        }

        var body: some View {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Sidebar
                List(NavigationSection.allCases, id: \.self, selection: $selectedSection) {
                    section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.iconName)
                    }
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            toggleSidebar()
                        } label: {
                            Label("Toggle Sidebar", systemImage: "sidebar.left")
                        }
                    }
                }
            } detail: {
                // Detail content with proper materials and spacing
                Group {
                    switch selectedSection {
                    case .goals:
                        goalsView
                    case .today:
                        todayView
                    case .insights:
                        insightsView
                    case .settings:
                        settingsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
            .sheet(isPresented: $showingCreateGoal) {
                MacOSGoalCreationView(viewModel: GoalCreationViewModel(modelContext: modelContext))
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

        // MARK: - Goals View

        private var goalsView: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if goals.isEmpty {
                            emptyGoalsState
                        } else {
                            goalsListContent
                        }
                    }
                    .frame(maxWidth: 600)
                    .padding(20)
                }
                .navigationTitle("Goals")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCreateGoal = true
                        } label: {
                            Label("Add Goal", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }

        private var emptyGoalsState: some View {
            VStack(spacing: 20) {
                Image(systemName: "target")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("Create your first goal")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Set up proactive prompts to stay on track.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showingCreateGoal = true
                } label: {
                    Label("Create Goal", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }

        private var goalsListContent: some View {
            ForEach(goals) { goal in
                NavigationLink(destination: GoalDetailView(goal: goal)) {
                    MacOSGoalCard(goal: goal)
                }
                .buttonStyle(.plain)
            }
        }

        // MARK: - Today View

        private var todayView: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if let dashboardViewModel = todayViewModel {
                            TodayDashboardView(viewModel: dashboardViewModel)
                                .frame(maxWidth: 600)
                        } else {
                            ProgressView("Loading today")
                                .task {
                                    initializeDashboard()
                                }
                        }
                    }
                    .padding(20)
                }
                .navigationTitle("Today")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            todayViewModel?.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(todayViewModel == nil)
                    }
                }
            }
        }

        // MARK: - Insights View

        private var insightsView: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        insightsHeader

                        if goals.isEmpty {
                            emptyInsightsState
                        } else {
                            VStack(spacing: 16) {
                                ForEach(goals) { goal in
                                    MacOSGoalTrendCard(goal: goal)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 600)
                    .padding(20)
                }
                .navigationTitle("Insights")
            }
        }

        private var insightsHeader: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your progress")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Review trends, streaks, and latest responses for each goal.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }

        private var emptyInsightsState: some View {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("Add a goal to unlock trends")
                        .font(.headline)
                    Text("Create your first goal to see charts, streaks, and insights here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }

        // MARK: - Settings View

        private var settingsView: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        MacOSSettingsView(
                            sendDailyDigest: $sendDailyDigest,
                            allowNotificationPreviews: $allowNotificationPreviews
                        )
                    }
                    .frame(maxWidth: 600)
                    .padding(20)
                }
                .navigationTitle("Settings")
            }
        }

        // MARK: - Helper Functions

        private func initializeDashboard() {
            if todayViewModel == nil {
                let viewModel = TodayDashboardViewModel(modelContext: modelContext)
                viewModel.refresh()
                todayViewModel = viewModel
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
                    print(
                        "[NotificationRouting] Goal \(id) found via fallback fetch (not in Query)")
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

        private func toggleSidebar() {
            NSApp.keyWindow?.firstResponder?.tryToPerform(
                #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        }
    }

    // MARK: - Navigation Section

    extension MacOSContentView {
        enum NavigationSection: String, CaseIterable {
            case goals
            case today
            case insights
            case settings

            var title: String {
                rawValue.capitalized
            }

            var iconName: String {
                switch self {
                case .goals: return "target"
                case .today: return "sun.max.fill"
                case .insights: return "chart.line.uptrend.xyaxis"
                case .settings: return "gearshape"
                }
            }
        }
    }

    // MARK: - MacOS Goal Card

    private struct MacOSGoalCard: View {
        @Bindable var goal: TrackingGoal

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if !goal.goalDescription.isEmpty {
                            Text(goal.goalDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Label(goal.categoryDisplayName, systemImage: "tag")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
    }

    // MARK: - MacOS Goal Trend Card

    private struct MacOSGoalTrendCard: View {
        @Environment(\.modelContext) private var modelContext
        let goal: TrackingGoal

        @State private var trendsViewModel: GoalTrendsViewModel?

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.title)
                        .font(.headline)

                    if let category = goal.categoryDisplayName.nonEmpty {
                        Label(category, systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Trends content
                if let viewModel = trendsViewModel {
                    GoalTrendsView(viewModel: viewModel)
                } else {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Gathering insights...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                }

                // Action
                NavigationLink {
                    GoalDetailView(goal: goal)
                } label: {
                    Label("Open goal details", systemImage: "chevron.right.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.link)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .task { updateViewModel(forceCreate: trendsViewModel == nil) }
            .onChange(of: goal.persistentModelID) { _, _ in
                updateViewModel(forceCreate: true)
            }
            .onChange(of: goal.updatedAt) { _, _ in
                trendsViewModel?.refresh()
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

    // MARK: - MacOS Settings View

    private struct MacOSSettingsView: View {
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
            VStack(alignment: .leading, spacing: 24) {
                // Notifications Section
                settingsSection(title: "Notifications") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Daily summary digest", isOn: $sendDailyDigest)
                        Toggle("Allow reminder previews", isOn: $allowNotificationPreviews)
                    }
                }

                // Data Management Section
                settingsSection(title: "Data Management") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                handleExport()
                            } label: {
                                Label("Export data", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isProcessing || settingsViewModel == nil)

                            Text("Save a backup of your goals and history to Files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                isPresentingImporter = true
                            } label: {
                                Label("Import data", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isProcessing || settingsViewModel == nil)

                            Text("Restore a previous backup. Existing data will be replaced.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Support Section
                settingsSection(title: "Support") {
                    VStack(alignment: .leading, spacing: 12) {
                        Link(destination: URL(string: "https://future.life/support")!) {
                            Label("Help Center", systemImage: "questionmark.circle")
                        }
                        .buttonStyle(.link)

                        Link(destination: URL(string: "https://future.life/privacy")!) {
                            Label("Privacy Policy", systemImage: "lock.shield")
                        }
                        .buttonStyle(.link)
                    }
                }

                // About Section
                settingsSection(title: "About") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Future – Life Updates")
                            .font(.headline)
                        Text("Build 26.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                    // Debug Section
                    settingsSection(title: "Debug") {
                        if #available(macOS 15.0, *) {
                            NavigationLink {
                                DebugAIChatView()
                            } label: {
                                Label("AI Debug Chat", systemImage: "bubble.left.and.bubble.right")
                            }
                            .buttonStyle(.link)

                            Text("Inspect Apple Intelligence responses in a local conversation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Label(
                                "AI Debug Chat requires macOS 15 or later",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                #endif
            }
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

        @ViewBuilder
        private func settingsSection<Content: View>(
            title: String, @ViewBuilder content: () -> Content
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                content()
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
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
                alertInfo = SettingsAlert(
                    title: "Export failed", message: error.localizedDescription)
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
                alertInfo = SettingsAlert(
                    title: "Import failed", message: error.localizedDescription)
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
                alertInfo = SettingsAlert(
                    title: "Import failed", message: error.localizedDescription)
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
                    "\"\(goalTitle)\" has been paused. Reactivate it from the Goals section to start tracking again."
                )
            }
        }
    }

#endif

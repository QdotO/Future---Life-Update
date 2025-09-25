//
//  ContentView.swift
//  Future - Life Updates
//
//  Created by Quincy Obeng on 9/23/25.
//

import SwiftUI
import SwiftData

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
                    recentGoals: Array(goals.prefix(3))
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
        .onChange(of: goals) { _ in
            todayViewModel?.refresh()
        }
        .onChange(of: scenePhase) { phase in
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

                CardBackground {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Deep dive coming soon")
                            .font(AppTheme.Typography.bodyStrong)
                        Text("Detailed trends and streaks will land here once we finish crunching more data.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .background(AppTheme.Palette.background.ignoresSafeArea())
    }
}

private struct SettingsRootView: View {
    @Binding var sendDailyDigest: Bool
    @Binding var allowNotificationPreviews: Bool

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
    }
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

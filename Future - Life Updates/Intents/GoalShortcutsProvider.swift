import AppIntents

struct GoalShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogGoalIntent(),
            phrases: [
                "Log progress in \(.applicationName)",
                "Update my goal with \(.applicationName)"
            ],
            shortTitle: "Quick Log",
            systemImageName: "chart.bar.doc.horizontal"
        )
    }

    static var appShortcutsTitle: LocalizedStringResource {
        "Goal Logging"
    }
}

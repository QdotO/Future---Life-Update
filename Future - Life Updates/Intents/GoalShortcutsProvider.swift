import AppIntents

struct GoalShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogGoalIntent(),
            phrases: [
                "Log progress in \(.applicationName)",
                "Update my goal with \(.applicationName)"
            ]
        )
    }

    static var appShortcutsTitle: LocalizedStringResource {
        "Goal Logging"
    }
}

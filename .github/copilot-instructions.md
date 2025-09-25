# Future – Life Updates • AI onboarding

## Architecture snapshot

- `Future___Life_UpdatesApp` injects `AppEnvironment.shared.modelContainer` and a shared `NotificationRoutingController` into `ContentView`; any feature entry point should respect that environment wiring.
- The domain lives in `Item.swift` (`TrackingGoal`, `Question`, `Schedule`, `DataPoint`, `ScheduleTime`) with cascade relationships; keep mutations on the main actor and call `goal.bumpUpdatedAt()` whenever user-facing data changes.

## SwiftData & model context

- Always obtain persistence through `@Environment(\.modelContext)` or `AppEnvironment.shared.modelContext`; override contexts in async work/tests via `AppEnvironment.shared.withModelContext(_:perform:)` as the App Intents and tests do.
- Tests and previews spin up an in-memory store by recreating the schema (see `PreviewSampleData.makePreviewContainer()` and `PhaseOneFeatureTests.makeInMemoryContainer()`); mirror that pattern for new fixtures.

## UI & view models

- UI flows are MVVM with `@Observable` view models under `ViewModels/` and SwiftUI screens in `Views/`. Instantiate view models with the live `ModelContext` (example: `GoalCreationView` passes `modelContext` into `GoalCreationViewModel`).
- `DataEntryViewModel.saveEntries()` overwrites same-day numeric responses and uses `numericDelta` for `.scale`/`.slider`; preserve this behavior so `GoalHistoryViewModel` and `GoalTrendsViewModel` continue to compute deltas and streaks correctly.

## Notifications & routing

- `NotificationScheduler` is the single touchpoint for local notifications; schedule or resend reminders after any schedule/category toggle (see `GoalCreationView.handleSave()` and `GoalEditView.handleSave()`).
- `NotificationCenterDelegate` forwards taps into `NotificationRoutingController`, which `ContentView` converts into `NotificationLogEntryView` sheets; new notification entry points must publish a `NotificationRoutingController.Route` with the goal/question IDs.

## Shortcuts / App Intents

- `QuickLogGoalIntent` and `GoalShortcutLogger` rely on SwiftData; wrap intent work in `AppEnvironment.shared.withModelContext` so logging can reuse the caller’s in-memory context during tests.
- `GoalShortcutQuery` filters to active goals and limits fetches; extend queries by adjusting its `FetchDescriptor`s so Spotlight/Shortcuts stay performant.

## Testing & QA

- Unit-style tests live under `Future - Life UpdatesTests/` and use the Swift `Testing` framework; keep tests `@MainActor` when touching SwiftData and reuse the in-memory container helpers.
- Example command line run (Xcode 16+):
  - `xcodebuild -project "Future - Life Updates.xcodeproj" -scheme "Future - Life UpdatesTests" -destination 'platform=iOS Simulator,name=iPhone 15' test`

## Previews & sample data

- Use `PreviewSampleData.makePreviewContainer()` to seed realistic goals/questions; attach via `.modelContainer(container)` in previews to avoid duplicate schema code.
- When adding preview-only tweaks, keep them inside the SwiftUI preview macros so runtime codepaths stay production-ready.

## Conventions & gotchas

- `Schedule.times` is stored as `[ScheduleTime]`; whenever you manipulate reminder times convert to `DateComponents` using the helpers in `DateComponents+Formatting.swift` to keep timezone handling intact.
- `GoalTrendsViewModel` fetches only numeric/boolean data; if you add new response types ensure they either map to numeric averages or are excluded to avoid crashing `Charts`.
- Stick to `@MainActor` for view models and notification delegates—mixing threads with SwiftData will crash.
- Any change to `TrackingGoal.questions` or `goal.isActive` should end with `try modelContext.save()` and a notification reschedule so pending requests stay in sync.

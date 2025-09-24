# iOS 26 Best Practices Review

Last updated: September 23, 2025

## Research Summary

Apple's WWDC25 cycle introduced official "What's new in iOS 26" and refreshed SwiftUI guidance, alongside deeper dives into Apple Intelligence, App Intents, and other system updates. The following primary sources capture the most relevant material for Life Updates:

| Topic | Reference |
| --- | --- |
| Platform overview for iOS 26 | [What's new in iOS 26](https://developer.apple.com/ios/whats-new/) |
| SwiftUI fundamentals & data flow | [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/) |
| SwiftUI 2025 updates & structure guidance | [What's new in SwiftUI](https://developer.apple.com/swiftui/whats-new/) |
| Interface & design heuristics | [SwiftUI Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/swiftui/) |
| Migrating / modernizing SwiftUI | [Migrating to the latest SwiftUI](https://developer.apple.com/documentation/swiftui/migrating_to_the_latest_swiftui) |
| SwiftData architecture & persistence | [SwiftData Essentials](https://developer.apple.com/documentation/swiftdata) |
| Modeling guidance | [Designing a Model with SwiftData](https://developer.apple.com/documentation/swiftdata/designing-a-model) |
| Persistence workflow | [Persisting Data in SwiftData](https://developer.apple.com/documentation/swiftdata/persisting-data-in-swiftdata) |
| Change observation patterns | [Managing Change with SwiftData](https://developer.apple.com/documentation/swiftdata/managing-change-with-swiftdata) |
| Liquid Glass visual refresh & UI adoption | [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) |
| Foundation Models framework overview | [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels) |
| App Intents 2025 updates | [App Intents updates](https://developer.apple.com/documentation/updates/appintents) |
| Live Translation APIs | [Call Translation API](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/) |
| Age-appropriate experience tooling | [Declared Age Range API](https://developer.apple.com/documentation/declaredagerange/) |

## Alignment with the Life Updates Codebase

| Guidance | Observed practice | Notes |
| --- | --- | --- |
| **Use the new Observation framework with SwiftUI** (WWDC24, SwiftUI docs) | `DataEntryViewModel` is marked `@Observable` and accessed via `@State` in `DataEntryView`. | Matches Apple's recommendations for lightweight view models with the Observation system. |
| **Keep model-layer work on the main actor when updating UI state** (SwiftData Essentials) | `DataEntryViewModel` is `@MainActor` and `saveEntries` performs synchronous `modelContext.save()`. | Aligns with the requirement that `ModelContext` mutations run on the main actor. |
| **Leverage `@Environment(\.modelContext)` instead of bespoke containers** (Persisting Data in SwiftData) | `DataEntryView` pulls the environment context and updates the view model in `onAppear`. | Mostly aligned, though the initializer still constructs an ad-hoc in-memory container as fallback; consider depending solely on the environment for clarity. |
| **Normalize data changes instead of appending duplicates** (Managing Change with SwiftData) | `saveEntries` overwrites the "today" data point and removes duplicates before saving. | Good compliance; prevents redundant rows. |
| **Surface deltas and current totals for user clarity** (HIG + SwiftUI guidance) | Data-entry UI now shows "Today's total" and "Change" values beside inputs. | Matches HIG emphasis on immediate feedback and clarity. |
| **Background work for HealthKit or long operations** (WWDC24 best practices) | Water logging uses `Task` to dispatch `HealthKitManager` writes off the main thread. | Appropriate off-main handling so UI stays responsive. |
| **Adopt Liquid Glass by using standard components** (Adopting Liquid Glass overview) | Forms, navigation stacks, and toolbars rely on SwiftUI defaults without custom background effects. | Already aligned, but continue to audit custom views (for example, hero cards) to ensure they keep system-provided materials intact. |
| **Deepen App Intents integration for system surfaces** (WWDC25 App Intents updates) | `GoalAppIntents` defines `GoalEntity` queries and suggested entities via `AppEnvironment`-backed SwiftData fetches. | Baseline support is in place; consider layering new visual intelligence search hooks and richer parameter metadata to surface common logging shortcuts in Spotlight, Control Center, and widgets. |

## Opportunities & Recommendations

1. **Streamline model-context provisioning**  
   - _Reference:_ [Persisting Data in SwiftData](https://developer.apple.com/documentation/swiftdata/persisting-data-in-swiftdata) advises leaning on environment propagation.  
   - _Observation:_ `DataEntryView` still constructs a fallback `ModelContainer` in `init`. In production this shouldn't happen, but the code path adds complexity. Consider injecting a container explicitly for previews/tests (as already done) and relying solely on the environment by default.

2. **Adopt typed formatters for numeric summaries**  
   - _Reference:_ [SwiftUI Documentation — Formatting values](https://developer.apple.com/documentation/swiftui/text/format(_:)) encourages reusable `FormatStyle`s.  
   - _Observation:_ Numeric labels build ad-hoc format strings. Extracting a shared `NumberFormatStyle` (e.g., `MeasurementFormatter` or `FloatingPointFormatStyle`) would centralize localization and precision control.

3. **Document SwiftData model intents**  
   - _Reference:_ [Designing a Model with SwiftData](https://developer.apple.com/documentation/swiftdata/designing-a-model) suggests annotating relationships/constraints.  
   - _Observation:_ Model classes (`TrackingGoal`, `DataPoint`) are well-defined but could benefit from inline comments or a short `docs/` note describing retention policies (e.g., why duplicates are filtered on save). This aids future contributors.

4. **Evaluate preview setup for Observation-based view models**  
   - _Reference:_ [Migrating to the latest SwiftUI](https://developer.apple.com/documentation/swiftui/migrating_to_the_latest_swiftui) recommends ensuring previews mirror runtime configuration.  
   - _Observation:_ The `#Preview` for `DataEntryView` configures a `.modelContainer(...)`, which is good. Validating that the `viewModel` also uses `updateContext` inside previews (e.g., by calling `onAppear` via `.task {}`) would guarantee parity.

5. **Track SwiftData change handling as OS updates ship**  
   - _Reference:_ [Managing Change with SwiftData](https://developer.apple.com/documentation/swiftdata/managing-change-with-swiftdata) highlights observation-driven UI refresh.  
   - _Observation:_ The current view model manually calls `reloadState()`. As future iOS releases enhance automatic change propagation, revisit whether explicit reloads are still needed or if `@ModelContext` observation suffices.

6. **Audit custom surfaces for Liquid Glass compatibility**  
   - _Reference:_ [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) recommends minimizing bespoke backgrounds on controls, navigation, and floating surfaces.  
   - _Observation:_ Most Life Updates screens lean on system materials, but any bespoke glass effects (for example, goal cards or headers) should be reviewed to ensure they respect reduced-transparency settings and don’t mask system-provided materials.

7. **Adopt WWDC25 App Intents enhancements for shortcuts and visual intelligence**  
   - _Reference:_ [App Intents updates](https://developer.apple.com/documentation/updates/appintents) describe new metadata, visual intelligence hooks, and Control Center integrations.  
   - _Observation:_ `GoalAppIntents` already publishes entities and suggestions; review the new Action metadata and visual intelligence APIs so logging shortcuts show up in Spotlight, widgets, and Control Center without additional user setup.

8. **Prototype Apple Intelligence summaries with the Foundation Models framework**  
   - _Reference:_ [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels) unlocks on-device summarization, extraction, and classification.  
   - _Observation:_ Daily goal entries and trend screens are natural candidates for concise summaries (“You’ve met your hydration goal 5 days in a row”). Explore lightweight prompts that respect on-device processing and privacy guarantees.

9. **Plan for new privacy surfaces (Declared Age Range, Live Translation)**  
   - _Reference:_ [Declared Age Range API](https://developer.apple.com/documentation/declaredagerange/) and [Call Translation API](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/) emphasize age-aware UX and translation accessibility in iOS 26.  
   - _Observation:_ While not immediate requirements, add these APIs to the roadmap for future family or collaboration features so the app stays compliant with age gating and multilingual assistive expectations.

## Next Steps

- Track WWDC25 session transcripts and documentation updates (especially SwiftUI, App Intents, and Foundation Models) for any follow-on API changes before iOS 26 GM.  
- Prototype the prioritized opportunities above, starting with model-context simplification, formatter reuse, and the new App Intents metadata.  
- Schedule a follow-up audit once iOS 26 beta releases stabilize to confirm no breaking changes for SwiftData persistence or accessibility affordances.

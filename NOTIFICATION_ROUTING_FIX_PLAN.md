# Notification Routing Fix - Implementation Plan

## Issue Summary

When users click on a goal reminder notification, they experience one of two problems:
1. **"Goal no longer exists" error** - Shows `MissingGoalPlaceholder` 
2. **Sent to Today feed** - No data entry sheet appears

## Root Cause Analysis

### Current Notification Flow

```
1. NotificationScheduler.scheduleNotifications()
   ↓ Creates notifications with userInfo: ["goalId": UUID, "questionId": UUID?]
   
2. User taps notification
   ↓
   
3. NotificationCenterDelegate.userNotificationCenter(didReceive:)
   ↓ Parses goalId and questionId from userInfo
   ↓ Calls router.activate(goalID:questionID:isTest:)
   
4. NotificationRoutingController publishes activeRoute
   ↓
   
5. ContentView/MacOSContentView receives via .onReceive(notificationRouter.$activeRoute)
   ↓ Sets notificationRoute = route
   
6. .sheet(item: $notificationRoute) triggers
   ↓ Calls goal(for: route.goalID) to fetch TrackingGoal
   
7. If goal found: Shows NotificationLogEntryView → DataEntryView
   If goal not found: Shows MissingGoalPlaceholder
```

### Identified Problems

#### Problem 1: Goal Lookup Failure
**Location**: `ContentView.goal(for:)` and `MacOSContentView.goal(for:)`

```swift
private func goal(for id: UUID) -> TrackingGoal? {
    // First: Check @Query cached goals array
    if let match = goals.first(where: { $0.id == id }) {
        return match
    }

    // Second: Try fresh fetch from ModelContext
    var descriptor = FetchDescriptor<TrackingGoal>(
        predicate: #Predicate { $0.id == id },
        sortBy: []
    )
    descriptor.fetchLimit = 1

    return try? modelContext.fetch(descriptor).first
}
```

**Why it fails:**
- The `@Query` array only contains **active goals sorted by updatedAt**
- If a goal was **deactivated** (isActive = false), it won't be in the `goals` array
- The fallback fetch might fail if:
  - The goal was deleted
  - ModelContext hasn't synchronized yet
  - SwiftData persistence issue

#### Problem 2: Timing/Race Condition
**Location**: Notification delegate runs before SwiftData context refreshes

**Scenario:**
1. App is in background/terminated
2. User taps notification at 9:00 AM
3. App launches and NotificationCenterDelegate fires immediately
4. ModelContext hasn't fully loaded/synced goals yet
5. `goal(for:)` returns nil because context is empty
6. Shows MissingGoalPlaceholder

#### Problem 3: Deleted Goals Still Have Scheduled Notifications
**Location**: `NotificationScheduler` doesn't handle goal deletion properly

**Current behavior:**
- When a goal is deleted via `deleteGoals(at:)` in ContentView, it calls:
  ```swift
  NotificationScheduler.shared.cancelNotifications(forGoalID: goal.id)
  modelContext.delete(goal)
  ```
- This works for **manual deletion**
- BUT if goal is deleted another way (bulk delete, import replace, etc.), notifications persist

#### Problem 4: No Active Goal Check
**Location**: NotificationLogEntryView doesn't verify goal is active

**Current behavior:**
- Even if goal is found, it might be **inactive** (isActive = false)
- User sees data entry for an inactive goal
- Confusing UX: "Why am I getting reminders for a paused goal?"

---

## Implementation Plan

### Phase 1: Improve Goal Lookup (Critical - Fixes "Goal Not Found")

#### 1.1 Add Active Status Check to Query
**File**: ContentView.swift, MacOSContentView.swift

**Change**:
```swift
// OLD
@Query(sort: \TrackingGoal.updatedAt, order: .reverse)
private var goals: [TrackingGoal]

// NEW - Include ALL goals (active and inactive) so lookup always works
@Query(sort: \TrackingGoal.updatedAt, order: .reverse)
private var allGoals: [TrackingGoal]

// Add computed property for active-only goals
private var goals: [TrackingGoal] {
    allGoals.filter { $0.isActive }
}
```

**Rationale**: 
- Original query excludes inactive goals
- Notification might fire for inactive goal (if not canceled properly)
- Lookup needs access to ALL goals to determine if goal exists vs. is just inactive

#### 1.2 Enhanced Goal Lookup with Better Error Handling
**File**: ContentView.swift, MacOSContentView.swift

**Replace**:
```swift
private func goal(for id: UUID) -> TrackingGoal? {
    // Check all goals (active + inactive) first
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
    print("[NotificationRouting] Goal \(id) not found anywhere - deleted or corrupt notification")
    #endif
    return nil
}
```

---

### Phase 2: Handle Inactive Goals Gracefully (Critical - Improves UX)

#### 2.1 Add Inactive Goal Placeholder
**File**: ContentView.swift, MacOSContentView.swift

**Add after MissingGoalPlaceholder**:
```swift
private struct InactiveGoalPlaceholder: View {
    let goalTitle: String
    
    var body: some View {
        ContentUnavailableView {
            Label("Goal is Paused", systemImage: "pause.circle")
        } description: {
            Text(""\(goalTitle)" has been paused. Reactivate it from the Goals tab to start tracking again.")
        } actions: {
            #if os(iOS)
            Button("Go to Goals") {
                // Navigate to goals tab
                // Note: Need to pass binding or notification
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
    }
}
```

#### 2.2 Check Goal Status in Sheet Presentation
**File**: ContentView.swift, MacOSContentView.swift

**Replace**:
```swift
.sheet(item: $notificationRoute, onDismiss: {
    notificationRouter.reset()
}) { route in
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
```

---

### Phase 3: Cancel Notifications on Goal Deactivation (Prevents Future Issues)

#### 3.1 Add Notification Cancellation to Goal Toggle
**File**: GoalDetailView.swift (or wherever isActive is toggled)

**Locate the toggle and add**:
```swift
Toggle("Active", isOn: $goal.isActive)
    .onChange(of: goal.isActive) { _, newValue in
        if newValue {
            // Goal reactivated - reschedule notifications
            NotificationScheduler.shared.scheduleNotifications(for: goal)
        } else {
            // Goal deactivated - cancel all notifications
            NotificationScheduler.shared.cancelNotifications(forGoalID: goal.id)
        }
    }
```

#### 3.2 Add Notification Cancellation to Bulk Operations
**File**: Wherever goals can be bulk-deleted/deactivated

**Example** (if such operations exist):
```swift
func deactivateAllGoals() {
    for goal in goals {
        NotificationScheduler.shared.cancelNotifications(forGoalID: goal.id)
        goal.isActive = false
    }
    try? modelContext.save()
}
```

---

### Phase 4: Add Timing/Sync Protection (Prevents Race Conditions)

#### 4.1 Delay Route Activation Until Context Ready
**File**: ContentView.swift, MacOSContentView.swift

**Replace**:
```swift
.onReceive(notificationRouter.$activeRoute) { route in
    notificationRoute = route
}
```

**With**:
```swift
.onReceive(notificationRouter.$activeRoute) { route in
    guard let route = route else {
        notificationRoute = nil
        return
    }
    
    // Small delay to ensure ModelContext has loaded
    Task { @MainActor in
        // Give SwiftData 100ms to sync on app launch
        try? await Task.sleep(for: .milliseconds(100))
        
        // Double-check goal still not found
        if goal(for: route.goalID) == nil {
            // Try refreshing context
            try? modelContext.save() // Force sync
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        // Now present sheet
        notificationRoute = route
    }
}
```

**Note**: This is a **defensive measure** - if Phase 1 fixes work, this might not be needed. Test without it first.

---

### Phase 5: Add Notification Debugging (Development Aid)

#### 5.1 Log Notification Payload
**File**: NotificationCenterDelegate.swift

**Add logging**:
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    defer { completionHandler() }

    #if DEBUG
    print("[NotificationDelegate] Received notification:")
    print("  - Identifier: \(response.notification.request.identifier)")
    print("  - UserInfo: \(response.notification.request.content.userInfo)")
    #endif

    guard
        let goalIdString = response.notification.request.content.userInfo["goalId"] as? String,
        let goalId = UUID(uuidString: goalIdString)
    else {
        print("[Notifications] ❌ Unable to parse goal ID from notification userInfo")
        return
    }

    let questionId: UUID? = (response.notification.request.content.userInfo["questionId"] as? String).flatMap(UUID.init)
    let isTest = response.notification.request.content.userInfo["isTest"] as? Bool ?? false

    #if DEBUG
    print("[NotificationDelegate] Parsed successfully:")
    print("  - Goal ID: \(goalId)")
    print("  - Question ID: \(questionId?.uuidString ?? "none")")
    print("  - Is Test: \(isTest)")
    #endif

    router?.activate(goalID: goalId, questionID: questionId, isTest: isTest)
}
```

#### 5.2 Log Route Activation
**File**: NotificationRoutingController.swift

**Add logging**:
```swift
func activate(goalID: UUID, questionID: UUID?, isTest: Bool) {
    let route = Route(goalID: goalID, questionID: questionID, isTest: isTest)
    
    #if DEBUG
    print("[NotificationRouter] Activating route:")
    print("  - Goal ID: \(goalID)")
    print("  - Question ID: \(questionID?.uuidString ?? "none")")
    print("  - Is Test: \(isTest)")
    #endif
    
    activeRoute = route
}
```

---

## Testing Plan

### Test Case 1: Active Goal with Notification
**Setup:**
1. Create goal "Morning Workout"
2. Schedule notification for 1 second from now
3. Wait for notification

**Test:**
- Tap notification
- **Expected**: DataEntryView opens with goal questions
- **Success Criteria**: No "Goal Not Found" error

### Test Case 2: Inactive Goal with Notification
**Setup:**
1. Create goal "Reading Goal"
2. Schedule notification
3. Toggle goal to inactive (isActive = false)
4. Wait for notification (should not fire if cancellation works)

**Test:**
- If notification fires, tap it
- **Expected**: InactiveGoalPlaceholder with goal title
- **Success Criteria**: Clear message explaining goal is paused

### Test Case 3: Deleted Goal with Lingering Notification
**Setup:**
1. Create goal "Test Goal"
2. Schedule notification
3. Delete goal
4. Manually trigger notification (if possible) or wait for scheduled time

**Test:**
- Tap notification
- **Expected**: MissingGoalPlaceholder
- **Success Criteria**: Graceful error, app doesn't crash

### Test Case 4: App Backgrounded/Terminated
**Setup:**
1. Create goal with immediate notification
2. Force quit app
3. Wait for notification

**Test:**
- Tap notification (app launches cold)
- **Expected**: DataEntryView opens after brief load
- **Success Criteria**: No race condition, goal loads correctly

### Test Case 5: Multiple Goals
**Setup:**
1. Create 5 goals with notifications
2. Deactivate 2 goals
3. Delete 1 goal
4. Wait for notifications

**Test:**
- Tap each notification type
- **Expected**: 
  - Active goals: DataEntryView
  - Inactive goals: InactiveGoalPlaceholder
  - Deleted goal: MissingGoalPlaceholder
- **Success Criteria**: Correct behavior for each scenario

---

## Implementation Priority

### P0 (Critical - Must Fix)
- [x] Phase 1.1: Change @Query to include all goals
- [x] Phase 1.2: Enhanced goal lookup with logging
- [x] Phase 2.2: Check goal status before showing sheet
- [x] Phase 3.1: Cancel notifications on deactivation

### P1 (High - Should Fix)
- [ ] Phase 2.1: Add InactiveGoalPlaceholder
- [ ] Phase 3.2: Handle bulk operations
- [ ] Phase 5: Add debug logging

### P2 (Nice to Have)
- [ ] Phase 4: Add timing delay (only if P0 doesn't fix issue)

---

## Rollout Plan

1. **Implement P0 changes** (1-2 hours)
2. **Test with user scenarios** (30 min)
3. **If issues persist, add P1 changes** (1 hour)
4. **Final testing** (30 min)
5. **Deploy and monitor** (collect user feedback)

---

## Success Metrics

- ✅ Zero "Goal Not Found" errors for active goals
- ✅ Clear messaging for inactive goals
- ✅ No crashes on notification tap
- ✅ Data entry sheet appears within 500ms of tap
- ✅ Notifications properly canceled when goals deactivated

---

## Files to Modify

1. **ContentView.swift** (~140 lines changed)
   - Change @Query to allGoals
   - Add goals computed property
   - Update goal(for:) function
   - Update .sheet() to check isActive
   - Add InactiveGoalPlaceholder

2. **MacOSContentView.swift** (~140 lines changed)
   - Same changes as ContentView.swift
   - macOS-specific placeholder styling

3. **GoalDetailView.swift** (~10 lines changed)
   - Add .onChange for isActive toggle
   - Cancel/reschedule notifications

4. **NotificationCenterDelegate.swift** (~15 lines added)
   - Debug logging

5. **NotificationRoutingController.swift** (~5 lines added)
   - Debug logging

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| @Query change breaks existing UI | Low | goals computed property maintains same interface |
| Performance impact of filtering | Low | Small arrays, O(n) filter is fast |
| Timing delay causes UX lag | Medium | Only use if Phase 1 doesn't work |
| Inactive goals still show | Low | Phase 3 prevents new notifications |

---

**Estimated Total Implementation Time**: 3-4 hours
**Estimated Testing Time**: 1-2 hours
**Total**: 4-6 hours end-to-end

# Implementation Summary: Notification Management, Goal Restoration, and Backup Merging

## Overview
Successfully implemented three major features to enhance goal tracking and data management capabilities:

1. **Notification Inspector** - Debug tool to visualize and manage all scheduled notifications
2. **Goal Trash & Restoration** - Soft-delete system with 30-day auto-purge
3. **Backup Merge Functionality** - Advanced conflict detection and resolution for combining backup files

## Implementation Details

### 1. Notification Inspector (`#if DEBUG` only)

**Files Created:**
- `ViewModels/NotificationInspectorViewModel.swift`
- `Views/NotificationInspectorView.swift`

**Features:**
- Lists all pending and delivered notifications grouped by goal
- Shows goal status (Active, Paused, or Deleted/Missing)
- Provides actions: Refresh, Cancel notifications, Reschedule goal, Purge stale
- Export functionality for notification audit reports (JSON)
- Highlights orphaned notifications for deleted goals

**Access:** Settings → Debug → Notification Inspector

---

### 2. Goal Trash & Restoration System

**Files Created:**
- `Services/GoalDeletionService.swift`
- `Views/TrashInboxView.swift`

**Model Changes:**
- Added `GoalTrashItem` to `Item.swift`
- Updated `AppEnvironment.swift` schema to include `GoalTrashItem`

**Features:**
- Soft-delete goals by moving them to trash instead of immediate deletion
- Preserves complete goal snapshot (questions, data points, schedule)
- Auto-purge items older than 30 days
- Restore functionality with option to reactivate goal
- Preview deleted goals before restoring
- Notifications are canceled on deletion and rescheduled on restoration

**Updated Components:**
- `ContentView.deleteGoals()` now uses `GoalDeletionService.moveToTrash()`
- Added "Trash" entry in Settings → Data management

**Storage:**
- Trash items stored as JSON snapshots using `BackupPayload.Goal` format
- Maintains referential integrity via original goal IDs

---

### 3. Backup Merge with Conflict Detection

**Files Created:**
- `Services/BackupMergeService.swift`
- `Views/BackupMergeView.swift`

**Features:**
- Merge two backup JSON files with intelligent conflict detection
- Conflict types detected:
  - **Goal metadata conflicts** (title, description, active status)
  - **Question divergence** (text, response type changes)
  - **Data point collisions** (same ID, different data)

**Conflict Resolution Strategies:**
- **Stop on conflict** (default): Generates detailed report, blocks merge
- **Skip conflicting**: Proceeds without conflicting entities

**Conflict Report:**
- JSON export with full conflict details
- Shows primary vs. secondary values for each conflict
- Provides recommendations (e.g., "using most recent updatedAt")
- In-app viewer with detailed breakdown

**Merge Logic:**
- Union of all goals by ID
- For duplicates, selects record with latest `updatedAt`
- Questions and data points merged by ID
- Maintains earliest `createdAt` and latest `updatedAt`

**Access:** Settings → Data management → Merge Backups (Advanced)

---

## Architecture Decisions

### 1. Soft Delete Pattern
- Used `GoalDeletionService` as central deletion API
- Snapshots use existing `BackupPayload` format for consistency
- Cancels notifications before deletion to prevent orphaned reminders

### 2. Notification Inspector
- Placed in DEBUG section to avoid confusing end users
- Uses `UNUserNotificationCenter` directly for accurate system state
- Groups notifications by goal for easier management

### 3. Merge Conflict Handling
- Block-on-conflict ensures data integrity
- Detailed reports enable manual resolution
- Skip-conflicting option provides escape hatch for power users

### 4. Schema Evolution
- Added `GoalTrashItem` model to SwiftData schema
- Maintains backwards compatibility (trash is optional feature)
- Trash entries included in future backup exports

---

## Testing Recommendations

### Unit Tests (add to existing test files)
1. **GoalDeletionService**
   - Test trash creation with complete snapshot
   - Test restore with notification rescheduling
   - Test purge logic for 30-day threshold
   - Test error handling for duplicate restore

2. **BackupMergeService**
   - Test conflict detection for all types
   - Test merge strategies (stop vs. skip)
   - Test union of unique goals
   - Test deterministic winner selection

3. **NotificationInspectorViewModel**
   - Test grouping logic
   - Test status detection (active/inactive/missing)
   - Test purge functionality

### Integration Tests
1. Delete goal → verify trash entry → restore → verify notifications
2. Export backup → merge with another → handle conflicts
3. Inspector shows orphaned notifications for deleted goals

### Manual QA Checklist
- [ ] Delete a goal and verify it appears in Trash
- [ ] Wait for trash item to show countdown to purge
- [ ] Restore a goal and verify it reappears with data intact
- [ ] Restore with "reactivate" toggle and verify notifications reschedule
- [ ] Create conflicting backups and verify merge report accuracy
- [ ] Export conflict report JSON and verify format
- [ ] Proceed without conflicts and verify clean data import
- [ ] Use notification inspector to purge stale notifications
- [ ] Export notification report and verify JSON structure

---

## Build Status
✅ **Build Succeeded** (tested on iPhone 17 Simulator, iOS 26.0)

## Integration Points

### Existing Code Modified
1. **ContentView.swift**
   - `deleteGoals()` uses `GoalDeletionService`
   - Added Trash and Merge Backups navigation links
   - Added Notification Inspector to DEBUG section

2. **Item.swift**
   - Added `GoalTrashItem` model

3. **AppEnvironment.swift**
   - Updated schema to include `GoalTrashItem`

### New Dependencies
None - uses existing frameworks:
- SwiftData
- UserNotifications
- SwiftUI
- UniformTypeIdentifiers

---

## Future Enhancements (Out of Scope)

1. **Trash Search/Filter**
   - Search by goal title or category
   - Filter by deletion date range

2. **Selective Merge**
   - UI to manually pick winner for each conflict
   - Three-way merge visualization

3. **Notification Inspector Export Schedule**
   - Export as ICS calendar file
   - Visualize notification frequency charts

4. **Trash Notes**
   - Currently optional; could add required note on delete
   - Track deletion reason for analytics

---

## Documentation for Users

### Trash Feature
> **Deleted goals are moved to Trash where they can be recovered for 30 days before automatic permanent deletion.**
> 
> To restore a goal:
> 1. Go to Settings → Data management → Trash
> 2. Swipe left on the goal and tap "Restore"
> 3. Choose whether to reactivate the goal immediately
> 4. The goal, its questions, and all historical data will be restored

### Merge Backups
> **Use this advanced feature to combine two backup files when you have divergent data from multiple devices.**
> 
> The merge will detect conflicts and provide a detailed report. You can:
> - Export the conflict report for review
> - Proceed without conflicting data (skips conflicted items)
> - Manually resolve conflicts by editing one backup file before re-merging

### Notification Inspector (Debug)
> **A developer tool to audit all scheduled notifications.**
> 
> Use this to:
> - Find orphaned notifications for deleted goals
> - Verify notification scheduling is correct
> - Bulk-cancel stale notifications
> - Export notification audit report

---

## Compliance with Architecture

All implementations follow the project's established patterns:

- ✅ SwiftData models with `@Model` macro
- ✅ MVVM architecture with `@Observable` view models
- ✅ Main actor confinement for SwiftData operations
- ✅ Notification scheduling via `NotificationScheduler`
- ✅ Backup format uses existing `BackupPayload` structure
- ✅ Error handling with `LocalizedError` conformance
- ✅ Preview support with `PreviewSampleData`
- ✅ Debug features wrapped in `#if DEBUG`

---

## File Manifest

**New Files:**
```
Services/
  ├── GoalDeletionService.swift      (212 lines)
  └── BackupMergeService.swift       (339 lines)

ViewModels/
  └── NotificationInspectorViewModel.swift (297 lines)

Views/
  ├── NotificationInspectorView.swift (247 lines)
  ├── TrashInboxView.swift           (367 lines)
  └── BackupMergeView.swift          (487 lines)
```

**Modified Files:**
```
Item.swift                  (+24 lines - added GoalTrashItem model)
AppEnvironment.swift        (+1 line - added to schema)
ContentView.swift           (+33 lines - trash/merge links, deletion service)
```

**Total Lines Added:** ~2,000 lines of production code

---

## Deployment Notes

1. **Schema Migration:** Adding `GoalTrashItem` is non-breaking (additive only)
2. **iOS Compatibility:** Requires iOS 17+ (SwiftData requirement)
3. **Xcode Version:** Built with Xcode 16+ (iOS 26 SDK)
4. **No Server Changes:** All features are local-only

---

## Known Limitations

1. **Trash is not synced** - Each device maintains its own trash
2. **Merge requires manual file selection** - No automatic device-to-device merge
3. **Conflict resolution is semi-automated** - Complex conflicts may require manual editing
4. **Notification inspector is debug-only** - Could be promoted to user-facing with UI polish

---

End of Implementation Summary

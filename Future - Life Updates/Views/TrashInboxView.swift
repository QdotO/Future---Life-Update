import SwiftData
import SwiftUI

struct TrashInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GoalTrashItem.deletedAt, order: .reverse) private var trashItems: [GoalTrashItem]
    @State private var deletionService: GoalDeletionService?
    @State private var selectedItem: GoalTrashItem?
    @State private var showingRestoreSheet = false
    @State private var showingPreview = false
    @State private var reactivateOnRestore = true
    @State private var alertInfo: TrashAlert?
    @State private var isProcessing = false

    var body: some View {
        List {
            if trashItems.isEmpty {
                ContentUnavailableView(
                    "Trash is Empty",
                    systemImage: "trash",
                    description: Text(
                        "Deleted goals appear here for 30 days before being permanently removed.")
                )
            } else {
                Section {
                    Text("Items older than 30 days are automatically purged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(trashItems) { item in
                    TrashItemRow(item: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                permanentlyDelete(item)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }

                            Button {
                                selectedItem = item
                                showingRestoreSheet = true
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                selectedItem = item
                                showingPreview = true
                            } label: {
                                Label("Preview", systemImage: "eye")
                            }
                            .tint(.green)
                        }
                }
            }
        }
        .navigationTitle("Trash")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !trashItems.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        purgeOldItems()
                    } label: {
                        Label("Purge Old", systemImage: "trash.slash")
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .sheet(isPresented: $showingRestoreSheet) {
            if let item = selectedItem {
                RestoreSheet(
                    item: item,
                    reactivateOnRestore: $reactivateOnRestore,
                    onRestore: {
                        restore(item)
                    }
                )
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let item = selectedItem {
                TrashItemPreview(item: item)
            }
        }
        .alert(item: $alertInfo) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            if deletionService == nil {
                deletionService = GoalDeletionService(modelContext: modelContext)
            }
            purgeOldItems()
        }
    }

    private func restore(_ item: GoalTrashItem) {
        guard let service = deletionService else { return }
        isProcessing = true

        do {
            try service.restoreFromTrash(item, reactivate: reactivateOnRestore)
            alertInfo = TrashAlert(
                title: "Goal Restored",
                message: "'\(item.goalTitle)' has been restored successfully."
            )
            showingRestoreSheet = false
        } catch {
            alertInfo = TrashAlert(
                title: "Restore Failed",
                message: error.localizedDescription
            )
        }

        isProcessing = false
    }

    private func permanentlyDelete(_ item: GoalTrashItem) {
        guard let service = deletionService else { return }
        isProcessing = true

        do {
            try service.permanentlyDelete(item)
        } catch {
            alertInfo = TrashAlert(
                title: "Delete Failed",
                message: error.localizedDescription
            )
        }

        isProcessing = false
    }

    private func purgeOldItems() {
        guard let service = deletionService else { return }

        do {
            try service.purgeOldTrashItems(olderThanDays: 30)
        } catch {
            print("Failed to purge old trash items: \(error)")
        }
    }
}

private struct TrashItemRow: View {
    let item: GoalTrashItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.goalTitle)
                .font(.headline)

            HStack {
                Label("Deleted \(item.deletedAt, style: .relative)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if daysUntilPurge > 0 {
                    Text("\(daysUntilPurge)d left")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Expires soon")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let note = item.userNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }

    private var daysUntilPurge: Int {
        let calendar = Calendar.current
        let now = Date()
        let purgeDate = calendar.date(byAdding: .day, value: 30, to: item.deletedAt) ?? now
        let days = calendar.dateComponents([.day], from: now, to: purgeDate).day ?? 0
        return max(0, days)
    }
}

private struct RestoreSheet: View {
    let item: GoalTrashItem
    @Binding var reactivateOnRestore: Bool
    let onRestore: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "This will restore '\(item.goalTitle)' with all its questions and data points."
                    )
                    .font(.subheadline)
                }

                Section {
                    Toggle("Reactivate goal on restore", isOn: $reactivateOnRestore)
                    Text(
                        "If enabled, the goal will be set to active and notifications will be rescheduled."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Deleted", value: item.deletedAt, format: .dateTime)

                    if let note = item.userNote, !note.isEmpty {
                        LabeledContent("Note") {
                            Text(note)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Restore Goal")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") {
                        onRestore()
                    }
                }
            }
        }
    }
}

private struct TrashItemPreview: View {
    let item: GoalTrashItem
    @Environment(\.dismiss) private var dismiss
    @State private var goalSnapshot: BackupPayload.Goal?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let error = errorMessage {
                    ContentUnavailableView(
                        "Preview Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if let snapshot = goalSnapshot {
                    List {
                        Section("Overview") {
                            LabeledContent("Title", value: snapshot.title)
                            LabeledContent("Category", value: snapshot.category.displayName)
                            if !snapshot.goalDescription.isEmpty {
                                LabeledContent("Description") {
                                    Text(snapshot.goalDescription)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            LabeledContent("Status", value: snapshot.isActive ? "Active" : "Paused")
                        }

                        Section("Questions") {
                            if snapshot.questions.isEmpty {
                                Text("No questions")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(snapshot.questions, id: \.id) { question in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(question.text)
                                            .font(.headline)
                                        Text(question.responseType.rawValue.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Section("Data Points") {
                            LabeledContent("Total Entries", value: "\(snapshot.dataPoints.count)")
                            if let earliest = snapshot.dataPoints.first?.timestamp,
                                let latest = snapshot.dataPoints.last?.timestamp
                            {
                                LabeledContent("Date Range") {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(earliest, style: .date)
                                        Text("to")
                                            .font(.caption2)
                                        Text(latest, style: .date)
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView("Loading preview...")
                }
            }
            .navigationTitle("Preview")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                loadSnapshot()
            }
        }
    }

    private func loadSnapshot() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let snapshot = try decoder.decode(BackupPayload.Goal.self, from: item.goalSnapshot)
            goalSnapshot = snapshot
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TrashAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        TrashInboxView()
    }
    .modelContainer(for: [TrackingGoal.self, GoalTrashItem.self], inMemory: true)
}

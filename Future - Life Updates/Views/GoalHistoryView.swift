import SwiftUI
import SwiftData

struct GoalHistoryView: View {
    @Bindable private var goal: TrackingGoal
    @State private var viewModel: GoalHistoryViewModel

    init(goal: TrackingGoal, modelContext: ModelContext) {
        self._goal = Bindable(goal)
        self._viewModel = State(initialValue: GoalHistoryViewModel(goal: goal, modelContext: modelContext))
    }

    var body: some View {
        List {
            if viewModel.entries.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "tray")
            } else {
                ForEach(viewModel.entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.questionTitle)
                            .font(.headline)
                        Text(entry.responseSummary)
                            .font(.body)
                        Text(entry.timestamp, format: .dateTime.day().month().year().hour().minute())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let details = entry.additionalDetails {
                            Text(details)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("History")
        .toolbarTitleDisplayMode(.inline)
        .onChange(of: goal.updatedAt) { _, _ in
            viewModel.refresh()
        }
        .refreshable {
            viewModel.refresh()
        }
    }
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        let context = container.mainContext
        guard let goal = try context.fetch(FetchDescriptor<TrackingGoal>()).first else {
            return Text("No Sample Goal")
        }
        return NavigationStack {
            GoalHistoryView(goal: goal, modelContext: context)
                .modelContainer(container)
        }
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

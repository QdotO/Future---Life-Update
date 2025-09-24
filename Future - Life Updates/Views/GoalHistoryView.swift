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
            if viewModel.sections.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "tray")
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.questionTitle)
                                        .font(.headline)
                                    Spacer()
                                    Text(entry.timeSummary)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.responseSummary)
                                    .font(.body)
                                if let details = entry.additionalDetails {
                                    Text(details)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(section.date, format: .dateTime.month().day().year())
                    }
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

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
    @State private var showingCreateGoal = false

    @Query(sort: \TrackingGoal.updatedAt, order: .reverse)
    private var goals: [TrackingGoal]

    var body: some View {
        NavigationStack {
            Group {
                if goals.isEmpty {
                    emptyState
                } else {
                    goalsList
                }
            }
            .navigationTitle("Life Updates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        Label("Add Goal", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                GoalCreationView(viewModel: GoalCreationViewModel(modelContext: modelContext))
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
}

private struct GoalCardView: View {
    @Bindable var goal: TrackingGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Label(goal.category.displayName, systemImage: "tag")
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

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

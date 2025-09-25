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
    @EnvironmentObject private var notificationRouter: NotificationRoutingController
    @State private var showingCreateGoal = false
    @State private var notificationRoute: NotificationRoutingController.Route?

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
            .onReceive(notificationRouter.$activeRoute) { route in
                notificationRoute = route
            }
            .sheet(item: $notificationRoute, onDismiss: {
                notificationRouter.reset()
            }) { route in
                if let goal = goal(for: route.goalID) {
                    NotificationLogEntryView(
                        goal: goal,
                        questionID: route.questionID,
                        isTest: route.isTest,
                        modelContext: modelContext
                    )
                } else {
                    MissingGoalPlaceholder()
                }
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

    private func goal(for id: UUID) -> TrackingGoal? {
        if let match = goals.first(where: { $0.id == id }) {
            return match
        }

        var descriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == id },
            sortBy: []
        )
        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
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
                Label(goal.categoryDisplayName, systemImage: "tag")
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

private struct MissingGoalPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Goal Not Found",
            systemImage: "exclamationmark.triangle",
            description: Text("We couldn't find the goal for this reminder.")
        )
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

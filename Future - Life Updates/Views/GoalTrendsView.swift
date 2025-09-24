import SwiftUI
import Charts
import SwiftData

struct GoalTrendsView: View {
    @Bindable private var viewModel: GoalTrendsViewModel

    init(viewModel: GoalTrendsViewModel) {
        self._viewModel = Bindable(viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.dailySeries.isEmpty {
                emptyState
            } else {
                trendsChart
                streakSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No trend data yet",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Log numeric responses to unlock your progress insights.")
        )
        .frame(maxWidth: .infinity)
    }

    private var trendsChart: some View {
        Chart(viewModel.dailySeries) { entry in
            AreaMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Average", entry.averageValue)
            )
            .foregroundStyle(.linearGradient(colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)], startPoint: .top, endPoint: .bottom))

            LineMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Average", entry.averageValue)
            )
            .foregroundStyle(Color.accentColor)
            .symbol(Circle())
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Average", entry.averageValue)
            )
            .annotation(position: .top) {
                Text(entry.averageValue, format: .number.precision(.fractionLength(0...1)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(6, viewModel.dailySeries.count))) { value in
                if let dateValue = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dateValue, format: .dateTime.month().day())
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .accessibilityLabel("Trend of daily averages")
    }

    private var streakSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(streakHeadline)
                        .font(.title3.weight(.semibold))
                }
            } icon: {
                Image(systemName: viewModel.currentStreakDays > 0 ? "flame.fill" : "flame")
                    .foregroundStyle(viewModel.currentStreakDays > 0 ? .orange : .secondary)
            }

            if viewModel.currentStreakDays > 0 {
                Text("You've logged progress \(viewModel.currentStreakDays) days in a row. Keep the momentum going!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log today's update to start your next streak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private var streakHeadline: String {
        if viewModel.currentStreakDays == 0 {
            return "No active streak"
        }
        if viewModel.currentStreakDays == 1 {
            return "1 day"
        }
        return "\(viewModel.currentStreakDays) days"
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer(),
       let goals = try? container.mainContext.fetch(FetchDescriptor<TrackingGoal>()),
       let goal = goals.first {
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: container.mainContext)
        GoalTrendsView(viewModel: viewModel)
            .padding()
            .modelContainer(container)
    } else {
        Text("Preview Unavailable")
    }
}

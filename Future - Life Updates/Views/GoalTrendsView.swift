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
            let hasNumeric = !viewModel.dailySeries.isEmpty
            let hasBoolean = !viewModel.booleanStreaks.isEmpty
            let hasSnapshots = !viewModel.responseSnapshots.isEmpty

            if !hasNumeric && !hasBoolean && !hasSnapshots {
                emptyState
            } else {
                if hasNumeric {
                    numericSection
                }
                if hasSnapshots {
                    responsesSection
                }
                if hasBoolean {
                    booleanSection
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No insights yet",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Log a few updates to unlock charts and streaks for this goal.")
        )
        .frame(maxWidth: .infinity)
    }

    private var numericSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily progress")
                .font(.headline)
            numericChart
            streakSummary
        }
    }

    private var numericChart: some View {
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

    private var booleanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yes/No streaks")
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.booleanStreaks) { streak in
                    booleanCard(for: streak)
                }
            }
        }
    }

    private func booleanCard(for streak: GoalTrendsViewModel.BooleanStreak) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(streak.questionTitle)
                    .font(.headline)
                Spacer()
                Image(systemName: streak.currentStreak > 0 ? "flame.fill" : "flame")
                    .foregroundStyle(streak.currentStreak > 0 ? .orange : .secondary)
            }

            Text(booleanStreakHeadline(for: streak))
                .font(.title3.weight(.semibold))

            Text("Longest streak: \(booleanBestDescription(for: streak))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let detail = booleanDetailLine(for: streak) {
                Text(detail)
                    .font(.caption)
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

    private func booleanStreakHeadline(for streak: GoalTrendsViewModel.BooleanStreak) -> String {
        switch streak.currentStreak {
        case 0:
            return "No active yes streak"
        case 1:
            return "1-day yes streak"
        default:
            return "\(streak.currentStreak)-day yes streak"
        }
    }

    private func booleanBestDescription(for streak: GoalTrendsViewModel.BooleanStreak) -> String {
        switch streak.bestStreak {
        case 0:
            return "None yet"
        case 1:
            return "1 day"
        default:
            return "\(streak.bestStreak) days"
        }
    }

    private func booleanDetailLine(for streak: GoalTrendsViewModel.BooleanStreak) -> String? {
        guard let date = streak.lastResponseDate else {
            return "No responses yet"
        }

        let dateText = date.formatted(.dateTime.month().day())
        if let value = streak.lastResponseValue {
            return "Last answered \(value ? "Yes" : "No") on \(dateText)"
        }
        return "Last response recorded on \(dateText)"
    }

    private var responsesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest responses")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.responseSnapshots) { snapshot in
                    ResponseSnapshotTile(snapshot: snapshot)
                }
            }
        }
    }

    private struct ResponseSnapshotTile: View {
        let snapshot: GoalTrendsViewModel.ResponseSnapshot

        private static let relativeFormatter: RelativeDateTimeFormatter = {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter
        }()

        var body: some View {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .symbolRenderingMode(.hierarchical)
                    Text(snapshot.questionTitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Palette.neutralSubdued)
                    Spacer()
                    if let timestamp = snapshot.timestamp {
                        Text(Self.relativeFormatter.localizedString(for: timestamp, relativeTo: Date()))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(snapshot.primaryValue)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.neutralStrong)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(snapshot.detail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    if let target = targetValue {
                        Text(target)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = progressFraction {
                    ProgressView(value: progress)
                        .tint(AppTheme.Palette.primary)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.md)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

        private var iconName: String {
            switch snapshot.status {
            case .numeric:
                return "chart.bar.fill"
            case .boolean(let isComplete):
                return isComplete ? "checkmark.seal.fill" : "exclamationmark.circle"
            case .options:
                return "list.bullet.rectangle"
            case .text:
                return "text.quote"
            case .time:
                return "clock"
            }
        }

        private var iconColor: Color {
            switch snapshot.status {
            case .numeric:
                return AppTheme.Palette.primary
            case .boolean(let isComplete):
                return isComplete ? .green : .orange
            case .options:
                return AppTheme.Palette.secondary
            case .text:
                return AppTheme.Palette.neutralSubdued
            case .time:
                return AppTheme.Palette.primary
            }
        }

        private var backgroundColor: Color {
            switch snapshot.status {
            case .numeric:
                return AppTheme.Palette.primary.opacity(0.08)
            case .boolean(let isComplete):
                return (isComplete ? Color.green : Color.orange).opacity(0.12)
            case .options:
                return AppTheme.Palette.secondary.opacity(0.08)
            case .text:
                return AppTheme.Palette.surface.opacity(0.6)
            case .time:
                return AppTheme.Palette.primary.opacity(0.06)
            }
        }

        private var progressFraction: Double? {
            if case let .numeric(progress, _) = snapshot.status {
                return progress
            }
            return nil
        }

        private var targetValue: String? {
            if case let .numeric(_, target) = snapshot.status {
                return target
            }
            return nil
        }
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

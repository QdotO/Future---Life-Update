import SwiftData
import SwiftUI

struct GoalHistoryView: View {
    @Environment(\.designStyle) private var designStyle

    @Bindable private var goal: TrackingGoal
    @State private var viewModel: GoalHistoryViewModel

    init(goal: TrackingGoal, modelContext: ModelContext) {
        self._goal = Bindable(goal)
        self._viewModel = State(
            initialValue: GoalHistoryViewModel(goal: goal, modelContext: modelContext))
    }

    var body: some View {
        Group {
            if designStyle == .brutalist {
                brutalistHistory
            } else {
                legacyHistory
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

    private var legacyHistory: some View {
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
    }

    private var brutalistHistory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.lg) {
                if viewModel.sections.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "tray")
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.BrutalistSpacing.xl)
                        .background(AppTheme.BrutalistPalette.background)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    AppTheme.BrutalistPalette.border,
                                    lineWidth: AppTheme.BrutalistBorder.standard)
                        )
                } else {
                    ForEach(viewModel.sections) { section in
                        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                            Text(formattedSectionDate(section.date))
                                .font(AppTheme.BrutalistTypography.overline)
                                .foregroundColor(AppTheme.BrutalistPalette.secondary)

                            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                                ForEach(Array(section.entries.enumerated()), id: \.element.id) {
                                    index, entry in
                                    brutalistHistoryRow(entry)

                                    if index < section.entries.count - 1 {
                                        Rectangle()
                                            .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                                            .frame(height: 1)
                                    }
                                }
                            }
                            .brutalistCard()
                        }
                    }
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
    }

    private func brutalistHistoryRow(_ entry: GoalHistoryViewModel.Entry) -> some View {
        HStack(alignment: .top, spacing: AppTheme.BrutalistSpacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                if goal.questions.count > 1 {
                    Text(entry.questionTitle.uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }

                Text(naturalLanguageMoment(for: entry.timestamp))
                    .font(AppTheme.BrutalistTypography.body)

                Text(formattedEntryDate(entry.timestamp))
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)

                if let details = entry.additionalDetails {
                    Text(details)
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        .padding(.top, AppTheme.BrutalistSpacing.micro)
                }
            }

            Spacer(minLength: AppTheme.BrutalistSpacing.sm)

            Text(entry.responseSummary)
                .font(AppTheme.BrutalistTypography.bodyBold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func naturalLanguageMoment(for date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = goal.schedule.timezone

        let hour = calendar.component(.hour, from: date)
        let period: String
        switch hour {
        case 5..<12:
            period = "morning"
        case 12..<17:
            period = "afternoon"
        case 17..<21:
            period = "evening"
        case 21..<24:
            period = "late night"
        default:
            period = "overnight"
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.timeZone = goal.schedule.timezone
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: date)

        return "\(weekday) \(period)"
    }

    private func formattedEntryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = goal.schedule.timezone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = goal.schedule.timezone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
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

import SwiftData
import SwiftUI

struct TodayDashboardView: View {
    @Bindable var viewModel: TodayDashboardViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.designStyle) private var designStyle

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        Group {
            if designStyle == .brutalist {
                brutalistDashboard
            } else {
                legacyDashboard
            }
        }
    }

    private var legacyDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                upcomingRemindersSection
                todayHighlightsSection
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Palette.background.ignoresSafeArea())
        .refreshable {
            viewModel.refresh()
        }
    }

    private var brutalistDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xl) {
                brutalistUpcomingRemindersSection
                brutalistTodayHighlightsSection
            }
            .padding(AppTheme.BrutalistSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.BrutalistPalette.background.ignoresSafeArea())
        .refreshable {
            viewModel.refresh()
        }
    }

    private var upcomingRemindersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            headerLabel("Upcoming reminders")

            if viewModel.upcomingReminders.isEmpty {
                placeholderCard(
                    title: "You're all caught up",
                    subtitle: "No more reminders scheduled for today."
                )
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(viewModel.upcomingReminders) { reminder in
                        CardBackground {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(reminder.goal.title)
                                        .font(AppTheme.Typography.body.weight(.semibold))
                                    Spacer()
                                    Text(formattedTime(for: reminder))
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let category = reminder.goal.categoryDisplayName {
                                    Label(category, systemImage: "tag")
                                        .font(AppTheme.Typography.caption)
                                        .labelStyle(.titleAndIcon)
                                        .foregroundStyle(.secondary)
                                }

                                Text(nextRelativeDescription(for: reminder))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(
                                        reminder.scheduledDate < Date()
                                            ? Color.secondary : AppTheme.Palette.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var todayHighlightsSection: some View {
        let summaries = viewModel.goalQuestionMetrics.filter { !$0.metrics.isEmpty }
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            headerLabel("Today's highlights")

            if summaries.isEmpty {
                placeholderCard(
                    title: "Log something today",
                    subtitle: "Check-ins populate this feed with your progress."
                )
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(summaries) { summary in
                        CardBackground {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(summary.goal.title)
                                        .font(AppTheme.Typography.body.weight(.semibold))
                                    Spacer()
                                    if let category = summary.goal.categoryDisplayName {
                                        Label(category, systemImage: "tag")
                                            .font(AppTheme.Typography.caption)
                                            .labelStyle(.titleAndIcon)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                VStack(spacing: AppTheme.Spacing.md) {
                                    ForEach(summary.metrics) { metric in
                                        MetricTile(metric: metric)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var brutalistUpcomingRemindersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            brutalistSectionLabel("Upcoming reminders")

            if viewModel.upcomingReminders.isEmpty {
                brutalistPlaceholder(
                    title: "You're all caught up",
                    subtitle: "No more reminders scheduled for today."
                )
            } else {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    ForEach(viewModel.upcomingReminders) { reminder in
                        brutalistReminderCard(for: reminder)
                    }
                }
            }
        }
    }

    private var brutalistTodayHighlightsSection: some View {
        let summaries = viewModel.goalQuestionMetrics.filter { !$0.metrics.isEmpty }
        return VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            brutalistSectionLabel("Today's highlights")

            if summaries.isEmpty {
                brutalistPlaceholder(
                    title: "Log something today",
                    subtitle: "Check-ins populate this feed with your progress."
                )
            } else {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    ForEach(summaries) { summary in
                        brutalistHighlightCard(for: summary)
                    }
                }
            }
        }
    }

    private func brutalistReminderCard(for reminder: TodayDashboardViewModel.UpcomingReminder)
        -> some View
    {
        let relativeDescription = nextRelativeDescription(for: reminder)
        let isPast = reminder.scheduledDate < Date()

        return VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(reminder.goal.title)
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                Spacer()
                Text(formattedTime(for: reminder))
                    .font(AppTheme.BrutalistTypography.captionBold)
                    .foregroundColor(AppTheme.BrutalistPalette.accent)
            }

            if let category = reminder.goal.categoryDisplayName {
                brutalistMetaLabel(category, systemImage: "tag")
            }

            Text(relativeDescription.uppercased())
                .font(AppTheme.BrutalistTypography.captionMono)
                .foregroundColor(isPast ? Color.red : AppTheme.BrutalistPalette.secondary)
        }
        .brutalistCard()
    }

    private func brutalistHighlightCard(for summary: TodayDashboardViewModel.GoalQuestionMetrics)
        -> some View
    {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.goal.title)
                    .font(AppTheme.BrutalistTypography.bodyBold)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)
                Spacer()
                if let category = summary.goal.categoryDisplayName {
                    brutalistMetaLabel(category, systemImage: "tag")
                }
            }

            if let lastID = summary.metrics.last?.id {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
                    ForEach(summary.metrics) { metric in
                        BrutalistMetricRow(metric: metric)

                        if metric.id != lastID {
                            Rectangle()
                                .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .brutalistCard()
    }

    private func brutalistSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTheme.BrutalistTypography.overline)
            .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func brutalistPlaceholder(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            Text(title.uppercased())
                .font(AppTheme.BrutalistTypography.captionBold)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
            Text(subtitle)
                .font(AppTheme.BrutalistTypography.body)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        }
        .brutalistCard()
    }

    private func brutalistMetaLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: AppTheme.BrutalistSpacing.micro) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(text.uppercased())
                .font(AppTheme.BrutalistTypography.captionBold)
        }
        .foregroundColor(AppTheme.BrutalistPalette.secondary)
    }

    private func headerLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.Typography.sectionHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholderCard(title: String, subtitle: String) -> some View {
        CardBackground {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)

                    .font(AppTheme.Typography.body.weight(.semibold))
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedTime(for reminder: TodayDashboardViewModel.UpcomingReminder) -> String {
        let tz = TimeZone(identifier: reminder.timezoneIdentifier) ?? .current
        timeFormatter.timeZone = tz
        return timeFormatter.string(from: reminder.scheduledDate)
    }

    private func nextRelativeDescription(for reminder: TodayDashboardViewModel.UpcomingReminder)
        -> String
    {
        relativeFormatter.localizedString(for: reminder.scheduledDate, relativeTo: Date())
    }
}

private struct BrutalistMetricRow: View {
    let metric: TodayDashboardViewModel.QuestionMetric

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.BrutalistSpacing.xs) {
                Text(metric.questionText.uppercased())
                    .font(AppTheme.BrutalistTypography.captionBold)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
                Spacer()
                if let target = metric.targetValue {
                    Text("vs \(target.uppercased())")
                        .font(AppTheme.BrutalistTypography.captionMono)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }
            }

            Text(metric.primaryValue)
                .font(AppTheme.BrutalistTypography.title)
                .foregroundColor(AppTheme.BrutalistPalette.foreground)
                .lineLimit(1)

            if let progress = metric.progressFraction {
                BrutalistProgressBar(progress: progress)
                    .frame(height: 8)
            }

            if metric.detail.nonEmpty != nil {
                Text(metric.detail)
                    .font(AppTheme.BrutalistTypography.caption)
                    .foregroundColor(AppTheme.BrutalistPalette.secondary)
            }
        }
    }
}

private struct BrutalistProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            let width = geometry.size.width * clamped

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.BrutalistPalette.border.opacity(0.3))

                Capsule()
                    .fill(AppTheme.BrutalistPalette.accent)
                    .frame(width: max(0, width))
            }
            .animation(.easeInOut(duration: 0.35), value: clamped)
        }
    }
}

private struct MetricTile: View {
    let metric: TodayDashboardViewModel.QuestionMetric

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .symbolRenderingMode(.hierarchical)
                Text(metric.questionText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Palette.neutralSubdued)
                Spacer()
                if let target = metric.targetValue {
                    Text(target)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(metric.primaryValue)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.Palette.neutralStrong)
                .lineLimit(1)

            Text(metric.detail)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)

            if let progress = metric.progressFraction {
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
        switch metric.status {
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
        switch metric.status {
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
        switch metric.status {
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
}

extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

#Preview {
    do {
        let container = try PreviewSampleData.makePreviewContainer()
        let modelContext = container.mainContext
        let sampleViewModel = TodayDashboardViewModel(modelContext: modelContext)
        sampleViewModel.refresh()
        return TodayDashboardView(viewModel: sampleViewModel)
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

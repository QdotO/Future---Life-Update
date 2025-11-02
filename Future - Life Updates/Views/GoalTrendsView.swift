import Charts
import SwiftData
import SwiftUI

struct GoalTrendsView: View {
    @Environment(\.designStyle) private var designStyle
    @Bindable private var viewModel: GoalTrendsViewModel
    private let displayMode: DisplayMode

    enum DisplayMode {
        case full
        case compact
    }

    init(viewModel: GoalTrendsViewModel, displayMode: DisplayMode = .full) {
        self._viewModel = Bindable(viewModel)
        self.displayMode = displayMode
    }

    var body: some View {
        switch displayMode {
        case .full:
            fullBody
        case .compact:
            compactBody
        }
    }

    private var fullBody: some View {
        VStack(
            alignment: .leading,
            spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.lg : 20
        ) {
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
        .padding(.vertical, designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : 4)
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: displayStyleSpacing) {
            if viewModel.dailySeries.isEmpty {
                emptyState
            } else {
                compactProgress
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Group {
            if designStyle == .brutalist {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    Text("No insights yet".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    Text("Log a few updates to unlock charts and streaks for this goal.")
                        .font(AppTheme.BrutalistTypography.body)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }
                .padding(AppTheme.BrutalistSpacing.md)
                .brutalistCard()
            } else {
                ContentUnavailableView(
                    "No insights yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(
                        "Log a few updates to unlock charts and streaks for this goal.")
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var numericSection: some View {
        VStack(
            alignment: .leading,
            spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : 16
        ) {
            sectionTitle("Daily progress")
            calendarHeatMap(showLegend: true)
            streakSummary
        }
    }

    private var compactProgress: some View {
        VStack(alignment: .leading, spacing: displayStyleSpacing) {
            HStack(alignment: .top, spacing: displayStyleSpacing) {
                calendarHeatMap(showLegend: false)
                    .frame(maxWidth: 220)

                compactStreakSummary
            }

            if let summary = compactProgressSummary {
                Text(summary)
                    .font(compactBodyFont)
                    .foregroundColor(compactSecondaryColor)
            }
        }
    }

    private func calendarHeatMap(showLegend: Bool) -> some View {
        Group {
            if designStyle == .brutalist {
                brutalistHeatMap(showLegend: showLegend)
            } else {
                legacyHeatMap(showLegend: showLegend)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar showing daily averages by intensity")
    }

    private var displayStyleSpacing: CGFloat {
        if designStyle == .brutalist {
            return AppTheme.BrutalistSpacing.sm
        }
        return 12
    }

    private var compactBodyFont: Font {
        designStyle == .brutalist ? AppTheme.BrutalistTypography.caption : .caption
    }

    private var compactSecondaryColor: Color {
        designStyle == .brutalist ? AppTheme.BrutalistPalette.secondary : .secondary
    }

    private var compactStreakSummary: some View {
        VStack(alignment: .leading, spacing: displayStyleSpacing) {
            Text("Streak")
                .font(designStyle == .brutalist ? AppTheme.BrutalistTypography.overline : .caption)
                .foregroundColor(compactSecondaryColor)
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.BrutalistSpacing.micro) {
                Text(streakHeadline.uppercased())
                    .font(
                        designStyle == .brutalist
                            ? AppTheme.BrutalistTypography.bodyMono : .subheadline
                    )
                    .lineLimit(2)
                Image(systemName: viewModel.currentStreakDays > 0 ? "flame.fill" : "flame")
                    .foregroundColor(
                        viewModel.currentStreakDays > 0 ? accentColor : compactSecondaryColor)
            }
            Text(streakDetail)
                .font(compactBodyFont)
                .foregroundColor(compactSecondaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactProgressSummary: String? {
        guard let latest = viewModel.dailySeries.last else { return nil }
        let dateText = heatmapAccessibilityFormatter.string(from: latest.date)
        let formattedAverage = viewModel.formattedNumber(latest.averageValue)
        return "Last logged \(formattedAverage) on \(dateText)."
    }

    private var accentColor: Color {
        designStyle == .brutalist ? AppTheme.BrutalistPalette.accent : AppTheme.Palette.primary
    }

    private func brutalistHeatMap(showLegend: Bool) -> some View {
        heatMapGrid(
            cellSize: displayMode == .compact ? 22 : 28,
            columnSpacing: AppTheme.BrutalistSpacing.xs,
            rowSpacing: AppTheme.BrutalistSpacing.micro,
            cornerRadius: 0,
            labelFont: AppTheme.BrutalistTypography.captionMono,
            labelColor: AppTheme.BrutalistPalette.secondary,
            baseColor: AppTheme.BrutalistPalette.accent,
            emptyFill: AppTheme.BrutalistPalette.background,
            borderColor: AppTheme.BrutalistPalette.border,
            showLegend: showLegend
        )
        .padding(AppTheme.BrutalistSpacing.sm)
        .background(AppTheme.BrutalistPalette.background)
        .border(AppTheme.BrutalistPalette.border, width: AppTheme.BrutalistBorder.standard)
    }

    private func legacyHeatMap(showLegend: Bool) -> some View {
        heatMapGrid(
            cellSize: displayMode == .compact ? 20 : 26,
            columnSpacing: 6,
            rowSpacing: 4,
            cornerRadius: 6,
            labelFont: .caption,
            labelColor: .secondary,
            baseColor: AppTheme.Palette.primary,
            emptyFill: AppTheme.Palette.surface.opacity(0.4),
            borderColor: AppTheme.Palette.neutralSubdued.opacity(0.4),
            showLegend: showLegend
        )
        .padding(displayMode == .compact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func heatMapGrid(
        cellSize: CGFloat,
        columnSpacing: CGFloat,
        rowSpacing: CGFloat,
        cornerRadius: CGFloat,
        labelFont: Font,
        labelColor: Color,
        baseColor: Color,
        emptyFill: Color,
        borderColor: Color,
        showLegend: Bool
    ) -> some View {
        let weeks = heatmapWeeks
        let maxValue = heatmapMaxValue

        return VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    dayLabelColumn(rowSpacing: rowSpacing, font: labelFont, color: labelColor)

                    ForEach(weeks) { week in
                        VStack(spacing: rowSpacing) {
                            ForEach(week.cells.sorted(by: { $0.weekdayIndex < $1.weekdayIndex })) {
                                cell in
                                heatCell(
                                    cell,
                                    cellSize: cellSize,
                                    cornerRadius: cornerRadius,
                                    baseColor: baseColor,
                                    emptyFill: emptyFill,
                                    borderColor: borderColor,
                                    maxValue: maxValue
                                )
                            }

                            Text(week.label)
                                .font(labelFont)
                                .foregroundColor(labelColor)
                                .frame(width: cellSize)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
                .padding(.trailing, columnSpacing)
            }

            if showLegend {
                heatLegend(
                    baseColor: baseColor, emptyFill: emptyFill, font: labelFont, color: labelColor)
            }
        }
    }

    private func dayLabelColumn(rowSpacing: CGFloat, font: Font, color: Color) -> some View {
        VStack(spacing: rowSpacing) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(font)
                    .foregroundColor(color)
                    .frame(width: 32, height: 24, alignment: .leading)
                    .accessibilityHidden(true)
            }

            Text("")
                .frame(width: 32, height: 0)
        }
    }

    private func heatCell(
        _ cell: HeatmapCell,
        cellSize: CGFloat,
        cornerRadius: CGFloat,
        baseColor: Color,
        emptyFill: Color,
        borderColor: Color,
        maxValue: Double
    ) -> some View {
        let fill =
            cell.isFuture
            ? Color.clear
            : color(for: cell.value, baseColor: baseColor, emptyFill: emptyFill, maxValue: maxValue)

        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderColor.opacity(cell.isFuture ? 0.2 : 0.6),
                        lineWidth: designStyle == .brutalist ? AppTheme.BrutalistBorder.thin : 1)
            )
            .frame(width: cellSize, height: cellSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: cell))
    }

    private func heatLegend(baseColor: Color, emptyFill: Color, font: Font, color: Color)
        -> some View
    {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: designStyle == .brutalist ? 0 : 4)
                .fill(emptyFill)
                .frame(width: 28, height: 12)
            Text("Less")
                .font(font)
                .foregroundColor(color)

            LinearGradient(
                colors: [emptyFill, baseColor.opacity(0.25), baseColor.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 72, height: 12)
            .mask(
                RoundedRectangle(cornerRadius: designStyle == .brutalist ? 0 : 4)
            )

            Text("More")
                .font(font)
                .foregroundColor(color)
        }
        .accessibilityHidden(true)
    }

    private var heatmapWeeks: [HeatmapWeek] {
        let series = viewModel.dailySeries
        guard let lastEntry = series.last else { return [] }

        let calendar = heatmapCalendar
        let endDate = calendar.startOfDay(for: lastEntry.date)
        let endWeekStart = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
        let seriesByDay = Dictionary(
            uniqueKeysWithValues: series.map { (calendar.startOfDay(for: $0.date), $0) })

        let estimatedWeeks = Int(ceil(Double(series.count) / 7.0))
        let weeksToDisplay = min(max(estimatedWeeks, 4), 12)
        let startWeek =
            calendar.date(byAdding: .weekOfYear, value: -(weeksToDisplay - 1), to: endWeekStart)
            ?? endWeekStart

        var result: [HeatmapWeek] = []
        result.reserveCapacity(weeksToDisplay)

        var currentWeekStart = startWeek
        for _ in 0..<weeksToDisplay {
            var cells: [HeatmapCell] = []
            cells.reserveCapacity(7)

            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: currentWeekStart)
                else { continue }
                let dayStart = calendar.startOfDay(for: day)
                let normalizedWeekday = normalizedWeekdayIndex(for: dayStart, calendar: calendar)
                let average = seriesByDay[dayStart]?.averageValue
                let sampleCount = seriesByDay[dayStart]?.sampleCount ?? 0

                let cell = HeatmapCell(
                    date: dayStart,
                    weekdayIndex: normalizedWeekday,
                    value: average,
                    sampleCount: sampleCount,
                    isFuture: dayStart > endDate
                )
                cells.append(cell)
            }

            let week = HeatmapWeek(
                startDate: currentWeekStart, label: weekLabel(for: currentWeekStart), cells: cells)
            result.append(week)

            guard
                let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)
            else { break }
            currentWeekStart = nextWeek
        }

        return result
    }

    private var heatmapMaxValue: Double {
        guard let maxValue = viewModel.dailySeries.map(\.averageValue).max(), maxValue > 0 else {
            return 1
        }
        return maxValue
    }

    private var heatmapCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday-first grid keeps the vertical stack consistent.
        return calendar
    }

    private var weekdaySymbols: [String] {
        let calendar = heatmapCalendar
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        let head = symbols[firstIndex...]
        let tail = symbols[..<firstIndex]
        return Array(head + tail)
    }

    private func normalizedWeekdayIndex(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        let firstWeekday = calendar.firstWeekday
        let zeroIndexed = (weekday - firstWeekday + 7) % 7
        return zeroIndexed
    }

    private func weekLabel(for date: Date) -> String {
        heatmapWeekFormatter.string(from: date)
    }

    private func color(for value: Double?, baseColor: Color, emptyFill: Color, maxValue: Double)
        -> Color
    {
        guard let value, maxValue > 0 else { return emptyFill }
        let normalized = max(0, min(1, value / maxValue))
        let minimumOpacity: Double = designStyle == .brutalist ? 0.25 : 0.15
        let extra = (designStyle == .brutalist ? 0.7 : 0.6) * normalized
        return baseColor.opacity(minimumOpacity + extra)
    }

    private func accessibilityLabel(for cell: HeatmapCell) -> String {
        let dateText = heatmapAccessibilityFormatter.string(from: cell.date)

        if cell.isFuture {
            return "Upcoming day on \(dateText)"
        }

        if let value = cell.value {
            let formatted =
                heatmapNumberFormatter.string(from: NSNumber(value: value))
                ?? String(format: "%.1f", value)
            return "\(dateText), average \(formatted)"
        }

        return "\(dateText), no data recorded"
    }

    private static let heatmapWeekFormatterStorage: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var heatmapWeekFormatter: DateFormatter { Self.heatmapWeekFormatterStorage }

    private static let heatmapAccessibilityFormatterStorage: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var heatmapAccessibilityFormatter: DateFormatter {
        Self.heatmapAccessibilityFormatterStorage
    }

    private static let heatmapNumberFormatterStorage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private var heatmapNumberFormatter: NumberFormatter { Self.heatmapNumberFormatterStorage }

    private struct HeatmapWeek: Identifiable, Hashable {
        let startDate: Date
        let label: String
        let cells: [HeatmapCell]

        var id: Date { startDate }
    }

    private struct HeatmapCell: Identifiable, Hashable {
        let date: Date
        let weekdayIndex: Int
        let value: Double?
        let sampleCount: Int
        let isFuture: Bool

        var id: Date { date }
    }

    private var streakSummary: some View {
        Group {
            if designStyle == .brutalist {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    Text("Current streak".uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.BrutalistSpacing.xs) {
                        Text(streakHeadline.uppercased())
                            .font(AppTheme.BrutalistTypography.headlineMono)
                        Image(systemName: viewModel.currentStreakDays > 0 ? "flame.fill" : "flame")
                            .foregroundColor(
                                viewModel.currentStreakDays > 0
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.secondary)
                    }
                    Text(streakDetail)
                        .font(AppTheme.BrutalistTypography.caption)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                }
                .padding(AppTheme.BrutalistSpacing.md)
                .brutalistCard()
            } else {
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

                    Text(streakDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Palette.surface)
                )
            }
        }
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

    private var streakDetail: String {
        if viewModel.currentStreakDays > 0 {
            return
                "You've logged progress \(viewModel.currentStreakDays) days in a row. Keep the momentum going!"
        } else {
            return "Log today's update to start your next streak."
        }
    }

    private var booleanSection: some View {
        VStack(
            alignment: .leading,
            spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : 12
        ) {
            sectionTitle("Yes/No streaks")
            VStack(
                alignment: .leading,
                spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : 12
            ) {
                ForEach(viewModel.booleanStreaks) { streak in
                    booleanCard(for: streak)
                }
            }
        }
    }

    private func booleanCard(for streak: GoalTrendsViewModel.BooleanStreak) -> some View {
        Group {
            if designStyle == .brutalist {
                VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
                    HStack {
                        Text(streak.questionTitle.uppercased())
                            .font(AppTheme.BrutalistTypography.overline)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        Spacer()
                        Image(systemName: streak.currentStreak > 0 ? "flame.fill" : "flame")
                            .foregroundColor(
                                streak.currentStreak > 0
                                    ? AppTheme.BrutalistPalette.accent
                                    : AppTheme.BrutalistPalette.secondary)
                    }

                    Text(booleanStreakHeadline(for: streak).uppercased())
                        .font(AppTheme.BrutalistTypography.headlineMono)

                    Text("Longest streak: \(booleanBestDescription(for: streak))")
                        .font(AppTheme.BrutalistTypography.captionMono)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)

                    if let detail = booleanDetailLine(for: streak) {
                        Text(detail)
                            .font(AppTheme.BrutalistTypography.caption)
                            .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }
                .padding(AppTheme.BrutalistSpacing.md)
                .brutalistCard()
            } else {
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
                        .fill(AppTheme.Palette.surface)
                )
            }
        }
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
        VStack(
            alignment: .leading,
            spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : 12
        ) {
            sectionTitle("Latest responses")

            VStack(
                alignment: .leading,
                spacing: designStyle == .brutalist ? AppTheme.BrutalistSpacing.sm : 12
            ) {
                ForEach(viewModel.responseSnapshots) { snapshot in
                    ResponseSnapshotTile(snapshot: snapshot)
                }
            }
        }
    }

    private struct ResponseSnapshotTile: View {
        let snapshot: GoalTrendsViewModel.ResponseSnapshot
        @Environment(\.designStyle) private var designStyle

        private static let relativeFormatter: RelativeDateTimeFormatter = {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter
        }()

        var body: some View {
            Group {
                if designStyle == .brutalist {
                    brutalistContent
                } else {
                    legacyContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var brutalistContent: some View {
            VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.BrutalistSpacing.sm) {
                    Image(systemName: iconNameBrutalist)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconTintBrutalist)
                    Text(snapshot.questionTitle.uppercased())
                        .font(AppTheme.BrutalistTypography.overline)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    Spacer()
                    if let timestamp = snapshot.timestamp {
                        Text(
                            Self.relativeFormatter.localizedString(
                                for: timestamp, relativeTo: Date())
                        )
                        .font(AppTheme.BrutalistTypography.captionMono)
                        .foregroundColor(AppTheme.BrutalistPalette.secondary)
                    }
                }

                Text(snapshot.primaryValue)
                    .font(AppTheme.BrutalistTypography.titleMono)
                    .foregroundColor(AppTheme.BrutalistPalette.foreground)

                if !snapshot.detail.isEmpty || targetValue != nil {
                    VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.micro) {
                        if !snapshot.detail.isEmpty {
                            Text(snapshot.detail)
                                .font(AppTheme.BrutalistTypography.caption)
                                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        }
                        if let target = targetValue {
                            Text(target.uppercased())
                                .font(AppTheme.BrutalistTypography.captionMono)
                                .foregroundColor(AppTheme.BrutalistPalette.secondary)
                        }
                    }
                }

                if let progress = progressFraction {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.BrutalistPalette.border.opacity(0.25))
                            Rectangle()
                                .fill(AppTheme.BrutalistPalette.accent)
                                .frame(width: max(0, min(1, progress)) * geometry.size.width)
                        }
                        .frame(height: 10)
                    }
                    .frame(height: 10)
                }
            }
            .padding(AppTheme.BrutalistSpacing.md)
            .brutalistCard()
        }

        private var legacyContent: some View {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: iconNameLegacy)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColorLegacy)
                        .symbolRenderingMode(.hierarchical)
                    Text(snapshot.questionTitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Palette.neutralSubdued)
                    Spacer()
                    if let timestamp = snapshot.timestamp {
                        Text(
                            Self.relativeFormatter.localizedString(
                                for: timestamp, relativeTo: Date())
                        )
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
            .padding(AppTheme.Spacing.md)
            .background(backgroundColorLegacy)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

        private var iconNameBrutalist: String {
            switch snapshot.status {
            case .numeric: return "chart.xyaxis.line"
            case .boolean(let isComplete): return isComplete ? "checkmark.square" : "square"
            case .options: return "list.bullet"
            case .text: return "text.alignleft"
            case .time: return "clock"
            }
        }

        private var iconTintBrutalist: Color {
            switch snapshot.status {
            case .numeric: return AppTheme.BrutalistPalette.accent
            case .boolean(let isComplete):
                return isComplete
                    ? AppTheme.BrutalistPalette.accent : AppTheme.BrutalistPalette.secondary
            case .options: return AppTheme.BrutalistPalette.foreground
            case .text: return AppTheme.BrutalistPalette.secondary
            case .time: return AppTheme.BrutalistPalette.foreground
            }
        }

        private var iconNameLegacy: String {
            switch snapshot.status {
            case .numeric: return "chart.bar.fill"
            case .boolean(let isComplete):
                return isComplete ? "checkmark.seal.fill" : "exclamationmark.circle"
            case .options: return "list.bullet.rectangle"
            case .text: return "text.quote"
            case .time: return "clock"
            }
        }

        private var iconColorLegacy: Color {
            switch snapshot.status {
            case .numeric: return AppTheme.Palette.primary
            case .boolean(let isComplete): return isComplete ? .green : .orange
            case .options: return AppTheme.Palette.secondary
            case .text: return AppTheme.Palette.neutralSubdued
            case .time: return AppTheme.Palette.primary
            }
        }

        private var backgroundColorLegacy: Color {
            switch snapshot.status {
            case .numeric: return AppTheme.Palette.primary.opacity(0.08)
            case .boolean(let isComplete):
                return (isComplete ? Color.green : Color.orange).opacity(0.12)
            case .options: return AppTheme.Palette.secondary.opacity(0.08)
            case .text: return AppTheme.Palette.surface.opacity(0.6)
            case .time: return AppTheme.Palette.primary.opacity(0.06)
            }
        }

        private var progressFraction: Double? {
            if case .numeric(let progress, _) = snapshot.status {
                return progress
            }
            return nil
        }

        private var targetValue: String? {
            if case .numeric(_, let target) = snapshot.status {
                return target
            }
            return nil
        }
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        if designStyle == .brutalist {
            Text(text.uppercased())
                .font(AppTheme.BrutalistTypography.overline)
                .foregroundColor(AppTheme.BrutalistPalette.secondary)
        } else {
            Text(text)
                .font(.headline)
        }
    }
}

#Preview {
    if let container = try? PreviewSampleData.makePreviewContainer(),
        let goals = try? container.mainContext.fetch(FetchDescriptor<TrackingGoal>()),
        let goal = goals.first
    {
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: container.mainContext)
        GoalTrendsView(viewModel: viewModel)
            .padding()
            .modelContainer(container)
    } else {
        Text("Preview Unavailable")
    }
}

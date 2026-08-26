import SwiftUI

/// Archive tab — the year-by-year ledger, the library of finished books, the
/// days-lit heatmap (GitHub contribution-graph style, one full calendar
/// year), the stats grid, and the achievement ladder.
struct LibraryView: View {
    @StateObject private var viewModel = StatsViewModel()
    @EnvironmentObject private var purchaseService: PurchaseService
    /// Settings → Guide → History chooses between the two renderings below.
    /// Observed rather than read once, so flipping the setting redraws this
    /// screen — previously nothing here consulted it at all and the picker
    /// changed only its own label.
    @EnvironmentObject private var storageService: StorageService

    @State private var selectedBook: Book?
    @State private var showPaywall = false

    private let gatingService = SessionGatingService.shared
    private var isStatsLocked: Bool { !gatingService.isPremium }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    headerSection
                    yearsSection

                    if !viewModel.books.isEmpty {
                        booksSection
                    }

                    heatmapSection
                    statsGrid
                    achievementsSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxl)
                .trackScrollDirection(in: "libraryScroll")
            }
            .coordinateSpace(name: "libraryScroll")
            // Same soft bottom fade as Settings — a cue that scrolling up
            // reveals more, rather than a hard show/hide toggle keyed off
            // scroll direction (which was the source of real jank: it wrote
            // to @State on every pixel of scroll, forcing a full re-render
            // of the whole screen on every frame).
            .mask(
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black)
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 130)
                }
            )
        }
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book, viewModel: viewModel)
                .onDisappear {
                    // Books may have been renamed/recustomized inside
                    DispatchQueue.main.async { viewModel.refresh() }
                }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseService)
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Archive")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.primaryText)

            Text(headerSubtitle)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Spacing.sm)
    }

    private var headerSubtitle: String {
        viewModel.totalSessions == 0
            ? "Every page starts here."
            : "\(Milestone.formattedThreshold(viewModel.totalSessions)) \(viewModel.totalSessions == 1 ? "page" : "pages"), all time."
    }

    // MARK: - Achievements
    /// The full ladder, listed top to bottom — earned rows in white,
    /// unearned in dim gray. No badges, just a small gold star once earned.
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("ACHIEVEMENTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.Colors.tertiaryText)
                .padding(.horizontal, Theme.Spacing.xxs)

            if isStatsLocked {
                LockedMilestonesHint(onTap: { showPaywall = true })
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(Milestone.all.enumerated()), id: \.element.id) { index, milestone in
                        MilestoneRow(
                            milestone: milestone,
                            pages: viewModel.totalSessions,
                            isFirst: index == 0
                        )
                    }
                }
                .background(Theme.Colors.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Heatmap
    /// A year of days lit, styled to match GitHub's own contribution graph:
    /// green cells on near-black paper; relit days carry an open ring, never filled.
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                // Not "DAYS LIT": the summary beside it already reads
                // "147 days this year", so the row said "days" twice, and
                // the heading repeated the metric's name from the Write
                // screen. "History" is what Settings calls the setting that
                // decides what this section draws — the control and the
                // thing it controls now share a word.
                Text("HISTORY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.tertiaryText)

                Spacer()

                Text(heatmapSummary)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(.horizontal, Theme.Spacing.xxs)

            switch storageService.settings.calendarStyle {
            case .heatmap:
                ContributionHeatmap(
                    countsByDay: viewModel.sessionCountsByDate,
                    relitDates: viewModel.relitDates
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 4) {
                    Spacer()
                    Text("Less")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(HeatmapCell.fill(forLevel: level))
                            .frame(width: 9, height: 9)
                    }
                    Text("More")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Spacer()
                }

            case .monthGrid:
                CalendarView(
                    currentMonth: $viewModel.currentMonth,
                    sessionCountsByDate: viewModel.sessionCountsByDate,
                    relitDates: viewModel.relitDates,
                    onPreviousMonth: { viewModel.previousMonth() },
                    onNextMonth: { viewModel.nextMonth() },
                    compact: true
                )
            }
        }
    }

    private var heatmapSummary: String {
        let days = viewModel.sessionCountsByDate.count
        guard days > 0 else { return "No pages yet" }
        return "\(days) \(days == 1 ? "day" : "days") this year"
    }

    // MARK: - Stats Grid
    /// One consistent grid — every tile the same design and width.
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("INSIGHTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.Colors.tertiaryText)
                .padding(.horizontal, Theme.Spacing.xxs)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                spacing: 10
            ) {
                lockable("Time Reclaimed", formattedDuration(minutes: viewModel.timeReclaimed.allTimeMinutes), "instead of scrolling")
                lockable("Total Pages", "\(viewModel.totalSessions)", "all time")
                StatTile(title: "Days Lit", value: "\(viewModel.daysLit)", caption: longestCaption, locked: false)
                lockable("Longest Run", "\(viewModel.longestDaysLit)", viewModel.longestDaysLit == 1 ? "day" : "days")
                lockable("This Week", formattedDuration(minutes: viewModel.timeReclaimed.weekMinutes), weekDeltaCaption)
                lockable("Avg Session", formattedDuration(minutes: averageSessionMinutes), "per sitting")
                lockable("Pages This Month", "\(pagesThisMonth)", currentMonthName)
                lockable("Best Day", bestDayCount > 0 ? "\(bestDayCount)" : "—", bestDayCount > 0 ? "pages in one day" : "no pages yet")
            }
        }
    }

    private func lockable(_ title: String, _ value: String, _ caption: String) -> some View {
        StatTile(title: title, value: value, caption: caption, locked: isStatsLocked)
            .onTapGesture {
                if isStatsLocked {
                    AudioService.shared.playImpact(.light)
                    showPaywall = true
                }
            }
    }

    private var longestCaption: String {
        viewModel.daysLit == 0 && viewModel.longestDaysLit == 0
            ? "light your candle"
            : "longest \(viewModel.longestDaysLit)"
    }

    private var weekDeltaCaption: String {
        // The tile redacts its value behind The Golden Age; the caption must
        // not then hand the same information over. "-9 min vs last week" is
        // the comparison the locked number exists to give.
        guard !isStatsLocked else { return "vs last week" }
        let summary = viewModel.timeReclaimed
        if summary.lastWeekSeconds == 0 && summary.weekSeconds == 0 { return "no pages yet" }
        let delta = summary.weekDeltaMinutes
        if delta == 0 { return "same as last week" }
        return delta > 0 ? "+\(delta) min vs last week" : "\(delta) min vs last week"
    }

    private var averageSessionMinutes: Int {
        guard !viewModel.sessions.isEmpty else { return 0 }
        let seconds = viewModel.sessions.reduce(0.0) { $0 + $1.activeDuration }
        return Int(seconds / 60.0 / Double(viewModel.sessions.count))
    }

    private var pagesThisMonth: Int {
        let calendar = Calendar.current
        return viewModel.sessions.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    private var bestDayCount: Int {
        viewModel.sessionCountsByDate.values.max() ?? 0
    }

    // MARK: - Year Ledger
    /// Page counts year after year — the long view.
    @ViewBuilder
    private var yearsSection: some View {
        let years = viewModel.pageCountsByYear().reversed() as [(year: Int, pages: Int)]
        if !years.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("YEAR BY YEAR")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .padding(.horizontal, Theme.Spacing.xxs)

                VStack(spacing: 0) {
                    ForEach(Array(years.enumerated()), id: \.element.year) { index, entry in
                        HStack {
                            Text(String(entry.year))
                                .font(.system(size: 15, design: .rounded).monospacedDigit())
                                .foregroundColor(Theme.Colors.secondaryText)
                            Spacer()
                            // Proportion bar — relative to the biggest year
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.Colors.hairline)
                                    RoundedRectangle(cornerRadius: 2)
                                        // Plain, not gold. This is a
                                        // measurement, not a highlight — the
                                        // gold made it look like an award.
                                        .fill(Theme.Colors.adaptive(light: "8C8478", dark: "FFFFFF8C"))
                                        .frame(width: barWidth(maxPages: maxPages(years: years), pages: entry.pages, available: geo.size.width))
                                }
                            }
                            .frame(height: 8)

                            Text("\(entry.pages)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundColor(Theme.Colors.primaryText)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, Theme.Spacing.md)

                        if index < years.count - 1 {
                            Divider()
                                .background(Theme.Colors.subtleFill)
                        }
                    }
                }
                .background(Theme.Colors.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func maxPages(years: [(year: Int, pages: Int)]) -> Int {
        years.map(\.pages).max() ?? 1
    }

    private func barWidth(maxPages: Int, pages: Int, available: CGFloat) -> CGFloat {
        guard maxPages > 0 else { return 0 }
        return available * CGFloat(pages) / CGFloat(maxPages)
    }

    // MARK: - Books
    private var booksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("LIBRARY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.tertiaryText)
                Spacer()
                Text("\(viewModel.books.count)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(.horizontal, Theme.Spacing.xxs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.books) { book in
                        Button {
                            AudioService.shared.playImpact(.light)
                            selectedBook = book
                        } label: {
                            BookCoverView(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xxs)
            }
        }
    }

    private func formattedDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins) min"
    }
}

// MARK: - Milestone Row
/// One line of the ladder: title, state. Earned rows are solid, with a
/// small flickering gold star; the next one carries a thin progress
/// underline; the rest stay dim.
struct MilestoneRow: View {
    let milestone: Milestone
    let pages: Int
    let isFirst: Bool

    private var isEarned: Bool { pages >= milestone.threshold }

    private var progress: Double {
        let previous = Milestone.all.last(where: { $0.threshold <= pages })?.threshold ?? 0
        let span = Double(milestone.threshold - previous)
        guard span > 0, pages < milestone.threshold else { return isEarned ? 1 : 0 }
        return min(1, Double(pages - previous) / span)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider()
                    .background(Theme.Colors.subtleFill)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(milestone.title)
                    .font(.system(size: 17, weight: isEarned ? .bold : .regular, design: .rounded).monospacedDigit())
                    .foregroundColor(isEarned ? Theme.Colors.primaryText : Theme.Colors.tertiaryText)

                Spacer()

                HStack(spacing: 4) {
                    if isEarned {
                        AchievementStarIcon()
                    }
                    Text(isEarned ? "earned" : remainingText)
                        .font(.system(size: 12, design: .rounded).monospacedDigit())
                        .foregroundColor(isEarned ? Theme.Colors.secondaryText : Theme.Colors.tertiaryText)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.clear)
                    Rectangle()
                        .fill(isEarned ? Theme.Colors.secondaryText : Theme.Colors.tertiaryText)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 12)
            .padding(.top, 6)
        }
    }

    private var remainingText: String {
        let remaining = milestone.threshold - pages
        return "\(Milestone.formattedThreshold(remaining)) to go"
    }
}

// MARK: - Achievement Star
/// A super-small gold star beside "earned" — flickers gently, the same
/// jittery-loop language as the candle flame in the tab bar.
struct AchievementStarIcon: View {
    var size: CGFloat = 9
    /// Seconds to wait before starting the shimmer. A row of stars started
    /// together pulses in lockstep, which reads mechanical; staggering them
    /// makes the row glimmer instead.
    var phase: Double = 0

    @State private var opacity: Double = 0.75
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "FFE066"), Color(hex: "D4A017")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).delay(phase).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
                withAnimation(.easeInOut(duration: 1.3).delay(phase).repeatForever(autoreverses: true)) {
                    scale = 1.15
                }
            }
    }
}

// MARK: - Locked Milestones Hint
struct LockedMilestonesHint: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            AudioService.shared.playImpact(.light)
            onTap()
        }) {
            HStack {
                Text("Your place on the ladder, with The Golden Age.")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contribution Heatmap
/// GitHub-style activity grid, matching GitHub's own greens. Fixed window:
/// one calendar year, January on the left through December on the right,
/// Monday-start rows. Rendered as explicit week columns (not a lazy grid)
/// so every day lands in its true cell.
struct ContributionHeatmap: View {
    let countsByDay: [Date: Int]
    var relitDates: Set<Date> = []

    private static let cellSpacing: CGFloat = 2.5
    private static let gutterWidth: CGFloat = 26
    private static let monthLabelHeight: CGFloat = 12
    private static let rowSpacing: CGFloat = 4

    private static let cellSize: CGFloat = 11

    /// Monday-start calendar so row 0 of the grid — and of the weekday
    /// gutter's "Mon" label — always land on the same day, regardless of
    /// the device's region settings (which can default week start to Sunday).
    private static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            weekdayGutter
                .padding(.top, Self.monthLabelHeight + Self.rowSpacing)

            // Month labels scroll together with the grid — both live in the
            // same ScrollView so a label always sits above its real column.
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Self.rowSpacing) {
                        monthLabels
                        HStack(alignment: .top, spacing: Self.cellSpacing) {
                            ForEach(weeks.indices, id: \.self) { columnIndex in
                                VStack(spacing: Self.cellSpacing) {
                                    ForEach(0..<7, id: \.self) { rowIndex in
                                        if let date = weeks[columnIndex][rowIndex] {
                                            HeatmapCell(date: date, count: countFor(date), isRelit: relitDates.contains(date))
                                                .frame(width: Self.cellSize, height: Self.cellSize)
                                        } else {
                                            Color.clear
                                                .frame(width: Self.cellSize, height: Self.cellSize)
                                        }
                                    }
                                }
                                .id(columnIndex)
                            }
                        }
                        .padding(.trailing, Self.cellSpacing)
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .onAppear {
                    // Open on today's week, at the trailing edge — the rest
                    // of the year (Jan on the far left, Dec on the far
                    // right) is there to scroll to, not shown by default.
                    if let target = todayColumnIndex {
                        proxy.scrollTo(target, anchor: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Grid Data
    /// Columns of days, one calendar year: January 1st (far left) through
    /// December 31st (far right), Monday-start weeks. Only days outside the
    /// year itself (the partial weeks at either edge) are nil — future days
    /// within the year are real dates, just with a 0 count.
    private var weeks: [[Date?]] {
        let calendar = Self.calendar
        let today = calendar.startOfDay(for: Date())
        let year = calendar.component(.year, from: today)
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31)),
              let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: yearStart)?.start
        else { return [] }

        // Future days still get a real Date (rendered as an ordinary empty
        // cell, same as any past day with no session) — only days outside
        // the calendar year itself are nil. Without this, a month entirely
        // in the future (e.g. December, viewed in August) would be made up
        // of all-nil days, and the label logic below — which anchors each
        // month's label to its column's first non-nil day — would find
        // nothing to anchor to and silently skip that month's label.
        var columns: [[Date?]] = []
        var cursor = firstWeekStart
        while cursor <= yearEnd {
            var column: [Date?] = []
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: dayOffset, to: cursor),
                   day >= yearStart, day <= yearEnd {
                    column.append(day)
                } else {
                    column.append(nil)
                }
            }
            columns.append(column)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return columns
    }

    private var todayColumnIndex: Int? {
        let today = Self.calendar.startOfDay(for: Date())
        return weeks.firstIndex { $0.contains(today) }
    }

    private func countFor(_ date: Date) -> Int {
        countsByDay[date] ?? 0
    }

    // MARK: Labels
    /// Lives inside the same ScrollView as the grid (see `body`), so its
    /// leading edge is column 0 directly — no gutter offset to account for.
    private var monthLabels: some View {
        let columnWidth = Self.cellSize + Self.cellSpacing

        return ZStack(alignment: .topLeading) {
            ForEach(labelledColumns.indices, id: \.self) { entryIndex in
                let entry = labelledColumns[entryIndex]
                Text(entry.label)
                    .font(.system(size: 8))
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .fixedSize()
                    .offset(x: CGFloat(entry.column) * columnWidth)
            }
        }
        .frame(height: Self.monthLabelHeight, alignment: .topLeading)
    }

    private struct MonthLabelEntry {
        let label: String
        let column: Int
    }

    /// A label per column where the month changes.
    private var labelledColumns: [MonthLabelEntry] {
        let calendar = Self.calendar
        let cols = weeks
        var entries: [MonthLabelEntry] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        for (index, column) in cols.enumerated() {
            guard let day = column.compactMap({ $0 }).first else { continue }
            let prevAnchor = index > 0 ? cols[index - 1].compactMap({ $0 }).first : nil
            let month = calendar.component(.month, from: day)
            let prevMonth = prevAnchor.map { calendar.component(.month, from: $0) }
            if month != prevMonth {
                entries.append(MonthLabelEntry(label: formatter.string(from: day), column: index))
            }
        }
        return entries
    }

    private var weekdayGutter: some View {
        let letters = ["Mon", "", "Wed", "", "Fri", "", ""]
        return VStack(alignment: .leading, spacing: Self.cellSpacing) {
            ForEach(letters.indices, id: \.self) { index in
                Text(letters[index])
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: Self.gutterWidth, height: Self.cellSize, alignment: .leading)
            }
        }
    }
}

// MARK: - Heatmap Cell
struct HeatmapCell: View {
    let date: Date
    let count: Int
    var isRelit: Bool = false

    /// GitHub's own contribution-graph greens, empty to brightest.
    static func fill(forLevel level: Int) -> Color {
        switch level {
        // Gold, not GitHub green. The graph borrows its shape from a
        // contribution grid but it is counting candles, and green belonged
        // to a different product — the ramp now runs through the same gold
        // the rest of the app is built on.
        //
        // Each level is a pair, because a single ramp cannot serve both
        // themes: light runs pale to deep so a full week is the darkest
        // thing on the page, dark runs deep to bright so it is the
        // brightest. Getting that backwards is the bug this replaced, where
        // the emptiest week was the darkest mark in the light theme.
        //
        // Level 0 is deliberately a neutral warm grey rather than the
        // palest gold. Most days are one page, so level 1 is nearly the
        // whole graph — if it sat a few percent off the empty cell the
        // year read as blank. The step from nothing to something has to be
        // the largest one in the ramp.
        case 0: return Theme.Colors.adaptive(light: "E8E3D7", dark: "1A1A1A")
        case 1: return Theme.Colors.adaptive(light: "F0DC96", dark: "4A3A0E")
        case 2: return Theme.Colors.adaptive(light: "DDB94E", dark: "7D6218")
        case 3: return Theme.Colors.adaptive(light: "B98F22", dark: "B08F2E")
        default: return Theme.Colors.adaptive(light: "7E6318", dark: "E6C24A")
        }
    }

    private static func level(for count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...5: return 3
        default: return 4
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Self.fill(forLevel: Self.level(for: count)))
            .overlay {
                if isRelit {
                    Circle()
                        .strokeBorder(.white, lineWidth: 1)
                        .padding(2.5)
                }
            }
            .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(count) \(count == 1 ? "page" : "pages")\(isRelit ? ", relit" : "")")
    }
}

// MARK: - Stat Tile
struct StatTile: View {
    let title: String
    let value: String
    let caption: String
    let locked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Group {
                if locked {
                    Text("•••")
                } else {
                    Text(value)
                }
            }
            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundColor(locked ? Theme.Colors.tertiaryText : Theme.Colors.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.55)

            Text(caption)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .padding(6)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LibraryView()
        .environmentObject(StorageService.shared)
        .environmentObject(PurchaseService.shared)
}

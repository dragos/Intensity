import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        let stats = WeeklyStats(sessions: sessions)
        NavigationStack {
            List {
                if !sessions.isEmpty {
                    Section {
                        VStack(spacing: 14) {
                            StreakCard(stats: stats)
                            HStack(spacing: 12) {
                                StatTile(value: "\(stats.thisWeekCount)", label: "This week", symbol: "calendar")
                                StatTile(value: "\(stats.completedCount)", label: "Completed", symbol: "checkmark.circle")
                                StatTile(value: DurationFormat.total(stats.totalTime), label: "Total time", symbol: "clock")
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    Section("Minutes per week") {
                        WeeklyChart(weeks: stats.recentWeeks)
                            .padding(.vertical, 8)
                    }

                    ForEach(groupedByWeek, id: \.start) { group in
                        Section {
                            ForEach(group.sessions) { session in
                                SessionRow(session: session)
                            }
                            .onDelete { offsets in
                                withAnimation {
                                    offsets.map { group.sessions[$0] }.forEach(modelContext.delete)
                                }
                            }
                        } header: {
                            HStack {
                                Text(weekTitle(group.start))
                                Spacer()
                                Text(group.sessions.count == 1 ? "1 workout" : "\(group.sessions.count) workouts")
                            }
                        }
                    }
                }
            }
            .listSectionSpacing(20)
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "flame",
                        description: Text("Finish a workout and it will show up here, along with your weekly streak."))
                }
            }
            .navigationTitle("History")
        }
    }

    private var groupedByWeek: [(start: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) {
            calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start ?? $0.startedAt
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!) }
    }

    private func weekTitle(_ start: Date) -> String {
        let calendar = Calendar.current
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
        if start == thisWeek { return "This Week" }
        if let thisWeek, start == calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek) { return "Last Week" }
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}

// MARK: - Streak

private struct StreakCard: View {
    let stats: WeeklyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .symbolEffect(.breathe, isActive: stats.isThisWeekActive)
                VStack(alignment: .leading, spacing: -4) {
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(stats.currentStreak)))
                    Text("week streak")
                        .font(.headline)
                        .opacity(0.9)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best")
                        .font(.caption.weight(.semibold))
                        .opacity(0.8)
                    Text("\(stats.bestStreak) wk")
                        .font(.title3.weight(.bold))
                        .fontDesign(.rounded)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.18), in: .rect(cornerRadius: 14))
            }

            Text(message)
                .font(.subheadline.weight(.medium))
                .opacity(0.92)

            WeekDots(weeks: stats.recentWeeks)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(WorkoutTint.orange.gradient, in: .rect(cornerRadius: 28))
        .shadow(color: WorkoutTint.orange.color.opacity(0.3), radius: 14, y: 8)
    }

    private var message: String {
        switch (stats.isThisWeekActive, stats.currentStreak) {
        case (true, _):
            stats.thisWeekCount == 1
                ? "This week is in the bag. Keep it going!"
                : "\(stats.thisWeekCount) workouts this week — you're on fire."
        case (false, 0):
            "Complete a workout this week to start a streak."
        case (false, _):
            "Work out this week to extend your streak."
        }
    }
}

private struct WeekDots: View {
    let weeks: [WeekSummary]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(weeks) { week in
                    let isCurrent = week.id == weeks.last?.id
                    Capsule()
                        .fill(.white.opacity(week.isActive ? 1 : 0.25))
                        .frame(height: 22)
                        .overlay {
                            if isCurrent && !week.isActive {
                                Capsule().strokeBorder(.white, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            }
                        }
                }
            }
            HStack {
                Text("\(weeks.count) weeks ago")
                Spacer()
                Text("This week")
            }
            .font(.caption2.weight(.semibold))
            .opacity(0.8)
        }
        .accessibilityElement()
        .accessibilityLabel("\(weeks.filter(\.isActive).count) of the last \(weeks.count) weeks had a workout")
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(value)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

// MARK: - Chart

private struct WeeklyChart: View {
    let weeks: [WeekSummary]

    var body: some View {
        Chart(weeks) { week in
            BarMark(
                x: .value("Week", week.start, unit: .weekOfYear),
                y: .value("Minutes", week.minutes)
            )
            .foregroundStyle(WorkoutTint.orange.gradient)
            .cornerRadius(6)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 3)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) { Text("\(Int(minutes))m") }
                }
            }
        }
        .frame(height: 170)
    }
}

// MARK: - Rows

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.completed ? "checkmark" : "pause.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(session.tint.gradient, in: .rect(cornerRadius: 12))
                .opacity(session.completed ? 1 : 0.6)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName)
                    .font(.headline)
                Text(session.startedAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DurationFormat.clock(Int(session.duration)))
                    .font(.headline)
                    .monospacedDigit()
                Text(session.completed
                     ? "\(session.totalRounds) rounds"
                     : "\(session.roundsCompleted)/\(session.totalRounds) rounds")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(session.completed ? Color.secondary : Color.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

import Foundation

struct WeekSummary: Identifiable {
    let start: Date
    var workouts = 0
    var minutes = 0.0
    /// A week counts toward the streak when it has at least one completed workout.
    var isActive = false

    var id: Date { start }
}

/// Streaks and per-week totals derived from workout history.
/// Weeks follow the user's calendar (first weekday from their locale).
struct WeeklyStats {
    private(set) var currentStreak = 0
    private(set) var bestStreak = 0
    private(set) var thisWeekCount = 0
    private(set) var isThisWeekActive = false
    private(set) var completedCount = 0
    private(set) var totalTime: TimeInterval = 0
    /// The most recent weeks, oldest first, ending with the current week.
    private(set) var recentWeeks: [WeekSummary] = []

    init(sessions: [WorkoutSession], weekCount: Int = 12, now: Date = .now, calendar: Calendar = .current) {
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        }
        func week(_ offset: Int, from date: Date) -> Date {
            calendar.date(byAdding: .weekOfYear, value: offset, to: date)!
        }

        let completed = sessions.filter(\.completed)
        let activeWeeks = Set(completed.map { weekStart($0.startedAt) })
        let thisWeek = weekStart(now)

        completedCount = completed.count
        totalTime = sessions.reduce(0) { $0 + $1.duration }
        isThisWeekActive = activeWeeks.contains(thisWeek)
        thisWeekCount = completed.filter { weekStart($0.startedAt) == thisWeek }.count

        // The current week doesn't break a streak until it's over.
        var cursor = isThisWeekActive ? thisWeek : week(-1, from: thisWeek)
        while activeWeeks.contains(cursor) {
            currentStreak += 1
            cursor = week(-1, from: cursor)
        }

        var run = 0
        var previous: Date?
        for start in activeWeeks.sorted() {
            run = previous.map { week(1, from: $0) == start } == true ? run + 1 : 1
            bestStreak = max(bestStreak, run)
            previous = start
        }

        var summaries = (0..<weekCount).reversed().map { offset in
            WeekSummary(start: week(-offset, from: thisWeek))
        }
        let indexByStart = Dictionary(uniqueKeysWithValues: summaries.enumerated().map { ($1.start, $0) })
        for session in sessions {
            guard let index = indexByStart[weekStart(session.startedAt)] else { continue }
            summaries[index].minutes += session.duration / 60
            if session.completed {
                summaries[index].workouts += 1
                summaries[index].isActive = true
            }
        }
        recentWeeks = summaries
    }
}

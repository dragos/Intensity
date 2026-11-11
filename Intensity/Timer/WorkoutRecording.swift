import Foundation

/// What actually happened during a workout, in wall-clock time, for saving to Apple Health.
struct WorkoutRecording {
    struct Interval {
        let kind: PhaseKind
        let dates: DateInterval
    }

    /// Work and rest intervals in order; the get-ready phase isn't part of the workout.
    var intervals: [Interval] = []
    var pauses: [DateInterval] = []

    var start: Date? { intervals.first?.dates.start }
    var end: Date? { intervals.last?.dates.end }

    /// Pauses that fall inside the workout (a pause during get-ready doesn't count).
    var pausesDuringWorkout: [DateInterval] {
        guard let start, let end else { return [] }
        return pauses.filter { $0.start >= start && $0.end <= end }
    }

    /// Active (unpaused) time spent in phases of the given kind.
    func activeTime(in kind: PhaseKind) -> TimeInterval {
        intervals.filter { $0.kind == kind }.reduce(0) { total, interval in
            let paused = pauses.reduce(0) { $0 + (interval.dates.intersection(with: $1)?.duration ?? 0) }
            return total + interval.dates.duration - paused
        }
    }

    /// Rough active-energy estimate: MET × body mass (kg) × hours. Work counts as vigorous
    /// interval training (8 MET), rest as light activity (2.5 MET); paused time isn't counted.
    func estimatedCalories(bodyMassKg: Double) -> Double {
        let metHours = (8.0 * activeTime(in: .work) + 2.5 * activeTime(in: .rest)) / 3600
        return metHours * bodyMassKg
    }
}

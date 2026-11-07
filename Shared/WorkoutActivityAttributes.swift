import ActivityKit
import Foundation

/// Live Activity for a running workout, shown on the Lock Screen and in the Dynamic Island.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: PhaseStyle
        var round: Int
        var totalRounds: Int
        /// Start and end of the current phase; the system animates the countdown between them,
        /// so the app only has to update the activity when the phase changes.
        var phaseStart: Date
        var phaseEnd: Date
        /// Time left in the phase while paused; nil while running.
        var pausedRemaining: TimeInterval?
        /// What comes next, e.g. "Rest · 10s"; nil during the last interval.
        var next: String?
    }

    var workoutName: String
}

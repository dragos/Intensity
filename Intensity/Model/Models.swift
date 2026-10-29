import Foundation
import SwiftData

/// A saved interval workout definition.
@Model
final class Workout {
    var name: String = ""
    var rounds: Int = 8
    var workSeconds: Int = 20
    var restSeconds: Int = 10
    var tintName: String = "orange"
    var createdAt: Date = Date.now
    /// Position on the workouts screen; lower comes first.
    var sortIndex: Int = 0

    init(name: String, rounds: Int, workSeconds: Int, restSeconds: Int, tint: WorkoutTint,
         sortIndex: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.rounds = rounds
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.tintName = tint.rawValue
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var tint: WorkoutTint {
        get { WorkoutTint(rawValue: tintName) ?? .orange }
        set { tintName = newValue.rawValue }
    }

    var plan: WorkoutPlan {
        WorkoutPlan(rounds: rounds, workSeconds: workSeconds, restSeconds: restSeconds)
    }
}

/// A record of a workout that was performed. Stores a snapshot of the
/// workout's settings so history survives edits and deletions.
@Model
final class WorkoutSession {
    var startedAt: Date = Date.now
    var workoutName: String = ""
    var tintName: String = "orange"
    var roundsCompleted: Int = 0
    var totalRounds: Int = 0
    var workSeconds: Int = 0
    var restSeconds: Int = 0
    var duration: TimeInterval = 0
    var completed: Bool = false

    init(startedAt: Date, workoutName: String, tint: WorkoutTint, roundsCompleted: Int, totalRounds: Int,
         workSeconds: Int, restSeconds: Int, duration: TimeInterval, completed: Bool) {
        self.startedAt = startedAt
        self.workoutName = workoutName
        self.tintName = tint.rawValue
        self.roundsCompleted = roundsCompleted
        self.totalRounds = totalRounds
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.duration = duration
        self.completed = completed
    }

    var tint: WorkoutTint { WorkoutTint(rawValue: tintName) ?? .orange }
}

extension ModelContext {
    /// Sort index that places a new workout at the end of the list.
    func nextWorkoutSortIndex() -> Int {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.sortIndex, order: .reverse)])
        descriptor.fetchLimit = 1
        let last = (try? fetch(descriptor))?.first?.sortIndex ?? -1
        return last + 1
    }
}

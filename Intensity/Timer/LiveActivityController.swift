import ActivityKit
import Foundation

/// Starts, updates and ends the Live Activity for a running workout.
@MainActor
final class LiveActivityController {
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(workoutName: String, state: WorkoutActivityAttributes.ContentState) {
        // The user can turn Live Activities off for the app in Settings.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(
            attributes: WorkoutActivityAttributes(workoutName: workoutName),
            content: ActivityContent(state: state, staleDate: nil))
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Ends the activity. With a final state (a finished workout) the summary stays on the
    /// Lock Screen for a few minutes; without one (a cancelled workout) it disappears at once.
    func end(finalState: WorkoutActivityAttributes.ContentState?) {
        guard let activity else { return }
        self.activity = nil
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        let policy: ActivityUIDismissalPolicy = finalState == nil ? .immediate : .after(.now + 5 * 60)
        Task { await activity.end(content, dismissalPolicy: policy) }
    }

    /// Removes activities left behind when the app was terminated mid-workout.
    static func endLeftoverActivities() {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

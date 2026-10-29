import SwiftUI
import SwiftData

@main
struct IntensityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, WorkoutSession.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("didSeedWorkouts") private var didSeedWorkouts = false

    var body: some View {
        TabView {
            Tab("Workouts", systemImage: "bolt.heart.fill") {
                WorkoutListView()
            }
            Tab("History", systemImage: "chart.bar.fill") {
                HistoryView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { seedIfNeeded() }
    }

    private func seedIfNeeded() {
        if !didSeedWorkouts {
            didSeedWorkouts = true
            modelContext.insert(Workout(name: "Tabata", rounds: 8, workSeconds: 20, restSeconds: 10, tint: .orange, sortIndex: 0))
            modelContext.insert(Workout(name: "HIIT Sprints", rounds: 10, workSeconds: 40, restSeconds: 20, tint: .crimson, sortIndex: 1))
            modelContext.insert(Workout(name: "Steady Intervals", rounds: 6, workSeconds: 90, restSeconds: 30, tint: .ocean, sortIndex: 2))
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedHistory") {
            SampleData.insertHistory(into: modelContext)
        }
        #endif
    }
}

#if DEBUG
enum SampleData {
    /// Fills history with a few weeks of sessions, for previews and screenshots.
    static func insertHistory(into context: ModelContext) {
        let calendar = Calendar.current
        let samples: [(daysAgo: Int, name: String, tint: WorkoutTint, rounds: Int, work: Int, rest: Int, completed: Bool)] = [
            (0, "Tabata", .orange, 8, 20, 10, true),
            (2, "HIIT Sprints", .crimson, 10, 40, 20, true),
            (6, "Steady Intervals", .ocean, 6, 90, 30, true),
            (9, "Tabata", .orange, 8, 20, 10, false),
            (11, "HIIT Sprints", .crimson, 10, 40, 20, true),
            (15, "Tabata", .orange, 8, 20, 10, true),
            (17, "Steady Intervals", .ocean, 6, 90, 30, true),
            (30, "HIIT Sprints", .crimson, 10, 40, 20, true),
            (38, "Tabata", .orange, 8, 20, 10, true),
            (44, "Tabata", .orange, 8, 20, 10, true),
        ]
        for sample in samples {
            let date = calendar.date(byAdding: .day, value: -sample.daysAgo, to: .now)!
            let plan = WorkoutPlan(rounds: sample.rounds, workSeconds: sample.work, restSeconds: sample.rest)
            let rounds = sample.completed ? sample.rounds : sample.rounds / 2
            context.insert(WorkoutSession(
                startedAt: date, workoutName: sample.name, tint: sample.tint,
                roundsCompleted: rounds, totalRounds: sample.rounds,
                workSeconds: sample.work, restSeconds: sample.rest,
                duration: sample.completed ? TimeInterval(plan.totalSeconds) : TimeInterval(plan.totalSeconds / 2),
                completed: sample.completed))
        }
    }
}
#endif

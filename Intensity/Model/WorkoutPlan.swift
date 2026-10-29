import Foundation

enum PhaseKind: Hashable {
    case prepare, work, rest
}

struct Phase: Hashable {
    let kind: PhaseKind
    /// 1-based round this phase belongs to.
    let round: Int
    let duration: TimeInterval
}

/// The timeline of a workout: a short "get ready" phase, then work/rest
/// alternating for each round. There is no rest after the final round.
struct WorkoutPlan: Hashable {
    static let prepareSeconds = 5

    var rounds: Int
    var workSeconds: Int
    var restSeconds: Int

    /// Total workout time, excluding the get-ready phase.
    var totalSeconds: Int {
        rounds * workSeconds + max(rounds - 1, 0) * restSeconds
    }

    var phases: [Phase] {
        var result = [Phase(kind: .prepare, round: 1, duration: TimeInterval(Self.prepareSeconds))]
        for round in 1...max(rounds, 1) {
            result.append(Phase(kind: .work, round: round, duration: TimeInterval(workSeconds)))
            if restSeconds > 0 && round < rounds {
                result.append(Phase(kind: .rest, round: round, duration: TimeInterval(restSeconds)))
            }
        }
        return result
    }
}

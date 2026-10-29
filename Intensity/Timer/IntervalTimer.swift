import Foundation
import Observation

/// Drives a running workout. Time is derived from wall-clock deadlines rather
/// than counting ticks, so it stays accurate across pauses and app suspension.
@MainActor
@Observable
final class IntervalTimer {
    enum State {
        case idle, running, paused, finished
    }

    let plan: WorkoutPlan
    let phases: [Phase]

    private(set) var state: State = .idle
    private(set) var phaseIndex = 0
    private(set) var remaining: TimeInterval
    /// Increments on every countdown beep so views can flash or tap.
    private(set) var cueCount = 0
    private(set) var startedAt: Date?

    @ObservationIgnored private var phaseEndsAt: Date?
    @ObservationIgnored private var lastCueSecond: Int?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let sounds = SoundPlayer.shared

    init(plan: WorkoutPlan) {
        self.plan = plan
        self.phases = plan.phases
        self.remaining = phases[0].duration
    }

    // MARK: Derived values

    var currentPhase: Phase { phases[phaseIndex] }

    var nextPhase: Phase? {
        phases.indices.contains(phaseIndex + 1) ? phases[phaseIndex + 1] : nil
    }

    /// Whole seconds shown on screen (rounded up, like a real countdown).
    var displaySeconds: Int { max(0, Int(remaining.rounded(.up))) }

    /// Fraction of the current phase still to go, 1 → 0.
    var phaseFraction: Double {
        currentPhase.duration > 0 ? remaining / currentPhase.duration : 0
    }

    /// Workout time done so far, excluding the get-ready phase.
    var elapsedWorkoutTime: TimeInterval {
        if state == .finished { return TimeInterval(plan.totalSeconds) }
        let past = phases[..<phaseIndex].filter { $0.kind != .prepare }.reduce(0) { $0 + $1.duration }
        let current = currentPhase.kind == .prepare ? 0 : currentPhase.duration - remaining
        return past + current
    }

    var roundsCompleted: Int {
        if state == .finished { return plan.rounds }
        return phases[..<phaseIndex].filter { $0.kind == .work }.count
    }

    // MARK: Controls

    func start() {
        guard state == .idle else { return }
        startedAt = .now
        sounds.activate()
        enterPhase(0)
        run()
    }

    func togglePause() {
        state == .running ? pause() : resume()
    }

    func pause() {
        guard state == .running else { return }
        update()
        state = .paused
        tickTask?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        run()
    }

    func skip() {
        guard state == .running || state == .paused else { return }
        guard phaseIndex + 1 < phases.count else { return finish() }
        enterPhase(phaseIndex + 1)
        if state == .running { phaseEndsAt = .now + remaining }
    }

    /// Tears down the ticker and audio. Call when leaving the workout screen.
    func stop() {
        tickTask?.cancel()
        tickTask = nil
        sounds.deactivate()
    }

    // MARK: Ticking

    private func run() {
        state = .running
        phaseEndsAt = .now + remaining
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.update()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func update() {
        guard state == .running, var end = phaseEndsAt else { return }
        let now = Date.now
        // Catch up on any phases that ended while we weren't ticking.
        while end <= now {
            guard phaseIndex + 1 < phases.count else { return finish() }
            enterPhase(phaseIndex + 1)
            end += currentPhase.duration
        }
        phaseEndsAt = end
        remaining = end.timeIntervalSince(now)
        cueIfNeeded()
    }

    private func enterPhase(_ index: Int) {
        phaseIndex = index
        remaining = phases[index].duration
        lastCueSecond = nil
        switch phases[index].kind {
        case .work: sounds.play(.go)
        case .rest: sounds.play(.rest)
        case .prepare: break
        }
    }

    /// Beeps on each of the last 3 seconds before an intensity period starts.
    private func cueIfNeeded() {
        guard nextPhase?.kind == .work else { return }
        let second = displaySeconds
        guard (1...3).contains(second), second != lastCueSecond else { return }
        lastCueSecond = second
        cueCount += 1
        sounds.play(.countdown)
    }

    private func finish() {
        tickTask?.cancel()
        remaining = 0
        state = .finished
        sounds.play(.finish)
    }
}

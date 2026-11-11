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
    let workoutName: String

    private(set) var state: State = .idle
    private(set) var phaseIndex = 0
    private(set) var remaining: TimeInterval
    /// Increments on every countdown beep so views can flash or tap.
    private(set) var cueCount = 0
    private(set) var startedAt: Date?

    @ObservationIgnored private var phaseEndsAt: Date?
    @ObservationIgnored private var phaseStartedAt: Date?
    @ObservationIgnored private var pausedAt: Date?
    @ObservationIgnored private var recording = WorkoutRecording()
    @ObservationIgnored private var lastCueSecond: Int?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let sounds = SoundPlayer.shared
    @ObservationIgnored private let liveActivity = LiveActivityController()

    init(plan: WorkoutPlan, workoutName: String) {
        self.plan = plan
        self.phases = plan.phases
        self.workoutName = workoutName
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

    /// The workout's timeline so far, for Apple Health. For a workout ended early, the
    /// interval in progress counts up to now, or up to when it was paused.
    var recordingSoFar: WorkoutRecording {
        guard state != .finished, let phaseStartedAt else { return recording }
        var copy = recording
        let end = pausedAt ?? .now
        if currentPhase.kind != .prepare, end > phaseStartedAt {
            copy.intervals.append(.init(kind: currentPhase.kind, dates: DateInterval(start: phaseStartedAt, end: end)))
        }
        return copy
    }

    /// Snapshot for the Lock Screen and Dynamic Island.
    private var activityState: WorkoutActivityAttributes.ContentState {
        let end = state == .running ? (phaseEndsAt ?? .now + remaining) : .now + remaining
        return WorkoutActivityAttributes.ContentState(
            phase: state == .finished ? .done : PhaseStyle(currentPhase.kind),
            round: currentPhase.round,
            totalRounds: plan.rounds,
            phaseStart: end - currentPhase.duration,
            phaseEnd: end,
            pausedRemaining: state == .paused ? remaining : nil,
            next: nextPhase.map { "\(PhaseStyle($0.kind).title) · \(DurationFormat.short(Int($0.duration)))" })
    }

    // MARK: Controls

    func start() {
        guard state == .idle else { return }
        startedAt = .now
        sounds.activate()
        enterPhase(0, at: .now)
        run()
        liveActivity.start(workoutName: workoutName, state: activityState)
    }

    func togglePause() {
        state == .running ? pause() : resume()
    }

    func pause() {
        guard state == .running else { return }
        update()
        state = .paused
        pausedAt = .now
        tickTask?.cancel()
        liveActivity.update(activityState)
    }

    func resume() {
        guard state == .paused else { return }
        if let pausedAt { recording.pauses.append(DateInterval(start: pausedAt, end: .now)) }
        pausedAt = nil
        run()
        liveActivity.update(activityState)
    }

    func skip() {
        guard state == .running || state == .paused else { return }
        guard phaseIndex + 1 < phases.count else { return finish(at: pausedAt ?? .now) }
        enterPhase(phaseIndex + 1, at: .now)
        if state == .running { phaseEndsAt = .now + remaining }
        liveActivity.update(activityState)
    }

    /// Tears down the ticker, audio and Live Activity. Call when leaving the workout screen.
    func stop() {
        tickTask?.cancel()
        tickTask = nil
        sounds.deactivate()
        // No-op after finish(), which already ended the activity with its summary.
        liveActivity.end(finalState: nil)
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
        let startIndex = phaseIndex
        // Catch up on any phases that ended while we weren't ticking.
        while end <= now {
            guard phaseIndex + 1 < phases.count else { return finish(at: end) }
            enterPhase(phaseIndex + 1, at: end)
            end += currentPhase.duration
        }
        phaseEndsAt = end
        remaining = end.timeIntervalSince(now)
        if phaseIndex != startIndex { liveActivity.update(activityState) }
        cueIfNeeded()
    }

    /// Moves to a phase. `date` is when it began: the scheduled boundary when catching up,
    /// so the recorded timeline stays exact even if ticks ran late.
    private func enterPhase(_ index: Int, at date: Date) {
        closeCurrentPhase(at: date)
        phaseStartedAt = date
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

    private func closeCurrentPhase(at date: Date) {
        guard let phaseStartedAt, currentPhase.kind != .prepare, date > phaseStartedAt else { return }
        recording.intervals.append(.init(kind: currentPhase.kind, dates: DateInterval(start: phaseStartedAt, end: date)))
    }

    private func finish(at date: Date) {
        closeCurrentPhase(at: date)
        phaseStartedAt = nil
        pausedAt = nil
        tickTask?.cancel()
        remaining = 0
        state = .finished
        sounds.play(.finish)
        liveActivity.end(finalState: activityState)
    }
}

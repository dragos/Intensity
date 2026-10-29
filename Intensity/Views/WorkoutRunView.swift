import SwiftUI
import SwiftData
import UIKit

struct WorkoutRunView: View {
    let workout: Workout

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("soundEnabled") private var soundEnabled = true

    @State private var timer: IntervalTimer
    @State private var didSave = false
    @State private var confirmingExit = false
    @State private var resumeAfterDialog = false

    init(workout: Workout) {
        self.workout = workout
        _timer = State(initialValue: IntervalTimer(plan: workout.plan))
    }

    private var isFinished: Bool { timer.state == .finished }

    private var style: PhaseStyle {
        isFinished ? .done : PhaseStyle(timer.currentPhase.kind)
    }

    var body: some View {
        ZStack {
            PhaseBackground(style: style)
            CueFlash(trigger: timer.cueCount)

            if isFinished {
                WorkoutSummaryView(name: workout.name, plan: workout.plan) { dismiss() }
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                timerContent
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .animation(.smooth(duration: 0.5), value: isFinished)
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(.impact(weight: .heavy), trigger: timer.phaseIndex)
        .sensoryFeedback(.impact(weight: .light), trigger: timer.cueCount)
        .sensoryFeedback(.success, trigger: isFinished)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            SoundPlayer.shared.isMuted = !soundEnabled
            timer.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            timer.stop()
        }
        .onChange(of: soundEnabled) { _, enabled in
            SoundPlayer.shared.isMuted = !enabled
        }
        .onChange(of: timer.state) { _, state in
            if state == .finished { save(completed: true) }
        }
        .confirmationDialog("End workout?", isPresented: $confirmingExit, titleVisibility: .visible) {
            if timer.roundsCompleted > 0 {
                Button("End & Save") {
                    save(completed: false)
                    dismiss()
                }
            }
            Button(timer.roundsCompleted > 0 ? "Discard" : "End Workout", role: .destructive) { dismiss() }
            Button("Keep Going", role: .cancel) {
                if resumeAfterDialog { timer.resume() }
            }
        } message: {
            Text("You've completed \(timer.roundsCompleted) of \(workout.rounds) rounds.")
        }
    }

    // MARK: Timer

    private var timerContent: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)

            Label(timer.state == .paused ? "Paused" : style.title, systemImage: timer.state == .paused ? "pause.fill" : style.symbol)
                .font(.title2.weight(.heavy))
                .textCase(.uppercase)
                .tracking(3)
                .contentTransition(.interpolate)
                .animation(.smooth, value: style)

            countdown
                .padding(.vertical, 28)

            nextUp

            Spacer(minLength: 12)
            overallProgress
            controls
                .padding(.top, 28)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack {
            Button(action: requestExit) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 46, height: 46)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End workout")

            Spacer()
            VStack(spacing: 2) {
                Text(workout.name)
                    .font(.headline)
                Text(roundText)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .opacity(0.85)
            }
            Spacer()

            Button { soundEnabled.toggle() } label: {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.headline)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 46, height: 46)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(soundEnabled ? "Mute sounds" : "Unmute sounds")
        }
    }

    private var roundText: String {
        timer.currentPhase.kind == .prepare
            ? "\(workout.rounds) rounds"
            : "Round \(timer.currentPhase.round) of \(workout.rounds)"
    }

    private var countdown: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: timer.phaseFraction)
                .stroke(.white, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .white.opacity(0.5), radius: 8)

            Text(countdownText)
                .font(.system(size: 150, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.25), value: timer.displaySeconds)
                .padding(40)
                .keyframeAnimator(initialValue: 1.0, trigger: timer.cueCount) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.14, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.4)
                }
        }
        .opacity(timer.state == .paused ? 0.55 : 1)
        .frame(maxWidth: 340)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("\(style.title), \(timer.displaySeconds) seconds left")
    }

    private var countdownText: String {
        let seconds = timer.displaySeconds
        return seconds >= 60 ? DurationFormat.clock(seconds) : "\(seconds)"
    }

    private var nextUp: some View {
        Group {
            if let next = timer.nextPhase {
                let nextStyle = PhaseStyle(next.kind)
                Label("Next: \(nextStyle.title) · \(DurationFormat.short(Int(next.duration)))", systemImage: nextStyle.symbol)
            } else {
                Label("Last interval — finish strong!", systemImage: "flag.checkered")
            }
        }
        .font(.headline)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
    }

    private var overallProgress: some View {
        let total = Double(max(workout.plan.totalSeconds, 1))
        let elapsed = timer.elapsedWorkoutTime
        return VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(.white)
                        .frame(width: geo.size.width * min(elapsed / total, 1))
                }
            }
            .frame(height: 8)
            HStack {
                Text("\(DurationFormat.clock(Int(elapsed))) elapsed")
                Spacer()
                Text("\(DurationFormat.clock(Int((total - elapsed).rounded(.up)))) left")
            }
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .opacity(0.85)
        }
    }

    private var controls: some View {
        HStack(spacing: 36) {
            Color.clear.frame(width: 64, height: 64)

            Button { timer.togglePause() } label: {
                Image(systemName: timer.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 36, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 100, height: 100)
                    .glassEffect(.regular.tint(.white.opacity(0.15)).interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(timer.state == .paused ? "Resume" : "Pause")

            Button { timer.skip() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2.weight(.semibold))
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip interval")
        }
    }

    // MARK: Actions

    private func requestExit() {
        // Nothing worth saving yet: leave straight away.
        if timer.elapsedWorkoutTime < 1 {
            dismiss()
            return
        }
        resumeAfterDialog = timer.state == .running
        timer.pause()
        confirmingExit = true
    }

    private func save(completed: Bool) {
        guard !didSave, completed || timer.roundsCompleted > 0 else { return }
        didSave = true
        modelContext.insert(WorkoutSession(
            startedAt: timer.startedAt ?? .now,
            workoutName: workout.name,
            tint: workout.tint,
            roundsCompleted: timer.roundsCompleted,
            totalRounds: workout.rounds,
            workSeconds: workout.workSeconds,
            restSeconds: workout.restSeconds,
            duration: timer.elapsedWorkoutTime,
            completed: completed))
    }
}

// MARK: - Background

private struct PhaseBackground: View {
    let style: PhaseStyle

    var body: some View {
        ZStack {
            ForEach(PhaseStyle.allCases, id: \.self) { candidate in
                candidate.mesh
                    .opacity(candidate == style ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: style)
        .ignoresSafeArea()
    }
}

/// A brief white flash on each countdown beep.
private struct CueFlash: View {
    let trigger: Int

    var body: some View {
        Color.white
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                LinearKeyframe(0.22, duration: 0.06)
                LinearKeyframe(0.0, duration: 0.45)
            }
    }
}

// MARK: - Summary

private struct WorkoutSummaryView: View {
    let name: String
    let plan: WorkoutPlan
    var onDone: () -> Void

    @Query private var sessions: [WorkoutSession]
    @State private var appeared = false

    var body: some View {
        let stats = WeeklyStats(sessions: sessions)
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 104))
                .symbolEffect(.bounce, value: appeared)
                .shadow(color: .white.opacity(0.4), radius: 20)
            VStack(spacing: 6) {
                Text("Workout Complete")
                    .font(.largeTitle.weight(.heavy))
                    .fontDesign(.rounded)
                Text(name)
                    .font(.title3.weight(.medium))
                    .opacity(0.85)
            }
            HStack(spacing: 12) {
                SummaryStat(value: DurationFormat.clock(plan.totalSeconds), label: "Time")
                SummaryStat(value: "\(plan.rounds)", label: "Rounds")
                SummaryStat(value: "\(stats.currentStreak)", label: "Week streak")
            }
            Spacer()
            Button(action: onDone) {
                Text("Done")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .glassEffect(.regular.tint(.white.opacity(0.2)).interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .onAppear { appeared = true }
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
            Text(label)
                .font(.caption.weight(.medium))
                .opacity(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

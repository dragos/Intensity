import ActivityKit
import SwiftUI
import WidgetKit

typealias WorkoutActivityState = WorkoutActivityAttributes.ContentState

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(name: context.attributes.workoutName, state: context.state)
                .activityBackgroundTint(context.state.phase.color)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(state.title, systemImage: state.symbol)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(state.phase.accent)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: state)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(state.phase.accent)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        PhaseProgress(state: state)
                            .tint(state.phase.accent)
                        HStack {
                            Text(context.attributes.workoutName)
                                .lineLimit(1)
                            Spacer()
                            Text(state.roundText)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: state.symbol)
                    .foregroundStyle(state.phase.accent)
            } compactTrailing: {
                Countdown(state: state)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .foregroundStyle(state.phase.accent)
                    // A timer Text otherwise claims all the width it can get.
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: state.symbol)
                    .foregroundStyle(state.phase.accent)
            }
            .keylineTint(state.phase.accent)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let name: String
    let state: WorkoutActivityState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(state.title, systemImage: state.symbol)
                        .font(.headline.weight(.heavy))
                        .textCase(.uppercase)
                    Text("\(name) · \(state.roundText)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .opacity(0.85)
                }
                Spacer(minLength: 8)
                Countdown(state: state)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .frame(maxWidth: 140, alignment: .trailing)
            }

            if state.phase != .done {
                PhaseProgress(state: state)
                    .tint(.white)
                Text(state.next.map { "Next: \($0)" } ?? "Last interval, finish strong!")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

// MARK: - Shared pieces

/// Time left in the phase. While running, the system animates it from the phase dates,
/// so it keeps ticking without updates from the app.
private struct Countdown: View {
    let state: WorkoutActivityState

    var body: some View {
        Group {
            if state.phase == .done {
                Image(systemName: "checkmark")
            } else if let remaining = state.pausedRemaining {
                Text(DurationFormat.clock(Int(remaining.rounded(.up))))
            } else {
                Text(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

private struct PhaseProgress: View {
    let state: WorkoutActivityState

    var body: some View {
        if state.phase == .done {
            EmptyView()
        } else if let remaining = state.pausedRemaining {
            let total = state.phaseEnd.timeIntervalSince(state.phaseStart)
            ProgressView(value: total > 0 ? remaining / total : 0)
        } else {
            ProgressView(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        }
    }
}

private extension WorkoutActivityState {
    var isPaused: Bool { pausedRemaining != nil && phase != .done }

    var title: String { isPaused ? "Paused" : phase.title }

    var symbol: String { isPaused ? "pause.fill" : phase.symbol }

    var roundText: String {
        phase == .prepare || phase == .done ? "\(totalRounds) rounds" : "Round \(round) of \(totalRounds)"
    }
}

import SwiftUI
import SwiftData

struct WorkoutEditorView: View {
    let workout: Workout?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var rounds: Int
    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var tint: WorkoutTint

    init(workout: Workout?) {
        self.workout = workout
        _name = State(initialValue: workout?.name ?? "")
        _rounds = State(initialValue: workout?.rounds ?? 8)
        _workSeconds = State(initialValue: workout?.workSeconds ?? 30)
        _restSeconds = State(initialValue: workout?.restSeconds ?? 15)
        _tint = State(initialValue: workout?.tint ?? .orange)
    }

    private var plan: WorkoutPlan {
        WorkoutPlan(rounds: rounds, workSeconds: workSeconds, restSeconds: restSeconds)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("e.g. Morning Tabata", text: $name)
                        .font(.headline)
                        .submitLabel(.done)
                }

                Section("Intervals") {
                    ValueStepperRow(title: "Rounds", symbol: "repeat", color: .indigo,
                                    value: $rounds, range: 1...99, step: { _ in 1 }, format: { "\($0)" })
                    ValueStepperRow(title: "Work", symbol: "flame.fill", color: .orange,
                                    value: $workSeconds, range: 5...3600, step: Self.durationStep,
                                    format: DurationFormat.clock)
                    ValueStepperRow(title: "Rest", symbol: "wind", color: .teal,
                                    value: $restSeconds, range: 0...3600, step: Self.durationStep,
                                    format: { $0 == 0 ? "None" : DurationFormat.clock($0) })
                }

                Section("Color") {
                    HStack {
                        ForEach(WorkoutTint.allCases) { option in
                            Circle()
                                .fill(option.gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if option == tint {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(4)
                                .overlay(Circle().strokeBorder(option.color, lineWidth: option == tint ? 2.5 : 0))
                                .frame(maxWidth: .infinity)
                                .contentShape(.circle)
                                .onTapGesture { withAnimation(.snappy) { tint = option } }
                                .accessibilityLabel(option.rawValue.capitalized)
                                .accessibilityAddTraits(option == tint ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(workout == nil ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(DurationFormat.clock(plan.totalSeconds))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(plan.totalSeconds)))
                Text("total")
                    .font(.headline)
                    .opacity(0.8)
                Spacer()
            }
            IntervalStrip(plan: plan)
                .frame(height: 10)
            Text("\(rounds) rounds · \(DurationFormat.short(workSeconds)) work · \(restSeconds == 0 ? "no rest" : DurationFormat.short(restSeconds) + " rest")")
                .font(.subheadline.weight(.medium))
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(tint.gradient, in: .rect(cornerRadius: 24))
        .animation(.snappy, value: plan)
    }

    /// Finer steps for short durations, coarser for long ones.
    private static func durationStep(_ value: Int) -> Int {
        switch value {
        case ..<60: 5
        case ..<300: 15
        default: 30
        }
    }

    private func save() {
        if let workout {
            workout.name = trimmedName
            workout.rounds = rounds
            workout.workSeconds = workSeconds
            workout.restSeconds = restSeconds
            workout.tint = tint
        } else {
            modelContext.insert(Workout(name: trimmedName, rounds: rounds, workSeconds: workSeconds,
                                        restSeconds: restSeconds, tint: tint,
                                        sortIndex: modelContext.nextWorkoutSortIndex()))
        }
        dismiss()
    }
}

private struct ValueStepperRow: View {
    let title: String
    let symbol: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Step size to use when moving up from the given value.
    let step: (Int) -> Int
    let format: (Int) -> String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color.gradient, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(format(value))
                    .font(.title2.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
            }
            Spacer()
            Stepper(title, onIncrement: increment, onDecrement: decrement)
                .labelsHidden()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increment()
            case .decrement: decrement()
            @unknown default: break
            }
        }
    }

    private func increment() {
        withAnimation(.snappy) { value = min(range.upperBound, value + step(value)) }
    }

    private func decrement() {
        withAnimation(.snappy) { value = max(range.lowerBound, value - step(value - 1)) }
    }
}

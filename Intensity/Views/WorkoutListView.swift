import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Workout.sortIndex), SortDescriptor(\Workout.createdAt)])
    private var workouts: [Workout]

    @State private var isCreating = false
    @State private var editing: Workout?
    @State private var running: Workout?

    var body: some View {
        NavigationStack {
            // A List (rather than a ScrollView) gives native long-press-and-drag reordering.
            List {
                ForEach(workouts) { workout in
                    // The whole card is the start button. Keep the plain style on this Button rather
                    // than the List, and don't give the card an interaction contentShape: with
                    // those, the row's swipe actions stopped opening.
                    Button { running = workout } label: { WorkoutCard(workout: workout) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Starts the workout")
                        .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        // No full swipe: deleting a workout should take a deliberate tap.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(workout) }
                            Button("Edit", systemImage: "pencil") { editing = workout }
                                .tint(.indigo)
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(workout) }
                                .tint(.gray)
                        }
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts", systemImage: "bolt.heart")
                    } description: {
                        Text("Create an interval workout to get started.")
                    } actions: {
                        Button("New Workout") { isCreating = true }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Workout", systemImage: "plus") { isCreating = true }
                }
            }
            .sheet(isPresented: $isCreating) { WorkoutEditorView(workout: nil) }
            .sheet(item: $editing) { WorkoutEditorView(workout: $0) }
            .fullScreenCover(item: $running) { WorkoutRunView(workout: $0) }
        }
    }

    private func duplicate(_ workout: Workout) {
        withAnimation {
            modelContext.insert(Workout(name: "\(workout.name) Copy", rounds: workout.rounds,
                                        workSeconds: workout.workSeconds, restSeconds: workout.restSeconds,
                                        tint: workout.tint, sortIndex: modelContext.nextWorkoutSortIndex()))
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = workouts
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, workout) in reordered.enumerated() where workout.sortIndex != index {
            workout.sortIndex = index
        }
        // Persist right away instead of waiting for autosave.
        try? modelContext.save()
    }

    private func delete(_ workout: Workout) {
        withAnimation { modelContext.delete(workout) }
    }
}

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Text("\(DurationFormat.clock(workout.plan.totalSeconds)) total")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                // Visual cue only; the whole card is the start button.
                Image(systemName: "play.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(workout.tint.color)
                    .frame(width: 54, height: 54)
                    .background(.white, in: .circle)
                    .accessibilityHidden(true)
            }

            IntervalStrip(plan: workout.plan)
                .frame(height: 10)

            // Full card width for the chips; they only wrap at the largest text sizes.
            FlowLayout(spacing: 8) {
                StatChip(symbol: "repeat", text: "\(workout.rounds)×")
                StatChip(symbol: "flame.fill", text: DurationFormat.short(workout.workSeconds))
                StatChip(symbol: "wind", text: workout.restSeconds > 0 ? DurationFormat.short(workout.restSeconds) : "None")
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(workout.tint.gradient, in: .rect(cornerRadius: 28))
        .shadow(color: workout.tint.color.opacity(0.35), radius: 14, y: 8)
        .contentShape(.dragPreview, .rect(cornerRadius: 28))
        // No context menu: long-press is reserved for dragging to reorder.
        // Edit, duplicate and delete are swipe actions on the list row.
    }
}

private struct StatChip: View {
    let symbol: String
    let text: String

    var body: some View {
        // HStack rather than Label: inside a List, Label picks up wide row-icon spacing.
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.2), in: .capsule)
    }
}

/// Places subviews left to right, starting a new row when the next one doesn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(subviews, maxWidth: bounds.width).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            size.width = min(size.width, maxWidth)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return (frames, CGSize(width: width, height: y + rowHeight))
    }
}

/// A proportional preview of the workout timeline: solid bars for work, faint bars for rest.
struct IntervalStrip: View {
    let plan: WorkoutPlan
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            let segments = plan.phases.filter { $0.kind != .prepare }
            let spacing: CGFloat = segments.count > 40 ? 1 : 3
            let total = max(segments.reduce(0) { $0 + $1.duration }, 1)
            let available = max(geo.size.width - spacing * CGFloat(segments.count - 1), 0)
            HStack(spacing: spacing) {
                ForEach(segments.indices, id: \.self) { index in
                    Capsule()
                        .fill(color.opacity(segments[index].kind == .work ? 0.95 : 0.35))
                        .frame(width: max(1, available * segments[index].duration / total))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

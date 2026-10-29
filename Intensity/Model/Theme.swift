import SwiftUI

/// Color theme a workout card can use.
enum WorkoutTint: String, CaseIterable, Identifiable {
    case orange, crimson, magenta, violet, ocean, mint

    var id: Self { self }

    var colors: [Color] {
        switch self {
        case .orange:  [Color(red: 1.00, green: 0.64, blue: 0.22), Color(red: 0.98, green: 0.33, blue: 0.18)]
        case .crimson: [Color(red: 1.00, green: 0.40, blue: 0.42), Color(red: 0.84, green: 0.11, blue: 0.32)]
        case .magenta: [Color(red: 0.98, green: 0.40, blue: 0.72), Color(red: 0.68, green: 0.20, blue: 0.78)]
        case .violet:  [Color(red: 0.58, green: 0.48, blue: 1.00), Color(red: 0.34, green: 0.22, blue: 0.86)]
        case .ocean:   [Color(red: 0.28, green: 0.72, blue: 1.00), Color(red: 0.12, green: 0.38, blue: 0.92)]
        case .mint:    [Color(red: 0.26, green: 0.86, blue: 0.68), Color(red: 0.04, green: 0.58, blue: 0.56)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var color: Color { colors[1] }
}

/// Visual identity of each period while a workout is running.
enum PhaseStyle: CaseIterable {
    case prepare, work, rest, done

    init(_ kind: PhaseKind) {
        switch kind {
        case .prepare: self = .prepare
        case .work: self = .work
        case .rest: self = .rest
        }
    }

    var title: String {
        switch self {
        case .prepare: "Get Ready"
        case .work: "Work"
        case .rest: "Rest"
        case .done: "Done"
        }
    }

    var symbol: String {
        switch self {
        case .prepare: "hourglass"
        case .work: "flame.fill"
        case .rest: "wind"
        case .done: "checkmark.seal.fill"
        }
    }

    /// Light, mid and dark tones used to build the mesh background.
    private var palette: (Color, Color, Color) {
        switch self {
        case .prepare: (Color(red: 0.42, green: 0.45, blue: 0.98), Color(red: 0.26, green: 0.27, blue: 0.80), Color(red: 0.10, green: 0.11, blue: 0.40))
        case .work:    (Color(red: 1.00, green: 0.62, blue: 0.22), Color(red: 0.98, green: 0.28, blue: 0.20), Color(red: 0.70, green: 0.04, blue: 0.24))
        case .rest:    (Color(red: 0.30, green: 0.92, blue: 0.72), Color(red: 0.06, green: 0.66, blue: 0.62), Color(red: 0.03, green: 0.30, blue: 0.48))
        case .done:    (Color(red: 0.96, green: 0.48, blue: 0.86), Color(red: 0.56, green: 0.26, blue: 0.92), Color(red: 0.18, green: 0.10, blue: 0.48))
        }
    }

    var mesh: MeshGradient {
        let (light, mid, dark) = palette
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.65, 0.42], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                light, light, mid,
                light, mid, mid,
                mid, dark, dark,
            ]
        )
    }
}

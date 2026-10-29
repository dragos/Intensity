# Intensity

An interval training timer for iPhone, built with SwiftUI and SwiftData.

## Features

- **Workouts** – define a workout with a name, number of rounds, work and rest durations, and a color. Drag cards to reorder them; swipe left to edit, duplicate or delete.
- **Big, glanceable timer** – a large countdown inside a progress ring, with the background color showing the current period: indigo to get ready, red-orange for work, teal for rest.
- **Audio cues** – a beep on each of the last 3 seconds before every work period, plus tones when work, rest and the workout start or finish. Sounds play with the silent switch on and mix with your music.
- **Keeps going when locked** – the timer and sounds keep running with the screen locked, and the screen stays awake while a workout is open.
- **History and streaks** – past workouts grouped by week, a weekly streak (weeks with at least one completed workout), your best streak, and a minutes-per-week chart.
- **Large text support** – layouts adapt to Dynamic Type, up to the accessibility sizes.

## Requirements

- Xcode 27 or later
- iOS 26 or later (the app uses the Liquid Glass APIs)

## Running it

1. Open `Intensity.xcodeproj`.
2. To run on a simulator, pick one in the toolbar and press **⌘R**.
3. To run on your own iPhone:
   - In the **Intensity** target, open **Signing & Capabilities**.
   - Choose your own **Team**. A free Apple ID's Personal Team is enough.
   - Change the **Bundle Identifier** to something unique, for example `com.yourname.Intensity`.
   - Turn on **Developer Mode** on the phone (Settings → Privacy & Security), select the phone in Xcode and press **⌘R**.

In Debug builds, launching with the `-seedHistory` argument fills History with sample sessions.

## Project layout

```
Intensity/
├── IntensityApp.swift       App entry, tab view, first-launch sample workouts
├── Model/                   SwiftData models, workout timeline, weekly stats, theme
├── Timer/                   IntervalTimer (timing engine) and SoundPlayer (synthesized cues)
└── Views/                   Workout list, editor, running workout, history
```

There are no third-party dependencies and no sound files: the cue tones are generated in code with `AVAudioEngine`.

## License

[MIT](LICENSE)

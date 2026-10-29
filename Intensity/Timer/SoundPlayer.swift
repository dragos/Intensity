import AVFoundation

/// Plays synthesized cue tones. Keeping the audio engine running for the
/// whole workout also keeps the timer alive when the screen is locked
/// (the app declares the `audio` background mode).
@MainActor
final class SoundPlayer {
    enum Cue {
        case countdown, go, rest, finish
    }

    static let shared = SoundPlayer()

    var isMuted = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        buffers[.countdown] = makeTone([(880, 0.16)])
        buffers[.go] = makeTone([(1320, 0.5)])
        buffers[.rest] = makeTone([(740, 0.16), (494, 0.32)])
        buffers[.finish] = makeTone([(784, 0.14), (988, 0.14), (1175, 0.14), (1568, 0.6)])
    }

    func activate() {
        let session = AVAudioSession.sharedInstance()
        // .playback plays even with the silent switch on; mixing keeps the user's music going.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        startEngineIfNeeded()
    }

    func deactivate() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ cue: Cue) {
        guard !isMuted, let buffer = buffers[cue] else { return }
        startEngineIfNeeded()
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func startEngineIfNeeded() {
        // The engine stops on interruptions such as phone calls; restart it lazily.
        if !engine.isRunning { try? engine.start() }
        if engine.isRunning && !player.isPlaying { player.play() }
    }

    /// Renders a sequence of notes (frequency in Hz, duration in seconds)
    /// with a fast attack and a smooth decay so the beeps sound clean.
    private func makeTone(_ notes: [(frequency: Double, duration: Double)]) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let gapFrames = Int(0.03 * sampleRate)
        let attackFrames = Double(Int(0.004 * sampleRate))
        let totalFrames = notes.reduce(0) { $0 + Int($1.duration * sampleRate) + gapFrames }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        let samples = buffer.floatChannelData![0]

        var offset = 0
        for note in notes {
            let frames = Int(note.duration * sampleRate)
            for i in 0..<frames {
                let t = Double(i) / sampleRate
                let attack = min(1, Double(i) / attackFrames)
                let decay = pow(1 - Double(i) / Double(frames), 1.6)
                let wave = sin(2 * .pi * note.frequency * t) + 0.3 * sin(4 * .pi * note.frequency * t)
                samples[offset + i] = Float(wave * attack * decay * 0.55)
            }
            offset += frames
            for i in 0..<gapFrames { samples[offset + i] = 0 }
            offset += gapFrames
        }
        return buffer
    }
}

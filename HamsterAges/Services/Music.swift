import AVFoundation

/// Procedural chiptune soundtrack: one looping 8-bar theme per era + a calm menu theme.
/// Each theme is rendered once (bass + arpeggio + pulse-wave lead + simple drums) and looped.
@MainActor
final class Music {
    static let shared = Music()

    enum Theme: Hashable {
        case menu
        case era(Int)
    }

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(!isEnabled, forKey: "hamsterages.musicMuted")
            if isEnabled, let t = current { current = nil; play(t) } else if !isEnabled { player.stop() }
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cache: [Theme: AVAudioPCMBuffer] = [:]
    private var current: Theme?

    private init() {
        isEnabled = !UserDefaults.standard.bool(forKey: "hamsterages.musicMuted")
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = 0.45
    }

    func play(_ theme: Theme) {
        guard isEnabled, theme != current || !player.isPlaying || !engine.isRunning else { return }
        current = theme
        let buffer = cache[theme] ?? makeBuffer(Music.samples(for: theme, sampleRate: format.sampleRate))
        cache[theme] = buffer
        do {
            if !engine.isRunning {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            }
        } catch { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }

    func stop() {
        player.stop()
        current = nil
    }

    /// Renders every theme off the main thread at launch so entering a battle never hitches.
    func prewarm() {
        let sr = format.sampleRate
        let themes: [Theme] = [.menu] + (0..<5).map { .era($0) }
        Task.detached(priority: .utility) {
            for t in themes {
                let samples = Music.samples(for: t, sampleRate: sr)
                await MainActor.run {
                    if Music.shared.cache[t] == nil { Music.shared.cache[t] = Music.shared.makeBuffer(samples) }
                }
            }
        }
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let ch = buffer.floatChannelData![0]
        for (i, v) in samples.enumerated() { ch[i] = v }
        return buffer
    }

    // MARK: Composition

    private struct Style {
        let bpm: Double
        let root: Int            // MIDI note of the tonic
        let scale: [Int]         // semitone offsets
        let progression: [Int]   // scale degrees of chord roots, one per bar (cycled)
        let seed: UInt64
        let leadDuty: Double
        let drums: Bool
        let leadDensity: Double
    }

    nonisolated private static func style(_ t: Theme) -> Style {
        let major = [0, 2, 4, 5, 7, 9, 11], minor = [0, 2, 3, 5, 7, 8, 10], dorian = [0, 2, 3, 5, 7, 9, 10]
        switch t {
        case .menu: return Style(bpm: 96, root: 60, scale: major, progression: [0, 5, 3, 4], seed: 11, leadDuty: 0.5, drums: false, leadDensity: 0.55)
        case .era(0): return Style(bpm: 112, root: 57, scale: minor, progression: [0, 0, 5, 4], seed: 21, leadDuty: 0.5, drums: true, leadDensity: 0.6)
        case .era(1): return Style(bpm: 120, root: 62, scale: dorian, progression: [0, 6, 3, 0], seed: 31, leadDuty: 0.25, drums: true, leadDensity: 0.7)
        case .era(2): return Style(bpm: 126, root: 60, scale: major, progression: [0, 3, 4, 0], seed: 41, leadDuty: 0.25, drums: true, leadDensity: 0.75)
        case .era(3): return Style(bpm: 132, root: 55, scale: minor, progression: [0, 5, 6, 4], seed: 51, leadDuty: 0.125, drums: true, leadDensity: 0.8)
        default: return Style(bpm: 140, root: 57, scale: minor, progression: [0, 3, 5, 4], seed: 61, leadDuty: 0.125, drums: true, leadDensity: 0.85)
        }
    }

    nonisolated static func samples(for theme: Theme, sampleRate sr: Double) -> [Float] {
        let s = style(theme)
        let bars = 8, stepsPerBar = 16
        let stepLen = Int(60 / s.bpm / 4 * sr)
        let total = bars * stepsPerBar * stepLen
        var out = [Float](repeating: 0, count: total)
        var rng = SeededRandom(seed: s.seed)

        func midi(_ degree: Int, octave: Int = 0) -> Int {
            let n = s.scale.count
            let d = ((degree % n) + n) % n
            let o = Int((Double(degree) / Double(n)).rounded(.down))
            return s.root + s.scale[d] + 12 * (o + octave)
        }
        func freq(_ m: Int) -> Double { 440 * pow(2, Double(m - 69) / 12) }

        func note(_ m: Int, at step: Int, steps: Int, volume: Float, wave: (Double) -> Float) {
            let start = step * stepLen, len = steps * stepLen
            let f = freq(m) / sr
            var phase = 0.0
            for i in 0..<len where start + i < total {
                let t = Double(i) / Double(len)
                let env = Float(min(1, t * 60) * (t > 0.85 ? (1 - t) / 0.15 : 1))
                out[start + i] += wave(phase) * env * volume
                phase += f
            }
        }
        func pulse(_ duty: Double) -> (Double) -> Float { { p in p.truncatingRemainder(dividingBy: 1) < duty ? 1 : -1 } }
        let tri: (Double) -> Float = { p in Float(4 * abs(p.truncatingRemainder(dividingBy: 1) - 0.5) - 1) }

        func noise(at step: Int, seconds: Double, volume: Float, bright: Bool) {
            let start = step * stepLen, len = Int(seconds * sr)
            var y: Float = 0
            for i in 0..<len where start + i < total {
                let w = Float.random(in: -1...1, using: &rng)
                y += (bright ? 0.9 : 0.25) * (w - y)
                let v = bright ? (w - y) : y
                out[start + i] += v * Float(exp(-Double(i) / Double(len) * 5)) * volume
            }
        }
        func kick(at step: Int) {
            let start = step * stepLen, len = Int(0.14 * sr)
            var phase = 0.0
            for i in 0..<len where start + i < total {
                let t = Double(i) / Double(len)
                phase += (120 - 80 * t) / sr
                out[start + i] += Float(sin(2 * .pi * phase) * (1 - t)) * 0.35
            }
        }

        var leadDegree = 7
        for bar in 0..<bars {
            let chord = s.progression[bar % s.progression.count]
            let base = bar * stepsPerBar
            // Bass: root on beats 1 and 3, fifth pickup on the last 8th.
            note(midi(chord, octave: -2), at: base, steps: 7, volume: 0.16, wave: pulse(0.5))
            note(midi(chord, octave: -2), at: base + 8, steps: 5, volume: 0.16, wave: pulse(0.5))
            note(midi(chord + 4, octave: -2), at: base + 14, steps: 2, volume: 0.13, wave: pulse(0.5))
            // Arpeggio on 8ths.
            let tones = [chord, chord + 2, chord + 4, chord + 2]
            for k in 0..<8 {
                note(midi(tones[k % 4]), at: base + k * 2, steps: 2, volume: 0.06, wave: tri)
            }
            // Lead: seeded random walk, landing on chord tones on strong beats.
            var step = 0
            while step < stepsPerBar {
                let len = [2, 2, 4, 4, 6][Int.random(in: 0..<5, using: &rng)]
                if Double.random(in: 0..<1, using: &rng) < s.leadDensity {
                    if step % 8 == 0 {
                        leadDegree = chord + [0, 2, 4][Int.random(in: 0..<3, using: &rng)] + 7
                    } else {
                        leadDegree += [-2, -1, -1, 1, 1, 2][Int.random(in: 0..<6, using: &rng)]
                    }
                    leadDegree = min(13, max(4, leadDegree))
                    note(midi(leadDegree), at: base + step, steps: min(len, stepsPerBar - step), volume: 0.075, wave: pulse(s.leadDuty))
                }
                step += len
            }
            // Drums.
            if s.drums {
                kick(at: base); kick(at: base + 8)
                if bar % 2 == 1 { kick(at: base + 10) }
                noise(at: base + 4, seconds: 0.09, volume: 0.22, bright: false)
                noise(at: base + 12, seconds: 0.09, volume: 0.22, bright: false)
                for h in stride(from: 2, to: 16, by: 4) { noise(at: base + h, seconds: 0.03, volume: 0.1, bright: true) }
            }
        }

        return out.map { tanhf($0 * 1.2) * 0.8 }   // soft clip
    }
}

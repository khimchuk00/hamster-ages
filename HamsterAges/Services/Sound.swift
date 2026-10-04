import AVFoundation
import QuartzCore

/// Procedurally synthesized SFX (no audio assets). Buffers are generated once at launch,
/// played through a small pool of AVAudioPlayerNodes. Category .ambient respects the silent switch.
@MainActor
final class Sound {
    static let shared = Sound()

    enum Effect: CaseIterable {
        case tap, hit, pop, coin, boom, evolve, win, lose, card, squeak
    }

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(!isEnabled, forKey: "hamsterages.muted") }
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    /// A few pitch-shifted takes of each effect so repeated hits don't sound like a machine gun of clones.
    private var buffers: [Effect: [AVAudioPCMBuffer]] = [:]
    private var lastPlayed: [Effect: TimeInterval] = [:]
    private var next = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        isEnabled = !UserDefaults.standard.bool(forKey: "hamsterages.muted")
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.55
        for e in Effect.allCases {
            let base = synth(e)
            let varied: Set<Effect> = [.hit, .pop, .coin, .tap, .squeak]
            buffers[e] = varied.contains(e) ? [0.92, 1.0, 1.08].map { resample(base, rate: $0) } : [base]
        }
    }

    func play(_ e: Effect, minInterval: TimeInterval = 0.05) {
        guard isEnabled, let takes = buffers[e], let buffer = takes.randomElement() else { return }
        let now = CACurrentMediaTime()
        if let last = lastPlayed[e], now - last < minInterval { return }
        lastPlayed[e] = now
        // The engine stops on audio interruptions / route changes; play() on a stopped engine throws an ObjC exception.
        if !engine.isRunning {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            } catch { return }
        }
        let p = players[next]
        next = (next + 1) % players.count
        p.stop()
        p.scheduleBuffer(buffer, at: nil, options: [])
        p.play()
    }

    // MARK: Synthesis

    private func synth(_ e: Effect) -> AVAudioPCMBuffer {
        switch e {
        case .tap: return tone([(880, 0.045)], wave: .square, volume: 0.25)
        case .hit: return noise(duration: 0.06, volume: 0.35, decay: 40, lowpass: 0.35)
        case .pop: return sweep(from: 520, to: 140, duration: 0.12, wave: .sine, volume: 0.45)
        case .coin: return tone([(1318, 0.05), (1760, 0.09)], wave: .square, volume: 0.18)
        case .boom: return noise(duration: 0.55, volume: 0.9, decay: 6, lowpass: 0.08)
        case .evolve: return tone([(523, 0.08), (659, 0.08), (784, 0.08), (1046, 0.22)], wave: .triangle, volume: 0.4)
        case .win: return tone([(523, 0.1), (659, 0.1), (784, 0.1), (1046, 0.12), (784, 0.08), (1046, 0.35)], wave: .square, volume: 0.22)
        case .lose: return tone([(392, 0.16), (349, 0.16), (311, 0.16), (262, 0.4)], wave: .triangle, volume: 0.4)
        case .card: return sweep(from: 400, to: 1200, duration: 0.15, wave: .triangle, volume: 0.35)
        case .squeak: return tone([(1760, 0.04), (2349, 0.05), (1568, 0.07)], wave: .triangle, volume: 0.22)
        }
    }

    private enum Wave { case sine, square, triangle }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        b.frameLength = AVAudioFrameCount(samples.count)
        let ch = b.floatChannelData![0]
        for (i, s) in samples.enumerated() { ch[i] = s }
        return b
    }

    /// Plays the buffer faster (> 1, higher pitch) or slower (< 1) by linear interpolation.
    private func resample(_ src: AVAudioPCMBuffer, rate: Double) -> AVAudioPCMBuffer {
        guard rate != 1, let input = src.floatChannelData?[0] else { return src }
        let n = Int(src.frameLength)
        let m = max(1, Int(Double(n) / rate))
        var out = [Float](repeating: 0, count: m)
        for i in 0..<m {
            let x = Double(i) * rate
            let j = Int(x), f = Float(x - Double(j))
            let a = input[min(j, n - 1)], b = input[min(j + 1, n - 1)]
            out[i] = a + (b - a) * f
        }
        return buffer(out)
    }

    private func osc(_ wave: Wave, phase: Double) -> Float {
        let x = phase.truncatingRemainder(dividingBy: 1)
        switch wave {
        case .sine: return Float(sin(2 * .pi * x))
        case .square: return x < 0.5 ? 1 : -1
        case .triangle: return Float(4 * abs(x - 0.5) - 1)
        }
    }

    /// Sequence of notes with a short attack/release envelope per note.
    private func tone(_ notes: [(freq: Double, dur: Double)], wave: Wave, volume: Float) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        var out: [Float] = []
        for (freq, dur) in notes {
            let n = Int(dur * sr)
            var phase = 0.0
            for i in 0..<n {
                let t = Double(i) / Double(n)
                let env = Float(min(1, t * 40) * pow(1 - t, 1.5))
                out.append(osc(wave, phase: phase) * env * volume)
                phase += freq / sr
            }
        }
        return buffer(out)
    }

    private func sweep(from f0: Double, to f1: Double, duration: Double, wave: Wave, volume: Float) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let n = Int(duration * sr)
        var phase = 0.0
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(n)
            out[i] = osc(wave, phase: phase) * Float(min(1, t * 30) * (1 - t)) * volume
            phase += (f0 + (f1 - f0) * t) / sr
        }
        return buffer(out)
    }

    private func noise(duration: Double, volume: Float, decay: Double, lowpass: Float) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let n = Int(duration * sr)
        var out = [Float](repeating: 0, count: n)
        var y: Float = 0
        var rng = SeededRandom(seed: 1234)
        for i in 0..<n {
            let t = Double(i) / sr
            let white = Float.random(in: -1...1, using: &rng)
            y += lowpass * (white - y)                       // one-pole low-pass for a "thud"
            out[i] = y * Float(exp(-decay * t)) * volume * 2
        }
        return buffer(out)
    }
}

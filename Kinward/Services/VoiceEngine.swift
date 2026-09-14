import Foundation
import AVFoundation
import Observation

/// Recording and playback of the one thing that can't be rewritten later: a voice.
@MainActor
@Observable
final class VoiceRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var levels: [Double] = []
    private(set) var currentRef: String?
    var permissionDenied = false

    var durationText: String {
        let m = Int(elapsed) / 60, s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { c in
            AVAudioApplication.requestRecordPermission { granted in c.resume(returning: granted) }
        }
    }

    func start() async {
        guard await requestPermission() else { permissionDenied = true; return }
        let session = AVAudioSession.sharedInstance()
        // Deliberately no Bluetooth route: HFP headset mics are 8–16 kHz, and this
        // recording is meant to still sound like the person in thirty years.
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let ref = MediaStore.newAudioRef()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let r = try AVAudioRecorder(url: MediaStore.url(for: ref), settings: settings)
            r.isMeteringEnabled = true
            r.record()
            recorder = r; currentRef = ref
            isRecording = true; isPaused = false
            elapsed = 0; levels = []
            startTimer()
            Haptics.settle()
        } catch {
            permissionDenied = true
        }
    }

    func pause() {
        recorder?.pause(); isPaused = true; timer?.invalidate(); Haptics.detent()
    }
    func resume() {
        recorder?.record(); isPaused = false; startTimer(); Haptics.detent()
    }

    /// Returns the saved reference, duration and the waveform we drew while listening.
    @discardableResult
    func stop() -> (ref: String, duration: TimeInterval, levels: [Double])? {
        timer?.invalidate(); timer = nil
        guard let r = recorder, let ref = currentRef else { return nil }
        let d = r.currentTime
        r.stop()
        recorder = nil; isRecording = false; isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Haptics.kept()
        let result = (ref, max(d, elapsed), levels)
        currentRef = nil
        return result
    }

    func discard() {
        timer?.invalidate(); timer = nil
        recorder?.stop()
        MediaStore.delete(currentRef)
        recorder = nil; currentRef = nil
        isRecording = false; isPaused = false; elapsed = 0; levels = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let r = recorder, r.isRecording else { return }
        r.updateMeters()
        elapsed = r.currentTime
        let db = Double(r.averagePower(forChannel: 0))          // roughly -60...0
        let norm = max(0, min(1, (db + 55) / 55))
        levels.append(pow(norm, 0.65))
        if levels.count > 1400 { levels.removeFirst(levels.count - 1400) }
    }
}

@MainActor
@Observable
final class VoicePlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = VoicePlayer()
    private var player: AVAudioPlayer?
    private var timer: Timer?

    private(set) var playingRef: String?
    private(set) var progress: Double = 0
    private(set) var currentTime: TimeInterval = 0
    var isPlaying: Bool { player?.isPlaying ?? false }

    func toggle(ref: String) {
        if playingRef == ref, let p = player {
            if p.isPlaying { p.pause(); timer?.invalidate() }
            else { p.play(); startTimer() }
            return
        }
        play(ref: ref)
    }

    func play(ref: String) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: MediaStore.url(for: ref)) else { return }
        p.delegate = self
        p.play()
        player = p; playingRef = ref; progress = 0
        startTimer()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player?.stop(); player = nil
        playingRef = nil; progress = 0; currentTime = 0
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let p = self.player else { return }
                self.currentTime = p.currentTime
                self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}

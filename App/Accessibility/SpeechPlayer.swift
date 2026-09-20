import AVFoundation
import Observation
import ReportCore

/// Reads a card aloud the way a screen reader presents it, and reports which
/// block is being spoken so the canvas can follow along.
///
/// The point is empathy: an author hears "Image. No description." instead of
/// reading a lint message about it.
@MainActor
@Observable
final class SpeechPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    private(set) var currentSegment: SpokenSegment?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var segments: [ObjectIdentifier: SpokenSegment] = [:]
    @ObservationIgnored private var lastUtterance: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// - Parameter volume: 0 is silent. Screenshots and UI tests follow the
    ///   narration without making the Mac talk.
    func speak(_ spoken: [SpokenSegment], language: String = "en-US", volume: Float = 1) {
        stop()
        guard !spoken.isEmpty else { return }
        let voice = AVSpeechSynthesisVoice(language: language)
        for segment in spoken {
            let utterance = AVSpeechUtterance(string: segment.text)
            utterance.voice = voice
            utterance.volume = volume
            utterance.postUtteranceDelay = segment.kind == .heading ? 0.25 : 0.12
            let identifier = ObjectIdentifier(utterance)
            segments[identifier] = segment
            lastUtterance = identifier
            synthesizer.speak(utterance)
        }
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        segments.removeAll()
        lastUtterance = nil
        currentSegment = nil
        isSpeaking = false
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.currentSegment = self.segments[identifier]
        }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor in
            if identifier == self.lastUtterance {
                self.stop()
            }
        }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in
            self.currentSegment = nil
        }
    }
}

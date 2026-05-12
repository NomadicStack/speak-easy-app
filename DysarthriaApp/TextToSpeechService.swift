import Foundation
import AVFoundation
import Combine

class TextToSpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?
    
    override init() {
        super.init()
        setupVoice()
    }
    
    private func setupVoice() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let zoeVoice = voices.first(where: { $0.name.contains("Zoe") }) {
            self.voice = zoeVoice
        } else if let highQualityEnglish = voices.first(where: { $0.language == "en-US" && $0.quality == .enhanced }) {
            self.voice = highQualityEnglish
        } else {
            self.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback is the most stable for AVSpeechSynthesizer
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("TTS Session Error: \(error.localizedDescription)")
        }
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = self.voice
        
        // Slightly slower rate for better clarity
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

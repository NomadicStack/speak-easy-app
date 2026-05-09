import Foundation
import AVFoundation
import Combine

class TextToSpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
    }
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        
        // Attempt to find a high-quality, natural-sounding voice
        // Prefer "Zoe" if available, otherwise any high-quality English voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let zoeVoice = voices.first(where: { $0.name.contains("Zoe") }) {
            utterance.voice = zoeVoice
        } else if let highQualityEnglish = voices.first(where: { $0.language == "en-US" && $0.quality == .enhanced }) {
            utterance.voice = highQualityEnglish
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Slightly slower rate for better clarity
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

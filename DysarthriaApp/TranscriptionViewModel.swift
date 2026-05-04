import Foundation
import Combine
import CoreML
import WhisperKit

@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var transcribedText: String = "Press record to start."
    @Published var isTranscribing: Bool = false
    @Published var modelLoadingMessage: String = "Loading model..."
    @Published var isModelLoaded: Bool = false
    @Published var initialPrompt: String = "The user is speaking clearly."
    
    private var whisperKit: WhisperKit?
    
    init() {
        Task {
            await initializeWhisperKit()
        }
    }
    
    func initializeWhisperKit() async {
        do {
            // Phase 1: Temporary setup using base whisper-small.en
            // This will automatically download the CoreML model on first run if not bundled.
            self.modelLoadingMessage = "Downloading/Loading openai_whisper-small.en..."
            let config = WhisperKitConfig(
                model: "openai_whisper-small.en",
                computeOptions: ModelComputeOptions(
                    melCompute: .cpuAndNeuralEngine,
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                )
            )
            self.whisperKit = try await WhisperKit(config)
            self.isModelLoaded = true
            self.modelLoadingMessage = "Model ready"
        } catch {
            self.modelLoadingMessage = "Error loading model: \(error.localizedDescription)"
            print("WhisperKit initialization error: \(error)")
        }
    }
    
    func clearTranscription() {
        self.transcribedText = "Press record to start."
    }
    
    func transcribeAudio(at url: URL) {
        guard let whisperKit = self.whisperKit, isModelLoaded else {
            self.transcribedText = "Model not ready."
            return
        }
        
        self.isTranscribing = true
        self.transcribedText = "Transcribing..."
        
        Task {
            do {
                var options = DecodingOptions()
                options.topK = 5 // Keep sampling constrained for more stable output.
                options.temperature = 0.0
                options.temperatureIncrementOnFallback = 0.2
                if let tokenizer = whisperKit.tokenizer {
                    options.promptTokens = tokenizer.encode(text: self.initialPrompt)
                }
                
                // Transcribe the audio file
                let result = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
                
                if let text = result.first?.text, !text.isEmpty {
                    self.transcribedText = text
                } else {
                    self.transcribedText = "[No transcription returned]"
                }
            } catch {
                self.transcribedText = "Error during transcription: \(error.localizedDescription)"
                print("Transcription error: \(error)")
            }
            
            self.isTranscribing = false
        }
    }
}

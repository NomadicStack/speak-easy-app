import Foundation
import Combine
import CoreML
import WhisperKit

struct TranscriptionCorrection: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let audioFileName: String
    let originalText: String
    let correctedText: String
}

@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var transcribedText: String = "Press record to start."
    @Published var isTranscribing: Bool = false
    @Published var modelLoadingMessage: String = "Loading model..."
    @Published var isModelLoaded: Bool = false
    @Published var initialPrompt: String = "The user is speaking clearly."
    
    // Stats and Feedback
    @Published var totalTranscriptions: Int = 0
    @Published var totalCorrections: Int = 0
    @Published var lastAudioURL: URL?
    @Published var originalTranscription: String = ""
    @Published var isEditing: Bool = false
    
    private var whisperKit: WhisperKit?
    private let correctionsKey = "saved_corrections"
    
    init() {
        self.totalTranscriptions = UserDefaults.standard.integer(forKey: "total_transcriptions")
        self.totalCorrections = UserDefaults.standard.integer(forKey: "total_corrections")
        
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
        self.originalTranscription = ""
        self.lastAudioURL = nil
    }
    
    func saveCorrection() {
        guard let audioURL = lastAudioURL, !originalTranscription.isEmpty else { return }
        
        // Save the audio file permanently for training
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let feedbackFolder = documentsURL.appendingPathComponent("FeedbackAudio")
        
        try? fileManager.createDirectory(at: feedbackFolder, withIntermediateDirectories: true)
        
        let newAudioFileName = "\(UUID().uuidString).wav"
        let permanentAudioURL = feedbackFolder.appendingPathComponent(newAudioFileName)
        
        do {
            if fileManager.fileExists(atPath: permanentAudioURL.path) {
                try fileManager.removeItem(at: permanentAudioURL)
            }
            try fileManager.copyItem(at: audioURL, to: permanentAudioURL)
            
            let correction = TranscriptionCorrection(
                timestamp: Date(),
                audioFileName: newAudioFileName,
                originalText: originalTranscription,
                correctedText: transcribedText
            )
            
            saveToLogs(correction)
            
            totalCorrections += 1
            UserDefaults.standard.set(totalCorrections, forKey: "total_corrections")
            isEditing = false
        } catch {
            print("Error saving correction: \(error)")
        }
    }
    
    private func saveToLogs(_ correction: TranscriptionCorrection) {
        var logs = getLogs()
        logs.append(correction)
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: correctionsKey)
        }
    }
    
    func getLogs() -> [TranscriptionCorrection] {
        if let data = UserDefaults.standard.data(forKey: correctionsKey),
           let logs = try? JSONDecoder().decode([TranscriptionCorrection].self, from: data) {
            return logs
        }
        return []
    }
    
    func getFeedbackAudioURLs() -> [URL] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let feedbackFolder = documentsURL.appendingPathComponent("FeedbackAudio")
        
        let logs = getLogs()
        return logs.compactMap { log in
            let url = feedbackFolder.appendingPathComponent(log.audioFileName)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
    }
    
    func prepareFeedbackReport() -> String {
        let logs = getLogs()
        var report = "SpeakEasy Feedback Report\n"
        report += "Total Transcriptions: \(totalTranscriptions)\n"
        report += "Total Corrections: \(totalCorrections)\n\n"
        
        for log in logs {
            report += "---\n"
            report += "Date: \(log.timestamp)\n"
            report += "Audio: \(log.audioFileName)\n"
            report += "Original: \(log.originalText)\n"
            report += "Corrected: \(log.correctedText)\n"
        }
        return report
    }
    
    func transcribeAudio(at url: URL) {
        guard let whisperKit = self.whisperKit, isModelLoaded else {
            self.transcribedText = "Model not ready."
            return
        }
        
        self.lastAudioURL = url
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
                    self.originalTranscription = text
                    self.totalTranscriptions += 1
                    UserDefaults.standard.set(totalTranscriptions, forKey: "total_transcriptions")
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

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
    
    // Stats and Feedback
    @Published var totalTranscriptions: Int = 0
    @Published var totalCorrections: Int = 0
    @Published var lastAudioURL: URL?
    @Published var originalTranscription: String = ""
    @Published var isEditing: Bool = false
    
    private var whisperKit: WhisperKit?
    private let correctionsKey = "saved_corrections"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.totalTranscriptions = UserDefaults.standard.integer(forKey: "total_transcriptions")
        self.totalCorrections = UserDefaults.standard.integer(forKey: "total_corrections")
        
        // Always start loading a model immediately on launch
        Task { await self.initializeWhisperKit() }
        
        // Listen for custom model activation — reinitialize WhisperKit when activated
        TokenService.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if case .active = status {
                    // Custom model was just activated — reinitialize with it
                    if !self.isTranscribing {
                        Task { await self.initializeWhisperKit() }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func initializeWhisperKit() async {
        self.isModelLoaded = false
        self.whisperKit = nil
        
        // Priority 1: Custom model (if available from token)
        if let modelDirURL = TokenService.shared.findModelDirectory() {
            do {
                let modelName = modelDirURL.lastPathComponent
                self.modelLoadingMessage = "Loading custom model (\(modelName))..."
                
                let config = WhisperKitConfig(
                    model: modelName,
                    modelFolder: modelDirURL.path,
                    tokenizerFolder: modelDirURL,
                    computeOptions: ModelComputeOptions(
                        melCompute: .cpuAndNeuralEngine,
                        audioEncoderCompute: .cpuAndNeuralEngine,
                        textDecoderCompute: .cpuAndNeuralEngine
                    ),
                    download: false
                )
                
                self.whisperKit = try await WhisperKit(config)
                self.isModelLoaded = true
                self.modelLoadingMessage = "Model ready (\(modelName))"
                return
            } catch {
                print("Custom model failed, falling back to free model: \(error)")
            }
        }
        
        // Priority 2: Free model (auto-download from WhisperKit hub)
        do {
            self.modelLoadingMessage = "Downloading speech model... This may take a few minutes on first launch."
            
            let config = WhisperKitConfig(
                model: "openai_whisper-small",
                computeOptions: ModelComputeOptions(
                    melCompute: .cpuAndNeuralEngine,
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                )
            )
            
            self.whisperKit = try await WhisperKit(config)
            self.isModelLoaded = true
            self.modelLoadingMessage = "Model ready (Whisper Small)"
        } catch {
            self.modelLoadingMessage = "Failed to load model: \(error.localizedDescription)"
            print("WhisperKit initialization error: \(error)")
            self.isModelLoaded = false
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
    
    func cancelEditing() {
        if !originalTranscription.isEmpty {
            transcribedText = originalTranscription
        }
        isEditing = false
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
    
    func prepareFeedbackReport(userEmail: String = "") -> String {
        let logs = getLogs()
        var report = "SpeakEasy Feedback Report\n"
        if !userEmail.isEmpty {
            report += "User Email: \(userEmail)\n"
        }
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
    
    func clearFeedbackData() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let feedbackFolder = documentsURL.appendingPathComponent("FeedbackAudio")
        
        // Delete all audio files in the feedback folder
        let logs = getLogs()
        for log in logs {
            let url = feedbackFolder.appendingPathComponent(log.audioFileName)
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }
        
        // Clear the logs in UserDefaults
        UserDefaults.standard.removeObject(forKey: correctionsKey)
    }
    
    func transcribeAudio(at url: URL) {
        guard let whisperKit = self.whisperKit, isModelLoaded else {
            self.transcribedText = "Model not ready."
            return
        }
        
        // Cleanup previous recording if it exists and wasn't saved
        if let previousURL = self.lastAudioURL, previousURL != url {
            try? FileManager.default.removeItem(at: previousURL)
        }
        
        self.lastAudioURL = url
        self.isTranscribing = true
        
        Task {
            do {
                var options = DecodingOptions()
                options.temperature = 0.0
                options.temperatureIncrementOnFallback = 0.2
                options.temperatureFallbackCount = 0 // Disable fallbacks to stick with the best guess
                options.logProbThreshold = nil // Do not reject based on confidence
                options.firstTokenLogProbThreshold = nil // Do not reject based on the first word
                options.suppressBlank = false
                options.language = "en"
                options.verbose = false
                
                // Transcribe the audio file
                print("Starting transcription for file: \(url.path)")
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("Audio file size: \(fileSize) bytes")
                }
                
                let result = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
                print("Transcription completed. Result count: \(result.count)")
                
                if let firstResult = result.first {
                    // Join segments with spaces and clean special tokens (e.g., <|...|>)
                    let newText = firstResult.segments
                        .map { segment in
                            segment.text
                                .replacingOccurrences(of: "<\\|.*?\\|>", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespaces)
                        }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    
                    if !newText.isEmpty {
                        // Append to existing text if it's not the default message
                        if self.transcribedText == "Press record to start." || 
                           self.transcribedText == "[No transcription returned]" ||
                           self.transcribedText == "Transcribing..." {
                            self.transcribedText = newText
                        } else {
                            // Ensure there is a newline between different recording sessions
                            let currentText = self.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.transcribedText = currentText + "\n" + newText
                        }
                        self.originalTranscription = self.transcribedText
                        self.totalTranscriptions += 1
                        UserDefaults.standard.set(totalTranscriptions, forKey: "total_transcriptions")
                    } else if self.transcribedText == "Press record to start." || self.transcribedText == "Transcribing..." {
                        self.transcribedText = "[No transcription returned]"
                    }
                } else {
                    if self.transcribedText == "Press record to start." || self.transcribedText == "Transcribing..." {
                        self.transcribedText = "[No transcription returned]"
                    }
                }
            } catch {
                self.transcribedText = "Error during transcription: \(error.localizedDescription)"
                print("Transcription error: \(error)")
            }
            
            self.isTranscribing = false
        }
    }
}

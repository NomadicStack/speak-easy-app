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
    @Published var initialPrompt: String = "The following is a transcription of a speaker with dysarthria, focusing on clear and accurate text output."
    
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
            self.modelLoadingMessage = "Loading custom dysarthria model..."
            
            // Check if model components exist in the bundle root (flattened) or a subfolder
            let bundleURL = Bundle.main.bundleURL
            let modelFolder: String
            let tokenizerURL: URL
            let modelName: String
            
            if let customFolderURL = Bundle.main.url(forResource: "CustomDysarthriaModel", withExtension: nil) {
                // Folder reference (retains structure)
                modelName = "CustomDysarthriaModel"
                modelFolder = customFolderURL.deletingLastPathComponent().path
                tokenizerURL = customFolderURL
            } else {
                // Flattened group (files at root)
                modelName = "" // Empty model name works with modelFolder pointing directly to components
                modelFolder = bundleURL.path
                tokenizerURL = bundleURL
            }
            
            let config = WhisperKitConfig(
                model: modelName,
                modelFolder: modelFolder,
                tokenizerFolder: tokenizerURL,
                computeOptions: ModelComputeOptions(
                    melCompute: .cpuAndNeuralEngine,
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                download: false
            )
            
            self.whisperKit = try await WhisperKit(config)
            self.isModelLoaded = true
            self.modelLoadingMessage = "Model ready (Custom)"
        } catch {
            self.modelLoadingMessage = "Error: \(error.localizedDescription)"
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
                options.suppressBlank = false // Help with initial silence
                
                // Note: promptTokens is currently disabled due to reports of empty results in some WhisperKit versions
                // if let tokenizer = whisperKit.tokenizer {
                //     options.promptTokens = tokenizer.encode(text: self.initialPrompt)
                // }
                
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

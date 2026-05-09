import Foundation
import SwiftUI
import Combine

@MainActor
class AACViewModel: ObservableObject {
    @Published var shorthandInput: String = ""
    @Published var isGenerating: Bool = false
    @Published var generatedOptions: [String] = []
    @Published var errorMessage: String?
    
    private let ttsService = TextToSpeechService()
    private let gemmaService = GemmaService()
    
    func expand() async {
        guard !shorthandInput.isEmpty else { return }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            try await gemmaService.loadModel()
            let rawResult = try await gemmaService.expandAAC(shorthand: shorthandInput)
            self.generatedOptions = parseOptions(rawResult)
            gemmaService.unloadModel()
        } catch {
            self.errorMessage = "Failed to expand shorthand: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    private func parseOptions(_ llmOutput: String) -> [String] {
        let lines = llmOutput.components(separatedBy: .newlines)
        let parsed: [String] = lines.compactMap { line in
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { return nil }
            
            // Remove numbered list markers like "1. ", "2. ", etc.
            if let range = cleaned.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                return String(cleaned[range.upperBound...])
            }
            return cleaned
        }
        
        // Strictly limit to 3 sentences as requested
        return Array(parsed.prefix(3))
    }
    func appendContextAndRegenerate(newTranscription: String) {
        guard !newTranscription.isEmpty else { return }
        
        if shorthandInput.isEmpty {
            shorthandInput = newTranscription
        } else {
            shorthandInput += " " + newTranscription
        }
        
        Task {
            await expand()
        }
    }
    
    func speak(_ text: String) {
        ttsService.speak(text)
    }
    
    func clear() {
        shorthandInput = ""
        generatedOptions = []
        errorMessage = nil
    }
}

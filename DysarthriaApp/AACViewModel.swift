import Foundation
import SwiftUI
import Combine

@MainActor
class AACViewModel: ObservableObject {
    @Published var shorthandInput: String = ""
    @Published var isGenerating: Bool = false
    @Published var generatedOptions: [String] = []
    @Published var errorMessage: String?
    
    @AppStorage("user_name") var userName: String = "User"
    
    private let ttsService = TextToSpeechService()
    private let gemmaService = GemmaService()
    
    func expand() async {
        guard !shorthandInput.isEmpty else { return }
        
        isGenerating = true
        errorMessage = nil
        
        let contacts = ContactManager.shared.contacts.map { "\($0.name): \($0.phoneNumber)" }.joined(separator: ", ")
        
        do {
            try await gemmaService.loadModel()
            let rawResult = try await gemmaService.expandAAC(
                shorthand: shorthandInput,
                userName: userName,
                contacts: contacts.isEmpty ? "None" : contacts
            )
            self.generatedOptions = parseOptions(rawResult)
            gemmaService.unloadModel()
        } catch {
            self.errorMessage = "Failed to expand shorthand: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    private func parseOptions(_ llmOutput: String) -> [String] {
        let lines = llmOutput.components(separatedBy: .newlines)
        var parsed: [String] = []
        
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { continue }
            
            // Remove numbered list markers like "1. ", "2. ", etc.
            if let range = cleaned.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                let text = String(cleaned[range.upperBound...]).trimmingCharacters(in: .init(charactersIn: " \""))
                parsed.append(text)
            } else if !cleaned.hasPrefix("<|") && !cleaned.hasPrefix("<turn") {
                // Fallback for lines that aren't markers or numbered but contain text
                parsed.append(cleaned)
            }
        }
        
        // Return up to 3 options
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

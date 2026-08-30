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
        print("--- Gemma Raw Output ---")
        print(llmOutput)
        print("------------------------")
        
        var text = llmOutput
        
        // 1. Remove all XML/turn-like tags: <|turn>model, <turn|>, <start_of_turn>, etc.
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        
        // 2. Remove leading metadata prefixes like "Output:", "Here are...", "Model:"
        text = text.replacingOccurrences(
            of: #"(?i)^\s*(?:here (?:are|is)[^:\n]*:|output:|decoded:|interpretation:|model:|user:)\s*"#,
            with: "",
            options: .regularExpression
        )
        
        // 3. Split multiple numbered / bulleted items on the same line:
        // e.g. "1. First sentence. 2. Second sentence." -> "1. First sentence.\n2. Second sentence."
        text = text.replacingOccurrences(
            of: #"(?<=\S)\s+(?=(?:\d+[\.\)]|[-*•]))"#,
            with: "\n",
            options: .regularExpression
        )
        
        let lines = text.components(separatedBy: .newlines)
        var parsed: [String] = []
        
        for line in lines {
            var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { continue }
            
            // Remove leading role markers if present (e.g. "model: ", "model ")
            if let roleRange = cleaned.range(of: #"^(?:model|user)\s*[\:\-]?\s*"#, options: [.regularExpression, .caseInsensitive]) {
                cleaned = String(cleaned[roleRange.upperBound...])
            }
            
            // Remove numbered / bullet list markers:
            // "1. ", "1) ", "1: ", "1 - ", "Option 1: ", "[1] ", "- ", "* ", "• "
            if let markerRange = cleaned.range(of: #"^(?:(?:option|choice|sentence|#)?\s*\d+[\.\)\:\-\]]*|[-*•])\s*"#, options: [.regularExpression, .caseInsensitive]) {
                cleaned = String(cleaned[markerRange.upperBound...])
            }
            
            // Remove style labels like "DIRECT: ", "NATURAL: ", "MESSAGING: ", "URGENT: ", "SMS: "
            if let labelRange = cleaned.range(of: #"^(?:direct|natural|messaging|urgent|sms|polite|casual|quick|sentence\s*\d*)\s*[\:\-]\s*"#, options: [.regularExpression, .caseInsensitive]) {
                cleaned = String(cleaned[labelRange.upperBound...])
            }
            
            // Clean up wrapping quotes and extra whitespace
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"\'`“”‘’"))
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate:
            // 1. Must not be empty
            if cleaned.isEmpty { continue }
            
            // 2. Must contain meaningful letters (at least 2 letters, rejecting lines like "2", ".", "-", "1.")
            let letterCount = cleaned.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            if letterCount < 2 { continue }
            
            // 3. Reject incomplete dangling fragments (e.g. "Hey Mom,", "Mom:", "Hey,")
            let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if (cleaned.hasSuffix(",") || cleaned.hasSuffix(":")) && words.count <= 3 {
                continue
            }
            
            // If it ends with a dangling comma or colon but has enough words, strip the trailing punctuation
            if cleaned.hasSuffix(",") || cleaned.hasSuffix(":") {
                cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Capitalize first letter if needed
            if let first = cleaned.first, first.isLowercase {
                cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
            }
            
            // Deduplicate (case-insensitive)
            if !parsed.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) {
                parsed.append(cleaned)
            }
            
            if parsed.count == 3 {
                break
            }
        }
        
        // Fallback: If nothing was parsed but the raw string has actual text
        if parsed.isEmpty {
            let fallback = llmOutput
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let letters = fallback.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            if letters >= 2 {
                parsed.append(fallback)
            }
        }
        
        return parsed
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

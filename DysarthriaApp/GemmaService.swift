import Foundation
import Combine
import SwiftUI
import LiteRTLMSwift

class GemmaService: ObservableObject {
    @Published var isModelLoaded: Bool = false
    @AppStorage("use_ai_simulation") var useSimulation: Bool = false
    
    private var engine: LiteRTLMEngine?
    
    func loadModel() async throws {
        if useSimulation {
            await MainActor.run { isModelLoaded = true }
            return
        }
        
        guard let modelInfo = ModelManager.shared.selectedModel,
              let localURL = modelInfo.localURL else {
            throw NSError(domain: "GemmaService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected or downloaded"])
        }
        
        await MainActor.run { isModelLoaded = false }
        
        do {
            print("--- LiteRTLM Loading Debug ---")
            print("Model Path: \(localURL.path)")
            
            let engine = LiteRTLMEngine(modelPath: localURL, backend: "cpu")
            // LiteRTLM loading can be slow (5-10s)
            try await engine.load()
            
            await MainActor.run {
                self.engine = engine
                self.isModelLoaded = true
            }
            print("LiteRTLM Model Loaded Successfully")
            print("---------------------------")
        } catch {
            print("Failed to initialize LiteRTLM: \(error)")
            throw error
        }
    }
    
    func unloadModel() {
        engine = nil
        isModelLoaded = false
    }
    
    func expandAAC(shorthand: String, userName: String, contacts: String) async throws -> String {
        if useSimulation {
            // Mock AI behavior for simulator testing
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay
            return """
            1. Could you help me with \(shorthand)?
            2. Could you please bring me \(shorthand)?
            3. I would like to say \(shorthand).
            """
        }
        
        guard let engine = engine else {
            throw NSError(domain: "GemmaService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No engine initialized"])
        }
        
        // Optimized prompt for Gemma 2-2B (Gemma 4)
        let prompt = """
        <|turn>user
        # ROLE
        You are a Speech-to-Intent Interpreter for \(userName). You translate noisy, fragmented transcripts (from a user with dysarthria) into clear, polished communication.

        # CONTEXT
        - SPEAKER: \(userName)
        - KEY CONTACTS: \(contacts)
        - INPUT SOURCE: A Whisper model that often makes phonetic errors (e.g., "wada" for "water", "bus lay" for "bus is late").

        # TASK
        Decode the "Input" shorthand. Even if the words are misspelled or fragmented, infer the most likely communicative intent using the SPEAKER and CONTACTS provided.

        # CORE RULES
        1. PHONETIC DECODING: If a word looks wrong, think of what it SOUNDS like.
        2. EMOJI INTERPRETATION: Emojis are high-signal intent markers. Interpret them literally (e.g., "🏀" = basketball/playing, "🍕" = hungry/pizza). If an emoji is present, prioritize its meaning.
        3. BE THE VOICE: Write in the first person ("I", "Me", "My").
        4. NO META-TALK: Output ONLY the 3 sentences as a numbered list. No preamble.

        # OUTPUT STYLE (Provide 3 distinct options)
        1. DIRECT: Short, high-speed, urgent (e.g., "I need water.")
        2. NATURAL: A complete, polite sentence (e.g., "Could you please bring me some water?")
        3. MESSAGING: Optimized for SMS, using contact names if relevant (e.g., "Hey Dad, could you bring me some water?")

        # EXAMPLES
        - Input: "🏀" -> Output: 1. I want to play basketball. 2. Can we go play some basketball? 3. Is it time for basketball?
        - Input: "wada" -> Output: 1. I need water. 2. Could you please bring me some water? 3. Hey Dad, can I have some water?
        - Input: "🍕 mom" -> Output: 1. Mom, I'm hungry for pizza. 2. Mom, can we order pizza? 3. Hey Mom, let's have pizza for dinner.

        Input: "\(shorthand)"
        <turn|>
        <|turn>model
        """
        
        return try await engine.generate(
            prompt: prompt,
            temperature: 0.6,
            maxTokens: 512
        )
    }
}

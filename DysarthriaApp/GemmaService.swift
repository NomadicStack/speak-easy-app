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
        
        // Gemma 4 specific turn marker format
        let prompt = """
        <|turn>user
        # ROLE
        You are a Communication Interpreter for a user with dysarthria. Your task is to transform fragmented, noisy speech transcripts from a Whisper model into clear, polished messages.

        # INPUT CONTEXT
        CRITICAL: The shorthand text provided is the output of a custom Whisper model transcribing dysarthria speech. 
        Because of the user's speech condition, some transcribed words might be phonetically similar but incorrect (e.g., "water" transcribed as "waiter"). 
        Use the provided USER NAME and KEY CONTACTS context to infer the most likely intended meaning.

        # CORE RULES
        1. INTERPRET: Look for the intent in fragments and context. Fix likely transcription errors based on common sense.
        2. DO NOT HALLUCINATE: If a fragment is truly unintelligible, ask for clarification instead of guessing complex details.
        3. BE CONCISE: The user prefers high-speed, direct communication.
        4. NO CHAT: Do not say "Here is your message". Output ONLY the polished result.

        # CONTEXT (Inject at Runtime)
        - USER NAME: \(userName)
        - KEY CONTACTS: \(contacts)

        # OUTPUT STRUCTURE
        Provide exactly three different natural, fully formed sentences that the user might want to say based on the shorthand. Format as a numbered list.
        Do not include any labels like "CASUAL" or "CLEAR". Just the sentences.

        Input: "\(shorthand)"
        <turn|>
        <|turn>model
        """
        
        return try await engine.generate(
            prompt: prompt,
            temperature: 0.7,
            maxTokens: 1024
        )
    }
}

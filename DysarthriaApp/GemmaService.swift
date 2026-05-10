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
    
    func expandAAC(shorthand: String) async throws -> String {
        if useSimulation {
            // Mock AI behavior for simulator testing
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay
            return """
            1. I would like to say: \(shorthand).
            2. Can you help me with \(shorthand)?
            3. \(shorthand.capitalized) is what I am thinking about.
            """
        }
        
        guard let engine = engine else {
            throw NSError(domain: "GemmaService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No engine initialized"])
        }
        
        // Gemma 4 specific turn marker format
        let prompt = """
        <|turn>user
        You are an Augmentative and Alternative Communication (AAC) assistant.
        A user has inputted a shorthand phrase. Expand this shorthand into three
        different natural, fully formed sentences that the user might want to say aloud.
        
        Rules:
        - Provide exactly 3 options.
        - Format as a numbered list (1., 2., 3.).
        - Do not include any conversational filler.
        - Make the tone polite and conversational.

        Shorthand: \(shorthand)
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

import Foundation
import Combine
import SwiftUI
import LiteRTLM

class GemmaService: ObservableObject {
    @Published var isModelLoaded: Bool = false
    @AppStorage("use_ai_simulation") var useSimulation: Bool = false
    
    private var engine: Engine?
    
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
        
        print("--- LiteRT-LM Loading Debug ---")
        print("Model Path: \(localURL.path)")
        
        do {
            print("Attempting Metal GPU acceleration...")
            let config = try EngineConfig(
                modelPath: localURL.path,
                backend: .gpu,
                maxNumTokens: 1024,
                cacheDir: NSTemporaryDirectory()
            )
            let engine = Engine(engineConfig: config)
            try await engine.initialize()
            
            await MainActor.run {
                self.engine = engine
                self.isModelLoaded = true
            }
            print("LiteRT-LM Model Loaded Successfully on GPU")
            print("---------------------------")
        } catch {
            print("GPU backend initialization failed: \(error.localizedDescription). Retrying with CPU backend...")
            do {
                let config = try EngineConfig(
                    modelPath: localURL.path,
                    backend: .cpu(),
                    maxNumTokens: 1024,
                    cacheDir: NSTemporaryDirectory()
                )
                let engine = Engine(engineConfig: config)
                try await engine.initialize()
                
                await MainActor.run {
                    self.engine = engine
                    self.isModelLoaded = true
                }
                print("LiteRT-LM Model Loaded Successfully on CPU")
                print("---------------------------")
            } catch {
                print("Failed to initialize LiteRT-LM on CPU: \(error)")
                throw error
            }
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
        
        // Compact, high-accuracy prompt for Gemma 2-2B (Gemma 4)
        let prompt = """
        <|turn>user
        You are a Speech-to-Intent Interpreter for \(userName) (contacts: \(contacts)).
        Decode the shorthand input into exactly 3 full first-person sentences.

        Rules:
        1. Write in first person ("I", "Can we", "Please").
        2. Emojis have high priority: 🍕=pizza/hungry, 🏇=horse riding, 🚽=bathroom, 💧=water/thirsty.
        3. Phonetic matching: decode noisy words (e.g. "wada" -> "water").
        4. Contact names: ONLY include a name (Dad, Mom) if explicitly mentioned in the shorthand input. Never assume contact names.
        5. Output ONLY 3 numbered sentences. No preamble or labels.

        Examples:
        - 🏀 -> 1. I want to play basketball. 2. Can we go play basketball? 3. Is it time for basketball?
        - 🏇 -> 1. I want to go horse riding. 2. Can we go for a horse ride? 3. I'd love to ride horses today.
        - wada -> 1. I need water. 2. Could you please bring me water? 3. May I have a glass of water?
        - 🍕 hungry -> 1. I am hungry for pizza. 2. Can we order pizza? 3. Let's get pizza for dinner.
        - 👨‍🦱 dad 🚽 bathroom -> 1. Dad, I need the bathroom. 2. Dad, can you help me to the bathroom? 3. Dad, please assist me to the restroom.
        - 🍕 mom -> 1. Mom, I'm hungry for pizza. 2. Mom, can we order pizza? 3. Hey Mom, let's have pizza tonight.

        Input: "\(shorthand)"
        <turn|>
        <|turn>model
        """
        
        let samplerConfig = try? SamplerConfig(topK: 40, topP: 0.95, temperature: 0.6)
        let convConfig = ConversationConfig(samplerConfig: samplerConfig)
        let conversation = try await engine.createConversation(with: convConfig)
        let response = try await conversation.sendMessage(Message(prompt))
        return response.toString
    }
}

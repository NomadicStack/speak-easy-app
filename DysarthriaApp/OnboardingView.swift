import SwiftUI

struct OnboardingView: View {
    @AppStorage("has_completed_onboarding") var hasCompletedOnboarding: Bool = false
    @State private var showModelSelection = false
    @ObservedObject var modelManager = ModelManager.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon / Logo
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 150, height: 150)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 15) {
                Text("Smart Speak")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("To enable AI-powered variations and expansion, we need to download an on-device brain (Gemma 4).")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            if let selectedModel = modelManager.selectedModel, selectedModel.localURL != nil {
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Brain Ready: \(selectedModel.name)")
                            .font(.headline)
                    }
                    
                    Button(action: {
                        hasCompletedOnboarding = true
                    }) {
                        Text("Enable Smart Speak")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                }
            } else {
                Button(action: {
                    showModelSelection = true
                }) {
                    Text("Select & Download AI Brain")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
            }
            
            Text("The model is 2.6GB. You can still use basic transcription while it downloads.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)
        }
        .sheet(isPresented: $showModelSelection) {
            NavigationView {
                ModelSelectionView()
            }
        }
    }
}

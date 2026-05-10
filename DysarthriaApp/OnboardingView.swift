import SwiftUI

struct OnboardingView: View {
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
                Text("Welcome to SpeakEasy")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("To enable Smart Speak variations and AI messaging, we need to download an on-device brain.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            if let selectedModel = modelManager.selectedModel {
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Ready: \(selectedModel.name)")
                            .font(.headline)
                    }
                    
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
                    }) {
                        Text("Get Started")
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
                    Text("Choose an AI Model")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
            }
            
            Text("Models are large (1GB+) and will download in the background.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
        }
        .sheet(isPresented: $showModelSelection) {
            NavigationView {
                ModelSelectionView()
            }
        }
    }
}

import SwiftUI

struct OnboardingView: View {
    @AppStorage("has_completed_onboarding") var hasCompletedOnboarding: Bool = false
    @State private var showModelSelection = false
    @ObservedObject var modelManager = ModelManager.shared
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: isPad ? 60 : 30) {
            Spacer()
            
            // App Icon / Logo
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: isPad ? 250 : 150, height: isPad ? 250 : 150)
                
                Image(systemName: "sparkles")
                    .font(.system(size: isPad ? 150 : 80))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 20) {
                Text("Smart Speak")
                    .font(isPad ? .system(size: 60, weight: .bold) : .largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("To enable AI-powered variations and expansion, we need to download an on-device brain (Gemma 4).")
                    .font(isPad ? .title : .title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isPad ? 80 : 40)
            }
            
            Spacer()
            
            if let selectedModel = modelManager.selectedModel, selectedModel.localURL != nil {
                VStack(spacing: 25) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(isPad ? .title : .headline)
                        Text("Brain Ready: \(selectedModel.name)")
                            .font(isPad ? .title : .headline)
                    }
                    
                    Button(action: {
                        hasCompletedOnboarding = true
                    }) {
                        Text("Enable Smart Speak")
                            .font(isPad ? .title2.bold() : .headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(isPad ? 30 : 16)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                    .padding(.horizontal, isPad ? 100 : 40)
                }
            } else {
                Button(action: {
                    showModelSelection = true
                }) {
                    Text("Select & Download AI Brain")
                        .font(isPad ? .title2.bold() : .headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(isPad ? 30 : 16)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                .padding(.horizontal, isPad ? 100 : 40)
            }
            
            Text("The model is 2.6GB. You can still use basic transcription while it downloads.")
                .font(isPad ? .title3 : .caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
                .padding(.bottom, isPad ? 60 : 40)
        }
        .sheet(isPresented: $showModelSelection) {
            NavigationView {
                ModelSelectionView()
            }
        }
    }
}

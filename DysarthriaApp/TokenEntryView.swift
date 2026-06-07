import SwiftUI

/// SwiftUI View that prompts users to input their access token, coordinates downloading,
/// and showcases progress through clean, accessible UI stages.
public struct TokenEntryView: View {
    @ObservedObject var tokenService = TokenService.shared
    @State private var tokenInput: String = ""
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: isPad ? 35 : 20) {
            Spacer()
            
            // Premium Branding Header
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: isPad ? 140 : 90, height: isPad ? 140 : 90)
                
                Image(systemName: "key.fill")
                    .font(.system(size: isPad ? 60 : 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Unlock Custom Voice Model")
                    .font(isPad ? .largeTitle.bold() : .title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text("SpeakEasy uses a custom Whisper speech-to-text model fine-tuned specifically for your speech patterns. Enter your paid access token below to retrieve and setup your personalized profile.")
                    .font(isPad ? .title3 : .subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isPad ? 40 : 15)
                    .lineSpacing(isPad ? 6 : 3)
            }
            
            Spacer().frame(height: 10)
            
            // Access control state switch
            VStack {
                switch tokenService.status {
                case .none, .error:
                    tokenInputView
                case .validating:
                    statusCardView(
                        title: "Verifying Access Token...",
                        message: "Connecting to secure repository and validating your key...",
                        isProgress: true
                    )
                case .downloading(let progress):
                    downloadingCardView(progress: progress)
                case .unzipping:
                    statusCardView(
                        title: "Extracting Speech Model...",
                        message: "Configuring files and checking model signatures. Please do not close the app.",
                        isProgress: true
                    )
                case .active(let modelName):
                    successCardView(modelName: modelName)
                }
            }
            .animation(.easeInOut, value: tokenService.status)
            
            Spacer()
            
            Text("Tokens are provided by email upon subscription setup. Model files work 100% offline once downloaded.")
                .font(.system(size: isPad ? 16 : 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding(isPad ? 40 : 20)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Input State View
    private var tokenInputView: View {
        VStack(spacing: 20) {
            // Error Display if applicable
            if case .error(let errorMessage) = tokenService.status {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(isPad ? .title3 : .body)
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(isPad ? .body : .subheadline)
                        .bold()
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, isPad ? 40 : 10)
            }
            
            // Input Fields Card
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.secondary)
                        .font(isPad ? .title3 : .body)
                    
                    SecureField("Enter Paid Token (e.g. tkn_live_...)", text: $tokenInput)
                        .font(isPad ? .title3 : .body)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(isPad ? 20 : 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                Button(action: {
                    tokenService.activateToken(tokenInput)
                }) {
                    HStack {
                        Text("Activate & Download Model")
                            .font(isPad ? .title3.bold() : .headline)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(isPad ? .title3 : .headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(isPad ? 20 : 14)
                    .background(tokenInput.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(tokenInput.isEmpty ? 0 : 0.2), radius: 6, x: 0, y: 3)
                }
                .disabled(tokenInput.isEmpty)
            }
            .padding(.horizontal, isPad ? 40 : 10)
        }
    }
    
    // MARK: - Validation & Unzipping Views
    private func statusCardView(title: String, message: String, isProgress: Bool) -> View {
        VStack(spacing: 20) {
            if isProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(isPad ? 2.0 : 1.3)
                    .padding()
            }
            
            Text(title)
                .font(isPad ? .title3.bold() : .headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(isPad ? .body : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(isPad ? 40 : 25)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, isPad ? 40 : 10)
    }
    
    // MARK: - Downloading View
    private func downloadingCardView(progress: Double) -> View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: isPad ? 3 : 2, anchor: .center)
                .cornerRadius(4)
                .padding(.horizontal)
            
            HStack {
                Text("Downloading Model Archive...")
                    .font(isPad ? .body.bold() : .subheadline.bold())
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(isPad ? .body.bold() : .subheadline.bold())
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            Text("Please keep SpeakEasy open and connected to Wi-Fi.")
                .font(isPad ? .body : .caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                tokenService.cancelDownload()
            }) {
                Label("Cancel Download", systemImage: "xmark.circle")
                    .font(isPad ? .body.bold() : .subheadline.bold())
                    .foregroundColor(.red)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .padding(isPad ? 40 : 25)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, isPad ? 40 : 10)
    }
    
    // MARK: - Success Card View
    private func successCardView(modelName: String) -> View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: isPad ? 90 : 60, height: isPad ? 90 : 60)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: isPad ? 50 : 35))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 6) {
                Text("Profile Successfully Activated!")
                    .font(isPad ? .title2.bold() : .headline.bold())
                    .foregroundColor(.primary)
                Text("Your fine-tuned model is configured.")
                    .font(isPad ? .body : .subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 15) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.blue)
                    .font(isPad ? .title1 : .title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelName)
                        .font(isPad ? .headline.bold() : .subheadline.bold())
                    Text("Ready for Speech Transcription")
                        .font(isPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Active")
                    .font(.system(size: isPad ? 14 : 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
            .padding()
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: {
                tokenService.resetToken()
            }) {
                Label("Deactivate and Delete Model Data", systemImage: "trash.fill")
                    .font(isPad ? .body.bold() : .subheadline.bold())
                    .foregroundColor(.red)
            }
            .padding(.top, 10)
        }
        .padding(isPad ? 40 : 25)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, isPad ? 40 : 10)
    }
}

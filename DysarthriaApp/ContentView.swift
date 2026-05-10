import SwiftUI
import MessageUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionVM = TranscriptionViewModel()
    @StateObject private var aacVM = AACViewModel()
    @State private var selectedTab = 0
    @AppStorage("has_completed_onboarding") var hasCompletedOnboarding: Bool = false
    
    // Detect device size class for responsive design
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Consider it an iPad if both size classes are regular (standard iPad layout)
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TranscriptionView(audioRecorder: audioRecorder, transcriptionVM: transcriptionVM, isPad: isPad)
                .tabItem {
                    Label("Transcribe", systemImage: "waveform")
                }
                .tag(0)
            
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView()
                } else {
                    AACExpanderView(viewModel: aacVM, transcriptionVM: transcriptionVM, audioRecorder: audioRecorder)
                }
            }
            .tabItem {
                Label("Smart Speak", systemImage: "sparkles")
            }
            .tag(1)
        }
        .onReceive(transcriptionVM.$isTranscribing) { isTranscribing in
                // If transcription just finished and we're on the expander tab, trigger expansion
                if !isTranscribing && selectedTab == 1 {
                    let newText = transcriptionVM.transcribedText
                    let cleanText = newText.replacingOccurrences(of: "Press record to start.", with: "")
                        .replacingOccurrences(of: "[No transcription returned]", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanText.isEmpty {
                        // Update shorthand and trigger expansion
                        if aacVM.shorthandInput.isEmpty {
                            aacVM.shorthandInput = cleanText
                        } else {
                            // We clear transcriptionVM before recording in Smart Speak tab,
                            // so cleanText only contains the latest spoken words.
                            // We just check if it's already there to be safe.
                            let currentShorthand = aacVM.shorthandInput.lowercased()
                            if !currentShorthand.contains(cleanText.lowercased()) {
                                aacVM.shorthandInput += " " + cleanText
                            }
                        }
                        
                        Task {
                            await aacVM.expand()
                        }
                    }
                }
            }
        }
    }

struct TranscriptionView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var transcriptionVM: TranscriptionViewModel
    var isPad: Bool
    
    @State private var isShowingMailView = false
    @State private var isShowingModelSelection = false

    var body: some View {
        VStack(spacing: isPad ? 40 : 30) {
            Text("SpeakEasy")
                .font(isPad ? .system(size: 50, weight: .bold) : .largeTitle.bold())
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding(.top, isPad ? 60 : 40)
            
            if !transcriptionVM.isModelLoaded {
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(isPad ? 1.5 : 1.0)
                    Text(transcriptionVM.modelLoadingMessage)
                        .font(isPad ? .title3 : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                DisclosureGroup("Advanced & Stats") {
                    VStack(alignment: .leading, spacing: 15) {
                        // Stats Section
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Usage Statistics")
                                .font(.headline)
                            HStack {
                                Text("Total Transcriptions: \(transcriptionVM.totalTranscriptions)")
                                Spacer()
                                Text("Corrections: \(transcriptionVM.totalCorrections)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Context Section
                        VStack(alignment: .leading, spacing: 5) {
                            Text("AI Hint (Context)")
                                .font(.headline)
                            Text("This helps the AI understand slurred speech better.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Context (e.g. key words)", text: $transcriptionVM.initialPrompt)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(isPad ? .title3 : .body)
                        }
                        
                        Divider()
                        
                        // Report Section
                        if transcriptionVM.totalCorrections > 0 {
                            Button(action: {
                                if MFMailComposeViewController.canSendMail() {
                                    isShowingMailView = true
                                } else {
                                    // Fallback to share sheet if mail is not configured
                                    let report = transcriptionVM.prepareFeedbackReport()
                                    let audioURLs = transcriptionVM.getFeedbackAudioURLs()
                                    var items: [Any] = [report]
                                    items.append(contentsOf: audioURLs)
                                    
                                    let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
                                    
                                    // Fix for iPad crash: Set popover source
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootVC = windowScene.windows.first?.rootViewController {
                                        
                                        if let popover = av.popoverPresentationController {
                                            popover.sourceView = rootVC.view
                                            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                                            popover.permittedArrowDirections = []
                                        }
                                        
                                        rootVC.present(av, animated: true)
                                    }
                                }
                            }) {
                                Label("Send Feedback Report", systemImage: "envelope.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .sheet(isPresented: $isShowingMailView) {
                                MailView(
                                    recipient: "developer@example.com", // Replace with your actual email
                                    subject: "SpeakEasy Feedback Report",
                                    body: transcriptionVM.prepareFeedbackReport(),
                                    attachments: transcriptionVM.getFeedbackAudioURLs()
                                ) { result in
                                    print("Mail result: \(result)")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    }
                    .padding(.horizontal, isPad ? 60 : 20)
                    .font(.subheadline)
                    .accentColor(.secondary)
                    }

                    if transcriptionVM.isModelLoaded {
                    HStack {
                    if !transcriptionVM.isEditing && transcriptionVM.transcribedText != "Press record to start." && !transcriptionVM.isTranscribing {
                        Button(action: {
                            transcriptionVM.isEditing = true
                        }) {
                            Label("Incorrect?", systemImage: "pencil.and.outline")
                                .foregroundColor(.orange)
                        }
                    } else {
                        // Placeholder to maintain centering when Incorrect button is hidden
                        Color.clear.frame(width: 80, height: 1)
                    }

                    Spacer()

                    // Model Ready Badge in the middle
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Model Ready")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green))

                    Spacer()

                    HStack(spacing: isPad ? 30 : 20) {
                        Button(action: {
                            UIPasteboard.general.string = transcriptionVM.transcribedText
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)

                        ShareLink(item: transcriptionVM.transcribedText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)
                    }
                    }
                    .padding(.horizontal, isPad ? 60 : 20)
                    }            
            ScrollView {
                if transcriptionVM.isEditing {
                    VStack(alignment: .trailing) {
                        TextEditor(text: $transcriptionVM.transcribedText)
                            .font(isPad ? .system(size: 34, weight: .bold) : .system(size: 24, weight: .bold))
                            .frame(minHeight: 200)
                            .padding(isPad ? 30 : 20)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Save Correction") {
                                        transcriptionVM.saveCorrection()
                                    }
                                    .bold()
                                    .foregroundColor(.blue)
                                }
                            }
                        
                        Button(action: {
                            transcriptionVM.saveCorrection()
                        }) {
                            Text("Save Correction")
                                .bold()
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding([.bottom, .trailing])
                    }
                } else {
                    Text(transcriptionVM.transcribedText)
                        .font(isPad ? .system(size: 54, weight: .bold) : .system(size: 34, weight: .bold))
                        .padding(isPad ? 30 : 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, isPad ? 60 : 20)
            .frame(maxWidth: 900)
            
            if transcriptionVM.isTranscribing {
                HStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(isPad ? 1.2 : 1.0)
                    Text("Transcribing...")
                        .font(isPad ? .title3 : .body)
                        .foregroundColor(.secondary)
                }
            } else {
                // Placeholder to keep UI from jumping when progress disappears
                Text(" ").font(isPad ? .title3 : .body).hidden()
            }
            
            Spacer()
            
            // Record and Clear Buttons
            HStack(spacing: isPad ? 60 : 40) {
                // Clear Button
                Button(action: {
                    transcriptionVM.clearTranscription()
                }) {
                    ZStack {
                        let buttonSize: CGFloat = isPad ? 100 : 70
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: isPad ? 5 : 3)
                        
                        Image(systemName: "trash")
                            .font(.system(size: buttonSize * 0.4, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)
                .opacity((transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing) ? 0.3 : 1.0)
                
                // Record Button
                Button(action: {
                    if audioRecorder.isRecording {
                        if let url = audioRecorder.stopRecording() {
                            transcriptionVM.transcribeAudio(at: url)
                        }
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    ZStack {
                        // Larger button size on iPads
                        let buttonSize: CGFloat = isPad ? 140 : 100
                        
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: isPad ? 10 : 7)
                        
                        if audioRecorder.isRecording {
                            // Stop square
                            RoundedRectangle(cornerRadius: isPad ? 10 : 6)
                                .fill(Color.white)
                                .frame(width: buttonSize * 0.35, height: buttonSize * 0.35)
                        } else {
                            // Microphone icon
                            Image(systemName: "mic.fill")
                                .font(.system(size: buttonSize * 0.4, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!transcriptionVM.isModelLoaded || transcriptionVM.isTranscribing)
                .opacity((!transcriptionVM.isModelLoaded || transcriptionVM.isTranscribing) ? 0.5 : 1.0)
            }
            .padding(.bottom, isPad ? 80 : 50)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

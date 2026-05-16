import SwiftUI
import MessageUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionVM = TranscriptionViewModel()
    @StateObject private var aacVM = AACViewModel()
    @State private var selectedTab = 0
    @AppStorage("has_completed_onboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("use_ai_simulation") var useSimulation: Bool = false
    @AppStorage("feedback_recipient") var feedbackRecipient: String = "developer@example.com"
    @AppStorage("user_email") var userEmail: String = ""

    
    init() {
        // Make tab bar text larger for accessibility
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        let font = UIFont.systemFont(ofSize: 18, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = attributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = attributes
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Detect device size class for responsive design
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Consider it an iPad if both size classes are regular (standard iPad layout)
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let useRail = isPad && isLandscape
            
            if useRail {
                HStack(spacing: 0) {
                    // Vertical Navigation Rail for iPad Landscape
                    VStack(spacing: 40) {
                        Spacer()
                            .frame(height: 40)
                        
                        Text("SpeakEasy")
                            .font(.title.bold())
                            .foregroundColor(.blue)
                            .padding(.bottom, 40)
                        
                        // Transcribe Tab
                        Button(action: { selectedTab = 0 }) {
                            VStack(spacing: 12) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 44, weight: .bold))
                                Text("Transcribe")
                                    .font(.system(size: 24, weight: .bold))
                            }
                            .frame(width: 160)
                            .padding(.vertical, 30)
                            .background(selectedTab == 0 ? Color.blue.opacity(0.1) : Color.clear)
                            .foregroundColor(selectedTab == 0 ? .blue : .secondary)
                            .cornerRadius(20)
                        }
                        
                        // Smart Speak Tab
                        Button(action: { selectedTab = 1 }) {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 44, weight: .bold))
                                Text("Smart Speak")
                                    .font(.system(size: 24, weight: .bold))
                            }
                            .frame(width: 160)
                            .padding(.vertical, 30)
                            .background(selectedTab == 1 ? Color.purple.opacity(0.1) : Color.clear)
                            .foregroundColor(selectedTab == 1 ? .purple : .secondary)
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                    }
                    .frame(width: 200)
                    .background(.ultraThinMaterial)
                    
                    Divider()
                    
                    // Main Content Area
                    Group {
                        if selectedTab == 0 {
                            TranscriptionView(audioRecorder: audioRecorder, transcriptionVM: transcriptionVM, isPad: isPad, isLandscape: isLandscape)
                        } else {
                            Group {
                                if !hasCompletedOnboarding && !useSimulation {
                                    OnboardingView()
                                } else {
                                    AACExpanderView(viewModel: aacVM, transcriptionVM: transcriptionVM, audioRecorder: audioRecorder, isLandscape: isLandscape)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .leading)
            } else {
                // Standard Portrait / iPhone Layout
                ZStack(alignment: .bottom) {
                    // Main Content Area
                    Group {
                        if selectedTab == 0 {
                            TranscriptionView(audioRecorder: audioRecorder, transcriptionVM: transcriptionVM, isPad: isPad, isLandscape: isLandscape)
                        } else {
                            Group {
                                if !hasCompletedOnboarding && !useSimulation {
                                    OnboardingView()
                                } else {
                                    AACExpanderView(viewModel: aacVM, transcriptionVM: transcriptionVM, audioRecorder: audioRecorder, isLandscape: isLandscape)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, isPad ? 140 : 100) // Increased space for larger tab bar
                    
                    // Custom Large Tab Bar
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            // Transcribe Tab
                            Button(action: { selectedTab = 0 }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: isPad ? 44 : 28, weight: .bold))
                                    Text("Transcribe")
                                        .font(.system(size: isPad ? 28 : 20, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isPad ? 30 : 20)
                                .background(selectedTab == 0 ? Color.blue.opacity(0.1) : Color.clear)
                                .foregroundColor(selectedTab == 0 ? .blue : .secondary)
                            }
                            
                            // Smart Speak Tab
                            Button(action: { selectedTab = 1 }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: isPad ? 44 : 28, weight: .bold))
                                    Text("Smart Speak")
                                        .font(.system(size: isPad ? 28 : 20, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isPad ? 30 : 20)
                                .background(selectedTab == 1 ? Color.purple.opacity(0.1) : Color.clear)
                                .foregroundColor(selectedTab == 1 ? .purple : .secondary)
                            }
                        }
                        .background(.ultraThinMaterial)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
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
    var isLandscape: Bool = false
    
    @State private var isShowingMailView = false
    @State private var isShowingModelSelection = false
    
    @AppStorage("feedback_recipient") var feedbackRecipient: String = "developer@example.com"
    @AppStorage("user_email") var userEmail: String = ""

    var body: some View {
        VStack(spacing: isPad ? (isLandscape ? 20 : 50) : 30) {
            // Header with Branding (Hide in Rail mode to avoid duplication)
            if !isLandscape || !isPad {
                HStack {
                    Text("SpeakEasy")
                        .font(isPad ? .largeTitle.bold() : .title2.bold())
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, isPad ? 20 : 10)
            }
            
            if !transcriptionVM.isModelLoaded {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(isPad ? 2.0 : 1.2)
                    Text(transcriptionVM.modelLoadingMessage)
                        .font(isPad ? .title : .headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                DisclosureGroup("Advanced & Stats") {
                    VStack(alignment: .leading, spacing: 20) {
                        // Stats Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Usage Statistics")
                                .font(.title3.bold())
                            HStack {
                                Text("Total Transcriptions: \(transcriptionVM.totalTranscriptions)")
                                Spacer()
                                Text("Corrections: \(transcriptionVM.totalCorrections)")
                            }
                            .font(.headline)
                            .foregroundColor(.secondary)
                        }
                        
                        Divider()

                        // Feedback Settings
                        DisclosureGroup("Feedback Configuration") {
                            VStack(alignment: .leading, spacing: 15) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recipient Email")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    TextField("developer@example.com", text: $feedbackRecipient)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.title3)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Email (for follow-up)")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    TextField("your@email.com", text: $userEmail)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.title3)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .font(.headline)

                        Divider()

                        // Report Section
                        if transcriptionVM.totalCorrections > 0 {
                            Button(action: {
                                if MFMailComposeViewController.canSendMail() {
                                    isShowingMailView = true
                                } else {
                                    // Fallback to share sheet if mail is not configured
                                    let report = transcriptionVM.prepareFeedbackReport(userEmail: userEmail)
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
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(15)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .sheet(isPresented: $isShowingMailView) {
                                MailView(
                                    recipient: feedbackRecipient,
                                    subject: "SpeakEasy Feedback Report",
                                    body: transcriptionVM.prepareFeedbackReport(userEmail: userEmail),
                                    attachments: transcriptionVM.getFeedbackAudioURLs(),
                                    preferredSenderEmail: userEmail
                                ) { result in
                                    if case .success(let mailResult) = result, mailResult == .sent {
                                        transcriptionVM.clearFeedbackData()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 15)
                }
                .padding(.horizontal, isPad ? (isLandscape ? 40 : 80) : 20)
                .font(.title3)
                .accentColor(.secondary)
            }

            if transcriptionVM.isModelLoaded {
                HStack {
                    if !transcriptionVM.isEditing && transcriptionVM.transcribedText != "Press record to start." && !transcriptionVM.isTranscribing {
                        Button(action: {
                            transcriptionVM.isEditing = true
                        }) {
                            Label("Incorrect?", systemImage: "pencil.and.outline")
                                .font(isPad ? .title3.bold() : .headline)
                                .foregroundColor(.orange)
                        }
                    } else {
                        // Placeholder to maintain centering when Incorrect button is hidden
                        Color.clear.frame(width: 80, height: 1)
                    }

                    Spacer()

                    // Model Ready Badge in the middle
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(isPad ? .title3 : .caption)
                        Text("Model Ready")
                            .font(isPad ? .title3.bold() : .caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.green))

                    Spacer()

                    HStack(spacing: isPad ? 40 : 20) {
                        Button(action: {
                            UIPasteboard.general.string = transcriptionVM.transcribedText
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(isPad ? .title3.bold() : .headline)
                        }
                        .disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)

                        ShareLink(item: transcriptionVM.transcribedText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(isPad ? .title3.bold() : .headline)
                        }
                        .disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)
                    }
                }
                .padding(.horizontal, isPad ? (isLandscape ? 40 : 80) : 20)
            }            
            
            ScrollView {
                if transcriptionVM.isEditing {
                    VStack(alignment: .trailing) {
                        TextEditor(text: $transcriptionVM.transcribedText)
                            .font(.system(size: isPad ? 48 : 28, weight: .bold))
                            .frame(minHeight: isLandscape ? 150 : 300)
                            .padding(isPad ? 40 : 20)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Save Correction") {
                                        transcriptionVM.saveCorrection()
                                    }
                                    .font(.headline.bold())
                                    .foregroundColor(.blue)
                                }
                            }
                        
                        Button(action: {
                            transcriptionVM.saveCorrection()
                        }) {
                            Text("Save Correction")
                                .font(.title3.bold())
                                .padding(20)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .padding([.bottom, .trailing], 20)
                    }
                } else {
                    Text(transcriptionVM.transcribedText)
                        .font(.system(size: isPad ? (isLandscape ? 64 : 72) : 40, weight: .bold))
                        .padding(isPad ? 40 : 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(24)
            .padding(.horizontal, isPad ? (isLandscape ? 40 : 80) : 20)
            .frame(maxWidth: 1000)
            
            if transcriptionVM.isTranscribing {
                HStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(isPad ? 1.5 : 1.2)
                    Text("Transcribing...")
                        .font(isPad ? .title2 : .headline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Placeholder to keep UI from jumping when progress disappears
                Text(" ").font(isPad ? .title2 : .headline).hidden()
            }
            
            if !isLandscape || !isPad {
                Spacer()
            }
            
            // Record and Clear Buttons
            HStack(spacing: isPad ? 80 : 40) {
                // Clear Button
                Button(action: {
                    transcriptionVM.clearTranscription()
                }) {
                    ZStack {
                        let buttonSize: CGFloat = isPad ? 120 : 80
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: isPad ? 8 : 4)
                        
                        Image(systemName: "trash")
                            .font(.system(size: buttonSize * 0.45, weight: .bold))
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
                        let buttonSize: CGFloat = isPad ? 180 : 110
                        
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: isPad ? 15 : 10)
                        
                        if audioRecorder.isRecording {
                            // Stop square
                            RoundedRectangle(cornerRadius: isPad ? 12 : 8)
                                .fill(Color.white)
                                .frame(width: buttonSize * 0.35, height: buttonSize * 0.35)
                        } else {
                            // Microphone icon
                            Image(systemName: "mic.fill")
                                .font(.system(size: buttonSize * 0.45, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!transcriptionVM.isModelLoaded || transcriptionVM.isTranscribing)
                .opacity((!transcriptionVM.isModelLoaded || transcriptionVM.isTranscribing) ? 0.5 : 1.0)
            }
            .padding(.bottom, isPad ? (isLandscape ? 40 : 100) : 60)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

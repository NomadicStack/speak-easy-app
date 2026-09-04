import SwiftUI
import MessageUI
import AVFoundation

public struct VoiceStudioView: View {
    @ObservedObject var sessionManager = TrainingSessionManager.shared
    @ObservedObject var deckProvider = PromptDeckProvider.shared
    @ObservedObject var customStore = CustomDeckStore.shared
    
    @AppStorage("feedback_recipient") var feedbackRecipient: String = "developer@example.com"
    @AppStorage("caregiver_cc_email") var caregiverCCEmail: String = ""
    @AppStorage("user_name") var userName: String = "User"
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var isShowingMailView = false
    @State private var isShowingShareSheet = false
    @State private var isShowingCustomDeckEditor = false
    @State private var isShowingResetConfirmation = false
    @State private var selectedDeckForDetail: PromptDeck? = nil
    @State private var preparedZipURL: URL? = nil
    @State private var mailSubject = ""
    @State private var mailBody = ""
    
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Group {
                if sessionManager.isSessionCompleted {
                    sessionCompletedView
                } else if sessionManager.activeDeck != nil {
                    activeRecordingStudioView
                } else {
                    deckSelectionHomeView
                }
            }
            .navigationBarHidden(sessionManager.activeDeck != nil)
            .sheet(isPresented: $isShowingMailView) {
                if let zipURL = preparedZipURL {
                    MailView(
                        recipient: feedbackRecipient,
                        ccRecipients: caregiverCCEmail.isEmpty ? nil : [caregiverCCEmail],
                        subject: mailSubject,
                        body: mailBody,
                        attachments: [zipURL],
                        preferredSenderEmail: nil
                    ) { result in
                        if case .success(let mailResult) = result, mailResult == .sent {
                            if zipURL.lastPathComponent.contains("Corrections") {
                                sessionManager.clearLiveCorrections()
                            } else {
                                if let deckId = sessionManager.activeDeck?.id {
                                    customStore.lockDeck(id: deckId)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingCustomDeckEditor) {
                CustomDeckEditorView(customStore: customStore, isPad: isPad)
            }
            .sheet(item: $selectedDeckForDetail) { deck in
                NavigationView {
                    DeckPhrasesDetailView(deckId: deck.id, customStore: customStore, isPad: isPad)
                }
                .navigationViewStyle(.stack)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - View 1: Deck Selection Home
    private var deckSelectionHomeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isPad ? 35 : 20) {
                // Header Banner
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Voice Studio")
                            .font(.system(size: isPad ? 44 : 30, weight: .bold))
                            .foregroundColor(.blue)
                        Spacer()
                        
                        // Custom decks management
                        Button(action: { isShowingCustomDeckEditor = true }) {
                            Label("Manage Decks", systemImage: "folder.badge.plus")
                                .font(isPad ? .title3.bold() : .subheadline.bold())
                                .foregroundColor(.blue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    
                    Text("Train your personalized speech recognition model in focused sessions. Select an example deck or create your own custom group.")
                        .font(isPad ? .title3 : .subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal, isPad ? 40 : 20)
                .padding(.top, isPad ? 30 : 15)
                
                // Pending Live Corrections Section (if any exist)
                if !sessionManager.pendingLiveCorrections.isEmpty {
                    liveCorrectionsCard
                        .padding(.horizontal, isPad ? 40 : 20)
                }
                
                // Decks List
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Select a Training Deck")
                            .font(isPad ? .title2.bold() : .headline.bold())
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: { isShowingCustomDeckEditor = true }) {
                            Label("New Deck", systemImage: "plus.circle.fill")
                                .font(isPad ? .headline.bold() : .subheadline.bold())
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, isPad ? 40 : 20)
                    
                    LazyVStack(spacing: isPad ? 20 : 15) {
                        ForEach(deckProvider.allDecks) { deck in
                            DeckCardRow(
                                deck: deck,
                                recordedCount: sessionManager.recordedSampleCount(for: deck.id),
                                isPad: isPad,
                                onStart: {
                                    sessionManager.startSession(with: deck)
                                },
                                onManage: deck.isCustom ? {
                                    selectedDeckForDetail = deck
                                } : nil
                            )
                        }
                    }
                    .padding(.horizontal, isPad ? 40 : 20)
                }
                
                Spacer().frame(height: isPad ? 100 : 60)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Live Corrections Card
    private var liveCorrectionsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(isPad ? .title : .title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pending Conversation Corrections")
                        .font(isPad ? .title3.bold() : .headline)
                    Text("\(sessionManager.pendingLiveCorrections.count) corrections ready to send")
                        .font(isPad ? .headline : .subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            HStack(spacing: 15) {
                Button(action: {
                    sendLiveCorrections()
                }) {
                    Label("Send Corrections Archive", systemImage: "envelope.fill")
                        .font(isPad ? .title3.bold() : .headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isPad ? 16 : 12)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    sessionManager.clearLiveCorrections()
                }) {
                    Image(systemName: "trash")
                        .font(isPad ? .title3 : .headline)
                        .foregroundColor(.red)
                        .padding(isPad ? 16 : 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(isPad ? 25 : 18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - View 2: Active Recording Studio
    private var activeRecordingStudioView: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            HStack {
                Button(action: {
                    sessionManager.exitSession()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Exit Session")
                    }
                    .font(isPad ? .title3.bold() : .headline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let deck = sessionManager.activeDeck {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(deck.title)
                            .font(isPad ? .headline : .subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                sessionManager.previousCard()
                            }) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(isPad ? .title2 : .title3)
                                    .foregroundColor(sessionManager.currentCardIndex > 0 ? .blue : Color.gray.opacity(0.3))
                            }
                            .disabled(sessionManager.currentCardIndex == 0)
                            
                            Text("Phrase \(sessionManager.currentCardIndex + 1) of \(deck.cards.count)")
                                .font(isPad ? .title3.bold() : .headline.bold())
                                .foregroundColor(.blue)
                            
                            Button(action: {
                                sessionManager.nextCard()
                            }) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(isPad ? .title2 : .title3)
                                    .foregroundColor(sessionManager.currentCardIndex + 1 < deck.cards.count ? .blue : Color.gray.opacity(0.3))
                            }
                            .disabled(sessionManager.currentCardIndex + 1 >= deck.cards.count)
                        }
                    }
                }
            }
            .padding(.horizontal, isPad ? 40 : 20)
            .padding(.top, isPad ? 20 : 15)
            .padding(.bottom, 10)
            
            // Progress Bar
            ProgressView(value: sessionManager.sessionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: isPad ? 3 : 2, anchor: .center)
                .padding(.horizontal, isPad ? 40 : 20)
                .padding(.bottom, isPad ? 15 : 10)
            
            // Fatigue Checkpoint / Break Reminder at Halfway Mark
            if let deck = sessionManager.activeDeck, deck.cards.count >= 4, sessionManager.currentCardIndex == deck.cards.count / 2 {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.orange)
                    Text("Halfway there! Take a breath or pause if you feel tired.")
                        .font(isPad ? .headline : .caption.bold())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
                .padding(.bottom, 12)
            }
            
            // Main Prompt Card
            if let card = sessionManager.currentCard {
                VStack(spacing: isPad ? 30 : 20) {
                    Spacer()
                    
                    // Card Text
                    Text(card.text)
                        .font(.system(size: isPad ? 44 : 30, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, isPad ? 40 : 20)
                        .lineSpacing(isPad ? 8 : 4)
                        .minimumScaleFactor(0.7)
                    
                    // Action Buttons (TTS Preview & Recorded Badge)
                    HStack(spacing: 12) {
                        Button(action: {
                            sessionManager.speakCurrentPrompt()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: sessionManager.isSpeakingPrompt ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(isPad ? .title2 : .headline)
                                Text(sessionManager.isSpeakingPrompt ? "Playing Example..." : "Listen to Prompt")
                                    .font(isPad ? .title3.bold() : .headline)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, isPad ? 22 : 16)
                            .padding(.vertical, isPad ? 12 : 10)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(25)
                        }
                        
                        if sessionManager.isCurrentCardRecorded {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Recorded")
                                    .font(isPad ? .title3.bold() : .subheadline.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, isPad ? 18 : 12)
                            .padding(.vertical, isPad ? 12 : 10)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(25)
                        }
                    }
                    
                    Spacer()
                    
                    // Live Waveform / Audio Level Bar
                    WaveformLevelBar(level: sessionManager.audioMeterLevel, isRecording: sessionManager.isRecording, isPad: isPad)
                    
                    if sessionManager.isRecording {
                        Text(String(format: "Recording... %.1fs", sessionManager.currentRecordingDuration))
                            .font(isPad ? .title3.bold() : .subheadline.bold())
                            .foregroundColor(.red)
                    } else if sessionManager.hasRecordedCurrentCard {
                        Text("Recorded (\(String(format: "%.1fs", sessionManager.currentRecordingDuration)))! Listen back or move to the next phrase.")
                            .font(isPad ? .headline : .subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text("Tap the microphone below and speak the phrase.")
                            .font(isPad ? .headline : .subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer().frame(height: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(24)
                .padding(.horizontal, isPad ? 40 : 20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
            
            // Bottom Action Controls
            VStack(spacing: isPad ? 25 : 15) {
                // Secondary Controls (Redo, Playback, Keep & Next)
                if sessionManager.hasRecordedCurrentCard && !sessionManager.isRecording {
                    HStack(spacing: isPad ? 30 : 15) {
                        // Redo Button
                        Button(action: {
                            sessionManager.redoCurrentCard()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Redo")
                            }
                            .font(isPad ? .title3.bold() : .headline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, isPad ? 16 : 12)
                            .padding(.horizontal, isPad ? 25 : 15)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(14)
                        }
                        
                        // Play Recording Button
                        Button(action: {
                            if sessionManager.isPlaying {
                                sessionManager.stopPlayback()
                            } else {
                                sessionManager.playCurrentRecording()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: sessionManager.isPlaying ? "stop.fill" : "play.fill")
                                Text(sessionManager.isPlaying ? "Stop" : "Play Back")
                            }
                            .font(isPad ? .title3.bold() : .headline)
                            .foregroundColor(.blue)
                            .padding(.vertical, isPad ? 16 : 12)
                            .padding(.horizontal, isPad ? 25 : 15)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(14)
                        }
                        
                        // Next Button
                        Button(action: {
                            sessionManager.keepAndNext()
                        }) {
                            HStack(spacing: 8) {
                                Text(sessionManager.currentCardIndex + 1 == sessionManager.activeDeck?.cards.count ? "Finish" : "Next")
                                Image(systemName: "arrow.right")
                            }
                            .font(isPad ? .title3.bold() : .headline.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, isPad ? 16 : 12)
                            .padding(.horizontal, isPad ? 35 : 20)
                            .background(Color.green)
                            .cornerRadius(14)
                        }
                    }
                    .padding(.top, 10)
                }
                
                // Big Record Button
                HStack {
                    Spacer()
                    Button(action: {
                        if sessionManager.isRecording {
                            sessionManager.stopRecording()
                        } else {
                            sessionManager.startRecording()
                        }
                    }) {
                        let buttonSize: CGFloat = isPad ? 120 : 85
                        ZStack {
                            Circle()
                                .fill(sessionManager.isRecording ? Color.red : Color.blue)
                                .frame(width: buttonSize, height: buttonSize)
                                .shadow(color: (sessionManager.isRecording ? Color.red : Color.blue).opacity(0.35), radius: 12, x: 0, y: 5)
                            
                            if sessionManager.isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .frame(width: buttonSize * 0.35, height: buttonSize * 0.35)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: buttonSize * 0.45, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, isPad ? 40 : 20)
            }
            .padding(.top, isPad ? 20 : 15)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - View 3: Session Completed & Summary
    private var sessionCompletedView: some View {
        ScrollView {
            VStack(spacing: isPad ? 35 : 20) {
                Spacer().frame(height: isPad ? 20 : 10)
                
                // Celebration Header
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: isPad ? 120 : 85, height: isPad ? 120 : 85)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: isPad ? 70 : 45))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 8) {
                    Text("Session Complete! 🎉")
                        .font(.system(size: isPad ? 38 : 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(sessionManager.recordedSamples.count) phrases recorded (\(totalAudioDurationFormatted) total audio) for your voice profile.")
                        .font(isPad ? .title3 : .body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                // Recorded Phrases Summary List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recorded Phrases (\(sessionManager.recordedSamples.count))")
                            .font(isPad ? .title3.bold() : .headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Tap to play back")
                            .font(isPad ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    
                    ForEach(Array(sessionManager.recordedSamples.enumerated()), id: \.element.id) { index, sample in
                        let isPlayingThis = sessionManager.isPlaying && sessionManager.playingSampleId == sample.id
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(isPad ? .headline.bold() : .subheadline.bold())
                                .foregroundColor(.blue)
                                .frame(width: 28, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sample.card.text)
                                    .font(isPad ? .headline : .subheadline)
                                    .lineLimit(2)
                                Text(String(format: "%.1fs audio", sample.duration))
                                    .font(isPad ? .subheadline : .caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                sessionManager.playSample(sample)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                                    Text(isPlayingThis ? "Stop" : "Play")
                                }
                                .font(isPad ? .subheadline.bold() : .caption.bold())
                                .foregroundColor(isPlayingThis ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isPlayingThis ? Color.red : Color.blue.opacity(0.12))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, isPad ? 40 : 20)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // 1. Send via Email
                    Button(action: {
                        sendSessionEmail()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(isPad ? .title3 : .headline)
                            Text("Send Voice Data via Email")
                                .font(isPad ? .title3.bold() : .headline.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isPad ? 18 : 14)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    
                    // 2. AirDrop / Share Sheet Fallback
                    Button(action: {
                        shareSessionArchive()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(isPad ? .title3 : .headline)
                            Text("AirDrop or Save Archive")
                                .font(isPad ? .title3.bold() : .headline.bold())
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isPad ? 18 : 14)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(16)
                    }
                    
                    // 3. Clear and Start Another
                    if let deck = sessionManager.activeDeck, deck.isCustom {
                        let isDeckLocked = customStore.decks.first(where: { $0.id == deck.id })?.isLocked ?? false
                        HStack(spacing: 6) {
                            Image(systemName: isDeckLocked ? "lock.fill" : "lock")
                                .font(isPad ? .subheadline : .caption)
                            Text(isDeckLocked ? "This group is locked to keep training data aligned." : "Sending will lock this group so no more phrases can be added.")
                                .font(isPad ? .subheadline : .caption)
                        }
                        .foregroundColor(isDeckLocked ? .orange : .secondary)
                        .padding(.top, 4)
                    }
                    
                    Button(action: {
                        sessionManager.exitSession()
                    }) {
                        Text("Return to Decks")
                            .font(isPad ? .title3.bold() : .headline.bold())
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    
                    if sessionManager.activeDeck != nil {
                        Button(role: .destructive, action: {
                            isShowingResetConfirmation = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset & Re-record Deck")
                            }
                            .font(isPad ? .subheadline : .caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, isPad ? 40 : 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert("Reset Deck Recordings?", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All", role: .destructive) {
                if let deckId = sessionManager.activeDeck?.id {
                    sessionManager.resetDeckRecordings(deckId: deckId)
                    sessionManager.exitSession()
                }
            }
        } message: {
            Text("This will delete all saved audio recordings for this deck so you can re-record from scratch.")
        }
    }
    
    private var totalAudioDurationFormatted: String {
        let totalSeconds = Int(sessionManager.recordedSamples.reduce(0) { $0 + $1.duration })
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Email & Share Actions
    private func sendSessionEmail() {
        guard let zipURL = sessionManager.prepareExportArchive(speakerName: userName) else { return }
        self.preparedZipURL = zipURL
        
        let deckTitle = sessionManager.activeDeck?.title ?? "Session"
        self.mailSubject = "SpeakEasy Voice Training Data - \(userName) (\(deckTitle))"
        self.mailBody = """
        SpeakEasy Voice Training Session Data
        Speaker: \(userName)
        Deck: \(deckTitle)
        Phrases Recorded: \(sessionManager.recordedSamples.count)
        Date: \(Date().formatted(date: .abbreviated, time: .shortened))

        Attached is the complete VoiceData ZIP archive containing 16kHz mono WAV recordings and the formatted metadata.csv ready for Whisper fine-tuning.
        """
        
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            // Fallback to native share sheet
            presentShareSheet(for: zipURL)
        }
    }
    
    private func sendLiveCorrections() {
        guard let zipURL = sessionManager.exportLiveCorrectionsArchive(speakerName: userName) else { return }
        self.preparedZipURL = zipURL
        
        self.mailSubject = "SpeakEasy Speech Corrections Data - \(userName)"
        self.mailBody = """
        SpeakEasy Speech Corrections Report
        Speaker: \(userName)
        Total Corrections: \(sessionManager.pendingLiveCorrections.count)
        Date: \(Date().formatted(date: .abbreviated, time: .shortened))

        Attached is the corrections ZIP archive containing 16kHz mono WAV recordings and metadata.csv.
        """
        
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            presentShareSheet(for: zipURL)
        }
    }
    
    private func shareSessionArchive() {
        guard let zipURL = sessionManager.prepareExportArchive(speakerName: userName) else { return }
        presentShareSheet(for: zipURL)
    }
    
    private func presentShareSheet(for fileURL: URL) {
        let av = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        av.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            if completed {
                if fileURL.lastPathComponent.contains("Corrections") {
                    sessionManager.clearLiveCorrections()
                } else {
                    if let deckId = sessionManager.activeDeck?.id {
                        customStore.lockDeck(id: deckId)
                    }
                }
            }
        }
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
}

// MARK: - Deck Card Row
struct DeckCardRow: View {
    let deck: PromptDeck
    let recordedCount: Int
    let isPad: Bool
    let onStart: () -> Void
    var onManage: (() -> Void)? = nil
    
    var isFullyRecorded: Bool {
        !deck.cards.isEmpty && recordedCount >= deck.cards.count
    }
    
    var isPartiallyRecorded: Bool {
        recordedCount > 0 && recordedCount < deck.cards.count
    }
    
    var body: some View {
        HStack(spacing: isPad ? 22 : 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(deck.isCustom ? Color.purple.opacity(0.12) : (isFullyRecorded ? Color.green.opacity(0.12) : Color.blue.opacity(0.12)))
                    .frame(width: isPad ? 70 : 50, height: isPad ? 70 : 50)
                Image(systemName: isFullyRecorded ? "checkmark.circle.fill" : deck.icon)
                    .font(isPad ? .title : .title3)
                    .foregroundColor(deck.isCustom ? (isFullyRecorded ? .green : .purple) : (isFullyRecorded ? .green : .blue))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(deck.title)
                        .font(isPad ? .title3.bold() : .headline.bold())
                    
                    if !deck.isCustom {
                        Text("Example")
                            .font(.system(size: isPad ? 12 : 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    } else if deck.isLocked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: isPad ? 10 : 8))
                            Text("Locked")
                                .font(.system(size: isPad ? 11 : 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    if isFullyRecorded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text("Done (\(deck.cards.count))")
                        }
                        .font(.system(size: isPad ? 13 : 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    } else if isPartiallyRecorded {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                            Text("\(recordedCount)/\(deck.cards.count) recorded")
                        }
                        .font(.system(size: isPad ? 13 : 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    } else {
                        Text("\(deck.cards.count) Phrases")
                            .font(.system(size: isPad ? 14 : 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                    }
                }
                
                Text(deck.description)
                    .font(isPad ? .body : .caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                if let onManage = onManage {
                    Button(action: onManage) {
                        Image(systemName: deck.isLocked ? "lock.fill" : "pencil")
                            .font(isPad ? .title3 : .headline)
                            .foregroundColor(deck.isLocked ? .orange : .purple)
                            .padding(isPad ? 12 : 8)
                            .background((deck.isLocked ? Color.orange : Color.purple).opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                
                if deck.cards.isEmpty {
                    if let onManage = onManage {
                        Button(action: onManage) {
                            Text("Add Phrases")
                                .font(isPad ? .title3.bold() : .headline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, isPad ? 18 : 12)
                                .padding(.vertical, isPad ? 12 : 8)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                    }
                } else if isFullyRecorded {
                    Button(action: onStart) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                            Text("Review")
                        }
                        .font(isPad ? .title3.bold() : .headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, isPad ? 20 : 14)
                        .padding(.vertical, isPad ? 12 : 8)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                } else if isPartiallyRecorded {
                    Button(action: onStart) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Resume")
                        }
                        .font(isPad ? .title3.bold() : .headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, isPad ? 20 : 14)
                        .padding(.vertical, isPad ? 12 : 8)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                } else {
                    Button(action: onStart) {
                        Text("Start")
                            .font(isPad ? .title3.bold() : .headline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, isPad ? 24 : 16)
                            .padding(.vertical, isPad ? 12 : 8)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(isPad ? 24 : 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Live Waveform Bar Visualizer
struct WaveformLevelBar: View {
    let level: Float
    let isRecording: Bool
    let isPad: Bool
    
    var body: some View {
        HStack(spacing: isPad ? 6 : 4) {
            ForEach(0..<12) { index in
                let threshold = Float(index) / 12.0
                let isActive = isRecording && (level > threshold)
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? (threshold > 0.7 ? Color.red : Color.blue) : Color.gray.opacity(0.2))
                    .frame(width: isPad ? 10 : 6, height: isPad ? CGFloat(16 + index * 3) : CGFloat(10 + index * 2))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
        .frame(height: isPad ? 50 : 35)
        .padding(.vertical, 5)
    }
}

// MARK: - Custom Deck Editor View
struct CustomDeckEditorView: View {
    @ObservedObject var customStore: CustomDeckStore
    let isPad: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var newGroupName: String = ""
    @State private var selectedIcon: String = "folder.fill"
    
    let availableIcons = [
        "folder.fill",
        "house.fill",
        "fork.knife",
        "heart.fill",
        "bubble.left.and.bubble.right.fill",
        "briefcase.fill",
        "car.fill",
        "cart.fill"
    ]
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: Create a New Group
                Section(header: Text("Create New Group Deck").font(isPad ? .headline : .caption.bold())) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Group Name")
                            .font(isPad ? .headline : .subheadline.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. 'Dining & Drinks' or 'Morning Routine'", text: $newGroupName)
                            .font(isPad ? .title3 : .body)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Select Icon")
                            .font(isPad ? .subheadline : .caption.bold())
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableIcons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.15))
                                                .frame(width: isPad ? 44 : 36, height: isPad ? 44 : 36)
                                            Image(systemName: icon)
                                                .font(isPad ? .headline : .subheadline)
                                                .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Button(action: {
                            guard !newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            _ = customStore.createDeck(groupName: newGroupName, icon: selectedIcon)
                            newGroupName = ""
                        }) {
                            Label("Create Group", systemImage: "plus.circle.fill")
                                .font(isPad ? .title3.bold() : .headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isPad ? 14 : 10)
                                .background(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 8)
                }
                
                // Section 2: Custom Groups List
                Section(
                    header: Text("Your Custom Groups (\(customStore.decks.count))").font(isPad ? .headline : .caption.bold()),
                    footer: Text("Add as few or as many phrases as you want to each group. Tap any group to view, add, or delete its phrases.").font(isPad ? .body : .caption)
                ) {
                    if customStore.decks.isEmpty {
                        Text("No custom decks created yet. Add a group above to start organizing phrases.")
                            .font(isPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(customStore.decks) { deck in
                            NavigationLink(destination: DeckPhrasesDetailView(deckId: deck.id, customStore: customStore, isPad: isPad)) {
                                HStack(spacing: 14) {
                                    Image(systemName: deck.icon)
                                        .font(isPad ? .title3 : .body)
                                        .foregroundColor(.purple)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(deck.title)
                                                .font(isPad ? .title3.bold() : .headline)
                                            if deck.isLocked {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: isPad ? 10 : 8))
                                                    Text("Locked")
                                                        .font(.system(size: isPad ? 11 : 9, weight: .bold))
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.12))
                                                .foregroundColor(.orange)
                                                .cornerRadius(6)
                                            }
                                        }
                                        Text("\(deck.cards.count) phrases")
                                            .font(isPad ? .body : .caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            customStore.deleteDeck(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Custom Decks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(isPad ? .title3.bold() : .headline.bold())
                }
            }
        }
    }
}

// MARK: - Deck Phrases Detail View
struct DeckPhrasesDetailView: View {
    let deckId: String
    @ObservedObject var customStore: CustomDeckStore
    let isPad: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var newPhraseText: String = ""
    
    var currentDeck: PromptDeck? {
        customStore.decks.first(where: { $0.id == deckId })
    }
    
    var body: some View {
        Group {
            if let deck = currentDeck {
                List {
                    if deck.isLocked {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.circle.fill")
                                    .font(isPad ? .title : .title2)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Group Locked")
                                        .font(isPad ? .headline.bold() : .subheadline.bold())
                                        .foregroundColor(.primary)
                                    Text("Voice training data for this group has already been sent. No more phrases can be added.")
                                        .font(isPad ? .subheadline : .caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    } else {
                        Section(header: Text("Add Phrase to \(deck.title)").font(isPad ? .headline : .caption.bold())) {
                            HStack(spacing: 12) {
                                TextField("Type phrase (e.g. 'Can I have some tea?')", text: $newPhraseText)
                                    .font(isPad ? .title3 : .body)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    guard !newPhraseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                    customStore.addPhrase(toDeckId: deckId, text: newPhraseText)
                                    newPhraseText = ""
                                }) {
                                    Text("Add")
                                        .font(isPad ? .title3.bold() : .headline.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(newPhraseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                        .cornerRadius(8)
                                }
                                .disabled(newPhraseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    
                    Section(
                        header: Text("Phrases (\(deck.cards.count))").font(isPad ? .headline : .caption.bold()),
                        footer: Text(deck.isLocked ? "Phrases are locked to preserve training data alignment." : "Swipe left to delete any phrase.").font(isPad ? .body : .caption)
                    ) {
                        if deck.cards.isEmpty {
                            Text("No phrases in this group yet. Enter a phrase above to add.")
                                .font(isPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(Array(deck.cards.enumerated()), id: \.element.id) { index, card in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1).")
                                        .font(isPad ? .headline.bold() : .subheadline.bold())
                                        .foregroundColor(deck.isLocked ? .orange : .purple)
                                        .frame(width: 28, alignment: .leading)
                                    Text(card.text)
                                        .font(isPad ? .title3 : .body)
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deck.isLocked ? nil : { indexSet in
                                customStore.deletePhrase(fromDeckId: deckId, at: indexSet)
                            })
                        }
                    }
                    
                    Section {
                        if deck.isLocked {
                            Button(action: {
                                customStore.unlockDeck(id: deckId)
                            }) {
                                Label("Unlock Group (Allows Editing)", systemImage: "lock.open")
                                    .font(isPad ? .title3.bold() : .headline)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            customStore.deleteDeck(id: deckId)
                            dismiss()
                        }) {
                            Label("Delete Group", systemImage: "trash")
                                .font(isPad ? .title3.bold() : .headline)
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle(deck.title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(isPad ? .title3.bold() : .headline.bold())
                    }
                }
            } else {
                Text("Group not found.")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

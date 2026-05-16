import SwiftUI

struct AACExpanderView: View {
    @ObservedObject var viewModel: AACViewModel
    @ObservedObject var transcriptionVM: TranscriptionViewModel
    @ObservedObject var audioRecorder: AudioRecorder
    @AppStorage("caregiver_phone_number") var caregiverNumber: String = ""
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    var isLandscape: Bool = false
    
    let quickChips = ["💧 thirsty", "🍕 hungry", "🚌 bus late", "👨‍⚕️ doc appt", "🔋 low battery", "🚪 open door"]
    
    @State private var isShowingModelSelection = false
    
    var body: some View {
        if isPad && isLandscape {
            // 2-Column Layout for iPad Landscape
            HStack(spacing: 0) {
                // Left Column: Input and Quick Chips
                VStack(spacing: 30) {
                    header
                    shorthandDisplay
                    quickChipsView
                    
                    Spacer()
                    
                    bottomControls
                }
                .frame(width: 450)
                .padding(.trailing, 20)
                
                Divider()
                
                // Right Column: Results
                VStack(spacing: 20) {
                    Text("Expanded Options")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    resultsSection
                }
            }
        } else {
            // Standard Portrait Layout
            VStack(spacing: isPad ? 40 : 20) {
                header
                shorthandDisplay
                quickChipsView
                resultsSection
                bottomControls
            }
        }
    }
    
    private var header: some View {
        HStack {
            if !isLandscape || !isPad {
                Text("SpeakEasy")
                    .font(isPad ? .largeTitle.bold() : .title2.bold())
                    .foregroundColor(.purple)
            } else {
                Text("Smart Speak")
                    .font(.largeTitle.bold())
                    .foregroundColor(.purple)
            }
            
            Spacer()
            
            Button(action: {
                isShowingModelSelection = true
            }) {
                Image(systemName: "brain.head.profile")
                    .font(isPad ? .largeTitle : .title2)
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal)
        .padding(.top, isPad ? 20 : 10)
        .sheet(isPresented: $isShowingModelSelection) {
            NavigationView {
                ModelSelectionView()
            }
        }
    }
    
    private var shorthandDisplay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shorthand")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ZStack(alignment: .topTrailing) {
                Text(viewModel.shorthandInput.isEmpty ? "Speak your shorthand..." : viewModel.shorthandInput)
                    .font(.system(size: isPad ? 48 : 28, weight: .bold))
                    .foregroundColor(viewModel.shorthandInput.isEmpty ? .gray.opacity(0.5) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(isPad ? 40 : 20)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(24)
                
                if !viewModel.shorthandInput.isEmpty {
                    Button(action: { viewModel.clear() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                            .padding(15)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var quickChipsView: some View {
        Group {
            if isPad && isLandscape {
                // Wrapping Flow-like layout using LazyVGrid for iPad Landscape
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 15)], spacing: 15) {
                    ForEach(quickChips, id: \.self) { chip in
                        chipButton(chip)
                    }
                }
                .padding(.horizontal)
            } else {
                // Standard Horizontal Scroll for Portrait/iPhone
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(quickChips, id: \.self) { chip in
                            chipButton(chip)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func chipButton(_ chip: String) -> some View {
        Button(action: {
            // Extract text without emoji (assumes "EMOJI space text")
            let components = chip.components(separatedBy: " ")
            let chipText = components.count > 1 ? components.dropFirst().joined(separator: " ") : chip
            
            if viewModel.shorthandInput.isEmpty {
                viewModel.shorthandInput = chipText
            } else {
                viewModel.shorthandInput += " " + chipText
            }
            Task { await viewModel.expand() }
        }) {
            Text(chip)
                .font(isPad ? .title3.bold() : .body.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.generatedOptions.isEmpty {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.generatedOptions, id: \.self) { option in
                        optionButton(option)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(24)
            .padding(.horizontal)
        } else if viewModel.isGenerating || transcriptionVM.isTranscribing {
            Spacer()
            loadingView
            Spacer()
        } else {
            Spacer()
            emptyStateView
            Spacer()
        }
    }
    
    private func optionButton(_ option: String) -> some View {
        HStack(spacing: 0) {
            // Main text area triggers speech
            Button(action: {
                viewModel.speak(option)
            }) {
                HStack(spacing: 20) {
                    Text(option)
                        .font(.system(size: isPad ? 34 : 22, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(isPad ? 40 : 25)
                .frame(maxWidth: .infinity)
            }
            
            // Action buttons on the right
            HStack(spacing: isPad ? 30 : 15) {
                // Speak Button (Visual indicator)
                Button(action: { viewModel.speak(option) }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: isPad ? 44 : 28))
                        .foregroundColor(.purple)
                }
                
                // Message Button
                Button(action: {
                    // Smart recipient selection
                    let foundRecipient = ContactManager.shared.findRecipient(for: viewModel.shorthandInput)
                    // If no contact found, pass an empty string (or empty list) instead of falling back to caregiverNumber
                    // to allow manual input.
                    let recipient = foundRecipient ?? ""
                    MessageService.shared.sendMessage(text: option, recipient: recipient)
                }) {
                    Image(systemName: "message.fill")
                        .font(.system(size: isPad ? 44 : 28))
                        .foregroundColor(.blue)
                }
            }
            .padding(.trailing, isPad ? 40 : 25)
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 40) {
            Circle()
                .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                .frame(width: isPad ? 160 : 100, height: isPad ? 160 : 100)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.purple, lineWidth: 8)
                        .rotationEffect(Angle(degrees: 360))
                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                )
            Text(transcriptionVM.isTranscribing ? "Listening..." : "Gemma is thinking...")
                .font(isPad ? .largeTitle.bold() : .title2.bold())
                .foregroundColor(.purple)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: isPad ? 120 : 80))
                .foregroundColor(.purple.opacity(0.3))
            Text("Tap the microphone below\nto speak your shorthand.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(isPad ? .title : .headline)
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: isPad ? 80 : 40) {
            // Clear Button
            Button(action: {
                viewModel.clear()
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
            .disabled(viewModel.shorthandInput.isEmpty && viewModel.generatedOptions.isEmpty)
            .opacity((viewModel.shorthandInput.isEmpty && viewModel.generatedOptions.isEmpty) ? 0.3 : 1.0)
            
            // Record Button
            Button(action: {
                if audioRecorder.isRecording {
                    if let url = audioRecorder.stopRecording() {
                        transcriptionVM.transcribeAudio(at: url)
                    }
                } else {
                    // Clear previous transcription to avoid duplication when appending
                    transcriptionVM.clearTranscription()
                    audioRecorder.startRecording()
                }
            }) {
                ZStack {
                    let buttonSize: CGFloat = isPad ? 180 : 110
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(radius: isPad ? 15 : 10)
                    
                    if audioRecorder.isRecording {
                        RoundedRectangle(cornerRadius: isPad ? 12 : 8)
                            .fill(Color.white)
                            .frame(width: buttonSize * 0.35, height: buttonSize * 0.35)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: buttonSize * 0.45, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(transcriptionVM.isTranscribing || viewModel.isGenerating)
            .opacity((transcriptionVM.isTranscribing || viewModel.isGenerating) ? 0.5 : 1.0)
        }
        .padding(.bottom, isPad ? (isLandscape ? 40 : 100) : 40)
    }
}

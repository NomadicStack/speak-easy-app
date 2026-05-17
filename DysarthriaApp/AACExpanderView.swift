import SwiftUI

struct AACExpanderView: View {
    @ObservedObject var viewModel: AACViewModel
    @ObservedObject var transcriptionVM: TranscriptionViewModel
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var chipManager = QuickChipManager.shared
    @AppStorage("caregiver_phone_number") var caregiverNumber: String = ""
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    var isLandscape: Bool = false
    
    @State private var isShowingModelSelection = false
    
    var body: some View {
        if isPad && isLandscape {
            // 2-Column Layout for iPad Landscape
            HStack(spacing: 0) {
                // Left Column: Input and Quick Chips
                VStack(spacing: 20) {
                    header
                    shorthandDisplay
                    quickChipsView
                    
                    Spacer(minLength: 20)
                    
                    bottomControls
                }
                .frame(width: 600)
                .frame(maxHeight: .infinity)
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
                    
                    Spacer()
                    resultsSection
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Standard Portrait Layout
            VStack(spacing: isPad ? 40 : 20) {
                header
                shorthandDisplay
                quickChipsView
                resultsSection
                
                Spacer()
                
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
                    .font(.system(size: isPad ? 38 : 24, weight: .bold))
                    .foregroundColor(viewModel.shorthandInput.isEmpty ? .gray.opacity(0.5) : .primary)
                    .frame(maxWidth: .infinity, minHeight: isPad ? (isLandscape ? 140 : 80) : 50, alignment: .topLeading)
                    .padding(isPad ? 30 : 15)
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
                // Large Board for iPad Landscape
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(chipManager.chips) { chip in
                            chipTile(chip.label)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                .frame(minHeight: 200, maxHeight: .infinity)
            } else {
                // Structured Grid for Portrait/iPhone (Max 2-3 rows visible)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shortcuts")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: isPad ? 150 : 90), spacing: 10)], spacing: 10) {
                            ForEach(chipManager.chips) { chip in
                                chipTile(chip.label)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    }
                    .frame(maxHeight: isPad ? 400 : 160) // Limit height to keep results visible
                }
            }
        }
    }
    
    private func chipTile(_ chip: String) -> some View {
        let components = chip.components(separatedBy: " ")
        let first = components.first ?? ""
        let rest = components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
        
        return Button(action: {
            if viewModel.shorthandInput.isEmpty {
                viewModel.shorthandInput = chip
            } else {
                viewModel.shorthandInput += " " + chip
            }
            Task { await viewModel.expand() }
        }) {
            VStack(spacing: isPad ? 8 : 4) {
                Text(first)
                    .font(.system(size: isPad ? 44 : 28))
                
                if !rest.isEmpty {
                    Text(rest)
                        .font(.system(size: isPad ? 16 : 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isPad ? 15 : 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1.5)
            )
            .foregroundColor(.blue)
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
            loadingView
        } else {
            emptyStateView
        }
    }
    
    private func optionButton(_ option: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // Main text area
            HStack {
                Text(option)
                    .font(.system(size: isPad ? 28 : 18, weight: .bold))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, isPad ? 110 : 80) // Space for corner buttons
                
                Spacer()
            }
            .padding(isPad ? 30 : 20)
            .frame(maxWidth: .infinity, minHeight: isPad ? 100 : 80, alignment: .leading)
            
            // Compact Action buttons in the corner
            HStack(spacing: isPad ? 15 : 10) {
                // Speak Button
                Button(action: { viewModel.speak(option) }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: isPad ? 20 : 16, weight: .bold))
                        .foregroundColor(.purple)
                        .frame(width: isPad ? 50 : 40, height: isPad ? 50 : 40)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Message Button
                Button(action: {
                    let foundRecipient = ContactManager.shared.findRecipient(for: viewModel.shorthandInput)
                    let recipient = foundRecipient ?? ""
                    MessageService.shared.sendMessage(text: option, recipient: recipient)
                }) {
                    Image(systemName: "message.fill")
                        .font(.system(size: isPad ? 20 : 16, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: isPad ? 50 : 40, height: isPad ? 50 : 40)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding([.bottom, .trailing], isPad ? 20 : 15)
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
            Text("Tap the microphone\nto speak your shorthand.")
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
                    let buttonSize: CGFloat = isPad ? 140 : 90
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

import SwiftUI

struct AACExpanderView: View {
    @ObservedObject var viewModel: AACViewModel
    @ObservedObject var transcriptionVM: TranscriptionViewModel
    @ObservedObject var audioRecorder: AudioRecorder
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    let quickChips = ["💧 thirsty", "🍕 hungry", "🚌 bus late", "👨‍⚕️ doc appt", "🔋 low battery", "🚪 open door"]
    
    var body: some View {
        VStack(spacing: isPad ? 30 : 20) {
            // Shorthand Display
            VStack(alignment: .leading, spacing: 10) {
                Text("Shorthand")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ZStack(alignment: .topTrailing) {
                    Text(viewModel.shorthandInput.isEmpty ? "Speak your shorthand..." : viewModel.shorthandInput)
                        .font(isPad ? .title : .headline)
                        .foregroundColor(viewModel.shorthandInput.isEmpty ? .gray.opacity(0.5) : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(isPad ? 25 : 15)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                    
                    if !viewModel.shorthandInput.isEmpty {
                        Button(action: { viewModel.clear() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.headline)
                                .padding(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Quick Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickChips, id: \.self) { chip in
                        Button(action: {
                            if viewModel.shorthandInput.isEmpty {
                                viewModel.shorthandInput = chip.components(separatedBy: " ").last ?? chip
                            } else {
                                viewModel.shorthandInput += " " + (chip.components(separatedBy: " ").last ?? chip)
                            }
                            Task { await viewModel.expand() }
                        }) {
                            Text(chip)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Results Section
            if !viewModel.generatedOptions.isEmpty {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(viewModel.generatedOptions, id: \.self) { option in
                            Button(action: {
                                viewModel.speak(option)
                            }) {
                                HStack(spacing: 15) {
                                    Text(option)
                                        .font(isPad ? .title3 : .body)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                }
                                .padding(isPad ? 25 : 18)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal)
            } else if viewModel.isGenerating || transcriptionVM.isTranscribing {
                Spacer()
                VStack(spacing: 30) {
                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 6)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .trim(from: 0, to: 0.3)
                                .stroke(Color.purple, lineWidth: 6)
                                .rotationEffect(Angle(degrees: 360))
                                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                        )
                    Text(transcriptionVM.isTranscribing ? "Listening to you..." : "Gemma is expanding...")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 25) {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.purple.opacity(0.3))
                    Text("Tap the microphone below\nto speak your shorthand.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .font(isPad ? .title2 : .headline)
                }
                Spacer()
            }
            
            // Bottom Controls (Record/Stop)
            HStack(spacing: 40) {
                // Clear Button
                Button(action: {
                    viewModel.clear()
                    transcriptionVM.clearTranscription()
                }) {
                    ZStack {
                        let buttonSize: CGFloat = isPad ? 100 : 70
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: buttonSize, height: buttonSize)
                        
                        Image(systemName: "trash")
                            .font(.system(size: buttonSize * 0.4, weight: .bold))
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
                        let buttonSize: CGFloat = isPad ? 140 : 100
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(radius: 10)
                        
                        if audioRecorder.isRecording {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .frame(width: buttonSize * 0.35, height: buttonSize * 0.35)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: buttonSize * 0.4, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(transcriptionVM.isTranscribing || viewModel.isGenerating)
                .opacity((transcriptionVM.isTranscribing || viewModel.isGenerating) ? 0.5 : 1.0)
            }
            .padding(.bottom, isPad ? 60 : 30)
        }
    }
}

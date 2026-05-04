import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionVM = TranscriptionViewModel()
    
    // Detect device size class for responsive design
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Consider it an iPad if both size classes are regular (standard iPad layout)
    var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
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
                DisclosureGroup("Advanced Context (Optional)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This hint helps the AI understand slurred speech better.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Context (e.g. key words)", text: $transcriptionVM.initialPrompt)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(isPad ? .title3 : .body)
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal, isPad ? 60 : 20)
                .font(.subheadline)
                .accentColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Model Ready")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green))
                .shadow(radius: 2)
            }
            
            HStack {
                Button(action: {
                    transcriptionVM.clearTranscription()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)
                
                Spacer()
                
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
            .padding(.horizontal, isPad ? 60 : 20)
            
            ScrollView {
                Text(transcriptionVM.transcribedText)
                    .font(isPad ? .system(size: 54, weight: .bold) : .system(size: 34, weight: .bold))
                    .padding(isPad ? 30 : 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, isPad ? 60 : 20)
            .frame(maxWidth: 900) // Caps the width elegantly on very large iPad Pro screens
            
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
                    let buttonSize: CGFloat = isPad ? 120 : 80
                    
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(radius: isPad ? 8 : 5)
                    
                    if audioRecorder.isRecording {
                        // Stop square
                        RoundedRectangle(cornerRadius: isPad ? 8 : 4)
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
            .padding(.bottom, isPad ? 80 : 50)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

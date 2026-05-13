import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    var recordingURL: URL?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Explicitly set category every time to ensure we switch from .playback (TTS) to .playAndRecord
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "recording_\(UUID().uuidString).wav"
            let fileURL = tempDir.appendingPathComponent(fileName)
            recordingURL = fileURL
            
            // WhisperKit requires 16kHz PCM audio
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        
        // Do not deactivate session immediately as it can interfere with subsequent audio tasks
        // like Text-to-Speech synthesis.
        
        return recordingURL
    }
}

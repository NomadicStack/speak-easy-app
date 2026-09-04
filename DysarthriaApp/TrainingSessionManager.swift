import Foundation
import AVFoundation
import Combine
import ZIPFoundation

public struct RecordedSample: Identifiable, Codable, Equatable {
    public var id: UUID
    public var card: PromptCard
    public var audioFileName: String
    public var duration: TimeInterval
    public var timestamp: Date
    
    public init(id: UUID = UUID(), card: PromptCard, audioFileName: String, duration: TimeInterval, timestamp: Date = Date()) {
        self.id = id
        self.card = card
        self.audioFileName = audioFileName
        self.duration = duration
        self.timestamp = timestamp
    }
}

public struct LiveCorrectionSample: Identifiable, Codable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var audioFileName: String
    public var originalText: String
    public var correctedText: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), audioFileName: String, originalText: String, correctedText: String) {
        self.id = id
        self.timestamp = timestamp
        self.audioFileName = audioFileName
        self.originalText = originalText
        self.correctedText = correctedText
    }
}

@MainActor
public final class TrainingSessionManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    public static let shared = TrainingSessionManager()
    
    // MARK: - Session State
    @Published public var activeDeck: PromptDeck? = nil
    @Published public var currentCardIndex: Int = 0
    @Published public var recordedSamples: [RecordedSample] = []
    @Published public var isSessionCompleted: Bool = false
    
    // MARK: - Audio Recording State
    @Published public var isRecording: Bool = false
    @Published public var audioMeterLevel: Float = 0.0 // 0.0 to 1.0 for visualizer
    @Published public var currentRecordingDuration: TimeInterval = 0.0
    @Published public var currentRecordedAudioURL: URL? = nil
    
    // MARK: - Audio Playback State
    @Published public var isPlaying: Bool = false
    @Published public var isSpeakingPrompt: Bool = false
    @Published public var playingSampleId: UUID? = nil
    
    // MARK: - Live Corrections Queue
    @Published public var pendingLiveCorrections: [LiveCorrectionSample] = []
    
    // Private audio components
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var meterTimer: Timer?
    private var durationTimer: Timer?
    
    private let liveCorrectionsKey = "pending_live_corrections_v1"
    
    private override init() {
        super.init()
        self.speechSynthesizer.delegate = self
        loadLiveCorrections()
    }
    
    // MARK: - Session Lifecycle
    public func startSession(with deck: PromptDeck) {
        stopPlayback()
        stopSpeaking()
        stopRecording()
        
        self.activeDeck = deck
        let existingSamples = loadSamples(for: deck.id)
        self.recordedSamples = existingSamples
        
        // Check if all cards in the deck are already recorded
        let allCardsRecorded = !deck.cards.isEmpty && deck.cards.allSatisfy { card in
            existingSamples.contains(where: { $0.card.id == card.id || $0.card.text == card.text })
        }
        
        if allCardsRecorded {
            // All phrases already recorded -> directly show completed review screen
            self.isSessionCompleted = true
            self.currentCardIndex = max(0, deck.cards.count - 1)
            self.currentRecordedAudioURL = nil
        } else {
            // Find the first unrecorded card in the deck
            if let firstUnrecordedIndex = deck.cards.firstIndex(where: { card in
                !existingSamples.contains(where: { $0.card.id == card.id || $0.card.text == card.text })
            }) {
                self.currentCardIndex = firstUnrecordedIndex
            } else {
                self.currentCardIndex = 0
            }
            self.isSessionCompleted = false
            loadCurrentCardRecording()
        }
    }
    
    public func exitSession() {
        stopRecording()
        stopPlayback()
        stopSpeaking()
        self.activeDeck = nil
        self.currentCardIndex = 0
        self.recordedSamples = []
        self.isSessionCompleted = false
        self.currentRecordedAudioURL = nil
        self.currentRecordingDuration = 0.0
    }
    
    public func loadCurrentCardRecording() {
        guard let deck = activeDeck, let card = currentCard else {
            self.currentRecordedAudioURL = nil
            self.currentRecordingDuration = 0.0
            return
        }
        if let sample = recordedSamples.first(where: { $0.card.id == card.id || $0.card.text == card.text }) {
            let audioDir = getDeckAudioDirectory(deckId: deck.id)
            let fileURL = audioDir.appendingPathComponent(sample.audioFileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                self.currentRecordedAudioURL = fileURL
                self.currentRecordingDuration = sample.duration
                return
            }
        }
        self.currentRecordedAudioURL = nil
        self.currentRecordingDuration = 0.0
    }
    
    public func previousCard() {
        guard currentCardIndex > 0 else { return }
        stopPlayback()
        stopRecording()
        currentCardIndex -= 1
        loadCurrentCardRecording()
    }
    
    public func nextCard() {
        guard let deck = activeDeck, currentCardIndex + 1 < deck.cards.count else { return }
        stopPlayback()
        stopRecording()
        currentCardIndex += 1
        loadCurrentCardRecording()
    }
    
    public var currentCard: PromptCard? {
        guard let deck = activeDeck, currentCardIndex < deck.cards.count else { return nil }
        return deck.cards[currentCardIndex]
    }
    
    public var hasRecordedCurrentCard: Bool {
        return currentRecordedAudioURL != nil
    }
    
    public var isCurrentCardRecorded: Bool {
        guard let card = currentCard else { return false }
        return recordedSamples.contains(where: { $0.card.id == card.id || $0.card.text == card.text })
    }
    
    public var sessionProgress: Double {
        guard let deck = activeDeck, !deck.cards.isEmpty else { return 0.0 }
        return Double(recordedSamples.count) / Double(deck.cards.count)
    }
    
    // MARK: - Audio Recording
    public func startRecording() {
        stopPlayback()
        stopSpeaking()
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "temp_training_\(UUID().uuidString).wav"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
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
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            isRecording = true
            currentRecordingDuration = 0.0
            
            // Audio level metering for waveform UI
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                    recorder.updateMeters()
                    let peak = recorder.averagePower(forChannel: 0)
                    // Normalize dB (-60 to 0) to 0.0 ... 1.0
                    let normalized = max(0.0, min(1.0, (peak + 60.0) / 60.0))
                    self.audioMeterLevel = normalized
                }
            }
            
            // Duration timer
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isRecording else { return }
                    self.currentRecordingDuration += 0.1
                }
            }
        } catch {
            print("Failed to start audio recorder: \(error)")
        }
    }
    
    public func stopRecording() {
        guard isRecording else { return }
        meterTimer?.invalidate()
        meterTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        audioMeterLevel = 0.0
        
        if let recordedURL = audioRecorder?.url, FileManager.default.fileExists(atPath: recordedURL.path) {
            self.currentRecordedAudioURL = recordedURL
        }
    }
    
    public nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag && FileManager.default.fileExists(atPath: recorder.url.path) {
                self.currentRecordedAudioURL = recorder.url
            }
        }
    }
    
    // MARK: - Audio Playback
    public func playCurrentRecording() {
        guard let url = currentRecordedAudioURL else {
            print("[VoiceStudio] playCurrentRecording: currentRecordedAudioURL is nil")
            return
        }
        stopSpeaking()
        stopPlayback()
        
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playAndRecord with .defaultToSpeaker so playback routes to loudspeaker
            // without invalid option errors (.defaultToSpeaker is only valid with .playAndRecord)
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            try? session.overrideOutputAudioPort(.speaker)
            
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            if player.play() {
                self.audioPlayer = player
                self.isPlaying = true
            } else {
                print("[VoiceStudio] audioPlayer.play() returned false for URL: \(url)")
            }
        } catch {
            print("[VoiceStudio] Failed to play with .playAndRecord: \(error), falling back to .playback")
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [])
                try session.setActive(true)
                
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.volume = 1.0
                player.prepareToPlay()
                if player.play() {
                    self.audioPlayer = player
                    self.isPlaying = true
                }
            } catch {
                print("[VoiceStudio] Fallback playback failed: \(error)")
            }
        }
    }
    
    public func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
    
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
    
    // MARK: - Text-to-Speech Preview
    public func speakCurrentPrompt() {
        guard let card = currentCard else { return }
        stopPlayback()
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
        
        let utterance = AVSpeechUtterance(string: card.text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85 // Slightly slower for clear enunciation
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        isSpeakingPrompt = true
        speechSynthesizer.speak(utterance)
    }
    
    public func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeakingPrompt = false
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeakingPrompt = false
        }
    }
    
    // MARK: - Session Navigation & Progress
    public func redoCurrentCard() {
        stopPlayback()
        stopRecording()
        guard let deck = activeDeck, let card = currentCard else { return }
        
        if let index = recordedSamples.firstIndex(where: { $0.card.id == card.id || $0.card.text == card.text }) {
            let sample = recordedSamples.remove(at: index)
            let audioDir = getDeckAudioDirectory(deckId: deck.id)
            let fileURL = audioDir.appendingPathComponent(sample.audioFileName)
            try? FileManager.default.removeItem(at: fileURL)
            saveSamples(for: deck.id)
        }
        
        if let tempURL = currentRecordedAudioURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        currentRecordedAudioURL = nil
        currentRecordingDuration = 0.0
    }
    
    public func keepAndNext() {
        guard let card = currentCard, let tempAudioURL = currentRecordedAudioURL, let deck = activeDeck else { return }
        stopPlayback()
        
        let audioFolder = getDeckAudioDirectory(deckId: deck.id)
        let sampleFileName = "sample_\(String(format: "%02d", currentCardIndex + 1))_\(card.id.uuidString.prefix(6)).wav"
        let destURL = audioFolder.appendingPathComponent(sampleFileName)
        
        // Copy audio from temp to deck's permanent audio folder if it was freshly recorded
        if tempAudioURL.path != destURL.path {
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.copyItem(at: tempAudioURL, to: destURL)
                try? FileManager.default.removeItem(at: tempAudioURL)
            } catch {
                print("[VoiceStudio] Error saving sample audio: \(error)")
            }
        }
        
        let newSample = RecordedSample(
            id: UUID(),
            card: card,
            audioFileName: sampleFileName,
            duration: currentRecordingDuration,
            timestamp: Date()
        )
        
        if let existingIndex = recordedSamples.firstIndex(where: { $0.card.id == card.id || $0.card.text == card.text }) {
            recordedSamples[existingIndex] = newSample
        } else {
            recordedSamples.append(newSample)
        }
        saveSamples(for: deck.id)
        
        // Check if all cards in deck are now recorded
        let allCardsRecorded = !deck.cards.isEmpty && deck.cards.allSatisfy { c in
            recordedSamples.contains(where: { $0.card.id == c.id || $0.card.text == c.text })
        }
        
        if allCardsRecorded {
            isSessionCompleted = true
        } else if currentCardIndex + 1 < deck.cards.count {
            currentCardIndex += 1
            loadCurrentCardRecording()
        } else {
            // Reached end of deck list, jump to any remaining unrecorded card
            if let firstUnrecorded = deck.cards.firstIndex(where: { c in
                !recordedSamples.contains(where: { $0.card.id == c.id || $0.card.text == c.text })
            }) {
                currentCardIndex = firstUnrecorded
                loadCurrentCardRecording()
            } else {
                isSessionCompleted = true
            }
        }
    }
    
    // MARK: - Directory & Persistence Helpers
    public func getVoiceStudioDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("VoiceStudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public func getDeckDirectory(deckId: String) -> URL {
        let dir = getVoiceStudioDirectory().appendingPathComponent("Decks", isDirectory: true).appendingPathComponent(deckId, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public func getDeckAudioDirectory(deckId: String) -> URL {
        let dir = getDeckDirectory(deckId: deckId).appendingPathComponent("audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public func saveSamples(for deckId: String) {
        let samplesFile = getDeckDirectory(deckId: deckId).appendingPathComponent("samples.json")
        if let data = try? JSONEncoder().encode(recordedSamples) {
            try? data.write(to: samplesFile, options: .atomic)
        }
        objectWillChange.send()
    }
    
    public func loadSamples(for deckId: String) -> [RecordedSample] {
        let samplesFile = getDeckDirectory(deckId: deckId).appendingPathComponent("samples.json")
        guard let data = try? Data(contentsOf: samplesFile),
              let decoded = try? JSONDecoder().decode([RecordedSample].self, from: data) else {
            return []
        }
        return decoded
    }
    
    public func recordedSampleCount(for deckId: String) -> Int {
        return loadSamples(for: deckId).count
    }
    
    public func isDeckFullyRecorded(deck: PromptDeck) -> Bool {
        guard !deck.cards.isEmpty else { return false }
        let saved = loadSamples(for: deck.id)
        return deck.cards.allSatisfy { card in
            saved.contains(where: { $0.card.id == card.id || $0.card.text == card.text })
        }
    }
    
    public func playSample(_ sample: RecordedSample) {
        if isPlaying && playingSampleId == sample.id {
            stopPlayback()
            return
        }
        
        guard let deck = activeDeck else { return }
        let audioDir = getDeckAudioDirectory(deckId: deck.id)
        let fileURL = audioDir.appendingPathComponent(sample.audioFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        stopSpeaking()
        stopPlayback()
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            try? session.overrideOutputAudioPort(.speaker)
            
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            if player.play() {
                self.audioPlayer = player
                self.isPlaying = true
                self.playingSampleId = sample.id
            }
        } catch {
            print("[VoiceStudio] playSample failed: \(error)")
        }
    }
    
    public func resetDeckRecordings(deckId: String) {
        stopPlayback()
        stopRecording()
        stopSpeaking()
        let deckDir = getDeckDirectory(deckId: deckId)
        try? FileManager.default.removeItem(at: deckDir)
        if activeDeck?.id == deckId {
            recordedSamples.removeAll()
            currentCardIndex = 0
            isSessionCompleted = false
            currentRecordedAudioURL = nil
            currentRecordingDuration = 0.0
        }
        objectWillChange.send()
    }
    
    // MARK: - ZIP Export Packaging (Whisper Fine-Tuning Format)
    public func prepareExportArchive(speakerName: String = "User") -> URL? {
        guard !recordedSamples.isEmpty, let deck = activeDeck else { return nil }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampStr = dateFormatter.string(from: Date())
        
        let exportFolderName = "VoiceData_\(deck.id)_\(timestampStr)"
        let exportFolderURL = tempDir.appendingPathComponent(exportFolderName, isDirectory: true)
        let exportAudioFolderURL = exportFolderURL.appendingPathComponent("audio", isDirectory: true)
        
        try? fileManager.removeItem(at: exportFolderURL)
        try? fileManager.createDirectory(at: exportAudioFolderURL, withIntermediateDirectories: true)
        
        let deckAudioDir = getDeckAudioDirectory(deckId: deck.id)
        
        // 1. Build metadata.csv content matching Whisper fine-tuning schema
        var csvLines = ["filepath,text,norm_text,splits,scenario_group,recorded_at"]
        let isoFormatter = ISO8601DateFormatter()
        
        for sample in recordedSamples {
            let srcAudioURL = deckAudioDir.appendingPathComponent(sample.audioFileName)
            let destAudioURL = exportAudioFolderURL.appendingPathComponent(sample.audioFileName)
            
            if fileManager.fileExists(atPath: srcAudioURL.path) {
                try? fileManager.copyItem(at: srcAudioURL, to: destAudioURL)
            }
            
            let relPath = "audio/\(sample.audioFileName)"
            let escapedText = "\"" + sample.card.text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let normText = "\"" + normalizeText(sample.card.text) + "\""
            let scenarioGroup = sample.card.category
            let dateStr = isoFormatter.string(from: sample.timestamp)
            
            csvLines.append("\(relPath),\(escapedText),\(normText),train,\(scenarioGroup),\(dateStr)")
        }
        
        let csvContent = csvLines.joined(separator: "\n")
        let csvURL = exportFolderURL.appendingPathComponent("metadata.csv")
        try? csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
        
        // 2. Compress the folder into a single .zip file using ZIPFoundation
        let zipURL = tempDir.appendingPathComponent("\(exportFolderName).zip")
        try? fileManager.removeItem(at: zipURL)
        
        do {
            try fileManager.zipItem(at: exportFolderURL, to: zipURL, shouldKeepParent: false)
            try? fileManager.removeItem(at: exportFolderURL)
            return zipURL
        } catch {
            print("Failed to create ZIP archive: \(error)")
            return nil
        }
    }
    
    // MARK: - Live Corrections Management
    public func addLiveCorrection(audioURL: URL, originalText: String, correctedText: String) {
        let fileManager = FileManager.default
        let liveFolder = getVoiceStudioDirectory().appendingPathComponent("LiveCorrections", isDirectory: true)
        try? fileManager.createDirectory(at: liveFolder, withIntermediateDirectories: true)
        
        let newAudioName = "correction_\(UUID().uuidString).wav"
        let destURL = liveFolder.appendingPathComponent(newAudioName)
        
        do {
            try fileManager.copyItem(at: audioURL, to: destURL)
            let item = LiveCorrectionSample(
                timestamp: Date(),
                audioFileName: newAudioName,
                originalText: originalText,
                correctedText: correctedText
            )
            pendingLiveCorrections.append(item)
            saveLiveCorrections()
        } catch {
            print("Error adding live correction: \(error)")
        }
    }
    
    public func exportLiveCorrectionsArchive(speakerName: String = "User") -> URL? {
        guard !pendingLiveCorrections.isEmpty else { return nil }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampStr = dateFormatter.string(from: Date())
        
        let exportFolderName = "VoiceData_Corrections_\(timestampStr)"
        let exportFolderURL = tempDir.appendingPathComponent(exportFolderName, isDirectory: true)
        let exportAudioFolderURL = exportFolderURL.appendingPathComponent("audio", isDirectory: true)
        
        try? fileManager.removeItem(at: exportFolderURL)
        try? fileManager.createDirectory(at: exportAudioFolderURL, withIntermediateDirectories: true)
        
        let liveFolder = getVoiceStudioDirectory().appendingPathComponent("LiveCorrections", isDirectory: true)
        
        var csvLines = ["filepath,text,norm_text,splits,scenario_group,recorded_at,original_transcription"]
        let isoFormatter = ISO8601DateFormatter()
        
        for item in pendingLiveCorrections {
            let srcAudio = liveFolder.appendingPathComponent(item.audioFileName)
            let destAudio = exportAudioFolderURL.appendingPathComponent(item.audioFileName)
            if fileManager.fileExists(atPath: srcAudio.path) {
                try? fileManager.copyItem(at: srcAudio, to: destAudio)
            }
            
            let relPath = "audio/\(item.audioFileName)"
            let escapedText = "\"" + item.correctedText.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let normText = "\"" + normalizeText(item.correctedText) + "\""
            let origText = "\"" + item.originalText.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let dateStr = isoFormatter.string(from: item.timestamp)
            
            csvLines.append("\(relPath),\(escapedText),\(normText),train,live_correction,\(dateStr),\(origText)")
        }
        
        let csvContent = csvLines.joined(separator: "\n")
        let csvURL = exportFolderURL.appendingPathComponent("metadata.csv")
        try? csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
        
        let zipURL = tempDir.appendingPathComponent("\(exportFolderName).zip")
        try? fileManager.removeItem(at: zipURL)
        
        do {
            try fileManager.zipItem(at: exportFolderURL, to: zipURL, shouldKeepParent: false)
            try? fileManager.removeItem(at: exportFolderURL)
            return zipURL
        } catch {
            print("Failed to zip live corrections: \(error)")
            return nil
        }
    }
    
    public func clearLiveCorrections() {
        let liveFolder = getVoiceStudioDirectory().appendingPathComponent("LiveCorrections", isDirectory: true)
        try? FileManager.default.removeItem(at: liveFolder)
        pendingLiveCorrections.removeAll()
        UserDefaults.standard.removeObject(forKey: liveCorrectionsKey)
    }
    
    private func saveLiveCorrections() {
        if let data = try? JSONEncoder().encode(pendingLiveCorrections) {
            UserDefaults.standard.set(data, forKey: liveCorrectionsKey)
        }
    }
    
    private func loadLiveCorrections() {
        guard let data = UserDefaults.standard.data(forKey: liveCorrectionsKey),
              let decoded = try? JSONDecoder().decode([LiveCorrectionSample].self, from: data) else {
            return
        }
        self.pendingLiveCorrections = decoded
    }
    
    // MARK: - Session Cleanup
    public func clearActiveSessionFiles() {
        if let deckId = activeDeck?.id {
            resetDeckRecordings(deckId: deckId)
        } else {
            recordedSamples.removeAll()
            isSessionCompleted = false
            currentCardIndex = 0
            currentRecordedAudioURL = nil
        }
    }
    
    // MARK: - Text Normalization Helper
    private func normalizeText(_ input: String) -> String {
        var str = input.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "'"))
        str = str.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
        return str.split(separator: " ").joined(separator: " ")
    }
}

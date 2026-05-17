import Foundation
import SwiftUI
import Combine

struct QuickChip: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String // The text shown on the button (e.g., "💧 thirsty")
}

class QuickChipManager: ObservableObject {
    @Published var chips: [QuickChip] = [] {
        didSet {
            saveChips()
        }
    }
    
    static let shared = QuickChipManager()
    private let storageKey = "saved_quick_chips"
    
    private let defaultChips = [
        "🍕 hungry", "😴 tired", "💧 thirsty", 
        "👩‍🦱 mom", "👨‍🦱 dad", "🚽 bathroom", "🔋 low battery"
    ]
    
    private init() {
        loadChips()
    }
    
    private func saveChips() {
        if let encoded = try? JSONEncoder().encode(chips) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadChips() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([QuickChip].self, from: data) {
            chips = decoded
        } else {
            // Initialize with default chips
            chips = defaultChips.map { QuickChip(label: $0) }
        }
    }
    
    func addChip(label: String) {
        let newChip = QuickChip(label: label)
        chips.append(newChip)
    }
    
    func deleteChip(at offsets: IndexSet) {
        chips.remove(atOffsets: offsets)
    }
    
    func updateChip(at index: Int, newLabel: String) {
        guard index >= 0 && index < chips.count else { return }
        chips[index].label = newLabel
    }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || scalar.properties.isEmojiPresentation)
    }
}

extension String {
    var startsWithEmoji: Bool {
        first?.isEmoji ?? false
    }
}

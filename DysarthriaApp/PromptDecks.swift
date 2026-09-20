import Foundation
import Combine
import SwiftUI

public struct PromptCard: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var category: String
    
    public init(id: UUID = UUID(), text: String, category: String = "general") {
        self.id = id
        self.text = text
        self.category = category
    }
}

public struct PromptDeck: Identifiable, Codable, Equatable {
    public var id: String
    public var title: String
    public var description: String
    public var icon: String
    public var cards: [PromptCard]
    public var isCustom: Bool
    public var isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, icon, cards, isCustom, isLocked
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        icon: String = "folder.fill",
        cards: [PromptCard] = [],
        isCustom: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.cards = cards
        self.isCustom = isCustom
        self.isLocked = isLocked
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "folder.fill"
        self.cards = try container.decodeIfPresent([PromptCard].self, forKey: .cards) ?? []
        self.isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }
}

public final class PromptDeckProvider: ObservableObject {
    public static let shared = PromptDeckProvider()
    
    /// Single curated 10-phrase example deck
    public static let exampleDeck = PromptDeck(
        id: "daily_essentials",
        title: "Daily Essentials",
        description: "Example 10-phrase deck for everyday assistance and needs.",
        icon: "star.fill",
        cards: [
            PromptCard(text: "I need a glass of water please.", category: "daily_essentials"),
            PromptCard(text: "Please help me sit up.", category: "daily_essentials"),
            PromptCard(text: "I am feeling too cold.", category: "daily_essentials"),
            PromptCard(text: "Can you adjust my pillow?", category: "daily_essentials"),
            PromptCard(text: "It is time for my medicine.", category: "daily_essentials"),
            PromptCard(text: "I would like something to eat.", category: "daily_essentials"),
            PromptCard(text: "Please turn on the light.", category: "daily_essentials"),
            PromptCard(text: "I need to use the restroom.", category: "daily_essentials"),
            PromptCard(text: "Could you open the window?", category: "daily_essentials"),
            PromptCard(text: "Thank you for your help.", category: "daily_essentials")
        ],
        isCustom: false
    )
    
    public var allDecks: [PromptDeck] {
        var decks = [PromptDeckProvider.exampleDeck]
        decks.append(contentsOf: CustomDeckStore.shared.decks)
        return decks
    }
}

/// Helper store for custom user/caregiver decks organized by group name and phrases
public final class CustomDeckStore: ObservableObject {
    public static let shared = CustomDeckStore()
    private let storageKey = "custom_training_decks_v2"
    private let legacyStorageKey = "custom_training_cards_v1"
    
    @Published public var decks: [PromptDeck] = []
    
    private init() {
        self.decks = loadDecks()
    }
    
    public func loadDecks() -> [PromptDeck] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PromptDeck].self, from: data) {
            return decoded
        }
        
        // Migration: check legacy single-card-list store
        if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
           let legacyCards = try? JSONDecoder().decode([PromptCard].self, from: data),
           !legacyCards.isEmpty {
            let migrated = PromptDeck(
                id: "custom_my_phrases",
                title: "Custom Phrases",
                description: "\(legacyCards.count) phrases",
                icon: "folder.fill",
                cards: legacyCards,
                isCustom: true
            )
            let initial = [migrated]
            if let encoded = try? JSONEncoder().encode(initial) {
                UserDefaults.standard.set(encoded, forKey: storageKey)
            }
            return initial
        }
        
        return []
    }
    
    @discardableResult
    public func createDeck(groupName: String, icon: String = "folder.fill") -> PromptDeck? {
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let slug = trimmed.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "_")
        let prefix = slug.isEmpty ? "group" : String(slug.prefix(20))
        let deckId = "custom_\(prefix)_\(UUID().uuidString.prefix(6).lowercased())"
        let newDeck = PromptDeck(
            id: deckId,
            title: trimmed,
            description: "0 phrases",
            icon: icon,
            cards: [],
            isCustom: true
        )
        decks.append(newDeck)
        save()
        return newDeck
    }
    
    public func deleteDeck(id: String) {
        decks.removeAll { $0.id == id }
        save()
    }
    
    public func deleteDeck(at indexSet: IndexSet) {
        decks.remove(atOffsets: indexSet)
        save()
    }
    
    public func lockDeck(id: String) {
        guard let index = decks.firstIndex(where: { $0.id == id }) else { return }
        decks[index].isLocked = true
        save()
    }
    
    public func unlockDeck(id: String) {
        guard let index = decks.firstIndex(where: { $0.id == id }) else { return }
        decks[index].isLocked = false
        save()
    }
    
    public func addPhrase(toDeckId deckId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = decks.firstIndex(where: { $0.id == deckId }) else { return }
        // Guard: Cannot add phrases to a locked group
        guard !decks[index].isLocked else { return }
        
        let card = PromptCard(text: trimmed, category: decks[index].id)
        decks[index].cards.append(card)
        let count = decks[index].cards.count
        decks[index].description = "\(count) \(count == 1 ? "phrase" : "phrases")"
        save()
    }
    
    public func deletePhrase(fromDeckId deckId: String, at indexSet: IndexSet) {
        guard let index = decks.firstIndex(where: { $0.id == deckId }) else { return }
        // Guard: Cannot delete phrases from a locked group
        guard !decks[index].isLocked else { return }
        decks[index].cards.remove(atOffsets: indexSet)
        let count = decks[index].cards.count
        decks[index].description = "\(count) \(count == 1 ? "phrase" : "phrases")"
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(decks) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        objectWillChange.send()
        PromptDeckProvider.shared.objectWillChange.send()
    }
}

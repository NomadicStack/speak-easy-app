import Foundation

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

public struct PromptDeck: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var description: String
    public var icon: String
    public var cards: [PromptCard]
    public var isCustom: Bool
    
    public init(id: String, title: String, description: String, icon: String, cards: [PromptCard], isCustom: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.cards = cards
        self.isCustom = isCustom
    }
}

public final class PromptDeckProvider {
    public static let shared = PromptDeckProvider()
    
    public var allDecks: [PromptDeck] {
        var decks = defaultDecks
        if let customDeck = customDeck, !customDeck.cards.isEmpty {
            decks.append(customDeck)
        }
        return decks
    }
    
    public var customDeck: PromptDeck? {
        let cards = CustomDeckStore.shared.loadCards()
        guard !cards.isEmpty else { return nil }
        return PromptDeck(
            id: "custom_caregiver",
            title: "Custom Phrases",
            description: "Personalized phrases added by you or your caregiver (\(cards.count) phrases)",
            icon: "person.badge.plus",
            cards: cards,
            isCustom: true
        )
    }
    
    /// Pre-defined standard decks with exactly 10 phrases each to prevent vocal fatigue
    public let defaultDecks: [PromptDeck] = [
        PromptDeck(
            id: "daily_essentials",
            title: "Daily Essentials",
            description: "High-priority requests for water, medicine, comfort, and immediate assistance.",
            icon: "drop.fill",
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
            ]
        ),
        PromptDeck(
            id: "home_comfort",
            title: "Home & Assistance",
            description: "Everyday requests for devices, room control, and restful comfort.",
            icon: "house.fill",
            cards: [
                PromptCard(text: "Please turn down the volume.", category: "home_comfort"),
                PromptCard(text: "Where is my phone?", category: "home_comfort"),
                PromptCard(text: "Can you close the door?", category: "home_comfort"),
                PromptCard(text: "I want to rest for a while.", category: "home_comfort"),
                PromptCard(text: "Please plug in my charger.", category: "home_comfort"),
                PromptCard(text: "Can I have some ice?", category: "home_comfort"),
                PromptCard(text: "I am ready for bed now.", category: "home_comfort"),
                PromptCard(text: "Please call my caregiver.", category: "home_comfort"),
                PromptCard(text: "What time is it right now?", category: "home_comfort"),
                PromptCard(text: "Everything is okay right now.", category: "home_comfort")
            ]
        ),
        PromptDeck(
            id: "conversation_greetings",
            title: "Greetings & Social",
            description: "Common social interactions, positive responses, and polite conversation.",
            icon: "bubble.left.and.bubble.right.fill",
            cards: [
                PromptCard(text: "Good morning, how are you?", category: "conversation"),
                PromptCard(text: "Yes, that sounds good to me.", category: "conversation"),
                PromptCard(text: "No, I do not want that.", category: "conversation"),
                PromptCard(text: "I agree with what you said.", category: "conversation"),
                PromptCard(text: "Can you repeat that please?", category: "conversation"),
                PromptCard(text: "It is very nice to see you.", category: "conversation"),
                PromptCard(text: "I am feeling much better today.", category: "conversation"),
                PromptCard(text: "Have a wonderful afternoon.", category: "conversation"),
                PromptCard(text: "I will see you tomorrow.", category: "conversation"),
                PromptCard(text: "Thank you, goodbye.", category: "conversation")
            ]
        ),
        PromptDeck(
            id: "health_pain",
            title: "Health & Well-being",
            description: "Important phrases for communicating pain, physical fatigue, and doctor needs.",
            icon: "heart.text.square.fill",
            cards: [
                PromptCard(text: "I am feeling pain right now.", category: "health_pain"),
                PromptCard(text: "My back is hurting a lot.", category: "health_pain"),
                PromptCard(text: "I am feeling very dizzy.", category: "health_pain"),
                PromptCard(text: "Please call the doctor.", category: "health_pain"),
                PromptCard(text: "I need help immediately.", category: "health_pain"),
                PromptCard(text: "I cannot reach my call button.", category: "health_pain"),
                PromptCard(text: "I am having trouble swallowing.", category: "health_pain"),
                PromptCard(text: "Please check my blood pressure.", category: "health_pain"),
                PromptCard(text: "I feel uncomfortable here.", category: "health_pain"),
                PromptCard(text: "Please stay with me for a bit.", category: "health_pain")
            ]
        )
    ]
}

/// Helper store for custom caregiver / user phrases
public final class CustomDeckStore: ObservableObject {
    public static let shared = CustomDeckStore()
    private let storageKey = "custom_training_cards_v1"
    
    @Published public var cards: [PromptCard] = []
    
    private init() {
        self.cards = loadCards()
    }
    
    public func loadCards() -> [PromptCard] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PromptCard].self, from: data) else {
            return []
        }
        return decoded
    }
    
    public func addCard(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cards.append(PromptCard(text: trimmed, category: "custom"))
        save()
    }
    
    public func deleteCard(at indexSet: IndexSet) {
        cards.remove(atOffsets: indexSet)
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

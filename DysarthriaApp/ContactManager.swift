import Foundation
import Combine
import SwiftUI

struct Contact: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var phoneNumber: String
}

class ContactManager: ObservableObject {
    @Published var contacts: [Contact] = [] {
        didSet {
            saveContacts()
        }
    }
    
    static let shared = ContactManager()
    private let storageKey = "saved_contacts"
    
    private init() {
        loadContacts()
    }
    
    private func saveContacts() {
        if let encoded = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = decoded
        }
    }
    
    func addContact(name: String, number: String) {
        let newContact = Contact(name: name, phoneNumber: number)
        contacts.append(newContact)
    }
    
    func deleteContact(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
    }
    
    func findRecipient(for shorthand: String) -> String? {
        let lowerShorthand = shorthand.lowercased()
        // Find if any contact name is mentioned in the shorthand
        if let contact = contacts.first(where: { lowerShorthand.contains($0.name.lowercased()) }) {
            return contact.phoneNumber
        }
        return nil
    }
}

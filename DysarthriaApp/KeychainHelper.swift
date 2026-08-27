import Foundation
import Security

/// A helper class to manage secure storage of the user's paid token in the iOS Keychain.
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let service = "com.dysarthriaapp.paidtoken"
    private let account = "user_paid_token"
    
    private init() {}
    
    /// Saves the token to the Keychain.
    /// - Parameter token: The token string to save.
    /// - Returns: True if saving succeeded, false otherwise.
    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        
        // Clear any existing token first to prevent conflicts
        deleteToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Accessible after first unlock (safest for background execution / persistent offline access)
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Loads the token from the Keychain.
    /// - Returns: The stored token string if it exists, nil otherwise.
    public func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Deletes the token from the Keychain.
    /// - Returns: True if deletion succeeded or if the item was not found, false otherwise.
    @discardableResult
    public func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

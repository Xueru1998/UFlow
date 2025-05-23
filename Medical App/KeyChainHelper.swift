import Foundation
import Security

class KeychainHelper {
    
    static func saveToken(token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: data
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
            if let data = item as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }
    
    static func removeToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

import Foundation

struct LoginResponse: Codable {
    let token: String
    let isAdmin: Bool
    let userId: String
}

struct UserData: Codable {
    let email: String
    let password: String
}

struct UserProfile: Codable {
    // Essential fields
    let id: String
    let email: String
    let username: String
    let firstname: String
    let lastname: String
    
    // Non-essential fields - made optional
    let isAdmin: Bool?
    let avatar: String?
    let avatarContentType: String?
    let place: String?
    let street: String?
    let telephone: String?
    let isVerified: Bool?
    let createdAt: String?
    let notes: [UserNote]?
    let notificationAssignedAt: [String]?

    // Use CodingKeys to map "_id" field to "id" and handle potential variations
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId = "userId" // Alternative for id
        case email
        case username
        case firstname, firstName // Handle both camelCase and lowercase
        case lastname, lastName // Handle both camelCase and lowercase
        case isAdmin, is_admin // Handle different naming conventions
        case avatar
        case avatarContentType
        case place
        case street
        case telephone, phone // Alternative field name
        case isVerified, is_verified // Handle different naming conventions
        case createdAt, created_at // Handle different naming conventions
        case notes
        case notificationAssignedAt, notification_assigned_at
    }
    
    // Custom initializer to handle missing or unexpected values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try both _id and userId for the id field
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else if let altId = try container.decodeIfPresent(String.self, forKey: .userId) {
            id = altId
        } else {
            // If neither is present, provide a default (or you could throw an error)
            id = "unknown"
        }
        
        // Email - essential field with fallback
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        
        // Username - essential field with fallback
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        
        // Firstname - try both camelCase and lowercase versions
        if let firstnameValue = try container.decodeIfPresent(String.self, forKey: .firstname) {
            firstname = firstnameValue
        } else {
            firstname = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        }
        
        // Lastname - try both camelCase and lowercase versions
        if let lastnameValue = try container.decodeIfPresent(String.self, forKey: .lastname) {
            lastname = lastnameValue
        } else {
            lastname = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        }
        
        // Optional fields - handle each one separately
        // isAdmin with different naming conventions and numeric boolean
        let isAdminValue = try container.decodeIfPresent(Bool.self, forKey: .isAdmin)
        let isAdminSnakeValue = try container.decodeIfPresent(Bool.self, forKey: .is_admin)
        let isAdminNumValue = try container.decodeIfPresent(Int.self, forKey: .isAdmin)
        let isAdminSnakeNumValue = try container.decodeIfPresent(Int.self, forKey: .is_admin)
        
        if let value = isAdminValue {
            isAdmin = value
        } else if let value = isAdminSnakeValue {
            isAdmin = value
        } else if let value = isAdminNumValue {
            isAdmin = value != 0
        } else if let value = isAdminSnakeNumValue {
            isAdmin = value != 0
        } else {
            isAdmin = nil
        }
        
        // Simple optional fields
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        avatarContentType = try container.decodeIfPresent(String.self, forKey: .avatarContentType)
        place = try container.decodeIfPresent(String.self, forKey: .place)
        street = try container.decodeIfPresent(String.self, forKey: .street)
        
        // Telephone with alternative field name - FIX: Use if-let instead of ??
        let phoneValue = try container.decodeIfPresent(String.self, forKey: .telephone)
        if let phone = phoneValue {
            telephone = phone
        } else {
            telephone = try container.decodeIfPresent(String.self, forKey: .phone)
        }
        
        // isVerified with different naming conventions
        let isVerifiedValue = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
        let isVerifiedSnakeValue = try container.decodeIfPresent(Bool.self, forKey: .is_verified)
        let isVerifiedNumValue = try container.decodeIfPresent(Int.self, forKey: .isVerified)
        let isVerifiedSnakeNumValue = try container.decodeIfPresent(Int.self, forKey: .is_verified)
        
        if let value = isVerifiedValue {
            isVerified = value
        } else if let value = isVerifiedSnakeValue {
            isVerified = value
        } else if let value = isVerifiedNumValue {
            isVerified = value != 0
        } else if let value = isVerifiedSnakeNumValue {
            isVerified = value != 0
        } else {
            isVerified = nil
        }
        
        // Date fields - FIX: Use if-let instead of ??
        let createdAtValue = try container.decodeIfPresent(String.self, forKey: .createdAt)
        if let createdAtDate = createdAtValue {
            createdAt = createdAtDate
        } else {
            createdAt = try container.decodeIfPresent(String.self, forKey: .created_at)
        }
        
        // Handle arrays that might be null
        notes = try container.decodeIfPresent([UserNote].self, forKey: .notes)
        
        // Handle notification array
        if let notifications = try container.decodeIfPresent([String].self, forKey: .notificationAssignedAt) {
            notificationAssignedAt = notifications
        } else {
            notificationAssignedAt = try container.decodeIfPresent([String].self, forKey: .notification_assigned_at)
        }
    }
    
    // Add encode method to comply with Encodable protocol
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(username, forKey: .username)
        try container.encode(firstname, forKey: .firstname)
        try container.encode(lastname, forKey: .lastname)
        
        // Encode optional fields
        try container.encodeIfPresent(isAdmin, forKey: .isAdmin)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(avatarContentType, forKey: .avatarContentType)
        try container.encodeIfPresent(place, forKey: .place)
        try container.encodeIfPresent(street, forKey: .street)
        try container.encodeIfPresent(telephone, forKey: .telephone)
        try container.encodeIfPresent(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(notificationAssignedAt, forKey: .notificationAssignedAt)
    }
    
    // Convenience initializer for manual creation (used in fallbacks)
    init(id: String, email: String, username: String, firstname: String, lastname: String,
         isAdmin: Bool? = nil, avatar: String? = nil, avatarContentType: String? = nil,
         place: String? = nil, street: String? = nil, telephone: String? = nil,
         isVerified: Bool? = nil, createdAt: String? = nil, notes: [UserNote]? = nil,
         notificationAssignedAt: [String]? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.firstname = firstname
        self.lastname = lastname
        self.isAdmin = isAdmin
        self.avatar = avatar
        self.avatarContentType = avatarContentType
        self.place = place
        self.street = street
        self.telephone = telephone
        self.isVerified = isVerified
        self.createdAt = createdAt
        self.notes = notes
        self.notificationAssignedAt = notificationAssignedAt
    }
}

struct UserNote: Codable {
    let comments: String?
    let id: String
    let createdAt: String?
    let updatedAt: String?

    // FIX: Only define the needed CodingKeys and handle "_id" using string value in init
    private enum CodingKeys: String, CodingKey {
        case comments
        case id = "_id"
        case createdAt, created_at
        case updatedAt, updated_at
    }
    
    // Custom initializer to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Only try to decode using the defined .id case
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else {
            // Just provide a default if missing
            id = "unknown"
        }
        
        comments = try container.decodeIfPresent(String.self, forKey: .comments)
        
        // Handle date fields with different naming conventions
        let createdAtValue = try container.decodeIfPresent(String.self, forKey: .createdAt)
        if let createdAtDate = createdAtValue {
            createdAt = createdAtDate
        } else {
            createdAt = try container.decodeIfPresent(String.self, forKey: .created_at)
        }
            
        let updatedAtValue = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        if let updatedAtDate = updatedAtValue {
            updatedAt = updatedAtDate
        } else {
            updatedAt = try container.decodeIfPresent(String.self, forKey: .updated_at)
        }
    }
    
    // Add encode method to comply with Encodable protocol
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(comments, forKey: .comments)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    // Manual initializer
    init(comments: String?, id: String, createdAt: String?, updatedAt: String?) {
        self.comments = comments
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

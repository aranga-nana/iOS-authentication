import Foundation

// MARK: - User Model

struct User: Identifiable, Codable {
    let id: String
    let email: String?
    let displayName: String?
    let profilePicture: String?
    let createdAt: Date?
    let updatedAt: Date?
    let lastLoginAt: Date?
    let isActive: Bool
    
    // Computed properties
    var initials: String {
        let name = displayName ?? email ?? "Anonymous"
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
    
    var displayTitle: String {
        return displayName ?? email?.components(separatedBy: "@").first ?? "Anonymous User"
    }
}

// MARK: - User Extensions

extension User {
    // Initialize from Firebase User
    init(from firebaseUser: Firebase.User) {
        self.id = firebaseUser.uid
        self.email = firebaseUser.email
        self.displayName = firebaseUser.displayName
        self.profilePicture = firebaseUser.photoURL?.absoluteString
        self.createdAt = firebaseUser.metadata.creationDate
        self.updatedAt = Date()
        self.lastLoginAt = firebaseUser.metadata.lastSignInDate
        self.isActive = true
    }
    
    // Initialize from API response
    init(from apiResponse: UserAPIResponse) {
        self.id = apiResponse.userId
        self.email = apiResponse.email
        self.displayName = apiResponse.displayName
        self.profilePicture = apiResponse.profilePicture
        self.createdAt = DateFormatter.iso8601.date(from: apiResponse.createdAt ?? "")
        self.updatedAt = DateFormatter.iso8601.date(from: apiResponse.updatedAt ?? "")
        self.lastLoginAt = DateFormatter.iso8601.date(from: apiResponse.lastLoginAt ?? "")
        self.isActive = apiResponse.isActive ?? true
    }
}

// MARK: - API Response Models

struct UserAPIResponse: Codable {
    let userId: String
    let email: String?
    let displayName: String?
    let profilePicture: String?
    let createdAt: String?
    let updatedAt: String?
    let lastLoginAt: String?
    let isActive: Bool?
    let preferences: [String: Any]?
    
    // Custom decoder for handling Any type in preferences
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        profilePicture = try container.decodeIfPresent(String.self, forKey: .profilePicture)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        lastLoginAt = try container.decodeIfPresent(String.self, forKey: .lastLoginAt)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        
        // Handle preferences as dictionary
        if let preferencesData = try container.decodeIfPresent(Data.self, forKey: .preferences) {
            preferences = try JSONSerialization.jsonObject(with: preferencesData) as? [String: Any]
        } else {
            preferences = nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case userId, email, displayName, profilePicture
        case createdAt, updatedAt, lastLoginAt, isActive, preferences
    }
}

struct BackendAuthResponse: Codable {
    let success: Bool
    let message: String
    let user: UserAPIResponse
    let accessToken: String
}

struct UserRegistrationData: Codable {
    let displayName: String?
    let profilePicture: String?
    let authMethod: String
    let preferences: [String: Any]?
    
    init(displayName: String?, profilePicture: String?, authMethod: String, preferences: [String: Any]? = nil) {
        self.displayName = displayName
        self.profilePicture = profilePicture
        self.authMethod = authMethod
        self.preferences = preferences
    }
    
    // Custom encoder for handling Any type in preferences
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(profilePicture, forKey: .profilePicture)
        try container.encode(authMethod, forKey: .authMethod)
        
        if let preferences = preferences {
            let data = try JSONSerialization.data(withJSONObject: preferences)
            try container.encode(data, forKey: .preferences)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case displayName, profilePicture, authMethod, preferences
    }
}

// MARK: - Profile Update Models

struct ProfileUpdateRequest: Codable {
    let displayName: String?
    let profilePicture: String?
    let preferences: [String: Any]?
    
    init(displayName: String? = nil, profilePicture: String? = nil, preferences: [String: Any]? = nil) {
        self.displayName = displayName
        self.profilePicture = profilePicture
        self.preferences = preferences
    }
    
    // Custom encoder for handling Any type in preferences
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(profilePicture, forKey: .profilePicture)
        
        if let preferences = preferences {
            let data = try JSONSerialization.data(withJSONObject: preferences)
            try container.encode(data, forKey: .preferences)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case displayName, profilePicture, preferences
    }
}

// MARK: - Error Models

struct APIErrorResponse: Codable {
    let error: Bool
    let message: String
    let errorCode: String?
    let timestamp: String
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    var notifications: Bool = true
    var biometricEnabled: Bool = false
    var theme: AppTheme = .system
    var language: String = "en"
    var autoLock: Bool = true
    var autoLockDuration: Int = 300 // 5 minutes in seconds
    
    // Convert to dictionary for API
    func toDictionary() -> [String: Any] {
        return [
            "notifications": notifications,
            "biometricEnabled": biometricEnabled,
            "theme": theme.rawValue,
            "language": language,
            "autoLock": autoLock,
            "autoLockDuration": autoLockDuration
        ]
    }
    
    // Initialize from dictionary
    init(from dictionary: [String: Any]? = nil) {
        guard let dict = dictionary else { return }
        
        notifications = dict["notifications"] as? Bool ?? true
        biometricEnabled = dict["biometricEnabled"] as? Bool ?? false
        theme = AppTheme(rawValue: dict["theme"] as? String ?? "system") ?? .system
        language = dict["language"] as? String ?? "en"
        autoLock = dict["autoLock"] as? Bool ?? true
        autoLockDuration = dict["autoLockDuration"] as? Int ?? 300
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

// MARK: - Authentication State

enum AuthenticationState {
    case unauthenticated
    case authenticated(User)
    case loading
    case error(String)
    case requiresBiometric
}

// MARK: - Form Validation

struct FormValidation {
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func isValidPassword(_ password: String) -> (isValid: Bool, message: String?) {
        guard password.count >= 8 else {
            return (false, "Password must be at least 8 characters long")
        }
        
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialCharacters = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil
        
        if !hasUppercase {
            return (false, "Password must contain at least one uppercase letter")
        }
        
        if !hasLowercase {
            return (false, "Password must contain at least one lowercase letter")
        }
        
        if !hasNumbers {
            return (false, "Password must contain at least one number")
        }
        
        if !hasSpecialCharacters {
            return (false, "Password must contain at least one special character")
        }
        
        return (true, nil)
    }
    
    static func isValidDisplayName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 50
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

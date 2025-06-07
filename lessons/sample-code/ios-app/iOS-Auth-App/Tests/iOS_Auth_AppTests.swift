import XCTest
@testable import iOS_Auth_App

class AuthenticationManagerTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    
    override func setUp() {
        super.setUp()
        authManager = AuthenticationManager.shared
    }
    
    override func tearDown() {
        authManager = nil
        super.tearDown()
    }
    
    // MARK: - Email Validation Tests
    
    func testValidEmailAddresses() {
        let validEmails = [
            "test@example.com",
            "user.name@domain.org",
            "user+tag@domain.co.uk",
            "123@domain.com"
        ]
        
        for email in validEmails {
            XCTAssertTrue(
                FormValidation.isValidEmail(email),
                "Email \(email) should be valid"
            )
        }
    }
    
    func testInvalidEmailAddresses() {
        let invalidEmails = [
            "invalid-email",
            "@domain.com",
            "user@",
            "user.domain.com",
            ""
        ]
        
        for email in invalidEmails {
            XCTAssertFalse(
                FormValidation.isValidEmail(email),
                "Email \(email) should be invalid"
            )
        }
    }
    
    // MARK: - Password Validation Tests
    
    func testValidPasswords() {
        let validPasswords = [
            "Password123!",
            "MySecure@Pass1",
            "Complex#Password2023"
        ]
        
        for password in validPasswords {
            let result = FormValidation.isValidPassword(password)
            XCTAssertTrue(result.isValid, "Password \(password) should be valid")
            XCTAssertNil(result.message, "Valid password should not have error message")
        }
    }
    
    func testInvalidPasswords() {
        let invalidPasswords = [
            ("short", "Password must be at least 8 characters long"),
            ("alllowercase123!", "Password must contain at least one uppercase letter"),
            ("ALLUPPERCASE123!", "Password must contain at least one lowercase letter"),
            ("NoNumbers!", "Password must contain at least one number"),
            ("NoSpecialChars123", "Password must contain at least one special character")
        ]
        
        for (password, expectedMessage) in invalidPasswords {
            let result = FormValidation.isValidPassword(password)
            XCTAssertFalse(result.isValid, "Password \(password) should be invalid")
            XCTAssertEqual(result.message, expectedMessage, "Error message should match expected")
        }
    }
    
    // MARK: - Display Name Tests
    
    func testValidDisplayNames() {
        let validNames = [
            "John Doe",
            "Jane",
            "User Name",
            "A"
        ]
        
        for name in validNames {
            XCTAssertTrue(
                FormValidation.isValidDisplayName(name),
                "Display name \(name) should be valid"
            )
        }
    }
    
    func testInvalidDisplayNames() {
        let invalidNames = [
            "",
            "   ",
            String(repeating: "A", count: 51) // Too long
        ]
        
        for name in invalidNames {
            XCTAssertFalse(
                FormValidation.isValidDisplayName(name),
                "Display name '\(name)' should be invalid"
            )
        }
    }
    
    // MARK: - User Model Tests
    
    func testUserInitialization() {
        let user = User(
            id: "test-id",
            email: "test@example.com",
            displayName: "Test User",
            profilePicture: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date(),
            isActive: true
        )
        
        XCTAssertEqual(user.id, "test-id")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertTrue(user.isActive)
    }
    
    func testUserInitials() {
        let userWithName = User(
            id: "1",
            email: "test@example.com",
            displayName: "John Doe",
            profilePicture: nil,
            createdAt: nil,
            updatedAt: nil,
            lastLoginAt: nil,
            isActive: true
        )
        XCTAssertEqual(userWithName.initials, "JD")
        
        let userWithEmail = User(
            id: "2",
            email: "jane@example.com",
            displayName: nil,
            profilePicture: nil,
            createdAt: nil,
            updatedAt: nil,
            lastLoginAt: nil,
            isActive: true
        )
        XCTAssertEqual(userWithEmail.initials, "JA")
    }
    
    func testUserDisplayTitle() {
        let userWithName = User(
            id: "1",
            email: "test@example.com",
            displayName: "John Doe",
            profilePicture: nil,
            createdAt: nil,
            updatedAt: nil,
            lastLoginAt: nil,
            isActive: true
        )
        XCTAssertEqual(userWithName.displayTitle, "John Doe")
        
        let userWithEmailOnly = User(
            id: "2",
            email: "jane@example.com",
            displayName: nil,
            profilePicture: nil,
            createdAt: nil,
            updatedAt: nil,
            lastLoginAt: nil,
            isActive: true
        )
        XCTAssertEqual(userWithEmailOnly.displayTitle, "jane")
    }
    
    // MARK: - User Preferences Tests
    
    func testUserPreferencesInitialization() {
        let preferences = UserPreferences()
        
        XCTAssertTrue(preferences.notifications)
        XCTAssertFalse(preferences.biometricEnabled)
        XCTAssertEqual(preferences.theme, .system)
        XCTAssertEqual(preferences.language, "en")
        XCTAssertTrue(preferences.autoLock)
        XCTAssertEqual(preferences.autoLockDuration, 300)
    }
    
    func testUserPreferencesFromDictionary() {
        let dictionary: [String: Any] = [
            "notifications": false,
            "biometricEnabled": true,
            "theme": "dark",
            "language": "es",
            "autoLock": false,
            "autoLockDuration": 600
        ]
        
        let preferences = UserPreferences(from: dictionary)
        
        XCTAssertFalse(preferences.notifications)
        XCTAssertTrue(preferences.biometricEnabled)
        XCTAssertEqual(preferences.theme, .dark)
        XCTAssertEqual(preferences.language, "es")
        XCTAssertFalse(preferences.autoLock)
        XCTAssertEqual(preferences.autoLockDuration, 600)
    }
    
    func testUserPreferencesToDictionary() {
        var preferences = UserPreferences()
        preferences.notifications = false
        preferences.biometricEnabled = true
        preferences.theme = .light
        
        let dictionary = preferences.toDictionary()
        
        XCTAssertEqual(dictionary["notifications"] as? Bool, false)
        XCTAssertEqual(dictionary["biometricEnabled"] as? Bool, true)
        XCTAssertEqual(dictionary["theme"] as? String, "light")
    }
    
    // MARK: - App Theme Tests
    
    func testAppThemeDisplayNames() {
        XCTAssertEqual(AppTheme.light.displayName, "Light")
        XCTAssertEqual(AppTheme.dark.displayName, "Dark")
        XCTAssertEqual(AppTheme.system.displayName, "System")
    }
    
    func testAppThemeRawValues() {
        XCTAssertEqual(AppTheme.light.rawValue, "light")
        XCTAssertEqual(AppTheme.dark.rawValue, "dark")
        XCTAssertEqual(AppTheme.system.rawValue, "system")
    }
    
    // MARK: - Date Formatter Tests
    
    func testISO8601DateFormatter() {
        let dateString = "2023-12-01T10:30:00.000Z"
        let date = DateFormatter.iso8601.date(from: dateString)
        
        XCTAssertNotNil(date, "Should parse ISO8601 date string")
        
        if let date = date {
            let formattedString = DateFormatter.iso8601.string(from: date)
            XCTAssertEqual(formattedString, dateString, "Should format date back to original string")
        }
    }
    
    func testDisplayDateFormatter() {
        let date = Date()
        let formattedString = DateFormatter.display.string(from: date)
        
        XCTAssertFalse(formattedString.isEmpty, "Display formatter should return non-empty string")
    }
}

// MARK: - Network Manager Tests

class NetworkManagerTests: XCTestCase {
    
    var networkManager: NetworkManager!
    
    override func setUp() {
        super.setUp()
        networkManager = NetworkManager.shared
    }
    
    override func tearDown() {
        networkManager = nil
        super.tearDown()
    }
    
    func testAPIEndpointConstruction() {
        let endpoint = "/users/profile"
        let fullURL = networkManager.buildURL(for: endpoint)
        
        XCTAssertTrue(fullURL.absoluteString.contains(endpoint), "URL should contain endpoint")
        XCTAssertTrue(fullURL.absoluteString.hasPrefix("https://"), "URL should use HTTPS")
    }
    
    func testRequestHeadersContainRequiredFields() {
        let headers = networkManager.defaultHeaders()
        
        XCTAssertNotNil(headers["Content-Type"], "Should have Content-Type header")
        XCTAssertNotNil(headers["Accept"], "Should have Accept header")
        XCTAssertNotNil(headers["User-Agent"], "Should have User-Agent header")
    }
}

// MARK: - Validation Helpers Tests

class ValidationHelpersTests: XCTestCase {
    
    func testPasswordStrengthCalculation() {
        // Test weak passwords
        let weakPasswords = ["123456", "password", "abc123"]
        for password in weakPasswords {
            let strength = ValidationHelpers.calculatePasswordStrength(password)
            XCTAssertTrue(strength <= 2, "Password '\(password)' should be weak (strength <= 2)")
        }
        
        // Test strong passwords
        let strongPasswords = ["MySecure@Pass123", "Complex#Password2023"]
        for password in strongPasswords {
            let strength = ValidationHelpers.calculatePasswordStrength(password)
            XCTAssertTrue(strength >= 4, "Password '\(password)' should be strong (strength >= 4)")
        }
    }
    
    func testRealTimeEmailValidation() {
        let validEmail = "test@example.com"
        let invalidEmail = "invalid-email"
        
        XCTAssertTrue(ValidationHelpers.validateEmailRealTime(validEmail))
        XCTAssertFalse(ValidationHelpers.validateEmailRealTime(invalidEmail))
    }
    
    func testDisplayNameValidation() {
        let validNames = ["John Doe", "Jane", "User Name"]
        let invalidNames = ["", "   ", String(repeating: "A", count: 51)]
        
        for name in validNames {
            XCTAssertTrue(ValidationHelpers.validateDisplayName(name), "Name '\(name)' should be valid")
        }
        
        for name in invalidNames {
            XCTAssertFalse(ValidationHelpers.validateDisplayName(name), "Name '\(name)' should be invalid")
        }
    }
}

// MARK: - Mock Classes for Testing

class MockAuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func signIn(email: String, password: String) async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if email == "test@example.com" && password == "Password123!" {
            currentUser = User(
                id: "mock-user-id",
                email: email,
                displayName: "Test User",
                profilePicture: nil,
                createdAt: Date(),
                updatedAt: Date(),
                lastLoginAt: Date(),
                isActive: true
            )
            isAuthenticated = true
        } else {
            errorMessage = "Invalid credentials"
        }
        
        isLoading = false
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }
}

// MARK: - Performance Tests

class PerformanceTests: XCTestCase {
    
    func testPasswordValidationPerformance() {
        let password = "MySecure@Password123"
        
        measure {
            for _ in 0..<1000 {
                _ = FormValidation.isValidPassword(password)
            }
        }
    }
    
    func testEmailValidationPerformance() {
        let email = "test@example.com"
        
        measure {
            for _ in 0..<1000 {
                _ = FormValidation.isValidEmail(email)
            }
        }
    }
    
    func testUserInitialsPerformance() {
        let user = User(
            id: "test-id",
            email: "test@example.com",
            displayName: "John Doe Smith Johnson",
            profilePicture: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date(),
            isActive: true
        )
        
        measure {
            for _ in 0..<1000 {
                _ = user.initials
            }
        }
    }
}

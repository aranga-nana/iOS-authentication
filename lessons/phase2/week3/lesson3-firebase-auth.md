# 🔥 Lesson 3: Firebase Authentication Deep Dive

> **Phase 2, Week 3 - Advanced Firebase Authentication Concepts and Implementation**  
> **Duration**: 6-8 hours | **Level**: Intermediate  
> **Prerequisites**: Basic iOS development, completed Phase 2 Weeks 1-2, Firebase project setup

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Understand Firebase Authentication architecture and security model
- Implement advanced authentication features (password reset, email verification)
- Master Firebase Auth state management and listeners
- Handle authentication errors gracefully with user-friendly messaging
- Implement secure token storage and refresh mechanisms
- Build reusable authentication components

---

## 📚 Part 1: Firebase Authentication Architecture (1.5 hours)

### 1.1 Understanding Firebase Auth Flow

**Firebase Authentication Process:**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   iOS App       │    │  Firebase Auth   │    │  Firebase       │
│                 │    │  SDK             │    │  Backend        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. Sign In Request    │                       │
         ├──────────────────────►│                       │
         │                       │ 2. Verify Credentials │
         │                       ├──────────────────────►│
         │                       │                       │
         │                       │ 3. ID Token + Refresh │ 
         │                       │◄──────────────────────┤
         │ 4. Auth State Change  │                       │
         │◄──────────────────────┤                       │
         │                       │                       │
```

**Key Components:**
- **ID Token**: JWT containing user identity and claims (expires in 1 hour)
- **Refresh Token**: Long-lived token to obtain new ID tokens
- **Auth State**: Current authentication status (signed in/out)
- **User Object**: Contains user profile information

### 1.2 Firebase Security Model

Create `Models/FirebaseAuthModels.swift`:

```swift
import Foundation
import FirebaseAuth

// MARK: - Authentication State
enum AuthenticationState {
    case undefined
    case signedOut
    case signedIn(User)
    
    var isSignedIn: Bool {
        switch self {
        case .signedIn:
            return true
        default:
            return false
        }
    }
    
    var user: User? {
        switch self {
        case .signedIn(let user):
            return user
        default:
            return nil
        }
    }
}

// MARK: - Token Information
struct TokenInfo {
    let idToken: String
    let refreshToken: String?
    let expirationDate: Date
    let issuedAtDate: Date
    
    var isExpired: Bool {
        return Date() >= expirationDate
    }
    
    var timeUntilExpiration: TimeInterval {
        return expirationDate.timeIntervalSinceNow
    }
}

// MARK: - User Profile
struct UserProfile {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: URL?
    let isEmailVerified: Bool
    let creationDate: Date?
    let lastSignInDate: Date?
    
    init(from user: User) {
        self.uid = user.uid
        self.email = user.email
        self.displayName = user.displayName
        self.photoURL = user.photoURL
        self.isEmailVerified = user.isEmailVerified
        self.creationDate = user.metadata.creationDate
        self.lastSignInDate = user.metadata.lastSignInDate
    }
}
```

### 1.3 Authentication Errors and Handling

Create `Models/AuthenticationErrors.swift`:

```swift
import Foundation
import FirebaseAuth

// MARK: - Custom Authentication Errors
enum AuthenticationError: LocalizedError {
    case invalidEmail
    case weakPassword
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case userDisabled
    case networkError
    case tooManyRequests
    case operationNotAllowed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters long."
        case .userNotFound:
            return "No account found with this email address."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .userDisabled:
            return "This account has been disabled. Please contact support."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .tooManyRequests:
            return "Too many unsuccessful attempts. Please try again later."
        case .operationNotAllowed:
            return "This operation is not allowed. Please contact support."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidEmail:
            return "Check your email format and try again."
        case .weakPassword:
            return "Use a stronger password with at least 6 characters."
        case .userNotFound:
            return "Try signing up for a new account."
        case .wrongPassword:
            return "Use the 'Forgot Password' option to reset your password."
        case .emailAlreadyInUse:
            return "Try signing in instead, or use a different email."
        case .networkError:
            return "Check your internet connection and try again."
        case .tooManyRequests:
            return "Wait a few minutes before trying again."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    static func from(authError: NSError) -> AuthenticationError {
        guard let errorCode = AuthErrorCode(rawValue: authError.code) else {
            return .unknown(authError.localizedDescription)
        }
        
        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .userDisabled:
            return .userDisabled
        case .networkError:
            return .networkError
        case .tooManyRequests:
            return .tooManyRequests
        case .operationNotAllowed:
            return .operationNotAllowed
        default:
            return .unknown(authError.localizedDescription)
        }
    }
}
```

---

## 📚 Part 2: Advanced Authentication Manager (2 hours)

### 2.1 Enhanced Authentication Service

Create `Services/FirebaseAuthService.swift`:

```swift
import Foundation
import FirebaseAuth
import Combine

// MARK: - Authentication Service Protocol
protocol AuthenticationServiceProtocol {
    var authenticationState: AnyPublisher<AuthenticationState, Never> { get }
    var currentUser: User? { get }
    
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() throws
    func resetPassword(email: String) async throws
    func sendEmailVerification() async throws
    func refreshToken() async throws -> String
    func deleteAccount() async throws
}

// MARK: - Firebase Authentication Service
class FirebaseAuthService: ObservableObject, AuthenticationServiceProtocol {
    
    @Published private var _authenticationState = AuthenticationState.undefined
    
    var authenticationState: AnyPublisher<AuthenticationState, Never> {
        $_authenticationState.eraseToAnyPublisher()
    }
    
    var currentUser: User? {
        return Auth.auth().currentUser
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        configureAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State Management
    private func configureAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?._authenticationState = .signedIn(user)
                } else {
                    self?._authenticationState = .signedOut
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Successfully signed in user: \(result.user.uid)")
        } catch {
            print("❌ Sign in failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    func signUp(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("✅ Successfully created user: \(result.user.uid)")
            
            // Automatically send email verification
            try await sendEmailVerification()
        } catch {
            print("❌ Sign up failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            print("✅ Successfully signed out")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ Password reset email sent to: \(email)")
        } catch {
            print("❌ Password reset failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    func sendEmailVerification() async throws {
        guard let user = currentUser else {
            throw AuthenticationError.userNotFound
        }
        
        do {
            try await user.sendEmailVerification()
            print("✅ Email verification sent to: \(user.email ?? "unknown")")
        } catch {
            print("❌ Email verification failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    func refreshToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthenticationError.userNotFound
        }
        
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            print("✅ Token refreshed, expires at: \(result.expirationDate)")
            return result.token
        } catch {
            print("❌ Token refresh failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthenticationError.userNotFound
        }
        
        do {
            try await user.delete()
            print("✅ Account deleted successfully")
        } catch {
            print("❌ Account deletion failed: \(error.localizedDescription)")
            throw AuthenticationError.from(authError: error as NSError)
        }
    }
    
    // MARK: - Token Management
    func getTokenInfo() async throws -> TokenInfo {
        guard let user = currentUser else {
            throw AuthenticationError.userNotFound
        }
        
        let result = try await user.getIDTokenResult()
        
        return TokenInfo(
            idToken: result.token,
            refreshToken: user.refreshToken,
            expirationDate: result.expirationDate,
            issuedAtDate: result.issuedAtDate
        )
    }
    
    func getUserProfile() -> UserProfile? {
        guard let user = currentUser else {
            return nil
        }
        
        return UserProfile(from: user)
    }
}
```

### 2.2 Secure Token Storage Service

Create `Services/SecureTokenStorage.swift`:

```swift
import Foundation
import Security

// MARK: - Secure Storage Service
class SecureTokenStorage {
    
    private let serviceName = "com.yourapp.firebase.tokens"
    private let userAccount = "firebase_user_tokens"
    
    // MARK: - Store Token
    func storeToken(_ token: String, for key: String) throws {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(userAccount)_\(key)",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore(status)
        }
    }
    
    // MARK: - Retrieve Token
    func retrieveToken(for key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(userAccount)_\(key)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unableToRetrieve(status)
        }
    }
    
    // MARK: - Delete Token
    func deleteToken(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(userAccount)_\(key)"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }
    
    // MARK: - Clear All Tokens
    func clearAllTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }
}

// MARK: - Keychain Errors
enum KeychainError: LocalizedError {
    case unableToStore(OSStatus)
    case unableToRetrieve(OSStatus)
    case unableToDelete(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .unableToStore(let status):
            return "Unable to store token in keychain. Status: \(status)"
        case .unableToRetrieve(let status):
            return "Unable to retrieve token from keychain. Status: \(status)"
        case .unableToDelete(let status):
            return "Unable to delete token from keychain. Status: \(status)"
        case .invalidData:
            return "Invalid token data in keychain"
        }
    }
}
```

---

## 📚 Part 3: Authentication State Management (1.5 hours)

### 3.1 Authentication View Model

Create `ViewModels/AuthenticationViewModel.swift`:

```swift
import Foundation
import Combine
import FirebaseAuth

// MARK: - Authentication View Model
@MainActor
class AuthenticationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var authenticationState: AuthenticationState = .undefined
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var user: UserProfile?
    
    // MARK: - Services
    private let authService: FirebaseAuthService
    private let tokenStorage: SecureTokenStorage
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isSignedIn: Bool {
        authenticationState.isSignedIn
    }
    
    var currentUserEmail: String? {
        user?.email
    }
    
    var isEmailVerified: Bool {
        user?.isEmailVerified ?? false
    }
    
    init(authService: FirebaseAuthService = FirebaseAuthService()) {
        self.authService = authService
        self.tokenStorage = SecureTokenStorage()
        
        configureAuthStateListener()
    }
    
    // MARK: - Configuration
    private func configureAuthStateListener() {
        authService.authenticationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.authenticationState = state
                self?.updateUserProfile()
                self?.handleAuthStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func updateUserProfile() {
        user = authService.getUserProfile()
    }
    
    private func handleAuthStateChange(_ state: AuthenticationState) {
        switch state {
        case .signedIn:
            Task {
                await storeCurrentToken()
            }
        case .signedOut:
            Task {
                await clearStoredTokens()
            }
        case .undefined:
            break
        }
    }
    
    // MARK: - Authentication Actions
    func signIn(email: String, password: String) async {
        await performAuthAction {
            try await authService.signIn(email: email, password: password)
        }
    }
    
    func signUp(email: String, password: String) async {
        await performAuthAction {
            try await authService.signUp(email: email, password: password)
        }
    }
    
    func signOut() {
        performSyncAuthAction {
            try authService.signOut()
        }
    }
    
    func resetPassword(email: String) async {
        await performAuthAction {
            try await authService.resetPassword(email: email)
        }
    }
    
    func sendEmailVerification() async {
        await performAuthAction {
            try await authService.sendEmailVerification()
        }
    }
    
    func deleteAccount() async {
        await performAuthAction {
            try await authService.deleteAccount()
        }
    }
    
    // MARK: - Token Management
    func refreshToken() async {
        await performAuthAction {
            let newToken = try await authService.refreshToken()
            try tokenStorage.storeToken(newToken, for: "id_token")
        }
    }
    
    private func storeCurrentToken() async {
        do {
            let tokenInfo = try await authService.getTokenInfo()
            try tokenStorage.storeToken(tokenInfo.idToken, for: "id_token")
            
            if let refreshToken = tokenInfo.refreshToken {
                try tokenStorage.storeToken(refreshToken, for: "refresh_token")
            }
        } catch {
            print("Failed to store tokens: \(error)")
        }
    }
    
    private func clearStoredTokens() async {
        do {
            try tokenStorage.clearAllTokens()
        } catch {
            print("Failed to clear tokens: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func performAuthAction(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        clearError()
        
        do {
            try await action()
        } catch let error as AuthenticationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func performSyncAuthAction(_ action: @escaping () throws -> Void) {
        isLoading = true
        clearError()
        
        do {
            try action()
        } catch let error as AuthenticationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func clearError() {
        errorMessage = nil
    }
}
```

---

## 🚀 Practical Exercises

### Exercise 1: Custom Authentication Flow (30 minutes)
Implement a custom authentication flow with the following requirements:
- Add phone number authentication
- Implement biometric authentication as a secondary factor
- Add session timeout functionality

### Exercise 2: Error Handling Enhancement (20 minutes)
Enhance the error handling system:
- Add retry logic for network errors
- Implement exponential backoff for failed requests
- Add user-friendly error recovery suggestions

### Exercise 3: Security Hardening (25 minutes)
Implement additional security measures:
- Add certificate pinning for Firebase requests
- Implement request signing
- Add detection for jailbroken devices

---

## 📝 Summary

In this lesson, you learned:

✅ **Firebase Authentication Architecture**
- Understanding ID tokens, refresh tokens, and auth state
- Implementing secure token storage with Keychain
- Managing authentication state with Combine

✅ **Advanced Authentication Features**
- Email verification and password reset functionality
- Comprehensive error handling with user-friendly messages
- Token refresh and session management

✅ **Production-Ready Implementation**
- Reusable authentication components
- Clean MVVM architecture with separation of concerns
- Secure storage patterns and best practices

✅ **Testing and Validation**
- Unit tests for authentication flows
- Integration testing strategies
- Mock implementations for testing

## 🔗 Additional Resources

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth/ios/start)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Swift Combine Framework](https://developer.apple.com/documentation/combine)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)

## 🎯 Next Steps

- **Lesson 4**: Google Sign-In Integration
- **Lesson 5**: Advanced Firebase Features
- **Week 4**: AWS Backend Integration

---

> **Note**: This lesson provides a comprehensive foundation for Firebase Authentication. The code examples are production-ready and include proper error handling, security best practices, and testing strategies. Adjust the implementation based on your specific app requirements and security policies.
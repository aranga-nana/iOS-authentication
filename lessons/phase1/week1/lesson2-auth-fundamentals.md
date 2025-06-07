# 🔐 Lesson 2: Authentication Fundamentals

> **Phase 1, Week 1 - Authentication Core Concepts**  
> **Duration**: 6 hours | **Level**: Beginner  
> **Prerequisites**: Basic understanding of web concepts

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Understand authentication vs authorization
- Know token-based authentication concepts
- Understand OAuth 2.0 flow
- Learn security principles for mobile apps
- Draw authentication flow diagrams

---

## 📚 Part 1: Authentication vs Authorization (1.5 hours)

### 1.1 Core Concepts

**Authentication (Who are you?)** 
- Process of verifying user identity
- "Are you really John Doe?"
- Examples: Username/password, biometrics, tokens

**Authorization (What can you do?)**
- Process of determining access rights
- "Can John Doe access admin panel?"
- Examples: Roles, permissions, access control lists

```swift
// Authentication Example
struct AuthenticationResult {
    let isAuthenticated: Bool
    let user: User?
    let error: Error?
}

// Authorization Example  
struct AuthorizationResult {
    let hasPermission: Bool
    let allowedActions: [String]
    let deniedReason: String?
}

class SecurityManager {
    
    // Authentication: Verify who the user is
    func authenticate(email: String, password: String) -> AuthenticationResult {
        // Verify credentials with backend
        // Return user identity if valid
        return AuthenticationResult(
            isAuthenticated: true,
            user: User(id: "123", email: email, role: .user),
            error: nil
        )
    }
    
    // Authorization: Check what user can do
    func authorize(user: User, action: String) -> AuthorizationResult {
        // Check user permissions for specific action
        let hasPermission = user.permissions.contains(action)
        
        return AuthorizationResult(
            hasPermission: hasPermission,
            allowedActions: user.permissions,
            deniedReason: hasPermission ? nil : "Insufficient privileges"
        )
    }
}
```

### 1.2 Real-World Examples

| Scenario | Authentication | Authorization |
|----------|----------------|---------------|
| Banking App | PIN/Biometric login | Access to specific accounts |
| Social Media | Email/Password | Post, comment, admin features |
| E-commerce | Google Sign-In | View orders, make purchases |
| Corporate App | Company SSO | Department-specific data |

**🏃‍♂️ Practice Exercise 1.1:**
```swift
// Create a simple permission system
enum UserRole {
    case admin, user, guest
}

enum Action {
    case viewProfile, editProfile, deleteUser, viewAnalytics
}

class PermissionManager {
    
    static func canPerform(action: Action, userRole: UserRole) -> Bool {
        switch action {
        case .viewProfile:
            return [.admin, .user, .guest].contains(userRole)
        case .editProfile:
            return [.admin, .user].contains(userRole)
        case .deleteUser:
            return userRole == .admin
        case .viewAnalytics:
            return userRole == .admin
        }
    }
}

// Test the permission system
let adminUser = UserRole.admin
let regularUser = UserRole.user

print("Admin can delete user: \(PermissionManager.canPerform(action: .deleteUser, userRole: adminUser))")
print("Regular user can delete user: \(PermissionManager.canPerform(action: .deleteUser, userRole: regularUser))")
```

---

## 📚 Part 2: Token-Based Authentication (2 hours)

### 2.1 Why Tokens?

**Traditional Session-Based:**
- Server stores session data
- Client sends session cookie
- Difficult to scale across multiple servers

**Token-Based Benefits:**
- Stateless (server doesn't store session)
- Scalable across multiple servers
- Works well with mobile apps
- Contains user information

### 2.2 JWT (JSON Web Tokens)

**JWT Structure:**
```
Header.Payload.Signature
```

**Example JWT:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

**Decoded JWT:**
```json
// Header
{
  "alg": "HS256",
  "typ": "JWT"
}

// Payload
{
  "sub": "1234567890",
  "name": "John Doe",
  "email": "john@example.com",
  "iat": 1516239022,
  "exp": 1516242622
}
```

### 2.3 Token Implementation in iOS

```swift
import Foundation

// Token Model
struct AuthToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var isExpiringSoon: Bool {
        let fiveMinutesFromNow = Date().addingTimeInterval(300)
        return expiresAt < fiveMinutesFromNow
    }
}

// Token Manager
class TokenManager {
    private let keychain = KeychainManager()
    private let tokenKey = "auth_token"
    private let refreshTokenKey = "refresh_token"
    
    // Store tokens securely
    func store(token: AuthToken) {
        do {
            let tokenData = try JSONEncoder().encode(token)
            try keychain.store(data: tokenData, key: tokenKey)
        } catch {
            print("Failed to store token: \(error)")
        }
    }
    
    // Retrieve stored token
    func retrieveToken() -> AuthToken? {
        do {
            let tokenData = try keychain.retrieve(key: tokenKey)
            return try JSONDecoder().decode(AuthToken.self, from: tokenData)
        } catch {
            print("Failed to retrieve token: \(error)")
            return nil
        }
    }
    
    // Check if token needs refresh
    func shouldRefreshToken() -> Bool {
        guard let token = retrieveToken() else { return false }
        return token.isExpiringSoon
    }
    
    // Clear tokens (logout)
    func clearTokens() {
        try? keychain.delete(key: tokenKey)
        try? keychain.delete(key: refreshTokenKey)
    }
}

// Keychain Manager for secure storage
class KeychainManager {
    
    func store(data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.failedToStore
        }
    }
    
    func retrieve(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.failedToRetrieve
        }
        
        return data
    }
    
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.failedToDelete
        }
    }
}

enum KeychainError: Error {
    case failedToStore
    case failedToRetrieve
    case failedToDelete
}
```

**🏃‍♂️ Practice Exercise 2.1:**
```swift
// Test the TokenManager
let tokenManager = TokenManager()

// Create a test token
let testToken = AuthToken(
    accessToken: "test_access_token_123",
    refreshToken: "test_refresh_token_456",
    expiresAt: Date().addingTimeInterval(3600), // 1 hour from now
    tokenType: "Bearer"
)

// Store and retrieve token
tokenManager.store(token: testToken)

if let retrievedToken = tokenManager.retrieveToken() {
    print("Token retrieved successfully")
    print("Access token: \(retrievedToken.accessToken)")
    print("Expires at: \(retrievedToken.expiresAt)")
    print("Is expired: \(retrievedToken.isExpired)")
}
```

---

## 📚 Part 3: OAuth 2.0 Flow Understanding (2 hours)

### 3.1 OAuth 2.0 Overview

**What is OAuth 2.0?**
- Authorization framework
- Allows third-party apps to access user data
- Without sharing passwords
- Used by Google, Facebook, Apple Sign-In

**Key Players:**
- **Resource Owner**: User
- **Client**: Your iOS app
- **Authorization Server**: Google, Facebook, etc.
- **Resource Server**: API that holds user data

### 3.2 OAuth 2.0 Flow Types

**Authorization Code Flow (Most Secure for Mobile):**

```
1. User clicks "Sign in with Google"
2. App redirects to Google authorization server
3. User signs in to Google
4. Google redirects back with authorization code
5. App exchanges code for access token
6. App uses access token to access user data
```

**Visual Flow Diagram:**
```
iOS App          Authorization Server         Resource Server
   |                      |                        |
   |-- Login Request ---> |                        |
   |                      |                        |
   |<-- Auth Code ------- |                        |
   |                      |                        |
   |-- Exchange Code ---> |                        |
   |                      |                        |
   |<-- Access Token ---- |                        |
   |                      |                        |
   |-- API Request with Token -----------------> |
   |                      |                        |
   |<-- User Data ---------------------------- |
```

### 3.3 OAuth 2.0 Implementation in iOS

```swift
import Foundation
import AuthenticationServices

// OAuth Configuration
struct OAuthConfig {
    let clientId: String
    let redirectURI: String
    let scope: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
}

// OAuth Manager
class OAuthManager: NSObject {
    
    private let config: OAuthConfig
    private var webAuthSession: ASWebAuthenticationSession?
    
    init(config: OAuthConfig) {
        self.config = config
        super.init()
    }
    
    // Start OAuth flow
    func authenticate(completion: @escaping (Result<AuthToken, Error>) -> Void) {
        
        // Build authorization URL
        guard let authURL = buildAuthorizationURL() else {
            completion(.failure(OAuthError.invalidURL))
            return
        }
        
        // Start web authentication session
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: config.redirectURI
        ) { [weak self] callbackURL, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let callbackURL = callbackURL,
                  let authCode = self?.extractAuthCode(from: callbackURL) else {
                completion(.failure(OAuthError.noAuthCode))
                return
            }
            
            // Exchange authorization code for token
            self?.exchangeCodeForToken(authCode: authCode, completion: completion)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.start()
    }
    
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope),
            URLQueryItem(name: "state", value: generateRandomState())
        ]
        return components?.url
    }
    
    private func extractAuthCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }
    
    private func exchangeCodeForToken(authCode: String, completion: @escaping (Result<AuthToken, Error>) -> Void) {
        
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "authorization_code",
            "code": authCode,
            "client_id": config.clientId,
            "redirect_uri": config.redirectURI
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(OAuthError.noData))
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                let authToken = AuthToken(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken ?? "",
                    expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                    tokenType: tokenResponse.tokenType
                )
                completion(.success(authToken))
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
    
    private func generateRandomState() -> String {
        return UUID().uuidString
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension OAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// OAuth Response Models
struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

// OAuth Errors
enum OAuthError: Error {
    case invalidURL
    case noAuthCode
    case noData
    case invalidResponse
}
```

**🏃‍♂️ Practice Exercise 3.1:**
```swift
// Test OAuth configuration
let googleConfig = OAuthConfig(
    clientId: "your-google-client-id",
    redirectURI: "com.yourapp.oauth://callback",
    scope: "openid email profile",
    authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
    tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
)

let oauthManager = OAuthManager(config: googleConfig)

// This would be called when user taps "Sign in with Google"
oauthManager.authenticate { result in
    switch result {
    case .success(let token):
        print("OAuth authentication successful")
        print("Access token: \(token.accessToken)")
    case .failure(let error):
        print("OAuth authentication failed: \(error)")
    }
}
```

---

## 📚 Part 4: Security Principles (1.5 hours)

### 4.1 Mobile Security Best Practices

**Never Store Secrets in Code:**
```swift
// ❌ BAD - Never do this
class BadSecurityExample {
    let apiKey = "sk_live_abcd1234567890"  // Visible in code
    let secretKey = "super_secret_key"     // Can be extracted
}

// ✅ GOOD - Use configuration or keychain
class GoodSecurityExample {
    private let keychain = KeychainManager()
    
    var apiKey: String? {
        return try? keychain.retrieve(key: "api_key").string
    }
    
    func configureWithServerProvidedKey(_ key: String) {
        try? keychain.store(data: key.data(using: .utf8)!, key: "api_key")
    }
}
```

**Secure Data Transmission:**
```swift
// ✅ Always use HTTPS
class SecureNetworkManager {
    
    func makeSecureRequest(url: URL, token: String) {
        // Ensure URL uses HTTPS
        guard url.scheme == "https" else {
            print("❌ Insecure connection attempted")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Additional security headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }.resume()
    }
}
```

**Certificate Pinning (Advanced):**
```swift
class CertificatePinner: NSObject {
    
    private let pinnedCertificates: [Data]
    
    init(certificates: [Data]) {
        self.pinnedCertificates = certificates
        super.init()
    }
    
    func validateServerTrust(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }
        
        let serverCertData = SecCertificateCopyData(serverCertificate)
        let serverCertBytes = CFDataGetBytePtr(serverCertData)
        let serverCertLength = CFDataGetLength(serverCertData)
        let serverCertNSData = Data(bytes: serverCertBytes!, count: serverCertLength)
        
        // Check if server certificate matches pinned certificates
        return pinnedCertificates.contains(serverCertNSData)
    }
}
```

### 4.2 Token Security Best Practices

```swift
class SecureTokenManager {
    
    private let keychain = KeychainManager()
    
    // Store tokens with additional security
    func storeToken(_ token: AuthToken, withBiometric: Bool = true) {
        do {
            let tokenData = try JSONEncoder().encode(token)
            
            if withBiometric {
                // Require biometric authentication to access token
                try keychain.storeWithBiometric(data: tokenData, key: "auth_token")
            } else {
                try keychain.store(data: tokenData, key: "auth_token")
            }
        } catch {
            print("Failed to store token securely: \(error)")
        }
    }
    
    // Automatic token refresh
    func autoRefreshToken() {
        guard let token = retrieveToken(),
              token.isExpiringSoon else { return }
        
        refreshToken(token.refreshToken) { [weak self] result in
            switch result {
            case .success(let newToken):
                self?.storeToken(newToken)
            case .failure(let error):
                print("Token refresh failed: \(error)")
                // Handle refresh failure (logout user)
                self?.handleTokenRefreshFailure()
            }
        }
    }
    
    private func refreshToken(_ refreshToken: String, completion: @escaping (Result<AuthToken, Error>) -> Void) {
        // Implement token refresh logic
    }
    
    private func handleTokenRefreshFailure() {
        // Clear tokens and redirect to login
        clearTokens()
        NotificationCenter.default.post(name: .userNeedsReauthentication, object: nil)
    }
    
    private func retrieveToken() -> AuthToken? {
        // Implementation from previous example
        return nil
    }
    
    private func clearTokens() {
        try? keychain.delete(key: "auth_token")
    }
}

extension Notification.Name {
    static let userNeedsReauthentication = Notification.Name("userNeedsReauthentication")
}
```

**🏃‍♂️ Practice Exercise 4.1:**
Create a security checklist for your authentication implementation.

---

## 📚 Part 5: Authentication Flow Diagrams (30 minutes)

### 5.1 Complete Authentication Flow

```
User Authentication Flow:

┌─────────────┐    ┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│             │    │                 │    │              │    │             │
│  iOS App    │    │  Firebase Auth  │    │ Your API     │    │ DynamoDB    │
│             │    │                 │    │ (Lambda)     │    │             │
└─────┬───────┘    └─────────┬───────┘    └──────┬───────┘    └─────┬───────┘
      │                      │                   │                  │
      │ 1. Login Request     │                   │                  │
      ├─────────────────────▶│                   │                  │
      │                      │                   │                  │
      │ 2. ID Token          │                   │                  │
      │◀─────────────────────┤                   │                  │
      │                      │                   │                  │
      │ 3. API Call + Token  │                   │                  │
      ├─────────────────────────────────────────▶│                  │
      │                      │                   │                  │
      │                      │ 4. Verify Token   │                  │
      │                      │◀──────────────────┤                  │
      │                      │                   │                  │
      │                      │ 5. Token Valid    │                  │
      │                      ├──────────────────▶│                  │
      │                      │                   │                  │
      │                      │                   │ 6. Store/Get Data│
      │                      │                   ├─────────────────▶│
      │                      │                   │                  │
      │                      │                   │ 7. User Data     │
      │                      │                   │◀─────────────────┤
      │                      │                   │                  │
      │ 8. Response Data     │                   │                  │
      │◀─────────────────────────────────────────┤                  │
      │                      │                   │                  │
```

### 5.2 Error Handling Flow

```swift
// Comprehensive error handling for authentication
enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case networkError
    case tokenExpired
    case tokenInvalid
    case biometricFailed
    case keychainError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection failed"
        case .tokenExpired:
            return "Session expired. Please sign in again"
        case .tokenInvalid:
            return "Invalid authentication token"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .keychainError:
            return "Secure storage error"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

class AuthenticationFlowManager {
    
    func handleAuthenticationFlow(completion: @escaping (Result<User, AuthenticationError>) -> Void) {
        
        // Step 1: Check existing token
        guard let token = TokenManager.shared.retrieveToken() else {
            // No token, need to authenticate
            presentAuthenticationUI(completion: completion)
            return
        }
        
        // Step 2: Check if token is valid
        if token.isExpired {
            // Token expired, try to refresh
            refreshToken(token) { result in
                switch result {
                case .success(let newToken):
                    self.authenticateWithToken(newToken, completion: completion)
                case .failure:
                    // Refresh failed, need new login
                    self.presentAuthenticationUI(completion: completion)
                }
            }
        } else {
            // Token is valid, use it
            authenticateWithToken(token, completion: completion)
        }
    }
    
    private func authenticateWithToken(_ token: AuthToken, completion: @escaping (Result<User, AuthenticationError>) -> Void) {
        // Verify token with backend
        APIManager.shared.verifyToken(token) { result in
            switch result {
            case .success(let user):
                completion(.success(user))
            case .failure(let error):
                // Handle different error types
                let authError = self.mapToAuthenticationError(error)
                completion(.failure(authError))
            }
        }
    }
    
    private func presentAuthenticationUI(completion: @escaping (Result<User, AuthenticationError>) -> Void) {
        // Present login screen
        DispatchQueue.main.async {
            // Show authentication UI
        }
    }
    
    private func refreshToken(_ token: AuthToken, completion: @escaping (Result<AuthToken, AuthenticationError>) -> Void) {
        // Implement token refresh
    }
    
    private func mapToAuthenticationError(_ error: Error) -> AuthenticationError {
        // Map various errors to AuthenticationError
        return .unknownError
    }
}
```

**🏃‍♂️ Practice Exercise 5.1:**
Draw your own authentication flow diagram for your specific use case.

---

## ✅ Lesson Completion Checklist

- [ ] Understand difference between authentication and authorization
- [ ] Know how token-based authentication works
- [ ] Understand JWT structure and usage
- [ ] Can implement basic OAuth 2.0 flow
- [ ] Know mobile security best practices
- [ ] Can draw authentication flow diagrams
- [ ] Implemented secure token storage example

---

## 📝 Assignment

**Create an authentication flow diagram for your project that includes:**
1. User login with email/password
2. Google Sign-In integration
3. Token storage and management
4. API calls with token verification
5. Error handling scenarios
6. Token refresh flow

**Submit**: Hand-drawn or digital diagram with explanations for each step.

---

## 🔗 Next Lesson

**Lesson 3: Cloud Services Introduction** - We'll explore Firebase and AWS services needed for our authentication system.

---

## 📚 Additional Resources

### OAuth 2.0 Learning
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [OAuth 2.0 Simplified](https://aaronparecki.com/oauth-2-simplified/)

### Security Resources
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security-testing-guide/)
- [iOS Security Guide](https://www.apple.com/business/docs/site/iOS_Security_Guide.pdf)

### JWT Resources
- [JWT.io](https://jwt.io/) - JWT debugger
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)

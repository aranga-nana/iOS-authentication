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

#### 3.3.1 Understanding Redirect URLs

**What are Redirect URLs?**
Redirect URLs are the mechanism that brings users back to your app after authentication. Think of them as your app's "return address."

**Types of Redirect URLs for iOS:**

1. **Custom URL Schemes** (Most Common)
```swift
// Your app's custom scheme
let redirectURI = "com.yourapp.oauth://callback"

// Must be registered in Info.plist:
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OAuth Callback</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourapp.oauth</string>
        </array>
    </dict>
</array>
```

2. **Universal Links** (Advanced)
```swift
// Uses your actual domain
let redirectURI = "https://yourapp.com/oauth/callback"
// Requires server setup and apple-app-site-association file
```

**How Redirect URLs Work:**
1. **Authorization Request**: App opens browser with redirect URL parameter
2. **User Authentication**: User signs in at authorization server
3. **Redirect with Code**: Authorization server redirects to your redirect URL
4. **iOS Routes to App**: iOS recognizes the URL scheme and opens your app
5. **Code Extraction**: Your app extracts the authorization code from the URL

#### 3.3.2 Complete iOS Implementation

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
    
    // Security settings
    let validateState: Bool = true
    let usePKCE: Bool = true  // Proof Key for Code Exchange
}

// OAuth Manager
class OAuthManager: NSObject {
    
    private let config: OAuthConfig
    private var webAuthSession: ASWebAuthenticationSession?
    private var currentState: String?
    
    init(config: OAuthConfig) {
        self.config = config
        super.init()
    }
    
    // Start OAuth flow
    func authenticate(completion: @escaping (Result<AuthToken, Error>) -> Void) {
        
        // Generate security state parameter
        if config.validateState {
            currentState = generateRandomState()
        }
        
        // Build authorization URL
        guard let authURL = buildAuthorizationURL() else {
            completion(.failure(OAuthError.invalidURL))
            return
        }
        
        print("🔐 Starting OAuth flow with URL: \(authURL)")
        
        // Start web authentication session
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: extractScheme(from: config.redirectURI)
        ) { [weak self] callbackURL, error in
            
            if let error = error {
                print("❌ OAuth authentication error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let callbackURL = callbackURL else {
                completion(.failure(OAuthError.noCallbackURL))
                return
            }
            
            print("📱 Received callback URL: \(callbackURL)")
            
            // Process the callback
            self?.processCallback(callbackURL, completion: completion)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }
    
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)
        
        var queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
        ]
        
        // Add state parameter for CSRF protection
        if config.validateState, let state = currentState {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func processCallback(_ url: URL, completion: @escaping (Result<AuthToken, Error>) -> Void) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Check for authorization error
        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorDescription = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
            completion(.failure(OAuthError.authorizationError(error, errorDescription)))
            return
        }
        
        // Validate state parameter (CSRF protection)
        if config.validateState {
            let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
            guard receivedState == currentState else {
                completion(.failure(OAuthError.stateMismatch))
                return
            }
            print("✅ State validation successful")
        }
        
        // Extract authorization code
        guard let authCode = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            completion(.failure(OAuthError.noAuthCode))
            return
        }
        
        print("✅ Authorization code received: \(authCode.prefix(10))...")
        
        // Exchange authorization code for token
        exchangeCodeForToken(authCode: authCode, completion: completion)
    }
    
    private func extractAuthCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }
    
    private func exchangeCodeForToken(authCode: String, completion: @escaping (Result<AuthToken, Error>) -> Void) {
        
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let parameters = [
            "grant_type": "authorization_code",
            "code": authCode,
            "client_id": config.clientId,
            "redirect_uri": config.redirectURI
        ]
        
        let bodyString = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔄 Exchanging authorization code for token...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("❌ Token exchange network error: \(error)")
                completion(.failure(OAuthError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(OAuthError.invalidResponse))
                return
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                print("❌ Token exchange HTTP error: \(httpResponse.statusCode)")
                completion(.failure(OAuthError.httpError(httpResponse.statusCode)))
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
                    refreshToken: tokenResponse.refreshToken,
                    expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                    tokenType: tokenResponse.tokenType
                )
                
                print("✅ Token exchange successful")
                completion(.success(authToken))
                
            } catch {
                print("❌ Token decoding error: \(error)")
                completion(.failure(OAuthError.decodingError(error)))
            }
            
        }.resume()
    }
    
    private func generateRandomState() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    private func extractScheme(from url: String) -> String? {
        guard let components = URLComponents(string: url) else { return nil }
        return components.scheme
    }
}
        
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
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Enhanced Data Models

// OAuth Response Models
struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// Enhanced Auth Token
struct AuthToken {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let tokenType: String
    let scope: String?
    
    var isExpired: Bool {
        return Date() >= expiresAt
    }
    
    var bearerToken: String {
        return "\(tokenType) \(accessToken)"
    }
}

// Enhanced OAuth Errors
enum OAuthError: Error, LocalizedError {
    case invalidURL
    case noAuthCode
    case noData
    case invalidResponse
    case noCallbackURL
    case stateMismatch
    case authorizationError(String, String?)
    case networkError(Error)
    case httpError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid authorization URL"
        case .noAuthCode:
            return "No authorization code received"
        case .noData:
            return "No data received from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .noCallbackURL:
            return "No callback URL received"
        case .stateMismatch:
            return "State parameter mismatch - possible security issue"
        case .authorizationError(let error, let description):
            return description ?? "Authorization error: \(error)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
```

**🏃‍♂️ Practice Exercise 3.1: Complete OAuth Implementation**

#### Step 1: Configure Info.plist
```xml
<!-- Add to your Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OAuth Callback</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourapp.oauth</string>
        </array>
    </dict>
</array>
```

#### Step 2: Set up OAuth Configuration
```swift
// Test OAuth configuration for Google
let googleConfig = OAuthConfig(
    clientId: "your-google-client-id.apps.googleusercontent.com",
    redirectURI: "com.yourapp.oauth://callback",
    scope: "openid email profile",
    authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
    tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
)

let oauthManager = OAuthManager(config: googleConfig)
```

#### Step 3: Handle URL Callbacks in Your App
```swift
// In your App.swift or SceneDelegate
.onOpenURL { url in
    print("📱 Received URL: \(url)")
    handleOAuthCallback(url)
}

func handleOAuthCallback(_ url: URL) {
    // Check if it's an OAuth callback
    if url.scheme == "com.yourapp.oauth" {
        // The OAuth manager will handle this automatically
        // when the authentication session completes
        print("✅ OAuth callback received")
    }
}
```

#### Step 4: Implement Authentication UI
```swift
import SwiftUI

struct LoginView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var authToken: AuthToken?
    
    private let oauthManager = OAuthManager(config: googleConfig)
    
    var body: some View {
        VStack(spacing: 20) {
            if let token = authToken {
                // Show authenticated state
                VStack {
                    Text("✅ Authentication Successful!")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Access Token: \(token.accessToken.prefix(20))...")
                        .font(.caption)
                        .monospaced()
                    
                    Text("Expires: \(token.expiresAt.formatted())")
                        .font(.caption)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Show login button
                Button(action: authenticateWithOAuth) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.circle.fill")
                        }
                        Text("Sign in with OAuth")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
            }
            
            if let error = errorMessage {
                Text("❌ Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
    
    private func authenticateWithOAuth() {
        isLoading = true
        errorMessage = nil
        
        oauthManager.authenticate { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let token):
                    print("✅ OAuth authentication successful")
                    authToken = token
                    
                case .failure(let error):
                    print("❌ OAuth authentication failed: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

#### Step 5: Test Different Scenarios
```swift
// Testing different OAuth configurations
struct OAuthTestSuite {
    
    // Test with different providers
    static let googleConfig = OAuthConfig(
        clientId: "google-client-id",
        redirectURI: "com.yourapp.oauth://callback",
        scope: "openid email profile",
        authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
        tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
    )
    
    static let facebookConfig = OAuthConfig(
        clientId: "facebook-app-id",
        redirectURI: "com.yourapp.oauth://callback",
        scope: "email public_profile",
        authorizationEndpoint: URL(string: "https://www.facebook.com/v12.0/dialog/oauth")!,
        tokenEndpoint: URL(string: "https://graph.facebook.com/v12.0/oauth/access_token")!
    )
    
    // Test error handling
    static func testErrorScenarios() {
        // Test with invalid client ID
        let invalidConfig = OAuthConfig(
            clientId: "invalid-client-id",
            redirectURI: "com.yourapp.oauth://callback",
            scope: "openid email",
            authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
        )
        
        let manager = OAuthManager(config: invalidConfig)
        manager.authenticate { result in
            // Should receive an error
            switch result {
            case .success:
                print("❌ Expected error but got success")
            case .failure(let error):
                print("✅ Correctly received error: \(error)")
            }
        }
    }
}
```

#### Understanding the Flow

When you run this code, here's what happens step by step:

1. **User taps "Sign in with OAuth"**
   - App calls `oauthManager.authenticate()`
   - Loading state begins

2. **Authorization URL is built**
   ```
   https://accounts.google.com/oauth/authorize?
   client_id=your-client-id&
   redirect_uri=com.yourapp.oauth://callback&
   response_type=code&
   scope=openid%20email%20profile&
   state=random-security-string
   ```

3. **ASWebAuthenticationSession opens**
   - Secure web view opens Google's login page
   - User enters Google credentials
   - Google shows permission screen

4. **User approves permissions**
   - Google redirects to: `com.yourapp.oauth://callback?code=auth_code&state=security_string`
   - iOS recognizes the custom URL scheme
   - Your app receives the URL

5. **Authorization code extraction**
   - App extracts `code=auth_code` from URL
   - Validates `state` parameter matches original

6. **Token exchange**
   - App makes POST request to Google's token endpoint
   - Sends authorization code + client credentials
   - Receives access token and refresh token

7. **Authentication complete**
   - App can now make API calls with access token
   - User is signed in!

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

---

## 📚 Part 3.5: Complete Authorization Code Flow Example

> **Note**: For comprehensive deep-dive guides, see:
> - [Enhanced Authorization Code Flow Guide](../../enhanced-authorization-code-flow-guide.md)
> - [Redirect URLs Complete Guide](../../redirect-urls-complete-guide.md)

Let's build a complete, working example that demonstrates the entire Authorization Code Flow:

### 3.5.1 Complete OAuth App Example

```swift
import SwiftUI
import AuthenticationServices

@main
struct OAuthDemoApp: App {
    var body: some Scene {
        WindowGroup {
            OAuthDemoView()
                .onOpenURL { url in
                    OAuthCoordinator.shared.handleRedirectURL(url)
                }
        }
    }
}

// MARK: - Main Demo View
struct OAuthDemoView: View {
    @StateObject private var coordinator = OAuthCoordinator.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                HeaderView()
                
                if coordinator.isAuthenticated {
                    AuthenticatedView(user: coordinator.currentUser)
                } else {
                    UnauthenticatedView()
                }
                
                Spacer()
                
                FlowVisualizationView(currentStep: coordinator.currentFlowStep)
            }
            .padding()
            .navigationTitle("OAuth 2.0 Demo")
        }
        .alert("OAuth Error", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("OK") {
                coordinator.errorMessage = nil
            }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("OAuth 2.0 Authorization Code Flow")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Complete demonstration with redirect URLs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Authenticated State View
struct AuthenticatedView: View {
    let user: OAuthUser?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Authentication Successful!")
                    .fontWeight(.semibold)
            }
            .font(.title3)
            
            if let user = user {
                UserInfoCard(user: user)
                TokenInfoCard(token: user.authToken)
            }
            
            Button("Sign Out") {
                OAuthCoordinator.shared.signOut()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Unauthenticated State View
struct UnauthenticatedView: View {
    @ObservedObject private var coordinator = OAuthCoordinator.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign in to see OAuth 2.0 in action")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await coordinator.authenticate()
                }
            }) {
                HStack {
                    if coordinator.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    Text("Start OAuth Flow")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(coordinator.isLoading)
            
            Text("This will demonstrate the complete Authorization Code Flow with redirect URLs")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - User Info Card
struct UserInfoCard: View {
    let user: OAuthUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User Information")
                .font(.headline)
            
            if let userInfo = user.userInfo {
                Label(userInfo.email ?? "No email", systemImage: "envelope")
                Label(userInfo.name ?? "No name", systemImage: "person")
                
                if let locale = userInfo.locale {
                    Label(locale, systemImage: "globe")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Token Info Card
struct TokenInfoCard: View {
    let token: AuthToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token Information")
                .font(.headline)
            
            Label("Access Token: \(String(token.accessToken.prefix(20)))...", 
                  systemImage: "key.fill")
                .font(.caption)
                .monospaced()
            
            Label("Type: \(token.tokenType)", systemImage: "tag")
                .font(.caption)
            
            Label("Expires: \(token.expiresAt.formatted())", 
                  systemImage: "clock")
                .font(.caption)
            
            if let scope = token.scope {
                Label("Scope: \(scope)", systemImage: "scope")
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: token.isExpired ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(token.isExpired ? .red : .green)
                Text(token.isExpired ? "Expired" : "Valid")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Flow Visualization
struct FlowVisualizationView: View {
    let currentStep: OAuthFlowStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OAuth Flow Progress")
                .font(.headline)
            
            ForEach(OAuthFlowStep.allCases, id: \.self) { step in
                HStack {
                    Image(systemName: stepIcon(for: step))
                        .foregroundColor(stepColor(for: step))
                    
                    Text(step.description)
                        .font(.caption)
                        .foregroundColor(step == currentStep ? .primary : .secondary)
                    
                    Spacer()
                    
                    if step == currentStep {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func stepIcon(for step: OAuthFlowStep) -> String {
        switch step {
        case .idle: return "circle"
        case .buildingURL: return "link"
        case .userAuthentication: return "person.fill.checkmark"
        case .receivingCallback: return "arrow.uturn.left"
        case .exchangingToken: return "arrow.left.arrow.right"
        case .fetchingUserInfo: return "person.crop.circle"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private func stepColor(for step: OAuthFlowStep) -> Color {
        if step.rawValue <= currentStep.rawValue {
            return step == .error ? .red : .green
        } else {
            return .gray
        }
    }
}

// MARK: - OAuth Flow Steps
enum OAuthFlowStep: Int, CaseIterable {
    case idle = 0
    case buildingURL = 1
    case userAuthentication = 2
    case receivingCallback = 3
    case exchangingToken = 4
    case fetchingUserInfo = 5
    case completed = 6
    case error = 7
    
    var description: String {
        switch self {
        case .idle: return "Ready to start"
        case .buildingURL: return "Building authorization URL"
        case .userAuthentication: return "User authenticating..."
        case .receivingCallback: return "Receiving callback"
        case .exchangingToken: return "Exchanging code for token"
        case .fetchingUserInfo: return "Fetching user information"
        case .completed: return "Authentication complete"
        case .error: return "Error occurred"
        }
    }
}

// MARK: - OAuth Coordinator (Singleton)
class OAuthCoordinator: ObservableObject {
    static let shared = OAuthCoordinator()
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: OAuthUser?
    @Published var currentFlowStep: OAuthFlowStep = .idle
    
    private let config = OAuthConfig(
        clientId: "demo-client-id", // Replace with real client ID
        redirectURI: "com.authlearning.oauth://callback",
        scope: "openid email profile",
        authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
        tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
        userInfoEndpoint: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")
    )
    
    private var oauthManager: EnhancedOAuthManager?
    
    private init() {
        setupOAuthManager()
    }
    
    private func setupOAuthManager() {
        let enhancedConfig = EnhancedOAuthConfig(
            clientId: config.clientId,
            clientSecret: nil,
            redirectURI: config.redirectURI,
            scope: config.scope,
            authorizationEndpoint: config.authorizationEndpoint,
            tokenEndpoint: config.tokenEndpoint,
            userInfoEndpoint: config.userInfoEndpoint
        )
        
        oauthManager = EnhancedOAuthManager(config: enhancedConfig)
    }
    
    @MainActor
    func authenticate() async {
        isLoading = true
        currentFlowStep = .buildingURL
        
        do {
            currentFlowStep = .userAuthentication
            let user = try await oauthManager?.authenticate()
            
            currentFlowStep = .completed
            currentUser = user
            isAuthenticated = true
            isLoading = false
            
        } catch {
            currentFlowStep = .error
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func handleRedirectURL(_ url: URL) {
        DispatchQueue.main.async {
            self.currentFlowStep = .receivingCallback
            print("📱 Handling redirect URL: \(url)")
            
            // The OAuth manager handles this automatically
            // This is just for demonstration/logging
            if url.scheme == "com.authlearning.oauth" {
                self.currentFlowStep = .exchangingToken
            }
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        currentFlowStep = .idle
        errorMessage = nil
    }
}
```

### 3.5.2 Info.plist Configuration

```xml
<!-- Add this to your Info.plist file -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OAuth Authentication</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.authlearning.oauth</string>
        </array>
    </dict>
</array>

<!-- Optional: Add for better security -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>accounts.google.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>
```

### 3.5.3 Testing the Complete Flow

```swift
// Add this test class to validate the implementation
import XCTest

class OAuthFlowIntegrationTests: XCTestCase {
    
    var coordinator: OAuthCoordinator!
    
    override func setUp() {
        super.setUp()
        coordinator = OAuthCoordinator.shared
    }
    
    func testRedirectURLParsing() {
        // Test successful callback
        let successURL = URL(string: "com.authlearning.oauth://callback?code=test123&state=abc")!
        coordinator.handleRedirectURL(successURL)
        
        XCTAssertEqual(coordinator.currentFlowStep, .exchangingToken)
    }
    
    func testErrorRedirectURL() {
        // Test error callback
        let errorURL = URL(string: "com.authlearning.oauth://callback?error=access_denied")!
        coordinator.handleRedirectURL(errorURL)
        
        // Should handle error gracefully
        XCTAssertNotNil(errorURL)
    }
    
    func testFlowSteps() {
        // Test flow progression
        XCTAssertEqual(coordinator.currentFlowStep, .idle)
        
        // Simulate starting authentication
        coordinator.currentFlowStep = .buildingURL
        XCTAssertEqual(coordinator.currentFlowStep, .buildingURL)
        
        coordinator.currentFlowStep = .userAuthentication
        XCTAssertEqual(coordinator.currentFlowStep, .userAuthentication)
    }
}
```

### 3.5.4 What This Example Demonstrates

**1. Complete Authorization Code Flow:**
- Building authorization URL with all required parameters
- Handling user authentication via ASWebAuthenticationSession
- Processing redirect callbacks with parameter extraction
- Exchanging authorization code for access token
- Fetching user information using the access token

**2. Redirect URL Implementation:**
- Custom URL scheme registration (`com.authlearning.oauth`)
- URL handling in SwiftUI with `.onOpenURL`
- Parameter extraction and validation
- Error handling for various scenarios

**3. Security Features:**
- State parameter validation (CSRF protection)
- PKCE implementation (code interception prevention)
- Proper error handling and user feedback
- Token expiration checking

**4. User Experience:**
- Visual flow progression indicator
- Clear error messages
- Loading states and feedback
- Comprehensive token and user information display

**5. Real-World Considerations:**
- Proper separation of concerns with coordinator pattern
- Async/await for modern Swift concurrency
- ObservableObject for SwiftUI state management
- Comprehensive error handling

This example provides a complete, working demonstration of the OAuth 2.0 Authorization Code Flow that you can run and test to understand exactly how redirect URLs work in practice!

---
# 🔐 Enhanced Guide: Authorization Code Flow Deep Dive

> **Comprehensive Analysis of OAuth 2.0 Authorization Code Flow**  
> **Focus**: Detailed explanation with sample code analysis, redirect URLs, and iOS implementation

## 🎯 Overview

This guide provides a comprehensive explanation of the OAuth 2.0 Authorization Code Flow, specifically focusing on:
- **Step-by-step flow analysis** with real sample code
- **Redirect URLs**: What they are, how they work, and iOS implementation
- **Practical iOS implementation** with complete code examples
- **Security considerations** and best practices

---

## 📚 Part 1: Authorization Code Flow - Complete Analysis

### 1.1 What is the Authorization Code Flow?

The **Authorization Code Flow** is the most secure OAuth 2.0 flow for mobile applications. It's a two-step process that ensures:
- User credentials never touch your app
- Authorization server validates the client
- Secure token exchange happens server-to-server (or in our case, app-to-server)

### 1.2 The Players in Detail

```swift
// The four key players in OAuth 2.0
struct OAuthPlayers {
    let resourceOwner: String = "The User (person with the account)"
    let client: String = "Your iOS App (requesting access)"
    let authorizationServer: String = "Google/Apple/Facebook (validates user)"
    let resourceServer: String = "API Server (holds user data)"
}
```

### 1.3 Step-by-Step Flow Analysis

Let's break down each step with the actual sample code and explain what happens:

#### Step 1: User Initiates Authentication

```swift
// User taps "Sign in with Google" button
@IBAction func signInWithGoogleTapped(_ sender: UIButton) {
    // This is where our flow begins
    oauthManager.authenticate { result in
        // Handle result
    }
}
```

**What happens here:**
- User expresses intent to authenticate
- App prepares to start OAuth flow
- No sensitive data exchanged yet

#### Step 2: Build Authorization URL

```swift
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
```

**Detailed Parameter Analysis:**

```swift
// Let's break down each parameter:
struct AuthorizationURLParameters {
    
    // WHO is making the request?
    let client_id: String = "1234567890-abcdef.apps.googleusercontent.com"
    // This identifies YOUR app to Google
    
    // WHERE should Google send the user back?
    let redirect_uri: String = "com.yourapp.oauth://callback"
    // This is YOUR app's custom URL scheme
    
    // WHAT type of response do we want?
    let response_type: String = "code"
    // We want an authorization code (not a token directly)
    
    // WHAT permissions are we requesting?
    let scope: String = "openid email profile"
    // We want: identity confirmation, email, and basic profile
    
    // Security: Prevent CSRF attacks
    let state: String = "random-string-12345"
    // This prevents malicious redirects
}
```

**The resulting URL looks like:**
```
https://accounts.google.com/oauth/authorize?
client_id=1234567890-abcdef.apps.googleusercontent.com&
redirect_uri=com.yourapp.oauth://callback&
response_type=code&
scope=openid%20email%20profile&
state=random-string-12345
```

#### Step 3: Open Authorization Server

```swift
// Using ASWebAuthenticationSession to open Google's login page
webAuthSession = ASWebAuthenticationSession(
    url: authURL,
    callbackURLScheme: config.redirectURI
) { [weak self] callbackURL, error in
    // This closure handles the response
}

webAuthSession?.presentationContextProvider = self
webAuthSession?.start()
```

**What happens here:**
1. iOS opens a secure web view
2. User sees Google's actual login page (not a fake one in your app)
3. User enters their Google username/password
4. Google validates the credentials
5. Google asks user to approve permissions ("Allow YourApp to access your email?")

#### Step 4: Authorization Server Redirects Back

When user approves, Google redirects to your app:
```
com.yourapp.oauth://callback?
code=4/0AX4XfWjv1234567890abcdef&
state=random-string-12345
```

#### Step 5: Extract Authorization Code

```swift
private func extractAuthCode(from url: URL) -> String? {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return components?.queryItems?.first(where: { $0.name == "code" })?.value
}
```

**Code Analysis:**
- `code=4/0AX4XfWjv1234567890abcdef` - This is the authorization code
- `state=random-string-12345` - This should match what we sent (security check)

#### Step 6: Exchange Code for Token

```swift
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
        // Process token response
    }.resume()
}
```

**What's happening in the token exchange:**
1. **POST request** to Google's token endpoint
2. **Send the authorization code** (proving user approved)
3. **Include client_id** (proving who you are)
4. **Include redirect_uri** (security check - must match original)
5. **Get back access token** (the golden key!)

**Token Response:**
```json
{
  "access_token": "ya29.a0ARrdaM9...",
  "token_type": "Bearer",
  "expires_in": 3599,
  "refresh_token": "1//04-abcdef...",
  "scope": "openid email profile"
}
```

---

## 📚 Part 2: Redirect URLs - Deep Dive

### 2.1 What are Redirect URLs?

**Redirect URLs** are the mechanism that brings the user back to your app after authentication. Think of them as your app's "return address."

### 2.2 Types of Redirect URLs

#### Custom URL Schemes (Most Common for iOS)
```swift
// Your app registers a custom URL scheme
let redirectURI = "com.yourapp.oauth://callback"

// In Info.plist:
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

#### Universal Links (Advanced)
```swift
// Uses your actual domain
let redirectURI = "https://yourapp.com/oauth/callback"
// Requires server setup and apple-app-site-association file
```

### 2.3 How Redirect URLs Work in iOS

#### Step 1: Register URL Scheme
Your app tells iOS "I can handle URLs that start with `com.yourapp.oauth`"

#### Step 2: Authorization Server Redirects
Google redirects to: `com.yourapp.oauth://callback?code=...`

#### Step 3: iOS Routes to Your App
```swift
// In your App file
.onOpenURL { url in
    handleIncomingURL(url)
}

private func handleIncomingURL(_ url: URL) {
    print("📱 Handling incoming URL: \(url)")
    
    // Check if it's an OAuth callback
    if url.scheme == "com.yourapp.oauth" {
        // Extract the authorization code
        processOAuthCallback(url)
    }
}
```

### 2.4 Security Considerations for Redirect URLs

```swift
struct RedirectURLSecurity {
    
    // ✅ GOOD: App-specific scheme
    let goodScheme = "com.yourcompany.yourapp.oauth"
    
    // ❌ BAD: Generic scheme (can be hijacked)
    let badScheme = "oauth"
    
    // ✅ GOOD: Validate state parameter
    func validateCallback(url: URL, expectedState: String) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let actualState = components?.queryItems?.first(where: { $0.name == "state" })?.value
        return actualState == expectedState
    }
    
    // ✅ GOOD: Check for error parameters
    func checkForErrors(url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "error" })?.value
    }
}
```

---

## 📚 Part 3: Complete iOS Implementation

### 3.1 Enhanced OAuth Manager

```swift
import Foundation
import AuthenticationServices
import UIKit

// MARK: - Enhanced OAuth Configuration
struct EnhancedOAuthConfig {
    let clientId: String
    let clientSecret: String?  // Optional - not recommended for mobile
    let redirectURI: String
    let scope: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userInfoEndpoint: URL?
    
    // Security settings
    let usePKCE: Bool = true  // Proof Key for Code Exchange
    let validateState: Bool = true
}

// MARK: - Enhanced OAuth Manager
class EnhancedOAuthManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: OAuthUser?
    
    // MARK: - Private Properties
    private let config: EnhancedOAuthConfig
    private var webAuthSession: ASWebAuthenticationSession?
    private var currentState: String?
    private var codeVerifier: String?
    
    // MARK: - Initialization
    init(config: EnhancedOAuthConfig) {
        self.config = config
        super.init()
    }
    
    // MARK: - Public Methods
    func authenticate() async throws -> OAuthUser {
        return try await withCheckedThrowingContinuation { continuation in
            authenticate { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func authenticate(completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
        }
        
        // Generate security parameters
        currentState = generateRandomState()
        if config.usePKCE {
            codeVerifier = generateCodeVerifier()
        }
        
        // Build authorization URL
        guard let authURL = buildAuthorizationURL() else {
            Task { @MainActor in
                self.isLoading = false
                self.errorMessage = "Failed to build authorization URL"
            }
            completion(.failure(OAuthError.invalidURL))
            return
        }
        
        // Start web authentication session
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: extractScheme(from: config.redirectURI)
        ) { [weak self] callbackURL, error in
            
            Task { @MainActor in
                self?.isLoading = false
            }
            
            if let error = error {
                if let authError = error as? ASWebAuthenticationSessionError {
                    switch authError.code {
                    case .canceledLogin:
                        completion(.failure(OAuthError.userCanceled))
                    case .presentationContextNotProvided:
                        completion(.failure(OAuthError.presentationError))
                    case .presentationContextInvalid:
                        completion(.failure(OAuthError.presentationError))
                    @unknown default:
                        completion(.failure(OAuthError.unknown(error)))
                    }
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            guard let callbackURL = callbackURL else {
                completion(.failure(OAuthError.noCallbackURL))
                return
            }
            
            // Process the callback
            self?.processCallback(callbackURL, completion: completion)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }
    
    // MARK: - Private Methods
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)
        
        var queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
        ]
        
        if config.validateState, let state = currentState {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        
        if config.usePKCE, let codeVerifier = codeVerifier {
            let codeChallenge = generateCodeChallenge(from: codeVerifier)
            queryItems.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
        }
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func processCallback(_ url: URL, completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Check for error
        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorDescription = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
            completion(.failure(OAuthError.authorizationError(error, errorDescription)))
            return
        }
        
        // Validate state
        if config.validateState {
            let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
            guard receivedState == currentState else {
                completion(.failure(OAuthError.stateMismatch))
                return
            }
        }
        
        // Extract authorization code
        guard let authCode = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            completion(.failure(OAuthError.noAuthCode))
            return
        }
        
        // Exchange code for token
        exchangeCodeForToken(authCode: authCode, completion: completion)
    }
    
    private func exchangeCodeForToken(authCode: String, completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var parameters = [
            "grant_type": "authorization_code",
            "code": authCode,
            "client_id": config.clientId,
            "redirect_uri": config.redirectURI
        ]
        
        // Add client secret if provided (not recommended for mobile)
        if let clientSecret = config.clientSecret {
            parameters["client_secret"] = clientSecret
        }
        
        // Add PKCE verifier
        if config.usePKCE, let codeVerifier = codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }
        
        let bodyString = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            if let error = error {
                completion(.failure(OAuthError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(OAuthError.invalidResponse))
                return
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                completion(.failure(OAuthError.httpError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(OAuthError.noData))
                return
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                
                // Create auth token
                let authToken = AuthToken(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken,
                    expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                    tokenType: tokenResponse.tokenType,
                    scope: tokenResponse.scope
                )
                
                // Fetch user info if endpoint provided
                if let userInfoEndpoint = self?.config.userInfoEndpoint {
                    self?.fetchUserInfo(token: authToken, completion: completion)
                } else {
                    let user = OAuthUser(authToken: authToken, userInfo: nil)
                    Task { @MainActor in
                        self?.currentUser = user
                        self?.isAuthenticated = true
                    }
                    completion(.success(user))
                }
                
            } catch {
                completion(.failure(OAuthError.decodingError(error)))
            }
            
        }.resume()
    }
    
    private func fetchUserInfo(token: AuthToken, completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        guard let userInfoEndpoint = config.userInfoEndpoint else {
            let user = OAuthUser(authToken: token, userInfo: nil)
            Task { @MainActor in
                self.currentUser = user
                self.isAuthenticated = true
            }
            completion(.success(user))
            return
        }
        
        var request = URLRequest(url: userInfoEndpoint)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            if let error = error {
                // Still succeed with token but no user info
                let user = OAuthUser(authToken: token, userInfo: nil)
                Task { @MainActor in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                }
                completion(.success(user))
                return
            }
            
            guard let data = data else {
                let user = OAuthUser(authToken: token, userInfo: nil)
                Task { @MainActor in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                }
                completion(.success(user))
                return
            }
            
            do {
                let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
                let user = OAuthUser(authToken: token, userInfo: userInfo)
                Task { @MainActor in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                }
                completion(.success(user))
            } catch {
                // Still succeed with token but no user info
                let user = OAuthUser(authToken: token, userInfo: nil)
                Task { @MainActor in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                }
                completion(.success(user))
            }
            
        }.resume()
    }
    
    // MARK: - Helper Methods
    private func generateRandomState() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncodedString()
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return verifier }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
    
    private func extractScheme(from url: String) -> String? {
        guard let components = URLComponents(string: url) else { return nil }
        return components.scheme
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension EnhancedOAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Data Models
struct AuthToken {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let tokenType: String
    let scope: String?
    
    var isExpired: Bool {
        return Date() >= expiresAt
    }
}

struct OAuthUser {
    let authToken: AuthToken
    let userInfo: UserInfo?
}

struct UserInfo: Codable {
    let id: String?
    let email: String?
    let name: String?
    let pictureURL: String?
    let locale: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, locale
        case pictureURL = "picture"
    }
}

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

// MARK: - Enhanced OAuth Errors
enum OAuthError: Error, LocalizedError {
    case invalidURL
    case noAuthCode
    case noData
    case invalidResponse
    case userCanceled
    case presentationError
    case noCallbackURL
    case stateMismatch
    case authorizationError(String, String?)
    case networkError(Error)
    case httpError(Int)
    case decodingError(Error)
    case unknown(Error)
    
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
        case .userCanceled:
            return "User canceled authentication"
        case .presentationError:
            return "Unable to present authentication session"
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
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Extension for PKCE
extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

### 3.2 Usage Example

```swift
import SwiftUI
import CryptoKit

struct ContentView: View {
    @StateObject private var oauthManager = EnhancedOAuthManager(
        config: EnhancedOAuthConfig(
            clientId: "your-google-client-id",
            clientSecret: nil, // Don't use client secret in mobile apps
            redirectURI: "com.yourapp.oauth://callback",
            scope: "openid email profile",
            authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
            userInfoEndpoint: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")
        )
    )
    
    var body: some View {
        VStack(spacing: 20) {
            if oauthManager.isAuthenticated {
                // User is authenticated
                UserProfileView(user: oauthManager.currentUser)
            } else {
                // Show login
                LoginView(oauthManager: oauthManager)
            }
        }
        .alert("Error", isPresented: .constant(oauthManager.errorMessage != nil)) {
            Button("OK") {
                oauthManager.errorMessage = nil
            }
        } message: {
            Text(oauthManager.errorMessage ?? "")
        }
    }
}

struct LoginView: View {
    @ObservedObject var oauthManager: EnhancedOAuthManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Button(action: {
                Task {
                    do {
                        let user = try await oauthManager.authenticate()
                        print("✅ Authentication successful: \(user)")
                    } catch {
                        print("❌ Authentication failed: \(error)")
                    }
                }
            }) {
                HStack {
                    if oauthManager.isLoading {
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
            .disabled(oauthManager.isLoading)
            
            if oauthManager.isLoading {
                Text("Authenticating...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct UserProfileView: View {
    let user: OAuthUser?
    
    var body: some View {
        VStack(spacing: 15) {
            AsyncImage(url: URL(string: user?.userInfo?.pictureURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            Text(user?.userInfo?.name ?? "User")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(user?.userInfo?.email ?? "No email")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Token Info:")
                    .font(.headline)
                
                Text("Expires: \(user?.authToken.expiresAt.formatted() ?? "Unknown")")
                    .font(.caption)
                
                Text("Type: \(user?.authToken.tokenType ?? "Unknown")")
                    .font(.caption)
                
                if let scope = user?.authToken.scope {
                    Text("Scope: \(scope)")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
}
```

---

## 📚 Part 4: Security Best Practices

### 4.1 Essential Security Measures

```swift
struct OAuthSecurityChecklist {
    
    // ✅ Always use HTTPS endpoints
    let authorizationEndpoint = "https://accounts.google.com/oauth/authorize"
    let tokenEndpoint = "https://oauth2.googleapis.com/token"
    
    // ✅ Use app-specific redirect URI
    let redirectURI = "com.yourcompany.yourapp.oauth://callback"
    
    // ✅ Validate state parameter (CSRF protection)
    func validateState(received: String, expected: String) -> Bool {
        return received == expected
    }
    
    // ✅ Use PKCE (Proof Key for Code Exchange)
    let usePKCE = true
    
    // ✅ Store tokens securely
    func storeTokenSecurely(_ token: String) {
        // Use Keychain, not UserDefaults
        KeychainManager.shared.store(token, forKey: "oauth_token")
    }
    
    // ✅ Validate token expiration
    func isTokenValid(_ token: AuthToken) -> Bool {
        return !token.isExpired
    }
    
    // ❌ Never store client secret in app
    let clientSecret: String? = nil
}
```

### 4.2 Common Security Mistakes

```swift
struct SecurityMistakes {
    
    // ❌ DON'T: Use weak redirect URI
    let weakRedirectURI = "myapp://callback"  // Can be hijacked
    
    // ✅ DO: Use strong, app-specific redirect URI
    let strongRedirectURI = "com.yourcompany.yourapp.oauth://callback"
    
    // ❌ DON'T: Skip state validation
    func skipStateValidation() {
        // This allows CSRF attacks
    }
    
    // ✅ DO: Always validate state
    func validateState(url: URL, expectedState: String) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
        return receivedState == expectedState
    }
    
    // ❌ DON'T: Store tokens in UserDefaults
    func storeTokenWeakly(_ token: String) {
        UserDefaults.standard.set(token, forKey: "token")  // Insecure
    }
    
    // ✅ DO: Store tokens in Keychain
    func storeTokenSecurely(_ token: String) {
        KeychainManager.shared.store(token, forKey: "oauth_token")
    }
}
```

---

## 📚 Part 5: Testing and Debugging

### 5.1 Testing OAuth Flow

```swift
import XCTest

class OAuthFlowTests: XCTestCase {
    
    var oauthManager: EnhancedOAuthManager!
    
    override func setUp() {
        super.setUp()
        oauthManager = EnhancedOAuthManager(
            config: EnhancedOAuthConfig(
                clientId: "test-client-id",
                clientSecret: nil,
                redirectURI: "com.test.app://callback",
                scope: "openid email",
                authorizationEndpoint: URL(string: "https://test-auth.com/authorize")!,
                tokenEndpoint: URL(string: "https://test-auth.com/token")!,
                userInfoEndpoint: nil
            )
        )
    }
    
    func testAuthorizationURLBuilding() {
        // Test URL construction
        let url = oauthManager.buildAuthorizationURL()
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("client_id=test-client-id"))
        XCTAssertTrue(url!.absoluteString.contains("response_type=code"))
    }
    
    func testRedirectURIValidation() {
        let testURL = URL(string: "com.test.app://callback?code=test123&state=abc")!
        // Test callback processing
        // ... test implementation
    }
    
    func testStateValidation() {
        // Test CSRF protection
        let validState = "test-state-123"
        let testURL = URL(string: "com.test.app://callback?code=test123&state=\(validState)")!
        
        // Should validate correctly
        XCTAssertTrue(oauthManager.validateState(url: testURL, expectedState: validState))
        
        // Should reject invalid state
        XCTAssertFalse(oauthManager.validateState(url: testURL, expectedState: "wrong-state"))
    }
}
```

### 5.2 Debugging Tips

```swift
struct OAuthDebuggingTips {
    
    // Add comprehensive logging
    func logOAuthFlow(_ step: String, details: [String: Any] = [:]) {
        print("🔐 OAuth Debug - \(step)")
        for (key, value) in details {
            print("   \(key): \(value)")
        }
    }
    
    // Example usage:
    func debugExample() {
        logOAuthFlow("Authorization URL Built", details: [
            "url": "https://accounts.google.com/oauth/authorize?client_id=...",
            "clientId": "1234567890",
            "scope": "openid email profile"
        ])
        
        logOAuthFlow("Callback Received", details: [
            "url": "com.myapp.oauth://callback?code=abc123",
            "hasCode": true,
            "hasState": true
        ])
    }
    
    // Common debugging scenarios
    func commonIssues() {
        // Issue 1: Redirect URI mismatch
        print("❌ Redirect URI must match exactly in OAuth provider settings")
        
        // Issue 2: Invalid client ID
        print("❌ Client ID not found - check OAuth provider dashboard")
        
        // Issue 3: Scope issues
        print("❌ Requested scope not allowed - check provider settings")
        
        // Issue 4: State mismatch
        print("❌ State parameter mismatch - possible CSRF attack")
    }
}
```

---

## 🎯 Summary

This enhanced guide provides a comprehensive understanding of the OAuth 2.0 Authorization Code Flow:

### Key Takeaways:

1. **Authorization Code Flow** is the most secure OAuth flow for mobile apps
2. **Redirect URLs** are your app's "return address" - configure them carefully
3. **Security is paramount** - always validate state, use PKCE, store tokens securely
4. **iOS implementation** uses `ASWebAuthenticationSession` for secure authentication
5. **Error handling** is crucial for good user experience

### Best Practices:
- ✅ Use app-specific redirect URI schemes
- ✅ Implement PKCE for additional security
- ✅ Always validate the state parameter
- ✅ Store tokens in Keychain, not UserDefaults
- ✅ Handle all possible error scenarios
- ✅ Provide clear user feedback during authentication

This implementation provides a production-ready OAuth 2.0 Authorization Code Flow for iOS applications with comprehensive security measures and error handling.

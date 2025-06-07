# 🔐 Enhanced Guide: Authorization Code Flow Deep Dive

> **Comprehensive Analysis of OAuth 2.0 Authorization Code Flow**  
> **Focus**: Detailed explanation with sample code analysis, redirect URLs, and iOS implementation

## 🎯 Overview

This guide provides a comprehensive explanation of the OAuth 2.0 Authorization Code Flow, specifically focusing on:
- **Step-by-step flow analysis** with real sample code
- **Redirect URLs**: What they are, how they work, and iOS implementation
- **Practical SwiftUI implementation** with complete code examples compatible with iOS 16.6+ and Swift 6
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
// User taps "Sign in with Google" button in SwiftUI
Button("Sign in with Google") {
    // This is where our flow begins
    Task {
        try await oauthManager.authenticate()
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
import SwiftUI
import CryptoKit // Required for PKCE implementation in Swift 6

// MARK: - Enhanced OAuth Configuration
/// Configuration struct that holds all OAuth 2.0 settings for the authorization flow
/// Compatible with iOS 16.6+ and Swift 6
/// 
/// This struct conforms to Sendable protocol for Swift 6 concurrency safety,
/// allowing it to be safely passed between actors and concurrent contexts
struct EnhancedOAuthConfig: Sendable { // Sendable ensures thread-safe usage in Swift 6
    
    /// Your app's client identifier registered with the OAuth provider
    /// This is a public identifier that uniquely identifies your app to the OAuth server
    /// Example: "123456789-abcdef.apps.googleusercontent.com" for Google OAuth
    /// 
    /// Security Note: This is NOT a secret - it's safe to include in your app bundle
    let clientId: String
    
    /// Client secret - STRONGLY NOT recommended for mobile apps due to security risks
    /// Mobile apps cannot securely store secrets since they can be reverse-engineered
    /// Use PKCE (Proof Key for Code Exchange) instead for mobile app security
    /// 
    /// When nil: Uses PKCE flow (recommended for mobile)
    /// When provided: Uses traditional client secret flow (not recommended)
    let clientSecret: String?
    
    /// The redirect URI where the authorization server sends the user back after authentication
    /// This MUST match EXACTLY what's registered with your OAuth provider
    /// 
    /// Format: "scheme://host/path" where scheme is your app's custom URL scheme
    /// Example: "com.yourcompany.yourapp.oauth://callback"
    /// 
    /// Critical: This must be registered in your app's Info.plist under CFBundleURLSchemes
    let redirectURI: String
    
    /// Space-separated list of permissions (scopes) your app is requesting
    /// Different OAuth providers support different scopes
    /// 
    /// Common examples:
    /// - Google: "openid email profile" (basic user info)
    /// - GitHub: "user:email" (user email access)
    /// - Microsoft: "User.Read" (read user profile)
    let scope: String
    
    /// URL where users authenticate and grant permissions to your app
    /// This is the OAuth provider's authorization endpoint
    /// 
    /// Examples:
    /// - Google: https://accounts.google.com/oauth/authorize
    /// - GitHub: https://github.com/login/oauth/authorize
    /// - Microsoft: https://login.microsoftonline.com/common/oauth2/v2.0/authorize
    let authorizationEndpoint: URL
    
    /// URL where authorization codes are exchanged for access tokens
    /// This is a server-to-server call (or app-to-server in mobile context)
    /// 
    /// Examples:
    /// - Google: https://oauth2.googleapis.com/token
    /// - GitHub: https://github.com/login/oauth/access_token
    /// - Microsoft: https://login.microsoftonline.com/common/oauth2/v2.0/token
    let tokenEndpoint: URL
    
    /// Optional URL to fetch user information using the access token
    /// Not all OAuth flows require this - some include user info in the token response
    /// 
    /// Examples:
    /// - Google: https://www.googleapis.com/oauth2/v2/userinfo
    /// - GitHub: https://api.github.com/user
    /// - Microsoft: https://graph.microsoft.com/v1.0/me
    let userInfoEndpoint: URL?
    
    // MARK: - Security Settings
    
    /// Enable PKCE (Proof Key for Code Exchange) - HIGHLY recommended for mobile apps
    /// PKCE prevents authorization code interception attacks by adding cryptographic proof
    /// 
    /// How it works:
    /// 1. Generate random 'code_verifier' (43-128 characters)
    /// 2. Create 'code_challenge' = BASE64URL(SHA256(code_verifier))
    /// 3. Send code_challenge with authorization request
    /// 4. Send code_verifier with token exchange request
    /// 5. Server verifies: SHA256(code_verifier) == code_challenge
    /// 
    /// This ensures only the app that initiated the flow can complete it
    let usePKCE: Bool = true
    
    /// Enable state parameter validation for CSRF (Cross-Site Request Forgery) protection
    /// The state parameter prevents malicious apps from hijacking your OAuth flow
    /// 
    /// How it works:
    /// 1. Generate random state value before starting OAuth flow
    /// 2. Include state in authorization URL
    /// 3. OAuth server returns state unchanged in callback
    /// 4. Verify returned state matches original value
    /// 
    /// If states don't match, the callback may be from a malicious source
    let validateState: Bool = true
}

// MARK: - Enhanced OAuth Manager
/// A comprehensive OAuth 2.0 manager that handles the complete Authorization Code Flow
/// 
/// This class provides:
/// - Secure authentication using ASWebAuthenticationSession
/// - PKCE support for mobile app security
/// - State validation for CSRF protection
/// - Comprehensive error handling
/// - SwiftUI integration with @Published properties
/// - iOS 16.6+ and Swift 6 compatibility
/// 
/// Usage:
/// ```swift
/// let manager = EnhancedOAuthManager(config: yourConfig)
/// let user = try await manager.authenticate()
/// ```
class EnhancedOAuthManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties for SwiftUI Integration
    
    /// Indicates whether the user is currently authenticated
    /// SwiftUI views will automatically update when this changes
    @Published var isAuthenticated = false
    
    /// Indicates whether an authentication operation is in progress
    /// Use this to show loading indicators in your UI
    @Published var isLoading = false
    
    /// Contains the current error message if authentication fails
    /// Use this to display error alerts to users
    @Published var errorMessage: String?
    
    /// Contains the current authenticated user's information
    /// Includes both the auth token and user profile data
    @Published var currentUser: OAuthUser?
    
    // MARK: - Private Properties
    
    /// OAuth configuration containing all endpoints and settings
    private let config: EnhancedOAuthConfig
    
    /// The current web authentication session
    /// Only one session can be active at a time
    private var webAuthSession: ASWebAuthenticationSession?
    
    /// Randomly generated state value for CSRF protection
    /// Generated fresh for each authentication attempt
    private var currentState: String?
    
    /// PKCE code verifier - cryptographically random string
    /// Used to prove the app that started the flow is completing it
    private var codeVerifier: String?
    
    // MARK: - Initialization
    
    /// Initializes the OAuth manager with the provided configuration
    /// - Parameter config: OAuth configuration containing endpoints and settings
    init(config: EnhancedOAuthConfig) {
        self.config = config
        super.init()
    }
    
    // MARK: - Public Authentication Methods
    
    /// Authenticates the user using OAuth 2.0 Authorization Code Flow (async/await)
    /// 
    /// This method uses Swift's modern async/await concurrency for clean asynchronous code
    /// Compatible with iOS 16.6+ and Swift 6 concurrency model
    /// 
    /// - Returns: An `OAuthUser` object containing auth token and user info
    /// - Throws: `OAuthError` for various failure scenarios
    /// 
    /// Example usage:
    /// ```swift
    /// do {
    ///     let user = try await oauthManager.authenticate()
    ///     print("Welcome, \(user.userInfo?.name ?? "User")!")
    /// } catch {
    ///     print("Authentication failed: \(error)")
    /// }
    /// ```
    func authenticate() async throws -> OAuthUser {
        return try await withCheckedThrowingContinuation { continuation in
            authenticate { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Authenticates the user using OAuth 2.0 Authorization Code Flow (callback-based)
    /// 
    /// This method provides the core OAuth flow implementation:
    /// 1. Generates security parameters (state, PKCE verifier)
    /// 2. Builds authorization URL with all required parameters
    /// 3. Opens secure web authentication session
    /// 4. Handles the callback with authorization code
    /// 5. Exchanges code for access token
    /// 6. Optionally fetches user information
    /// 
    /// - Parameter completion: Callback with Result containing OAuthUser or Error
    func authenticate(completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        // Update UI state on main thread (SwiftUI requirement)
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
        }
        
        // Generate fresh security parameters for this authentication attempt
        currentState = generateRandomState()
        if config.usePKCE {
            codeVerifier = generateCodeVerifier()
        }
        
        // Build the authorization URL with all required OAuth parameters
        guard let authURL = buildAuthorizationURL() else {
            Task { @MainActor in
                self.isLoading = false
                self.errorMessage = "Failed to build authorization URL"
            }
            completion(.failure(OAuthError.invalidURL))
            return
        }
        
        // Start the web authentication session
        // This opens a secure browser session that users trust
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: extractScheme(from: config.redirectURI)
        ) { [weak self] callbackURL, error in
            
            // Always update UI state on main thread
            Task { @MainActor in
                self?.isLoading = false
            }
            
            // Handle authentication session errors
            if let error = error {
                if let authError = error as? ASWebAuthenticationSessionError {
                    switch authError.code {
                    case .canceledLogin:
                        // User tapped "Cancel" - this is normal, not an error
                        completion(.failure(OAuthError.userCanceled))
                    case .presentationContextNotProvided:
                        // Developer error - missing presentation context
                        completion(.failure(OAuthError.presentationError))
                    case .presentationContextInvalid:
                        // System error - invalid presentation context
                        completion(.failure(OAuthError.presentationError))
                    @unknown default:
                        // Future error cases in newer iOS versions
                        completion(.failure(OAuthError.unknown(error)))
                    }
                } else {
                    // Other types of errors (network, etc.)
                    completion(.failure(error))
                }
                return
            }
            
            // Ensure we received a callback URL
            guard let callbackURL = callbackURL else {
                completion(.failure(OAuthError.noCallbackURL))
                return
            }
            
            // Process the OAuth callback URL
            self?.processCallback(callbackURL, completion: completion)
        }
        
        // Configure the web authentication session
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false // Allow cookies for better UX
        webAuthSession?.start()
    }
    
    // MARK: - Private Methods
    
    /// Builds the OAuth authorization URL with all required parameters
    /// 
    /// This method constructs the URL that will be opened in the web authentication session.
    /// The URL includes all OAuth 2.0 parameters required for the Authorization Code Flow:
    /// 
    /// Required parameters:
    /// - client_id: Identifies your app to the OAuth server
    /// - redirect_uri: Where to send the user after authentication
    /// - response_type: "code" for authorization code flow
    /// - scope: Permissions being requested
    /// 
    /// Optional security parameters:
    /// - state: Random value for CSRF protection
    /// - code_challenge: PKCE challenge derived from code_verifier
    /// - code_challenge_method: "S256" for SHA256 hashing
    /// 
    /// - Returns: Complete authorization URL or nil if construction fails
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)
        
        // Start with required OAuth 2.0 parameters
        var queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"), // Always "code" for Authorization Code Flow
            URLQueryItem(name: "scope", value: config.scope)
        ]
        
        // Add state parameter for CSRF protection if enabled
        if config.validateState, let state = currentState {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        
        // Add PKCE parameters if enabled
        if config.usePKCE, let codeVerifier = codeVerifier {
            let codeChallenge = generateCodeChallenge(from: codeVerifier)
            queryItems.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256")) // SHA256 method
        }
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    /// Processes the OAuth callback URL to extract the authorization code
    /// 
    /// This method handles the URL that the OAuth server redirects back to your app.
    /// It performs several security checks and validation steps:
    /// 
    /// 1. Check for OAuth error parameters (error, error_description)
    /// 2. Validate state parameter matches what we sent (CSRF protection)
    /// 3. Extract the authorization code from the URL
    /// 4. Exchange the code for an access token
    /// 
    /// Possible callback URL formats:
    /// - Success: com.yourapp.oauth://callback?code=abc123&state=xyz789
    /// - Error: com.yourapp.oauth://callback?error=access_denied&error_description=...
    /// 
    /// - Parameters:
    ///   - url: The callback URL received from the OAuth server
    ///   - completion: Callback with authentication result
    private func processCallback(_ url: URL, completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Check for OAuth error response
        // If the user denies permission or an error occurs, the OAuth server will
        // redirect with error parameters instead of an authorization code
        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorDescription = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
            completion(.failure(OAuthError.authorizationError(error, errorDescription)))
            return
        }
        
        // Validate state parameter for CSRF protection
        // This ensures the callback is from the same authentication request we initiated
        if config.validateState {
            let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
            guard receivedState == currentState else {
                completion(.failure(OAuthError.stateMismatch))
                return
            }
        }
        
        // Extract the authorization code
        // This is the temporary code that we'll exchange for an access token
        guard let authCode = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            completion(.failure(OAuthError.noAuthCode))
            return
        }
        
        // Exchange the authorization code for an access token
        exchangeCodeForToken(authCode: authCode, completion: completion)
    }
    
    /// Exchanges the authorization code for an access token
    /// 
    /// This is the second step of the OAuth Authorization Code Flow.
    /// We make a POST request to the token endpoint with:
    /// 
    /// Required parameters:
    /// - grant_type: "authorization_code" (specifies the OAuth flow type)
    /// - code: The authorization code from the callback
    /// - client_id: Your app's client identifier
    /// - redirect_uri: Must match the original redirect URI (security check)
    /// 
    /// Optional parameters:
    /// - client_secret: For traditional OAuth (not recommended for mobile)
    /// - code_verifier: For PKCE (recommended for mobile apps)
    /// 
    /// The server responds with:
    /// - access_token: The token for API calls
    /// - token_type: Usually "Bearer"
    /// - expires_in: Token lifetime in seconds
    /// - refresh_token: For getting new access tokens (optional)
    /// - scope: The actual permissions granted (may be less than requested)
    /// 
    /// - Parameters:
    ///   - authCode: The authorization code from the callback URL
    ///   - completion: Callback with authentication result
    private func exchangeCodeForToken(authCode: String, completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        
        // Prepare the token exchange request
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Build the request parameters
        var parameters = [
                        "grant_type": "authorization_code", // Specifies OAuth 2.0 Authorization Code Flow
            "code": authCode,                    // The authorization code from callback
            "client_id": config.clientId,        // Your app's identifier
            "redirect_uri": config.redirectURI   // Must match original (security check)
        ]
        
        // Add client secret if provided (not recommended for mobile apps)
        // Mobile apps cannot securely store client secrets since they can be reverse-engineered
        if let clientSecret = config.clientSecret {
            parameters["client_secret"] = clientSecret
        }
        
        // Add PKCE code verifier (recommended for mobile apps)
        // This proves that the app making the token request is the same one that initiated the flow
        if config.usePKCE, let codeVerifier = codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }
        
        // URL-encode the parameters for form submission
        let bodyString = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // Make the token exchange request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            // Handle network errors
            if let error = error {
                completion(.failure(OAuthError.networkError(error)))
                return
            }
            
            // Ensure we have an HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(OAuthError.invalidResponse))
                return
            }
            
            // Check for HTTP error status codes
            // 2xx status codes indicate success
            guard 200...299 ~= httpResponse.statusCode else {
                completion(.failure(OAuthError.httpError(httpResponse.statusCode)))
                return
            }
            
            // Ensure we received response data
            guard let data = data else {
                completion(.failure(OAuthError.noData))
                return
            }
            
            // Parse the token response JSON
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                
                // Create our internal token representation
                let authToken = AuthToken(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: tokenResponse.refreshToken,
                    expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                    tokenType: tokenResponse.tokenType,
                    scope: tokenResponse.scope
                )
                
                // Fetch additional user information if endpoint is configured
                if let userInfoEndpoint = self?.config.userInfoEndpoint {
                    self?.fetchUserInfo(token: authToken, completion: completion)
                } else {
                    // Complete authentication with token only (no user profile data)
                    let user = OAuthUser(authToken: authToken, userInfo: nil)
                    Task { @MainActor in
                        self?.currentUser = user
                        self?.isAuthenticated = true
                    }
                    completion(.success(user))
                }
                
            } catch {
                // Failed to parse token response JSON
                completion(.failure(OAuthError.decodingError(error)))
            }
            
        }.resume()
    }
    
    /// Fetches user profile information using the access token
    /// 
    /// This is an optional step that retrieves user profile data from the OAuth provider.
    /// Not all OAuth flows require this - some providers include user info in the token response.
    /// 
    /// The request is made with the access token in the Authorization header:
    /// Authorization: Bearer <access_token>
    /// 
    /// If user info fetching fails, we still consider authentication successful
    /// since we have a valid access token. The user object will just have nil userInfo.
    /// 
    /// - Parameters:
    ///   - token: The access token received from token exchange
    ///   - completion: Callback with authentication result
    private func fetchUserInfo(token: AuthToken, completion: @escaping (Result<OAuthUser, Error>) -> Void) {
        guard let userInfoEndpoint = config.userInfoEndpoint else {
            // No user info endpoint configured - complete with token only
            let user = OAuthUser(authToken: token, userInfo: nil)
            Task { @MainActor in
                self.currentUser = user
                self.isAuthenticated = true
            }
            completion(.success(user))
            return
        }
        
        // Prepare the user info request
        var request = URLRequest(url: userInfoEndpoint)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            // If user info request fails, still consider authentication successful
            // We have a valid token, just no additional user profile data
            if let error = error {
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
            
            // Try to parse user info, but don't fail authentication if it doesn't work
            do {
                let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
                let user = OAuthUser(authToken: token, userInfo: userInfo)
                Task { @MainActor in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                }
                completion(.success(user))
            } catch {
                // Parsing failed, but authentication still succeeded
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
    
    /// Generates a cryptographically secure random state value for CSRF protection
    /// 
    /// The state parameter is used to prevent Cross-Site Request Forgery (CSRF) attacks.
    /// It works by:
    /// 1. Generate a random state value before starting OAuth flow
    /// 2. Include this state in the authorization URL
    /// 3. OAuth server returns the state unchanged in the callback
    /// 4. Verify the returned state matches our original value
    /// 
    /// If the states don't match, someone may be trying to hijack the OAuth flow.
    /// 
    /// - Returns: A random string suitable for use as OAuth state parameter
    private func generateRandomState() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    /// Generates a cryptographically secure random code verifier for PKCE
    /// 
    /// PKCE (Proof Key for Code Exchange) prevents authorization code interception attacks.
    /// The code verifier is a cryptographically random string between 43-128 characters.
    /// 
    /// Process:
    /// 1. Generate random code_verifier (this method)
    /// 2. Create code_challenge = BASE64URL(SHA256(code_verifier))
    /// 3. Send code_challenge with authorization request
    /// 4. Send code_verifier with token exchange request
    /// 5. Server verifies: SHA256(code_verifier) == code_challenge
    /// 
    /// This ensures only the app that started the flow can complete it.
    /// 
    /// - Returns: A base64url-encoded random string for PKCE code verifier
    private func generateCodeVerifier() -> String {
        // Generate 32 random bytes (256 bits) for strong cryptographic security
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        
        // Convert to base64url encoding (URL-safe base64)
        return Data(buffer).base64URLEncodedString()
    }
    
    /// Generates a PKCE code challenge from the code verifier
    /// 
    /// The code challenge is derived from the code verifier using SHA256 hashing
    /// and base64url encoding. This is what gets sent to the authorization server.
    /// 
    /// The server will later verify that:
    /// BASE64URL(SHA256(received_code_verifier)) == sent_code_challenge
    /// 
    /// - Parameter verifier: The code verifier string
    /// - Returns: The SHA256-hashed, base64url-encoded code challenge
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return verifier }
        
        // Hash the verifier using SHA256 (CryptoKit framework - iOS 13.0+)
        let hash = SHA256.hash(data: data)
        
        // Convert hash to base64url encoding
        return Data(hash).base64URLEncodedString()
    }
    
    /// Extracts the URL scheme from a redirect URI
    /// 
    /// ASWebAuthenticationSession needs just the scheme part of the redirect URI
    /// to determine which app should handle the callback.
    /// 
    /// Example:
    /// - Input: "com.yourapp.oauth://callback"
    /// - Output: "com.yourapp.oauth"
    /// 
    /// - Parameter url: The complete redirect URI
    /// - Returns: Just the scheme portion, or nil if invalid
    private func extractScheme(from url: String) -> String? {
        guard let components = URLComponents(string: url) else { return nil }
        return components.scheme
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension EnhancedOAuthManager: ASWebAuthenticationPresentationContextProviding {
    /// Provides the presentation anchor for the web authentication session
    /// 
    /// In SwiftUI apps, we can use a simpler approach than the UIKit method.
    /// ASPresentationAnchor() automatically finds the appropriate window.
    /// 
    /// For more advanced scenarios where you need a specific window,
    /// you can access the current scene through @Environment(\.scenePhase)
    /// or use NSApplication.shared.keyWindow on macOS.
    /// 
    /// - Parameter session: The authentication session requesting a presentation anchor
    /// - Returns: The window that should present the authentication session
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // For SwiftUI apps, this simple approach works well
        // ASPresentationAnchor() automatically finds the key window
        return ASPresentationAnchor()
    }
}

// MARK: - Data Models

/// Represents an OAuth 2.0 access token and its metadata
/// 
/// This struct contains all the information returned by the OAuth token endpoint,
/// plus some convenience properties for token management.
/// 
/// Token lifecycle:
/// 1. Received from token exchange
/// 2. Used for API requests (Authorization: Bearer <token>)
/// 3. Monitored for expiration
/// 4. Refreshed using refresh token (if available)
struct AuthToken {
    /// The actual access token used for API requests
    /// Include this in the Authorization header: "Bearer \(accessToken)"
    let accessToken: String
    
    /// Optional refresh token for getting new access tokens
    /// Not all OAuth providers issue refresh tokens
    /// When the access token expires, use this to get a new one without re-authentication
    let refreshToken: String?
    
    /// When the access token expires
    /// After this time, API requests will return 401 Unauthorized
    /// Use the refresh token to get a new access token before this time
    let expiresAt: Date
    
    /// Type of token - usually "Bearer" for OAuth 2.0
    /// This tells you how to use the token in API requests
    let tokenType: String
    
    /// The actual permissions granted (may be less than requested)
    /// Space-separated list of scopes the user approved
    let scope: String?
    
    /// Convenience property to check if the token has expired
    /// Returns true if the current time is past the expiration time
    var isExpired: Bool {
        return Date() >= expiresAt
    }
}

/// Represents an authenticated OAuth user
/// 
/// This combines the access token with optional user profile information.
/// Not all OAuth flows provide user info - some just provide the token.
struct OAuthUser {
    /// The OAuth access token for making API requests
    let authToken: AuthToken
    
    /// Optional user profile information
    /// This is fetched from the userInfo endpoint if configured
    /// May be nil if user info fetching failed or wasn't configured
    let userInfo: UserInfo?
}

/// Represents user profile information from the OAuth provider
/// 
/// This struct uses common property names that work across different OAuth providers.
/// The actual JSON response format varies by provider, so we use CodingKeys to map
/// provider-specific field names to our standard properties.
/// 
/// Different providers use different field names:
/// - Google: "sub" for ID, "picture" for profile image
/// - GitHub: "id" for ID, "avatar_url" for profile image
/// - Microsoft: "id" for ID, "photo" for profile image
struct UserInfo: Codable {
    /// Unique user identifier from the OAuth provider
    /// This is stable and won't change even if the user changes their username
    let id: String?
    
    /// User's email address
    /// Only available if "email" scope was requested and granted
    let email: String?
    
    /// User's display name
    /// May be their real name or a chosen display name
    let name: String?
    
    /// URL to user's profile picture
    /// Different providers use different field names for this
    let pictureURL: String?
    
    /// User's locale/language preference
    /// Format: "en-US", "fr-FR", etc.
    let locale: String?
    
    /// Maps JSON field names to our struct properties
    /// This allows us to handle different providers with the same struct
    enum CodingKeys: String, CodingKey {
        case id, email, name, locale
        case pictureURL = "picture"  // Google uses "picture"
        // Add more mappings for other providers:
        // case pictureURL = "avatar_url"  // GitHub uses "avatar_url"
    }
}

/// Response from the OAuth token endpoint
/// 
/// This struct represents the JSON response when exchanging an authorization code
/// for an access token. The actual response format is standardized by OAuth 2.0 RFC.
/// 
/// Example JSON response:
/// ```json
/// {
///   "access_token": "ya29.a0ARrdaM9...",
///   "token_type": "Bearer",
///   "expires_in": 3599,
///   "refresh_token": "1//04-abcdef...",
///   "scope": "openid email profile"
/// }
/// ```
struct TokenResponse: Codable {
    /// The access token for making API requests
    let accessToken: String
    
    /// Type of token - usually "Bearer"
    let tokenType: String
        /// Token lifetime in seconds
    /// Common values: 3600 (1 hour), 7200 (2 hours)
    let expiresIn: Int
    
    /// Optional refresh token for getting new access tokens
    /// Not all providers issue refresh tokens
    let refreshToken: String?
    
    /// Space-separated list of approved scopes
    /// This is what the user actually approved (may be less than requested)
    let scope: String?
    
    /// Maps OAuth 2.0 standard JSON field names to our struct properties
    /// OAuth 2.0 uses snake_case in JSON responses, but Swift prefers camelCase
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Enhanced OAuth Errors

/// Comprehensive error types for OAuth 2.0 authentication flow
/// 
/// This enum covers all possible error scenarios in the OAuth flow:
/// - Configuration errors (invalid URLs, missing parameters)
/// - User interaction errors (cancellation, presentation issues)
/// - Network errors (connection failures, HTTP errors)
/// - OAuth protocol errors (authorization denied, invalid responses)
/// - Security errors (state mismatch, CSRF attempts)
/// 
/// Each error provides a user-friendly description through LocalizedError protocol.
enum OAuthError: Error, LocalizedError {
    /// Invalid authorization URL construction
    /// Usually indicates a configuration problem
    case invalidURL
    
    /// No authorization code received in callback
    /// May indicate OAuth server error or invalid response
    case noAuthCode
    
    /// No data received from server
    /// Network issue or server problem
    case noData
    
    /// Invalid HTTP response format
    /// Server returned non-HTTP response
    case invalidResponse
    
    /// User canceled the authentication process
    /// This is normal user behavior, not an error
    case userCanceled
    
    /// Cannot present authentication session
    /// iOS system issue or missing presentation context
    case presentationError
    
    /// No callback URL received
    /// OAuth flow didn't complete properly
    case noCallbackURL
    
    /// State parameter mismatch - possible security issue
    /// The state returned doesn't match what we sent
    /// This could indicate a CSRF attack or callback hijacking
    case stateMismatch
    
    /// OAuth authorization error with details
    /// The OAuth server returned an error response
    /// - Parameters:
    ///   - error: The error code (e.g., "access_denied")
    ///   - description: Optional human-readable error description
    case authorizationError(String, String?)
    
    /// Network connectivity error
    /// Internet connection issue or server unreachable
    case networkError(Error)
    
    /// HTTP error status code
    /// Server returned an error status (400, 401, 500, etc.)
    case httpError(Int)
    
    /// JSON decoding error
    /// Server response couldn't be parsed
    case decodingError(Error)
    
    /// Unknown or unexpected error
    /// Catch-all for unusual error scenarios
    case unknown(Error)
    
    /// User-friendly error descriptions for each error type
    /// These can be displayed directly to users in error alerts
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

/// Extension to Data for base64url encoding required by PKCE
/// 
/// PKCE requires base64url encoding, which is different from standard base64:
/// - Replace '+' with '-'
/// - Replace '/' with '_'
/// - Remove padding '=' characters
/// 
/// This makes the encoded string URL-safe for use in query parameters.
extension Data {
    /// Encodes the data using base64url encoding (RFC 4648 Section 5)
    /// This is required for PKCE code challenges and verifiers
    /// 
    /// - Returns: URL-safe base64 encoded string without padding
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")    // Make URL-safe
            .replacingOccurrences(of: "/", with: "_")    // Make URL-safe
            .replacingOccurrences(of: "=", with: "")     // Remove padding
    }
}
```

### 3.2 Complete SwiftUI Usage Example

```swift
import SwiftUI
import CryptoKit  // Required for PKCE implementation

/// Main content view demonstrating OAuth 2.0 authentication flow
/// 
/// This view showcases:
/// - SwiftUI integration with @StateObject for OAuth manager
/// - Conditional view rendering based on authentication state
/// - Error handling with alert presentation
/// - iOS 16.6+ and Swift 6 compatible code
struct ContentView: View {
    /// OAuth manager using @StateObject for proper SwiftUI lifecycle management
    /// @StateObject ensures the manager persists across view updates and creates it only once
    @StateObject private var oauthManager = EnhancedOAuthManager(
        config: EnhancedOAuthConfig(
            // Replace with your actual Google OAuth client ID
            // Get this from Google Cloud Console > APIs & Services > Credentials
            clientId: "your-google-client-id.apps.googleusercontent.com",
            
            // NEVER use client secret in mobile apps - it's not secure
            clientSecret: nil,
            
            // This MUST match what's registered in Google Console AND your Info.plist
            redirectURI: "com.yourcompany.yourapp.oauth://callback",
            
            // Scopes determine what user data you can access
            scope: "openid email profile",
            
            // Google's OAuth 2.0 endpoints (these are standard)
            authorizationEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
            userInfoEndpoint: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")
        )
    )
    
    var body: some View {
        VStack(spacing: 20) {
            // Conditional view rendering based on authentication state
            if oauthManager.isAuthenticated {
                // User has successfully authenticated - show their profile
                UserProfileView(user: oauthManager.currentUser)
            } else {
                // User needs to authenticate - show login interface
                LoginView(oauthManager: oauthManager)
            }
        }
        // Error handling: Show alert when error occurs
        .alert("Authentication Error", isPresented: .constant(oauthManager.errorMessage != nil)) {
            Button("OK") {
                // Clear error message when user acknowledges
                oauthManager.errorMessage = nil
            }
        } message: {
            Text(oauthManager.errorMessage ?? "An unknown error occurred")
        }
    }
}

/// Login view that presents the OAuth authentication interface
/// 
/// This view demonstrates:
/// - Modern async/await usage for clean asynchronous code
/// - Loading state management with button state changes
/// - Error handling in async context
/// - Accessible UI with proper button states
struct LoginView: View {
    /// Observed OAuth manager - changes will trigger UI updates
    @ObservedObject var oauthManager: EnhancedOAuthManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Welcome header
            Text("Welcome")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Authentication button with loading state
            Button(action: {
                // Use Task for modern Swift concurrency (iOS 15.0+)
                Task {
                    do {
                        // Attempt authentication using async/await
                        let user = try await oauthManager.authenticate()
                        print("✅ Authentication successful for user: \(user.userInfo?.name ?? "Unknown")")
                    } catch OAuthError.userCanceled {
                        // User canceled - this is normal, don't show error
                        print("ℹ️ User canceled authentication")
                    } catch {
                        // Other errors - these should be handled/displayed
                        print("❌ Authentication failed: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    // Show loading indicator when authentication is in progress
                    if oauthManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)  // iOS 16+ tint modifier
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
            .disabled(oauthManager.isLoading)  // Prevent multiple simultaneous attempts
            
            // Loading status text
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

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

## 📚 Part 2: ASWebAuthenticationSession - Deep Dive

### 2.1 What is ASWebAuthenticationSession?

`ASWebAuthenticationSession` is Apple's secure web authentication framework introduced in iOS 12 that provides a safe way for apps to authenticate users through web-based OAuth flows. It's the **recommended and secure approach** for handling OAuth 2.0 authentication in iOS applications.

```swift
import AuthenticationServices

// ASWebAuthenticationSession is the secure gateway between your app and OAuth providers
let webAuthSession = ASWebAuthenticationSession(
    url: authorizationURL,           // Where to authenticate
    callbackURLScheme: "yourapp",    // How to return to your app
    completionHandler: { url, error in
        // Handle the authentication result
    }
)
```

### 2.2 Why Use ASWebAuthenticationSession? 🔐

#### 2.2.1 Security Benefits

**1. Prevents Credential Phishing**
```swift
// ❌ DANGEROUS: Using WKWebView or SFSafariViewController for OAuth
// Users can't verify they're on the real OAuth provider's domain
// Your app could potentially intercept credentials

// ✅ SECURE: Using ASWebAuthenticationSession
// Shows real Safari browser with address bar
// Users can verify they're on accounts.google.com or login.microsoft.com
// Your app CANNOT access the login page or credentials
```

**2. Isolated Authentication Context**
```swift
struct SecurityComparison {
    
    // ❌ In-App WebView Problems:
    let webViewIssues = [
        "App can inject JavaScript to steal credentials",
        "No address bar - users can't verify URL authenticity",
        "Shared cookies/storage with your app",
        "No browser security features (anti-phishing, etc.)"
    ]
    
    // ✅ ASWebAuthenticationSession Benefits:
    let authSessionBenefits = [
        "Completely isolated from your app's web context",
        "Shows real Safari address bar for URL verification",
        "Inherits all Safari security features",
        "Your app cannot access the authentication page",
        "Uses system's trusted certificate validation"
    ]
}
```

**3. Trusted User Experience**
```swift
// Users see the familiar Safari interface they trust
// - Real address bar showing "accounts.google.com"
// - Safari's security indicators (lock icon, etc.)
// - Familiar autofill and password manager integration
// - Same interface they use for web browsing
```

#### 2.2.2 Technical Advantages

**1. Automatic Cookie Management**
```swift
// ASWebAuthenticationSession automatically:
// - Preserves existing login sessions (if user is already logged in)
// - Manages OAuth provider cookies appropriately
// - Handles cookie security and isolation

webAuthSession.prefersEphemeralWebBrowserSession = false
// false: Reuse existing login sessions (better UX)
// true: Always require fresh login (more secure for shared devices)
```

**2. System Integration**
```swift
// Integrates with iOS system features:
// - Proper app switching animations
// - System back gesture support
// - Automatic memory management
// - Proper landscape/portrait handling
// - Support for Split View and Slide Over on iPad
```

**3. OAuth Specification Compliance**
```swift
// ASWebAuthenticationSession enforces OAuth 2.0 best practices:
// - Requires HTTPS for authorization URLs (security)
// - Properly handles custom URL scheme redirects
// - Supports PKCE (Proof Key for Code Exchange)
// - Validates redirect URI matching
```

### 2.3 How ASWebAuthenticationSession Works 🔄

#### 2.3.1 The Authentication Flow

```swift
// Step 1: Initialize the session
let webAuthSession = ASWebAuthenticationSession(
    url: authorizationURL,
    callbackURLScheme: "com.yourapp.oauth"
) { callbackURL, error in
    // Step 4: Handle the result
    handleAuthenticationResult(callbackURL, error)
}

// Step 2: Configure presentation
webAuthSession.presentationContextProvider = self

// Step 3: Start the authentication
webAuthSession.start()
```

**What happens behind the scenes:**

```swift
struct ASWebAuthenticationSessionFlow {
    
    // 1. Session Initialization
    func initializeSession() {
        // Creates secure, isolated browser context
        // Validates authorization URL (must be HTTPS)
        // Sets up callback URL scheme monitoring
    }
    
    // 2. Browser Presentation
    func presentBrowser() {
        // Opens Safari or SFSafariViewController
        // User sees real OAuth provider login page
        // App goes to background, Safari comes to foreground
    }
    
    // 3. User Authentication
    func userAuthentication() {
        // User enters credentials in Safari (not in your app)
        // OAuth provider validates credentials
        // Provider asks user to authorize your app's permissions
    }
    
    // 4. Callback Handling
    func handleCallback() {
        // OAuth provider redirects to your app's URL scheme
        // iOS switches back to your app
        // ASWebAuthenticationSession captures the callback URL
        // Your completion handler is called with the result
    }
}
```

#### 2.3.2 Presentation Context Provider

```swift
// Your app must implement ASWebAuthenticationPresentationContextProviding
extension EnhancedOAuthManager: ASWebAuthenticationPresentationContextProvider {
    
    /// Provides the window for presenting the authentication session
    /// 
    /// This method tells iOS where to present the authentication browser.
    /// In SwiftUI apps, we can use ASPresentationAnchor() which automatically
    /// finds the appropriate window context.
    /// 
    /// For UIKit apps, you would typically return view.window or 
    /// UIApplication.shared.windows.first
    /// 
    /// - Parameter session: The web authentication session requesting presentation context
    /// - Returns: The window anchor for presenting the authentication interface
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // SwiftUI-compatible approach (iOS 16.6+)
        // ASPresentationAnchor() automatically finds the correct window
        return ASPresentationAnchor()
        
        // Alternative UIKit approach (if needed):
        // return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}
```

### 2.4 Error Handling and Edge Cases 🚨

```swift
// ASWebAuthenticationSession provides comprehensive error handling
func handleAuthenticationSessionError(_ error: Error) {
    
    if let authError = error as? ASWebAuthenticationSessionError {
        switch authError.code {
            
        case .canceledLogin:
            // User tapped "Cancel" button
            // This is normal user behavior, not an error
            print("👤 User canceled authentication")
            
        case .presentationContextNotProvided:
            // Developer error - forgot to set presentationContextProvider
            print("🔧 Missing presentation context provider")
            
        case .presentationContextInvalid:
            // System error - the presentation context is invalid
            print("⚠️ Invalid presentation context")
            
        @unknown default:
            // Future error cases in newer iOS versions
            print("❓ Unknown ASWebAuthenticationSession error: \(authError)")
        }
    }
}
```

### 2.5 PKCE Integration with ASWebAuthenticationSession 🔒

```swift
// ASWebAuthenticationSession works perfectly with PKCE
// (Proof Key for Code Exchange) for enhanced mobile security

class PKCEEnhancedAuth {
    
    /// Generates a cryptographically secure code verifier for PKCE
    /// 
    /// PKCE (RFC 7636) adds an extra layer of security to OAuth flows by ensuring
    /// that only the app that initiated the authentication can complete it.
    /// 
    /// The code verifier must be:
    /// - 43-128 characters long
    /// - Use characters: A-Z, a-z, 0-9, -, ., _, ~
    /// - Cryptographically random
    /// 
    /// - Returns: Base64URL-encoded random string suitable for PKCE
    private func generateCodeVerifier() -> String {
        // Generate 32 random bytes (256 bits of entropy)
        var buffer = Data(count: 32)
        let result = buffer.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            // Fallback to UUID-based generation if system random fails
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        
        // Convert to base64url encoding (URL-safe base64 without padding)
        return buffer.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Generates the code challenge from the code verifier
    /// 
    /// The code challenge is derived from the code verifier using SHA256 hash
    /// and base64url encoding. This is sent to the OAuth server during the
    /// authorization request.
    /// 
    /// - Parameter codeVerifier: The original code verifier
    /// - Returns: SHA256 hash of code verifier, base64url-encoded
    private func generateCodeChallenge(from codeVerifier: String) -> String {
        // Convert code verifier to data
        let data = codeVerifier.data(using: .utf8)!
        
        // Calculate SHA256 hash
        let hashedData = SHA256.hash(data: data)
        
        // Convert to base64url encoding
        return Data(hashedData).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Complete PKCE-enabled OAuth flow with ASWebAuthenticationSession
    func authenticateWithPKCE() {
        
        // 1. Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // 2. Build authorization URL with PKCE parameters
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"), // SHA256 method
            URLQueryItem(name: "state", value: generateRandomState())
        ]
        
        // 3. Start ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: components!.url!,
            callbackURLScheme: extractScheme(from: redirectURI)
        ) { callbackURL, error in
            
            // 4. In the callback, exchange code for token with code verifier
            if let callbackURL = callbackURL {
                self.exchangeCodeForToken(
                    from: callbackURL,
                    codeVerifier: codeVerifier  // Send original code verifier
                )
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
}
```

### 2.6 Best Practices and Recommendations 📋

```swift
struct ASWebAuthenticationSessionBestPractices {
    
    // ✅ DO: Always set presentation context provider
    func setupSession() {
        webAuthSession.presentationContextProvider = self
    }
    
    // ✅ DO: Handle all error cases
    func handleErrors(error: Error) {
        // Provide user-friendly error messages
        // Log errors for debugging
        // Implement retry logic where appropriate
    }
    
    // ✅ DO: Use PKCE for mobile apps
    let usePKCE = true
    
    // ✅ DO: Validate state parameter
    let validateState = true
    
    // ✅ DO: Use HTTPS for authorization URLs
    let authorizationURL = "https://accounts.google.com/oauth/authorize"
    
    // ❌ DON'T: Use HTTP URLs (will fail)
    let badURL = "http://insecure-oauth.com/auth"
    
    // ✅ DO: Clean up sessions properly
    func cleanup() {
        webAuthSession = nil
    }
    
    // ✅ DO: Consider user experience
    func configureSession() {
        // Allow reusing existing login sessions for better UX
        webAuthSession.prefersEphemeralWebBrowserSession = false
    }
}
```

### 2.7 Comparison with Alternatives 📊

| Approach | Security | User Trust | Implementation | Recommendation |
|----------|----------|------------|----------------|----------------|
| **ASWebAuthenticationSession** | ✅ Excellent | ✅ High | ✅ Simple | **✅ Recommended** |
| **SFSafariViewController** | ⚠️ Good | ✅ High | ⚠️ Complex | ⚠️ Possible |
| **WKWebView** | ❌ Poor | ❌ Low | ✅ Simple | ❌ Not Recommended |
| **UIWebView** | ❌ Very Poor | ❌ Very Low | ✅ Simple | ❌ Deprecated |

```swift
// Why ASWebAuthenticationSession wins:

// 1. Purpose-built for OAuth
let purposeBuilt = "Designed specifically for OAuth 2.0 flows"

// 2. Automatic security features
let autoSecurity = [
    "HTTPS enforcement",
    "Callback URL validation", 
    "Secure context isolation",
    "System-level security features"
]

// 3. Better user experience
let userExp = [
    "Familiar Safari interface",
    "Existing login session reuse",
    "Native iOS app switching",
    "Proper accessibility support"
]

// 4. Developer convenience
let devConvenience = [
    "Simple API",
    "Automatic error handling",
    "Built-in callback management",
    "No need to manage web views"
]
```

---

## 📚 Part 3: Redirect URLs - Deep Dive

### 3.1 What are Redirect URLs?

**Redirect URLs** are the mechanism that brings the user back to your app after authentication. Think of them as your app's "return address."

### 3.2 Types of Redirect URLs

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

### 3.3 How Redirect URLs Work in iOS

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

### 3.4 Security Considerations for Redirect URLs

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

## 📚 Part 4: Complete iOS Implementation

### 4.1 Enhanced OAuth Manager

```swift
import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit // Required for PKCE implementation in Swift 6

// MARK: - Enhanced OAuth Configuration
/// Configuration struct that holds all OAuth 2.0 settings for the authorization flow
/// Compatible with iOS 16.6+, SwiftUI, and Swift 6
/// 
/// This struct conforms to Sendable protocol for Swift 6 concurrency safety,
/// allowing it to be safely passed between actors and concurrent contexts.
/// Designed specifically for SwiftUI applications with modern async/await patterns.
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
    /// This ensures only the app that started the flow can complete it
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
    
    /// Optional custom URL scheme for development
    /// This allows using a different scheme during development/testing
    /// 
    /// Example: "dev.com.yourcompany.yourapp.oauth"
    /// 
    /// Leave nil to use the default scheme from redirectURI
    let developmentURLScheme: String?
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
    /// - client_secret: For traditional OAuth (not recommended for mobile apps)
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
    
    /// Complete PKCE-enabled OAuth flow with ASWebAuthenticationSession
    func authenticateWithPKCE() {
        
        // 1. Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // 2. Build authorization URL with PKCE parameters
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"), // SHA256 method
            URLQueryItem(name: "state", value: generateRandomState())
        ]
        
        // 3. Start ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: components!.url!,
            callbackURLScheme: extractScheme(from: redirectURI)
        ) { callbackURL, error in
            
            // 4. In the callback, exchange code for token with code verifier
            if let callbackURL = callbackURL {
                self.exchangeCodeForToken(
                    from: callbackURL,
                    codeVerifier: codeVerifier  // Send original code verifier
                )
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
}
```

### 4.2 Complete Code Listing

```swift
import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit // Required for PKCE implementation in Swift 6

// MARK: - Enhanced OAuth Configuration
/// Configuration struct that holds all OAuth 2.0 settings for the authorization flow
/// Compatible with iOS 16.6+, SwiftUI, and Swift 6
/// 
/// This struct conforms to Sendable protocol for Swift 6 concurrency safety,
/// allowing it to be safely passed between actors and concurrent contexts.
/// Designed specifically for SwiftUI applications with modern async/await patterns.
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
    /// This ensures only the app that started the flow can complete it
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
    
    /// Optional custom URL scheme for development
    /// This allows using a different scheme during development/testing
    /// 
    /// Example: "dev.com.yourcompany.yourapp.oauth"
    /// 
    /// Leave nil to use the default scheme from redirectURI
    let developmentURLScheme: String?
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
    /// - client_secret: For traditional OAuth (not recommended for mobile apps)
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
    
    /// Complete PKCE-enabled OAuth flow with ASWebAuthenticationSession
    func authenticateWithPKCE() {
        
        // 1. Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // 2. Build authorization URL with PKCE parameters
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"), // SHA256 method
            URLQueryItem(name: "state", value: generateRandomState())
        ]
        
        // 3. Start ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: components!.url!,
            callbackURLScheme: extractScheme(from: redirectURI)
        ) { callbackURL, error in
            
            // 4. In the callback, exchange code for token with code verifier
            if let callbackURL = callbackURL {
                self.exchangeCodeForToken(
                    from: callbackURL,
                    codeVerifier: codeVerifier  // Send original code verifier
                )
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
}
```

### 4.2 Complete Code Listing

```swift
import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit // Required for PKCE implementation in Swift 6

// MARK: - Enhanced OAuth Configuration
/// Configuration struct that holds all OAuth 2.0 settings for the authorization flow
/// Compatible with iOS 16.6+, SwiftUI, and Swift 6
/// 
/// This struct conforms to Sendable protocol for Swift 6 concurrency safety,
/// allowing it to be safely passed between actors and concurrent contexts.
/// Designed specifically for SwiftUI applications with modern async/await patterns.
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
    /// This ensures only the app that started the flow can complete it
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
    
    /// Optional custom URL scheme for development
    /// This allows using a different scheme during development/testing
    /// 
    /// Example: "dev.com.yourcompany.yourapp.oauth"
    /// 
    /// Leave nil to use the default scheme from redirectURI
    let developmentURLScheme: String?
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
    /// - client_secret: For traditional OAuth (not recommended for mobile apps)
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
    
    /// Complete PKCE-enabled OAuth flow with ASWebAuthenticationSession
    func authenticateWithPKCE() {
        
        // 1. Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // 2. Build authorization URL with PKCE parameters
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"), // SHA256 method
            URLQueryItem(name: "state", value: generateRandomState())
        ]
        
        // 3. Start ASWebAuthenticationSession
        let session = ASWebAuthenticationSession(
            url: components!.url!,
            callbackURLScheme: extractScheme(from: redirectURI)
        ) { callbackURL, error in
            
            // 4. In the callback, exchange code for token with code verifier
            if let callbackURL = callbackURL {
                self.exchangeCodeForToken(
                    from: callbackURL,
                    codeVerifier: codeVerifier  // Send original code verifier
                )
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
}
```

### 4.3 Example Usage

```swift
import SwiftUI

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var oauthManager = EnhancedOAuthManager(config: yourOAuthConfig)
    
    var body: some View {
        VStack {
            if oauthManager.isAuthenticated {
                Text("Welcome, \(oauthManager.currentUser?.userInfo?.name ?? "User")!")
            } else {
                Button("Sign In with Google") {
                    Task {
                        do {
                            let user = try await oauthManager.authenticate()
                            print("Authenticated user: \(user)")
                        } catch {
                            print("Authentication error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        .onOpenURL { url in
            // Handle incoming URL from OAuth provider
            oauthManager.handleIncomingURL(url)
        }
    }
}
```

---

## 📚 Part 5: Historical Alternatives to ASWebAuthenticationSession

### 2.8 Historical Evolution: Pre-ASWebAuthenticationSession Era 📜

Before `ASWebAuthenticationSession` was introduced in iOS 12, developers had to use various alternatives for OAuth authentication. Let's explore how OAuth implementation has evolved through different iOS versions and Swift versions.

#### 2.8.1 The Dark Ages: iOS 9-11 & Swift 3-4 Era

**1. UIWebView Approach (Deprecated since iOS 12)**
```swift
// ⚠️ DEPRECATED: How OAuth was done in iOS 9-11 with Swift 3-4
import UIKit
import WebKit

class LegacyOAuthViewController: UIViewController {
    
    @IBOutlet weak var webView: UIWebView! // Deprecated since iOS 12
    private var authURL: URL?
    private var callbackURLScheme: String?
    
    // Swift 3/4 style - no async/await, lots of optionals handling
    func startOAuthFlow(authURL: URL, callbackScheme: String) {
        self.authURL = authURL
        self.callbackURLScheme = callbackScheme
        
        // UIWebView was the primary option
        webView.delegate = self
        let request = URLRequest(url: authURL)
        webView.loadRequest(request)
    }
}

// Swift 3/4 delegate pattern
extension LegacyOAuthViewController: UIWebViewDelegate {
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        guard let url = request.url,
              let scheme = url.scheme,
              let callbackScheme = callbackURLScheme else {
            return true
        }
        
        // Manual callback handling
        if scheme == callbackScheme {
            // Extract authorization code manually
            if let code = extractAuthorizationCode(from: url) {
                // Handle success - lots of manual completion handling
                handleAuthorizationCode(code)
            }
            return false
        }
        
        return true
    }
    
    // Swift 3/4 error handling - no Result type
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        // Manual error handling
        print("OAuth failed: \(error.localizedDescription)")
    }
}
```

**Problems with UIWebView:**
```swift
struct UIWebViewProblems {
    let securityIssues = [
        "JavaScript injection possible",
        "No address bar - users can't verify URL",
        "App can intercept credentials",
        "Shared cookie storage with app",
        "No modern browser security features"
    ]
    
    let technicalIssues = [
        "Memory leaks common",
        "Poor performance",
        "No modern JavaScript support",
        "Deprecated since iOS 12",
        "Apple actively discourages usage"
    ]
    
    let developerExperience = [
        "Manual callback URL handling",
        "Complex delegate pattern",
        "No built-in OAuth support",
        "Lots of boilerplate code",
        "Error-prone implementation"
    ]
}
```

**2. SFSafariViewController Approach (iOS 9+)**
```swift
// Better alternative in iOS 9-11 era
import SafariServices

class ImprovedOAuthManager: NSObject {
    
    private var safariVC: SFSafariViewController?
    private var authURL: URL?
    private var completionHandler: ((URL?, Error?) -> Void)?
    
    // Swift 4 style - still no async/await
    func authenticate(authURL: URL, completion: @escaping (URL?, Error?) -> Void) {
        self.authURL = authURL
        self.completionHandler = completion
        
        // Present SFSafariViewController
        safariVC = SFSafariViewController(url: authURL)
        safariVC?.delegate = self
        
        // Manual presentation logic
        if let topVC = UIApplication.shared.keyWindow?.rootViewController {
            topVC.present(safariVC!, animated: true)
        }
    }
    
    // Manual URL handling through app delegate
    func handleCallback(url: URL) {
        safariVC?.dismiss(animated: true) {
            self.completionHandler?(url, nil)
        }
    }
}

// Swift 4 delegate implementation
extension ImprovedOAuthManager: SFSafariViewControllerDelegate {
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // User canceled
        completionHandler?(nil, OAuthError.userCanceled)
    }
}

// App Delegate handling (pre-SceneDelegate era)
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Manual routing to OAuth manager
        if url.scheme == "com.yourapp.oauth" {
            OAuthManager.shared.handleCallback(url: url)
            return true
        }
        
        return false
    }
}
```

#### 2.8.2 The Transition Period: iOS 12-15 & Swift 5 Era

**ASWebAuthenticationSession Introduction (iOS 12)**
```swift
// iOS 12+ introduced ASWebAuthenticationSession but with limitations
import AuthenticationServices

@available(iOS 12.0, *)
class TransitionOAuthManager: NSObject {
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    // Swift 5 - still using completion handlers, no async/await yet
    func authenticate(authURL: URL, callbackScheme: String, completion: @escaping (URL?, Error?) -> Void) {
        
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { callbackURL, error in
            completion(callbackURL, error)
        }
        
        // iOS 12-12.x: No presentation context provider needed
        webAuthSession?.start()
    }
}

// iOS 13+ required presentation context provider
@available(iOS 13.0, *)
extension TransitionOAuthManager: ASWebAuthenticationPresentationContextProviding {
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // iOS 13+ style
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
```

**Swift 5.0-5.4 Challenges:**
```swift
struct Swift5Challenges {
    
    // No async/await - completion handler hell
    func oldStyleNetworking() {
        // Nested completion handlers were common
        authenticateUser { result in
            switch result {
            case .success(let code):
                self.exchangeCodeForToken(code) { tokenResult in
                    switch tokenResult {
                    case .success(let token):
                        self.fetchUserInfo(token) { userResult in
                            // Callback hell...
                        }
                    case .failure(let error):
                        // Handle error
                    }
                }
            case .failure(let error):
                // Handle error
            }
        }
    }
    
    // Manual JSON parsing
    func parseTokenResponse(data: Data) throws -> TokenResponse {
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        guard let accessToken = json["access_token"] as? String,
              let tokenType = json["token_type"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw OAuthError.invalidResponse
        }
        
        return TokenResponse(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            refreshToken: json["refresh_token"] as? String
        )
    }
}
```

#### 2.8.3 Modern Era: iOS 16.6+ & Swift 6

**Current Best Practices (2024+)**
```swift
// iOS 16.6+ with Swift 6 - Modern async/await patterns
import AuthenticationServices
import SwiftUI

@MainActor
class ModernOAuthManager: NSObject, ObservableObject {
    
    @Published var isAuthenticated = false
    @Published var currentUser: OAuthUser?
    
    // Swift 6 async/await - clean, readable code
    func authenticate() async throws -> OAuthUser {
        
        let authURL = try buildAuthorizationURL()
        
        // Modern ASWebAuthenticationSession usage
        let callbackURL = try await withCheckedThrowingContinuation { continuation in
            
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: extractScheme(from: config.redirectURI)
            ) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: OAuthError.unknownError)
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
        
        // Extract and validate authorization code
        let authCode = try extractAndValidateAuthCode(from: callbackURL)
        
        // Exchange code for token
        let token = try await exchangeCodeForToken(authCode)
        
        // Fetch user info
        let user = try await fetchUserInfo(token: token)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
        
        return user
    }
}

// SwiftUI integration with modern patterns
struct ContentView: View {
    @StateObject private var oauthManager = ModernOAuthManager(config: yourOAuthConfig)
    
    var body: some View {
        VStack {
            if oauthManager.isAuthenticated {
                Text("Welcome, \(oauthManager.currentUser?.name ?? "User")!")
            } else {
                Button("Sign In") {
                    Task {
                        try await oauthManager.authenticate()
                    }
                }
            }
        }
    }
}
```

#### 2.8.4 Key Evolution Timeline

```swift
struct OAuthEvolutionTimeline {
    
    let milestones = [
        
        // iOS 9-11 Era (2015-2018)
        "iOS 9-11 + Swift 3-4": [
            "UIWebView primary method (insecure)",
            "SFSafariViewController introduced (better)",
            "Manual URL scheme handling",
            "Completion handler patterns",
            "Complex delegate implementations"
        ],
        
        // iOS 12-15 Era (2018-2021)
        "iOS 12-15 + Swift 5.0-5.4": [
            "ASWebAuthenticationSession introduced",
            "Presentation context provider required (iOS 13+)",
            "Better security but still completion handlers",
            "Result type introduced",
            "Combine framework available"
        ],
        
        // Modern Era (2022+)
        "iOS 16+ + Swift 5.5-6": [
            "async/await support",
            "Actor isolation and Sendable",
            "SwiftUI native integration",
            "Structured concurrency",
            "Better error handling with typed throws"
        ]
    ]
}
```

#### 2.8.5 Migration Guide: Legacy to Modern

**From UIWebView/SFSafariViewController to ASWebAuthenticationSession:**
```swift
// ❌ OLD: UIWebView approach
class LegacyOAuth {
    func authenticate(completion: @escaping (String?, Error?) -> Void) {
        // 50+ lines of complex web view handling
        // Security vulnerabilities
        // Poor user experience
    }
}

// ✅ NEW: ASWebAuthenticationSession approach
class ModernOAuth {
    func authenticate() async throws -> String {
        // 10 lines of clean, secure code
        // Built-in security features
        // Excellent user experience
    }
}
```

**From Completion Handlers to Async/Await:**
```swift
// ❌ OLD: Completion handler hell
func oldAuthenticate(completion: @escaping (Result<User, Error>) -> Void) {
    startAuth { authResult in
        switch authResult {
        case .success(let code):
            self.exchangeToken(code) { tokenResult in
                switch tokenResult {
                case .success(let token):
                    self.fetchUserInfo(token) { userResult in
                        // Callback hell...
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}

// ✅ NEW: Clean async/await
func modernAuthenticate() async throws -> User {
    let code = try await startAuth()
    let token = try await exchangeToken(code)
    let user = try await fetchUserInfo(token)
    return user
}
```

**Key Benefits of Modern Approach:**
```swift
struct ModernAdvantages {
    let security = [
        "ASWebAuthenticationSession isolation",
        "PKCE built-in support",
        "Automatic HTTPS enforcement",
        "System-level security features"
    ]
    
    let developer_experience = [
        "async/await eliminates callback hell",
        "Swift 6 Sendable ensures thread safety",
        "SwiftUI native integration",
        "Structured concurrency patterns",
        "Better error handling with typed throws"
    ]
    
    let user_experience = [
        "Familiar Safari interface",
        "Session reuse capabilities",
        "Native iOS animations",
        "Accessibility support",
        "Better performance"
    ]
}
```

---
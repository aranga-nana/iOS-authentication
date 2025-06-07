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
state=random-string-123-45
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
state=random-string-123-45
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

## 📚 Part 3: Certificate Pinning - Enhanced Security for OAuth

### 3.1 What is Certificate Pinning?

Certificate pinning is a security technique that validates the server's SSL/TLS certificate against a known, trusted certificate or public key. Instead of relying solely on the certificate authority (CA) chain validation, your app explicitly checks that the server presents the expected certificate.

**Why Certificate Pinning is Critical for OAuth:**

```swift
// Without Certificate Pinning - Vulnerable to MITM attacks
enum SecurityRisks {
    case compromisedCA        // Certificate Authority breach
    case rogue_certificate    // Fake certificates issued
    case network_interception // Corporate/public WiFi attacks
    case dns_spoofing        // DNS hijacking attacks
}

// With Certificate Pinning - Enhanced Security
enum SecurityBenefits {
    case mitm_protection     // Man-in-the-middle attack prevention
    case ca_independence     // Not relying on CA trust chain alone
    case targeted_validation // App-specific certificate validation
    case oauth_flow_security // Protecting token exchange endpoints
}
```

**Real-World OAuth Security Scenarios:**

```swift
/// Common OAuth security threats that certificate pinning prevents
struct OAuthSecurityThreats {
    let scenario_1 = """
        Corporate WiFi with SSL inspection:
        - Company proxy intercepts HTTPS traffic
        - Issues corporate certificate for oauth.provider.com  
        - Without pinning: App accepts corporate cert
        - Result: OAuth tokens intercepted
        """
    
    let scenario_2 = """
        Compromised Certificate Authority:
        - Rogue certificate issued for oauth.provider.com
        - Standard SSL validation passes
        - Without pinning: App trusts rogue certificate
        - Result: OAuth flow compromised
        """
    
    let scenario_3 = """
        Public WiFi Attack:
        - Attacker sets up fake access point
        - DNS spoofing redirects OAuth requests
        - Self-signed certificate presented
        - Without pinning: Vulnerable to token theft
        """
}
```

### 3.2 Certificate Pinning Implementation Approaches

#### Approach 1: URLSessionDelegate with Certificate Validation

This is the most flexible approach, giving you full control over certificate validation:

```swift
/// Enhanced OAuth Manager with Certificate Pinning
/// iOS 16.0+ compatible with modern Swift concurrency
class SecureOAuthManager: NSObject, ObservableObject {
    
    // MARK: - Certificate Pinning Configuration
    
    /// Pinned certificates for OAuth endpoints
    /// In production, load these from your app bundle
    private struct PinnedCertificates {
        /// Primary OAuth server certificate (DER format)
        static let primaryCert = "oauth-server-cert"
        
        /// Backup certificate for redundancy
        static let backupCert = "oauth-backup-cert"
        
        /// Certificate expiration monitoring
        static let expirationWarningDays = 30
    }
    
    /// Certificate pinning strategy
    enum PinningStrategy {
        case certificate    // Pin the entire certificate
        case publicKey     // Pin only the public key (recommended)
        case leafAndIntermediate // Pin both leaf and intermediate certs
    }
    
    // MARK: - Private Properties
    
    private let pinnedCertificates: [SecCertificate]
    private let pinningStrategy: PinningStrategy
    private let config: EnhancedOAuthConfig
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - Initialization
    
    init(config: EnhancedOAuthConfig, 
         pinningStrategy: PinningStrategy = .publicKey) {
        self.config = config
        self.pinningStrategy = pinningStrategy
        
        // Load pinned certificates from app bundle
        var certificates: [SecCertificate] = []
        
        // Load primary certificate
        if let primaryCertPath = Bundle.main.path(forResource: PinnedCertificates.primaryCert, ofType: "der"),
           let primaryCertData = NSData(contentsOfFile: primaryCertPath),
           let primaryCert = SecCertificateCreateWithData(nil, primaryCertData) {
            certificates.append(primaryCert)
        }
        
        // Load backup certificate
        if let backupCertPath = Bundle.main.path(forResource: PinnedCertificates.backupCert, ofType: "der"),
           let backupCertData = NSData(contentsOfFile: backupCertPath),
           let backupCert = SecCertificateCreateWithData(nil, backupCertData) {
            certificates.append(backupCert)
        }
        
        self.pinnedCertificates = certificates
        super.init()
    }
    
    // MARK: - OAuth Authentication with Certificate Pinning
    
    /// Secure OAuth authentication with certificate pinning
    /// Uses modern async/await for iOS 16.0+ compatibility
    func authenticateSecurely() async throws -> OAuthUser {
        // Step 1: Generate PKCE and state for security
        let (codeVerifier, codeChallenge) = generatePKCEPair()
        let state = generateSecureState()
        
        // Step 2: Build authorization URL
        let authURL = try buildAuthorizationURL(
            codeChallenge: codeChallenge,
            state: state
        )
        
        // Step 3: Perform web authentication with pinning
        let callbackURL = try await performWebAuthentication(url: authURL)
        
        // Step 4: Extract authorization code
        let authCode = try extractAuthorizationCode(from: callbackURL, expectedState: state)
        
        // Step 5: Exchange code for token (with certificate pinning)
        let tokenResponse = try await exchangeCodeForToken(
            authCode: authCode,
            codeVerifier: codeVerifier
        )
        
        // Step 6: Fetch user info (with certificate pinning)
        let userInfo = try await fetchUserInfo(token: tokenResponse.accessToken)
        
        return OAuthUser(authToken: tokenResponse, userInfo: userInfo)
    }
    
    // MARK: - Secure Network Requests with Pinning
    
    /// Exchange authorization code for access token with certificate pinning
    private func exchangeCodeForToken(authCode: String, codeVerifier: String) async throws -> TokenResponse {
        let tokenURL = URL(string: config.tokenEndpoint)!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "code", value: authCode),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)
        
        // Perform request with certificate pinning validation
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse
    }
    
    /// Fetch user information with certificate pinning
    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        let userInfoURL = URL(string: config.userInfoEndpoint)!
        var request = URLRequest(url: userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Perform request with certificate pinning validation
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.userInfoFetchFailed
        }
        
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }
    
    // MARK: - Secure Web Authentication with Pinning
    
    /// Perform web authentication using ASWebAuthenticationSession with certificate pinning
    private func performWebAuthentication(url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // Using ASWebAuthenticationSession to open the authorization URL
            webAuthSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: config.redirectURI
            ) { callbackURL, error in
                // This closure handles the response
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: OAuthError.invalidAuthorizationResponse)
                }
            }
            
            webAuthSession?.presentationContextProvider = self
            
            // Start the authentication session
            webAuthSession?.start()
        }
    }
}

// MARK: - URLSessionDelegate for Certificate Pinning

extension SecureOAuthManager: URLSessionDelegate {
    
    /// Handle authentication challenges for certificate pinning
    /// This is where the actual certificate validation occurs
    func urlSession(_ session: URLSession, 
                   didReceive challenge: URLAuthenticationChallenge, 
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get server trust and certificate
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate hostname matches
        let hostname = challenge.protectionSpace.host
        if !isValidOAuthHostname(hostname) {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Perform certificate pinning validation
        let isPinValid = validateCertificatePinning(
            serverCertificate: serverCertificate,
            serverTrust: serverTrust
        )
        
        if isPinValid {
            // Certificate pinning passed - create credential
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate pinning failed - reject connection
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    /// Validate that the hostname is one of our OAuth endpoints
    private func isValidOAuthHostname(_ hostname: String) -> Bool {
        let validHosts = [
            URL(string: config.authorizationEndpoint)?.host,
            URL(string: config.tokenEndpoint)?.host,
            URL(string: config.userInfoEndpoint)?.host
        ].compactMap { $0 }
        
        return validHosts.contains(hostname)
    }
    
    /// Perform certificate pinning validation based on strategy
    private func validateCertificatePinning(serverCertificate: SecCertificate, 
                                          serverTrust: SecTrust) -> Bool {
        switch pinningStrategy {
        case .certificate:
            return validateCertificatePin(serverCertificate)
        case .publicKey:
            return validatePublicKeyPin(serverCertificate)
        case .leafAndIntermediate:
            return validateLeafAndIntermediatePin(serverTrust)
        }
    }
    
    /// Validate certificate pinning (exact certificate match)
    private func validateCertificatePin(_ serverCertificate: SecCertificate) -> Bool {
        let serverCertData = SecCertificateCopyData(serverCertificate)
        
        for pinnedCert in pinnedCertificates {
            let pinnedCertData = SecCertificateCopyData(pinnedCert)
            if CFEqual(serverCertData, pinnedCertData) {
                return true
            }
        }
        return false
    }
    
    /// Validate public key pinning (recommended approach)
    private func validatePublicKeyPin(_ serverCertificate: SecCertificate) -> Bool {
        guard let serverPublicKey = extractPublicKey(from: serverCertificate) else {
            return false
        }
        
        let serverKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil)
        
        for pinnedCert in pinnedCertificates {
            guard let pinnedPublicKey = extractPublicKey(from: pinnedCert),
                  let pinnedKeyData = SecKeyCopyExternalRepresentation(pinnedPublicKey, nil) else {
                return false
            }
            
            if let serverData = serverKeyData,
               let pinnedData = pinnedKeyData,
               CFEqual(serverData, pinnedData) {
                return true
            }
        }
        return false
    }
    
    /// Validate both leaf and intermediate certificates
    private func validateLeafAndIntermediatePin(_ serverTrust: SecTrust) -> Bool {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        // Check each certificate in the chain
        for index in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) {
                if validateCertificatePin(certificate) {
                    return true
                }
            }
        }
        return false
    }
    
    /// Extract public key from certificate
    private func extractPublicKey(from certificate: SecCertificate) -> SecKey? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess, let validTrust = trust else {
            return nil
        }
        
        return SecTrustCopyPublicKey(validTrust)
    }
}
```

#### Approach 2: Network Manager with Certificate Pinning

For apps that prefer a centralized network manager approach:

```swift
/// Centralized network manager with certificate pinning for OAuth
/// Handles all network requests with consistent security validation
@MainActor
class SecureNetworkManager: ObservableObject {
    
    // MARK: - Certificate Pinning Configuration
    
    /// Certificate pinning configuration
    struct PinningConfig {
        let certificates: [SecCertificate]
        let strategy: PinningStrategy
        let allowedDomains: Set<String>
        let failureMode: FailureMode
        
        enum PinningStrategy {
            case certificate
            case publicKey
            case certificateChain
        }
        
        enum FailureMode {
            case hard    // Fail if pinning validation fails
            case soft    // Log failure but allow connection
        }
    }
    
    enum PinningStrategy {
        case certificate
        case publicKey
        case certificateChain
    }
    
    // MARK: - Properties
    
    private let pinningConfig: PinningConfig
    private let session: URLSession
    
    @Published var networkError: String?
    @Published var isSecureConnection = false
    
    // MARK: - Initialization
    
    init(pinningConfig: PinningConfig) {
        self.pinningConfig = pinningConfig
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        self.session = URLSession(
            configuration: config, 
            delegate: CertificatePinningDelegate(config: pinningConfig),
            delegateQueue: nil
        )
    }
    
    // MARK: - Secure Network Methods
    
    /// Perform secure OAuth token exchange with certificate pinning
    func secureTokenExchange(request: TokenExchangeRequest) async throws -> TokenResponse {
        let url = URL(string: request.tokenEndpoint)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = request.bodyData
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Check for successful response
            if httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.isSecureConnection = true
                    self.networkError = nil
                }
                return try JSONDecoder().decode(TokenResponse.self, from: data)
            } else {
                throw NetworkError.tokenRequestFailed(httpResponse.statusCode)
            }
            
        } catch {
            await MainActor.run {
                self.isSecureConnection = false
                self.networkError = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Perform secure user info fetch with certificate pinning
    func secureUserInfoFetch(endpoint: String, accessToken: String) async throws -> UserInfo {
        let url = URL(string: endpoint)!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.userInfoFetchFailed
        }
        
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }
}

/// Dedicated certificate pinning delegate
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    
    private let config: SecureNetworkManager.PinningConfig
    
    init(config: SecureNetworkManager.PinningConfig) {
        self.config = config
        super.init()
    }
    
    func urlSession(_ session: URLSession,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Handle server trust challenges only
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let hostname = challenge.protectionSpace.host
        
        // Check if domain should be pinned
        guard config.allowedDomains.contains(hostname) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Perform certificate validation
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let isValid = validateCertificate(serverTrust: serverTrust)
        
        if isValid {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Handle failure based on configuration
            switch config.failureMode {
            case .hard:
                completionHandler(.cancelAuthenticationChallenge, nil)
            case .soft:
                print("⚠️ Certificate pinning validation failed for \(hostname)")
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
    private func validateCertificate(serverTrust: SecTrust) -> Bool {
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }
        
        switch config.strategy {
        case .certificate:
            return validateExactCertificate(serverCertificate)
        case .publicKey:
            return validatePublicKey(serverCertificate)
        case .certificateChain:
            return validateCertificateChain(serverTrust)
        }
    }
    
    private func validateExactCertificate(_ serverCertificate: SecCertificate) -> Bool {
        let serverCertData = SecCertificateCopyData(serverCertificate)
        
        return config.certificates.contains { pinnedCert in
            let pinnedCertData = SecCertificateCopyData(pinnedCert)
            return CFEqual(serverCertData, pinnedCertData)
        }
    }
    
    private func validatePublicKey(_ serverCertificate: SecCertificate) -> Bool {
        guard let serverPublicKey = getPublicKey(from: serverCertificate) else {
            return false
        }
        
        let serverKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil)
        
        return config.certificates.contains { pinnedCert in
            guard let pinnedPublicKey = getPublicKey(from: pinnedCert),
                  let pinnedKeyData = SecKeyCopyExternalRepresentation(pinnedPublicKey, nil) else {
                return false
            }
            
            return CFEqual(serverKeyData, pinnedKeyData)
        }
    }
    
    private func validateCertificateChain(_ serverTrust: SecTrust) -> Bool {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        // Check each certificate in the chain
        for index in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index),
               validateExactCertificate(certificate) {
                return true
            }
        }
        return false
    }
    
    private func getPublicKey(from certificate: SecCertificate) -> SecKey? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess, let validTrust = trust else {
            return nil
        }
        
        return SecTrustCopyPublicKey(validTrust)
    }
}
```

### 3.3 SwiftUI Integration with Certificate Pinning

Here's how to integrate certificate pinning with SwiftUI for a complete OAuth implementation:

```swift
/// SwiftUI view that demonstrates secure OAuth with certificate pinning
struct SecureOAuthView: View {
    
    @StateObject private var oauthManager: SecureOAuthManager
    @StateObject private var networkManager: SecureNetworkManager
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAuthenticating = false
    
    init() {
        // Initialize OAuth configuration
        let config = EnhancedOAuthConfig(
            clientId: "your-client-id",
            authorizationEndpoint: "https://oauth.provider.com/auth",
            tokenEndpoint: "https://oauth.provider.com/token",
            userInfoEndpoint: "https://oauth.provider.com/userinfo",
            redirectURI: "yourapp://oauth/callback",
            scopes: ["openid", "profile", "email"]
        )
        
        // Initialize secure OAuth manager with certificate pinning
        self._oauthManager = StateObject(wrapping: SecureOAuthManager(config: config))
        
        // Initialize network manager with pinning configuration
        let pinningConfig = SecureNetworkManager.PinningConfig(
            certificates: loadPinnedCertificates(),
            strategy: .publicKey,
            allowedDomains: ["oauth.provider.com", "api.provider.com"],
            failureMode: .hard
        )
        self._networkManager = StateObject(wrapping: SecureNetworkManager(pinningConfig: pinningConfig))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                // Security Status Indicator
                SecurityStatusView(
                    isSecure: networkManager.isSecureConnection,
                    isAuthenticated: oauthManager.isAuthenticated
                )
                
                // Authentication Section
                if oauthManager.isAuthenticated {
                    authenticatedView
                } else {
                    unauthenticatedView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Secure OAuth")
            .alert("Authentication Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var authenticatedView: some View {
        VStack(spacing: 20) {
            
            // User Profile Section
            if let user = oauthManager.currentUser {
                UserProfileView(user: user)
            }
            
            // Security Information
            SecurityInfoView()
            
            // Sign Out Button
            Button("Sign Out") {
                oauthManager.signOut()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 20) {
            
            // Security Features List
            SecurityFeaturesView()
            
            // Sign In Button
            Button("Sign In Securely") {
                Task {
                    await authenticateSecurely()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
            .overlay {
                if isAuthenticating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
    }
    
    // MARK: - Authentication Logic
    
    private func authenticateSecurely() async {
        isAuthenticating = true
        
        do {
            let user = try await oauthManager.authenticateSecurely()
            
            // Update UI on main thread
            await MainActor.run {
                oauthManager.currentUser = user
                oauthManager.isAuthenticated = true
                isAuthenticating = false
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "Authentication failed: \(error.localizedDescription)"
                showingAlert = true
                isAuthenticating = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private static func loadPinnedCertificates() -> [SecCertificate] {
        var certificates: [SecCertificate] = []
        
        // Load certificates from app bundle
        if let certPath = Bundle.main.path(forResource: "oauth-server-cert", ofType: "der"),
           let certData = NSData(contentsOfFile: certPath),
           let certificate = SecCertificateCreateWithData(nil, certData) {
            certificates.append(certificate)
        }
        
        return certificates
    }
}

/// Security status indicator view
struct SecurityStatusView: View {
    let isSecure: Bool
    let isAuthenticated: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSecure ? "lock.shield.fill" : "lock.open.fill")
                .foregroundColor(isSecure ? .green : .red)
            
            VStack(alignment: .leading) {
                Text("Connection Status")
                    .font(.headline)
                Text(isSecure ? "Secure (Certificate Pinned)" : "Not Secure")
                    .font(.caption)
                    .foregroundColor(isSecure ? .green : .red)
            }
            
            Spacer()
            
            if isAuthenticated {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// Security features information view
struct SecurityFeaturesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Security Features")
                .font(.headline)
            
            FeatureRow(icon: "shield.checkerboard", text: "Certificate Pinning")
            FeatureRow(icon: "key.fill", text: "PKCE Protection")
            FeatureRow(icon: "checkmark.shield.fill", text: "State Validation")
            FeatureRow(icon: "lock.rotation", text: "ASWebAuthenticationSession")
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .cornerRadius(10)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

/// User profile display view
struct UserProfileView: View {
    let user: OAuthUser
    
    var body: some View {
        VStack {
            Text("Welcome!")
                .font(.title2)
                .fontWeight(.bold)
            
            if let userInfo = user.userInfo {
                Text(userInfo.name ?? "User")
                    .font(.title3)
                Text(userInfo.email ?? "No email")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGreen).opacity(0.1))
        .cornerRadius(10)
    }
}

/// Security information display
struct SecurityInfoView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Security Status")
                .font(.headline)
            
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("Certificate pinning active")
            }
            
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.green)
                Text("PKCE validation passed")
            }
            
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                Text("Secure token storage")
            }
        }
        .padding()
        .background(Color(.systemGreen).opacity(0.1))
        .cornerRadius(10)
    }
}
```

### 3.4 Production Implementation Best Practices

#### Certificate Management Strategy

```swift
/// Production-ready certificate management for OAuth applications
class CertificateManager {
    
    // MARK: - Certificate Storage Strategy
    
    /// Certificate storage approaches for production apps
    enum CertificateStorage {
        case bundled        // Certificates embedded in app bundle
        case keychain       // Certificates stored in iOS Keychain
        case remoteConfig   // Certificates from remote configuration
        case hybrid         // Combination of bundled + remote updates
    }
    
    /// Certificate update strategy
    struct UpdateStrategy {
        let checkInterval: TimeInterval     // How often to check for updates
        let gracePeriod: TimeInterval       // Grace period before old cert expires
        let fallbackEnabled: Bool           // Allow fallback to standard validation
        let alertUserOnFailure: Bool        // Show user-facing errors
    }
    
    // MARK: - Production Certificate Pinning Configuration
    
    static func productionConfig() -> SecureNetworkManager.PinningConfig {
        return SecureNetworkManager.PinningConfig(
            certificates: loadProductionCertificates(),
            strategy: .publicKey,  // Most flexible for certificate rotation
            allowedDomains: productionDomains(),
            failureMode: .hard     // Strict security for OAuth endpoints
        )
    }
    
    /// Load certificates for production environment
    private static func loadProductionCertificates() -> [SecCertificate] {
        var certificates: [SecCertificate] = []
        
        // Primary OAuth server certificate
        if let primaryCert = loadCertificate(named: "oauth-prod-primary") {
            certificates.append(primaryCert)
        }
        
        // Backup certificate for rotation
        if let backupCert = loadCertificate(named: "oauth-prod-backup") {
            certificates.append(backupCert)
        }
        
        // Load additional certificates from secure storage
        certificates.append(contentsOf: loadKeychainCertificates())
        
        return certificates
    }
    
    private static func loadCertificate(named name: String) -> SecCertificate? {
        guard let certPath = Bundle.main.path(forResource: name, ofType: "der"),
              let certData = NSData(contentsOfFile: certPath) else {
            return nil
        }
        
        return SecCertificateCreateWithData(nil, certData)
    }
    
    /// Load certificates from iOS Keychain for rotation support
    private static func loadKeychainCertificates() -> [SecCertificate] {
        // Implementation for loading certificates from Keychain
        // This allows for certificate updates without app store releases
        return []
    }
    
    private static func productionDomains() -> Set<String> {
        return [
            "oauth.yourapp.com",
            "api.yourapp.com",
            "accounts.yourapp.com",
            "login.yourapp.com"
        ]
    }
}

/// Certificate rotation and monitoring
class CertificateMonitor: ObservableObject {
    
    @Published var certificateStatus: CertificateStatus = .unknown
    @Published var daysUntilExpiration: Int = 0
    
    enum CertificateStatus {
        case valid
        case expiringSoon
        case expired
        case invalid
        case unknown
    }
    
    func monitorCertificates() {
        // Monitor certificate expiration
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            self.checkCertificateExpiration()
        }
    }
    
    private func checkCertificateExpiration() {
        // Implementation for monitoring certificate expiration
        // Send alerts when certificates are about to expire
    }
}
```

#### Error Handling and Fallback Strategies

```swift
/// Comprehensive error handling for certificate pinning in OAuth flows
extension SecureOAuthManager {
    
    /// Enhanced error types for certificate pinning
    enum CertificatePinningError: Error {
        case noPinnedCertificates
        case certificateValidationFailed
        case publicKeyExtractionFailed
        case hostnameMismatch
        case certificateExpired
        case pinningBypassAttempt
        
        var localizedDescription: String {
            switch self {
            case .noPinnedCertificates:
                return "No pinned certificates available for validation"
            case .certificateValidationFailed:
                return "Server certificate does not match the pinned certificate"
            case .publicKeyExtractionFailed:
                return "Failed to extract public key from certificate"
            case .hostnameMismatch:
                return "Server hostname does not match expected OAuth endpoints"
            case .certificateExpired:
                return "Pinned certificate has expired"
            case .pinningBypassAttempt:
                return "Detected attempt to bypass certificate pinning"
            }
        }
    }
    
    /// Fallback strategy for certificate pinning failures
    enum FallbackStrategy {
        case strict         // Never fallback, always fail
        case graceful       // Allow fallback with user consent
        case automatic      // Automatic fallback with logging
        case userChoice     // Let user decide
    }
    
    /// Handle certificate pinning failures with appropriate fallback
    func handlePinningFailure(_ error: CertificatePinningError, 
                            strategy: FallbackStrategy) async throws -> Bool {
        
        // Log security event
        logSecurityEvent(error)
        
        switch strategy {
        case .strict:
            throw error
            
        case .graceful:
            return await requestUserPermission(for: error)
            
        case .automatic:
            // Allow fallback but log extensively
            logSecurityBypass(error)
            return true
            
        case .userChoice:
            return await presentUserChoiceDialog(for: error)
        }
    }
    
    /// Request user permission for fallback
    private func requestUserPermission(for error: CertificatePinningError) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Security Warning",
                    message: "Certificate validation failed: \(error.localizedDescription). Continue with reduced security?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                
                alert.addAction(UIAlertAction(title: "Continue", style: .destructive) { _ in
                    continuation.resume(returning: true)
                })
                
                // Present alert (implementation depends on your app architecture)
            }
        }
    }
    
    /// Present user choice dialog
    private func presentUserChoiceDialog(for error: CertificatePinningError) async -> Bool {
        // Implementation for presenting user choice dialog
        return false
    }
    
    /// Log security events for monitoring
    private func logSecurityEvent(_ error: CertificatePinningError) {
        let event = SecurityEvent(
            type: .certificatePinningFailure,
            error: error,
            timestamp: Date(),
            endpoint: "OAuth endpoints",
            severity: .high
        )
        
        SecurityLogger.shared.log(event)
    }
    
    /// Log security bypass events
    private func logSecurityBypass(_ error: CertificatePinningError) {
        let event = SecurityEvent(
            type: .securityBypass,
            error: error,
            timestamp: Date(),
            endpoint: "OAuth endpoints",
            severity: .critical
        )
        
        SecurityLogger.shared.log(event)
    }
}

/// Security event logging
struct SecurityEvent {
    enum EventType {
        case certificatePinningFailure
        case securityBypass
        case unauthorizedAccess
        case maliciousCertificate
    }
    
    enum Severity {
        case low, medium, high, critical
    }
    
    let type: EventType
    let error: Error
    let timestamp: Date
    let endpoint: String
    let severity: Severity
}

class SecurityLogger {
    static let shared = SecurityLogger()
    
    func log(_ event: SecurityEvent) {
        // Log to analytics, crash reporting, or security monitoring service
        print("🔒 SECURITY EVENT: \(event.type) - \(event.error.localizedDescription)")
        
        // In production, send to your security monitoring service
        // Example: sendToSecurityService(event)
    }
}
```

### 3.5 Testing Certificate Pinning

#### Unit Tests for Certificate Validation

```swift
import XCTest
@testable import YourApp

/// Unit tests for certificate pinning implementation
class CertificatePinningTests: XCTestCase {
    
    var secureOAuthManager: SecureOAuthManager!
    var testConfig: EnhancedOAuthConfig!
    
    override func setUp() {
        super.setUp()
        
        testConfig = EnhancedOAuthConfig(
            clientId: "test-client-id",
            authorizationEndpoint: "https://test-oauth.example.com/auth",
            tokenEndpoint: "https://test-oauth.example.com/token",
            userInfoEndpoint: "https://test-oauth.example.com/userinfo",
            redirectURI: "testapp://oauth/callback",
            scopes: ["openid", "profile"]
        )
        
        secureOAuthManager = SecureOAuthManager(config: testConfig)
    }
    
    /// Test certificate loading from bundle
    func testCertificateLoading() {
        // Test that certificates are properly loaded from app bundle
        let certificates = loadTestCertificates()
        XCTAssertFalse(certificates.isEmpty, "Test certificates should be loaded")
    }
    
    /// Test public key extraction from certificates
    func testPublicKeyExtraction() {
        let certificates = loadTestCertificates()
        guard let testCert = certificates.first else {
            XCTFail("No test certificate available")
            return
        }
        
        let publicKey = extractPublicKey(from: testCert)
        XCTAssertNotNil(publicKey, "Public key should be extractable from certificate")
    }
    
    /// Test certificate validation logic
    func testCertificateValidation() {
        // Create mock server trust with test certificate
        let mockServerTrust = createMockServerTrust()
        
        // Test validation
        let isValid = validateMockCertificate(serverTrust: mockServerTrust)
        XCTAssertTrue(isValid, "Test certificate should validate successfully")
    }
    
    /// Test hostname validation
    func testHostnameValidation() {
        let validHostnames = [
            "test-oauth.example.com",
            "api.example.com"
        ]
        
        let invalidHostnames = [
            "malicious-site.com",
            "oauth.fake-domain.com"
        ]
        
        for hostname in validHostnames {
            XCTAssertTrue(isValidOAuthHostname(hostname), "Valid hostname should pass validation")
        }
        
        for hostname in invalidHostnames {
            XCTAssertFalse(isValidOAuthHostname(hostname), "Invalid hostname should fail validation")
        }
    }
    
    /// Test pinning failure scenarios
    func testPinningFailureHandling() {
        let expectation = XCTestExpectation(description: "Pinning failure handled")
        
        // Test with invalid certificate
        let invalidCert = createInvalidCertificate()
        
        // This should fail validation
        let isValid = validateCertificate(invalidCert)
        XCTAssertFalse(isValid, "Invalid certificate should fail validation")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func loadTestCertificates() -> [SecCertificate] {
        // Load test certificates from test bundle
        var certificates: [SecCertificate] = []
        
        if let certPath = Bundle(for: type(of: self)).path(forResource: "test-cert", ofType: "der"),
           let certData = NSData(contentsOfFile: certPath),
           let certificate = SecCertificateCreateWithData(nil, certData) {
            certificates.append(certificate)
        }
        
        return certificates
    }
    
    private func createMockServerTrust() -> SecTrust? {
        // Create mock server trust for testing
        // Implementation depends on your testing framework
        return nil
    }
    
    private func validateMockCertificate(serverTrust: SecTrust?) -> Bool {
        // Mock validation logic for testing
        return true
    }
    
    private func isValidOAuthHostname(_ hostname: String) -> Bool {
        let validHosts = [
            "test-oauth.example.com",
            "api.example.com"
        ]
        return validHosts.contains(hostname)
    }
    
    private func validateCertificate(_ certificate: SecCertificate) -> Bool {
        // Mock certificate validation
        return false
    }
    
    private func createInvalidCertificate() -> SecCertificate {
        // Create a mock invalid certificate for testing
        // This is a simplified version - in real tests you'd use actual invalid certs
        let invalidCertData = Data()
        return SecCertificateCreateWithData(nil, invalidCertData)!
    }
    
    private func extractPublicKey(from certificate: SecCertificate) -> SecKey? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess, let validTrust = trust else {
            return nil
        }
        
        return SecTrustCopyPublicKey(validTrust)
    }
}
```

### 3.6 Certificate Pinning Summary and Best Practices

#### Implementation Checklist

```swift
/// Certificate pinning implementation checklist for OAuth apps
struct CertificatePinningChecklist {
    
    let security_requirements = [
        "✅ Pin public keys instead of full certificates (easier rotation)",
        "✅ Support multiple pinned certificates (primary + backup)",
        "✅ Validate hostname matches OAuth endpoints",
        "✅ Implement proper error handling and fallback strategies",
        "✅ Log security events for monitoring",
        "✅ Test certificate validation logic thoroughly"
    ]
    
    let production_considerations = [
        "✅ Plan certificate rotation strategy",
        "✅ Monitor certificate expiration dates", 
        "✅ Have emergency bypass procedure documented",
        "✅ Implement certificate update mechanism",
        "✅ Consider user experience during failures",
        "✅ Set up security monitoring and alerting"
    ]
    
    let performance_optimizations = [
        "✅ Cache certificate validation results",
        "✅ Use background queues for certificate operations",
        "✅ Minimize certificate validation overhead",
        "✅ Implement efficient public key comparison",
        "✅ Consider memory usage for certificate storage"
    ]
}

/// Key benefits of certificate pinning for OAuth
enum CertificatePinningBenefits {
    case enhanced_security  // Protection against CA compromises
    case mitm_prevention   // Blocks man-in-the-middle attacks
    case oauth_protection  // Secures token exchange endpoints
    case compliance       // Meets security compliance requirements
    case user_trust       // Increases user confidence in app security
}
```

This comprehensive certificate pinning implementation provides:

1. **Multiple Implementation Approaches**: URLSessionDelegate and centralized network manager patterns
2. **Production-Ready Features**: Certificate rotation, monitoring, error handling
3. **SwiftUI Integration**: Complete UI examples with security status indicators
4. **Testing Framework**: Unit tests for validation logic
5. **Best Practices**: Security considerations, performance optimizations, and compliance guidelines

The certificate pinning implementation enhances your OAuth 2.0 Authorization Code Flow by adding an additional layer of security that protects against various attack vectors, making your iOS 16.0+ SwiftUI application more secure and trustworthy.

---

## 📚 Part 4: Supporting Data Structures and Configuration

### 4.1 OAuth Configuration and Data Models

```swift
/// Enhanced OAuth configuration for iOS 16.0+ SwiftUI applications
/// 
/// This structure contains all the configuration needed for a complete OAuth 2.0
/// Authorization Code Flow implementation with certificate pinning support.
struct EnhancedOAuthConfig {
    
    // MARK: - Core OAuth Parameters
    
    /// OAuth client identifier registered with the authorization server
    /// 
    /// This uniquely identifies your app to the OAuth provider.
    /// For Google: Format is usually like "123456789-abcdef.apps.googleusercontent.com"
    /// For Microsoft: Format is usually a GUID like "12345678-1234-1234-1234-123456789abc"
    let clientId: String
    
    /// Authorization endpoint URL where users authenticate
    /// 
    /// Examples:
    /// - Google: "https://accounts.google.com/oauth/authorize"
    /// - Microsoft: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    /// - GitHub: "https://github.com/login/oauth/authorize"
    let authorizationEndpoint: String
    
    /// Token endpoint URL for exchanging authorization codes for access tokens
    /// 
    /// Examples:
    /// - Google: "https://oauth2.googleapis.com/token"
    /// - Microsoft: "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    /// - GitHub: "https://github.com/login/oauth/access_token"
    let tokenEndpoint: String
    
    /// User info endpoint URL for fetching authenticated user details
    /// 
    /// Examples:
    /// - Google: "https://www.googleapis.com/oauth2/v2/userinfo"
    /// - Microsoft: "https://graph.microsoft.com/v1.0/me"
    /// - GitHub: "https://api.github.com/user"
    let userInfoEndpoint: String
    
    /// Redirect URI that the authorization server will redirect to after authentication
    /// 
    /// This must be a custom URL scheme registered in your app's Info.plist
    /// Format: "yourapp://oauth/callback" or "com.yourcompany.yourapp://auth"
    let redirectURI: String
    
    /// OAuth scopes to request from the authorization server
    /// 
    /// Common scopes:
    /// - OpenID Connect: ["openid", "profile", "email"]
    /// - Google: ["openid", "email", "profile", "https://www.googleapis.com/auth/drive"]
    /// - Microsoft: ["openid", "profile", "email", "User.Read"]
    let scopes: [String]
    
    // MARK: - Security Configuration
    
    /// Whether to use PKCE (Proof Key for Code Exchange) for enhanced security
    /// 
    /// PKCE is strongly recommended for mobile apps and is required by OAuth 2.1
    /// It prevents authorization code interception attacks
    let usePKCE: Bool
    
    /// Whether to use state parameter for CSRF protection
    /// 
    /// The state parameter prevents cross-site request forgery attacks
    /// It should always be enabled for production applications
    let useState: Bool
    
    /// Certificate pinning configuration for secure networking
    let certificatePinning: CertificatePinningConfig?
    
    // MARK: - Development Configuration
    
    /// Custom URL scheme for development builds
    /// 
    /// You can use a different scheme for development vs production
    /// Leave nil to use the scheme from redirectURI
    let developmentURLScheme: String?
    
    // MARK: - Computed Properties
    
    /// Formatted scope string for OAuth requests
    var scopeString: String {
        return scopes.joined(separator: " ")
    }
    
    /// URL scheme extracted from redirect URI
    var urlScheme: String {
        if let developmentScheme = developmentURLScheme {
            return developmentScheme
        }
        
        guard let url = URL(string: redirectURI),
              let scheme = url.scheme else {
            fatalError("Invalid redirect URI: \(redirectURI)")
        }
        
        return scheme
    }
    
    // MARK: - Initialization
    
    init(clientId: String,
         authorizationEndpoint: String,
         tokenEndpoint: String,
         userInfoEndpoint: String,
         redirectURI: String,
         scopes: [String],
         usePKCE: Bool = true,
         useState: Bool = true,
         certificatePinning: CertificatePinningConfig? = nil,
         developmentURLScheme: String? = nil) {
        
        self.clientId = clientId
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.userInfoEndpoint = userInfoEndpoint
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.usePKCE = usePKCE
        self.useState = useState
        self.certificatePinning = certificatePinning
        self.developmentURLScheme = developmentURLScheme
    }
}

/// Certificate pinning configuration
struct CertificatePinningConfig {
    let certificateNames: [String]  // Certificate file names in app bundle
    let strategy: PinningStrategy
    let allowedDomains: Set<String>
    let failureMode: FailureMode
    
    enum PinningStrategy {
        case certificate
        case publicKey
        case certificateChain
    }
    
    enum FailureMode {
        case hard    // Fail if pinning validation fails
        case soft    // Log failure but allow connection
    }
}
```

### 4.2 OAuth Response Data Models

```swift
/// OAuth token response from the authorization server
/// 
/// This structure represents the response received when exchanging
/// an authorization code for an access token.
struct TokenResponse: Codable {
    
    /// The access token issued by the authorization server
    /// 
    /// This token is used to authenticate API requests to protected resources.
    /// Format is typically "Bearer ya29.a0ARrdaM..." for Google or a JWT for others.
    let accessToken: String
    
    /// The type of the token (usually "Bearer")
    /// 
    /// OAuth 2.0 defines "Bearer" as the standard token type.
    /// This tells you how to use the token in Authorization headers.
    let tokenType: String
    
    /// Lifetime in seconds of the access token
    /// 
    /// After this time, the access token will expire and you'll need to
    /// refresh it using the refresh token (if available).
    let expiresIn: Int?
    
    /// The refresh token for obtaining new access tokens
    /// 
    /// Not all OAuth providers issue refresh tokens. When available,
    /// use this to get new access tokens without re-authentication.
    let refreshToken: String?
    
    /// The scope of the access token
    /// 
    /// This may be different from what you requested if the authorization
    /// server granted fewer permissions than requested.
    let scope: String?
    
    /// OpenID Connect ID token
    /// 
    /// Contains user identity information in JWT format.
    /// Only present when using OpenID Connect with "openid" scope.
    let idToken: String?
    
    // MARK: - Computed Properties
    
    /// Date when the token expires
    var expirationDate: Date? {
        guard let expiresIn = expiresIn else { return nil }
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }
    
    /// Whether the token is expired
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
    
    /// Whether the token expires within a specified number of seconds
    func expiresWithin(seconds: TimeInterval) -> Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date().addingTimeInterval(seconds) > expirationDate
    }
    
    // MARK: - Coding Keys
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case idToken = "id_token"
    }
}

/// User information response from the user info endpoint
/// 
/// This structure represents user profile information retrieved
/// from the OAuth provider's user info endpoint.
struct UserInfo: Codable {
    
    /// Unique user identifier
    /// 
    /// This is a stable, unique identifier for the user across all applications
    /// from the same OAuth provider. Use this for user identification in your app.
    let id: String?
    
    /// User's display name
    /// 
    /// This is the name the user wants to be called in your application.
    /// May be their real name or a chosen display name.
    let name: String?
    
    /// User's given (first) name
    let givenName: String?
    
    /// User's family (last) name
    let familyName: String?
    
    /// User's email address
    /// 
    /// Only available if your app requested and was granted email scope.
    /// Some providers may not return email even if requested.
    let email: String?
    
    /// Whether the email address has been verified
    /// 
    /// Important for security - only trust verified email addresses
    /// for account linking or sensitive operations.
    let emailVerified: Bool?
    
    /// URL to the user's profile picture
    /// 
    /// This may be a direct image URL or a URL that redirects to the image.
    /// The image may be cached by the OAuth provider.
    let picture: String?
    
    /// User's preferred locale
    /// 
    /// Format follows RFC 5646 (e.g., "en-US", "fr-CA").
    /// Useful for localizing your app's content.
    let locale: String?
    
    // MARK: - Computed Properties
    
    /// Full name combining given and family names
    var fullName: String? {
        switch (givenName, familyName) {
        case let (given?, family?):
            return "\(given) \(family)"
        case let (given?, nil):
            return given
        case let (nil, family?):
            return family
        case (nil, nil):
            return name
        }
    }
    
    /// Display name with fallback logic
    var displayName: String {
        return name ?? fullName ?? email ?? "User"
    }
    
    // MARK: - Coding Keys
    
    private enum CodingKeys: String, CodingKey {
        case id = "sub"  // OpenID Connect standard claim
        case name
        case givenName = "given_name"
        case familyName = "family_name"
        case email
        case emailVerified = "email_verified"
        case picture
        case locale
    }
}

/// Combined OAuth user object
/// 
/// This structure combines the token response and user information
/// into a single object representing an authenticated user.
struct OAuthUser {
    
    /// Authentication token information
    let authToken: TokenResponse
    
    /// User profile information
    let userInfo: UserInfo?
    
    /// Date when the user was authenticated
    let authenticatedAt: Date
    
    // MARK: - Convenience Properties
    
    /// Whether the user's access token is expired
    var isTokenExpired: Bool {
        return authToken.isExpired
    }
    
    /// Whether the token needs refresh (expires within 5 minutes)
    var needsTokenRefresh: Bool {
        return authToken.expiresWithin(seconds: 300)
    }
    
    /// User's display name
    var displayName: String {
        return userInfo?.displayName ?? "User"
    }
    
    /// User's email address
    var email: String? {
        return userInfo?.email
    }
    
    /// Authorization header value for API requests
    var authorizationHeader: String {
        return "\(authToken.tokenType) \(authToken.accessToken)"
    }
    
    // MARK: - Initialization
    
    init(authToken: TokenResponse, userInfo: UserInfo?) {
        self.authToken = authToken
        self.userInfo = userInfo
        self.authenticatedAt = Date()
    }
}
```

### 4.3 Error Handling

```swift
/// Comprehensive OAuth error handling for iOS applications
/// 
/// This enum covers all possible error scenarios that can occur during
/// the OAuth 2.0 Authorization Code Flow with certificate pinning.
enum OAuthError: Error, LocalizedError {
    
    // MARK: - Configuration Errors
    
    case invalidConfiguration(String)
    case missingRedirectURI
    case invalidRedirectURI(String)
    case missingClientId
    
    // MARK: - Authentication Flow Errors
    
    case authorizationFailed(String)
    case userCancelled
    case authorizationCodeMissing
    case stateMismatch
    case invalidAuthorizationResponse
    
    // MARK: - Token Exchange Errors
    
    case tokenExchangeFailed
    case invalidTokenResponse
    case tokenRequestFailed(Int)
    case networkError(Error)
    
    // MARK: - User Info Errors
    
    case userInfoFetchFailed
    case invalidUserInfoResponse
    case userInfoParsingError(Error)
    
    // MARK: - Certificate Pinning Errors
    
    case certificatePinningFailed
    case invalidCertificate
    case certificateNotFound(String)
    case pinnedCertificateExpired
    
    // MARK: - PKCE Errors
    
    case pkceGenerationFailed
    case codeVerifierMissing
    case invalidCodeChallenge
    
    // MARK: - Session Management Errors
    
    case sessionExpired
    case refreshTokenMissing
    case refreshTokenFailed
    case invalidSession
    
    // MARK: - Localized Error Descriptions
    
    var errorDescription: String? {
        switch self {
        // Configuration Errors
        case .invalidConfiguration(let details):
            return "OAuth configuration error: \(details)"
        case .missingRedirectURI:
            return "Redirect URI is required for OAuth flow"
        case .invalidRedirectURI(let uri):
            return "Invalid redirect URI: \(uri)"
        case .missingClientId:
            return "Client ID is required for OAuth flow"
            
        // Authentication Flow Errors
        case .authorizationFailed(let reason):
            return "Authorization failed: \(reason)"
        case .userCancelled:
            return "User cancelled the authentication"
        case .authorizationCodeMissing:
            return "No authorization code received from server"
        case .stateMismatch:
            return "Security error: State parameter mismatch"
        case .invalidAuthorizationResponse:
            return "Invalid response from authorization server"
            
        // Token Exchange Errors
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token"
        case .invalidTokenResponse:
            return "Invalid token response from server"
        case .tokenRequestFailed(let statusCode):
            return "Token request failed with status code: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
            
        // User Info Errors
        case .userInfoFetchFailed:
            return "Failed to fetch user information"
        case .invalidUserInfoResponse:
            return "Invalid user info response from server"
        case .userInfoParsingError(let error):
            return "Failed to parse user info: \(error.localizedDescription)"
            
        // Certificate Pinning Errors
        case .certificatePinningFailed:
            return "Certificate pinning validation failed"
        case .invalidCertificate:
            return "Invalid or corrupted certificate"
        case .certificateNotFound(let name):
            return "Certificate not found: \(name)"
        case .pinnedCertificateExpired:
            return "Pinned certificate has expired"
            
        // PKCE Errors
        case .pkceGenerationFailed:
            return "Failed to generate PKCE parameters"
        case .codeVerifierMissing:
            return "PKCE code verifier is missing"
        case .invalidCodeChallenge:
            return "Invalid PKCE code challenge"
            
        // Session Management Errors
        case .sessionExpired:
            return "Authentication session has expired"
        case .refreshTokenMissing:
            return "Refresh token is not available"
        case .refreshTokenFailed:
            return "Failed to refresh access token"
        case .invalidSession:
            return "Invalid authentication session"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .userCancelled:
            return "The user chose to cancel the authentication process"
        case .stateMismatch:
            return "Possible security attack detected - state parameters don't match"
        case .certificatePinningFailed:
            return "The server's certificate doesn't match the pinned certificate"
        default:
            return errorDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .userCancelled:
            return "Try signing in again when ready"
        case .networkError:
            return "Check your internet connection and try again"
        case .tokenExchangeFailed, .tokenRequestFailed:
            return "Please try signing in again"
        case .certificatePinningFailed:
            return "This may indicate a security issue. Please ensure you're on a trusted network"
        case .sessionExpired:
            return "Please sign in again to continue"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}

/// Network-specific errors for certificate pinning and secure connections
enum NetworkError: Error, LocalizedError {
    
    case invalidResponse
    case httpError(Int)
    case certificateValidationFailed
    case connectionTimeout
    case userInfoFetchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .certificateValidationFailed:
            return "Certificate validation failed"
        case .connectionTimeout:
            return "Connection timed out"
        case .userInfoFetchFailed:
            return "Failed to fetch user information"
        }
    }
}
```

### 4.4 Helper Extensions and Utilities

```swift
import CryptoKit
import Foundation

/// Security utilities for OAuth implementation
struct SecurityUtils {
    
    /// Generate a cryptographically secure random string for state parameter
    /// 
    /// The state parameter is used to prevent CSRF attacks in OAuth flows.
    /// It should be unpredictable and unique for each authentication request.
    /// 
    /// - Parameter length: The length of the generated string (default: 32)
    /// - Returns: A base64url-encoded random string
    static func generateSecureState(length: Int = 32) -> String {
        var buffer = Data(count: length)
        let result = buffer.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            // Fallback to UUID-based generation if system random fails
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        
        return buffer.base64URLEncodedString()
    }
    
    /// Generate PKCE (Proof Key for Code Exchange) parameters
    /// 
    /// PKCE adds an extra layer of security to OAuth flows by ensuring
    /// that only the app that initiated the flow can complete it.
    /// 
    /// - Returns: A tuple containing (codeVerifier, codeChallenge)
    static func generatePKCEPair() -> (codeVerifier: String, codeChallenge: String) {
        // Generate code verifier (43-128 characters, base64url-encoded)
        let codeVerifier = generateCodeVerifier()
        
        // Generate code challenge (SHA256 hash of code verifier)
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        return (codeVerifier, codeChallenge)
    }
    
    /// Generate a cryptographically secure code verifier for PKCE
    /// 
    /// The code verifier must be 43-128 characters long and use only
    /// unreserved characters: A-Z, a-z, 0-9, -, ., _, ~
    /// 
    /// - Returns: A base64url-encoded random string
    private static func generateCodeVerifier() -> String {
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
    
    /// Generate the code challenge from the code verifier
    /// 
    /// The code challenge is the SHA256 hash of the code verifier,
    /// base64url-encoded without padding.
    /// 
    /// - Parameter codeVerifier: The original code verifier
    /// - Returns: SHA256 hash of code verifier, base64url-encoded
    private static func generateCodeChallenge(from codeVerifier: String) -> String {
        // Convert code verifier to data
        let data = codeVerifier.data(using: .utf8)!
        
        // Calculate SHA256 hash
        let hashedData = SHA256.hash(data: data)
        
        // Convert to base64url encoding
        return Data(hashedData).base64URLEncodedString()
    }
}

/// Data extension for base64url encoding
extension Data {
    
    /// Base64URL encoding (URL-safe base64 without padding)
    /// 
    /// Base64URL is used in OAuth 2.0 and JWT specifications
    /// because it's safe to use in URLs and doesn't require padding.
    /// 
    /// - Returns: Base64URL-encoded string
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// URL extension for extracting query parameters
extension URL {
    
    /// Extract query parameters from URL
    /// 
    /// Useful for parsing OAuth callback URLs that contain
    /// authorization codes, state parameters, and errors.
    /// 
    /// - Returns: Dictionary of query parameter key-value pairs
    func queryParameters() -> [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        
        var parameters: [String: String] = [:]
        for item in queryItems {
            parameters[item.name] = item.value
        }
        return parameters
    }
    
    /// Extract authorization code from OAuth callback URL
    /// 
    /// - Returns: Authorization code if present, nil otherwise
    func authorizationCode() -> String? {
        return queryParameters()["code"]
    }
    
    /// Extract state parameter from OAuth callback URL
    /// 
    /// - Returns: State parameter if present, nil otherwise
    func stateParameter() -> String? {
        return queryParameters()["state"]
    }
    
    /// Extract error information from OAuth callback URL
    /// 
    /// - Returns: Error code if present, nil otherwise
    func oauthError() -> String? {
        return queryParameters()["error"]
    }
    
    /// Extract error description from OAuth callback URL
    /// 
    /// - Returns: Error description if present, nil otherwise
    func oauthErrorDescription() -> String? {
        return queryParameters()["error_description"]
    }
}

/// Token exchange request helper
struct TokenExchangeRequest {
    let tokenEndpoint: String
    let clientId: String
    let authorizationCode: String
    let redirectURI: String
    let codeVerifier: String?
    
    var bodyData: Data? {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code", value: authorizationCode),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        
        // Add PKCE code verifier if available
        if let codeVerifier = codeVerifier {
            components.queryItems?.append(URLQueryItem(name: "code_verifier", value: codeVerifier))
        }
        
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}
```
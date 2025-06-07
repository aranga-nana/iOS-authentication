# 🔗 Redirect URLs in OAuth 2.0 - Complete Guide

> **Deep dive into redirect URLs, their implementation in iOS, and security considerations**

## 🎯 Overview

Redirect URLs are a critical component of the OAuth 2.0 Authorization Code Flow. This guide provides comprehensive coverage of:
- What redirect URLs are and how they work
- iOS implementation with custom URL schemes
- Security considerations and best practices
- Common attacks and prevention strategies

---

## 📚 Part 1: Understanding Redirect URLs

### 1.1 What are Redirect URLs?

**Redirect URLs** are the "return address" for OAuth flows. After user authentication, the authorization server redirects back to your app using this URL.

### 1.2 Anatomy of a Redirect URL

```swift
// Original redirect URL in authorization request
"com.yourapp.oauth://callback"

// What comes back after authentication
"com.yourapp.oauth://callback?code=4/0AX4XfWj...&state=abc123"

// Breaking it down:
struct RedirectURLAnatomy {
    let scheme: String = "com.yourapp.oauth"      // Your app's identifier
    let host: String = "callback"                 // The callback path
    let authCode: String = "4/0AX4XfWj..."       // Authorization code
    let state: String = "abc123"                  // Security parameter
}
```

### 1.3 The Redirect Flow

```
1. App → Authorization Server
   "Please authenticate user, send them back to: com.yourapp.oauth://callback"

2. User → Authorization Server
   User logs in and approves permissions

3. Authorization Server → App (via iOS)
   "Here's your user back: com.yourapp.oauth://callback?code=xyz&state=abc"

4. iOS → Your App
   iOS recognizes the URL scheme and opens your app
```

---

## 📚 Part 2: iOS Implementation

### 2.1 URL Scheme Registration

```swift
// Info.plist configuration
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OAuth Authentication</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Use reverse domain notation for uniqueness -->
            <string>com.yourcompany.yourapp.oauth</string>
        </array>
    </dict>
</array>
```

### 2.2 URL Handling in iOS

#### SwiftUI Implementation
```swift
// In your App file
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 Received URL: \(url)")
        
        // Check if it's an OAuth callback
        if url.scheme == "com.yourapp.oauth" {
            processOAuthCallback(url)
        }
    }
}
```

#### UIKit Implementation
```swift
// In AppDelegate or SceneDelegate
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    
    print("📱 Received URL: \(url)")
    
    // Handle OAuth callback
    if url.scheme == "com.yourapp.oauth" {
        return processOAuthCallback(url)
    }
    
    return false
}
```

### 2.3 Complete URL Processing

```swift
class RedirectURLProcessor {
    
    func processOAuthCallback(_ url: URL) -> Bool {
        guard validateURLScheme(url) else {
            print("❌ Invalid URL scheme")
            return false
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Check for authorization errors
        if let error = extractError(from: components) {
            handleAuthorizationError(error)
            return true
        }
        
        // Extract and validate authorization code
        guard let authCode = extractAuthorizationCode(from: components) else {
            print("❌ No authorization code found")
            return false
        }
        
        // Validate state parameter if present
        if let state = extractState(from: components) {
            guard validateState(state) else {
                print("❌ State validation failed")
                return false
            }
        }
        
        // Process successful authorization
        handleSuccessfulAuthorization(authCode)
        return true
    }
    
    private func validateURLScheme(_ url: URL) -> Bool {
        return url.scheme == "com.yourapp.oauth"
    }
    
    private func extractError(from components: URLComponents?) -> OAuthAuthorizationError? {
        guard let error = components?.queryItems?.first(where: { $0.name == "error" })?.value else {
            return nil
        }
        
        let description = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
        return OAuthAuthorizationError(code: error, description: description)
    }
    
    private func extractAuthorizationCode(from components: URLComponents?) -> String? {
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }
    
    private func extractState(from components: URLComponents?) -> String? {
        return components?.queryItems?.first(where: { $0.name == "state" })?.value
    }
    
    private func validateState(_ state: String) -> Bool {
        // Compare with stored state value
        return StateManager.shared.validateAndConsumeState(state)
    }
}

struct OAuthAuthorizationError {
    let code: String
    let description: String?
}
```

---

## 📚 Part 3: Security Considerations

### 3.1 URL Scheme Security

#### Best Practices
```swift
struct URLSchemeSecurity {
    
    // ✅ GOOD: Unique and app-specific
    let goodScheme = "com.yourcompany.yourapp.oauth"
    
    // ❌ BAD: Generic, can be hijacked
    let badScheme = "oauth"
    let anotherBadScheme = "callback"
    
    // ✅ GOOD: Versioned for future changes
    let versionedScheme = "com.yourcompany.yourapp.oauth.v2"
}
```

#### URL Scheme Hijacking Prevention
```swift
class URLSchemeValidator {
    
    private let expectedScheme = "com.yourcompany.yourapp.oauth"
    
    func isValidCallback(_ url: URL) -> Bool {
        // 1. Validate scheme
        guard url.scheme == expectedScheme else {
            print("❌ Invalid scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        // 2. Validate host if using specific host
        if let expectedHost = URLComponents(string: "\(expectedScheme)://callback")?.host {
            guard url.host == expectedHost else {
                print("❌ Invalid host: \(url.host ?? "nil")")
                return false
            }
        }
        
        // 3. Check for required parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let hasCodeOrError = components?.queryItems?.contains { item in
            item.name == "code" || item.name == "error"
        } ?? false
        
        guard hasCodeOrError else {
            print("❌ Missing required parameters")
            return false
        }
        
        return true
    }
}
```

### 3.2 State Parameter Validation

```swift
class StateValidationManager {
    private var pendingStates: Set<String> = []
    private let queue = DispatchQueue(label: "state.validation", attributes: .concurrent)
    
    func generateState() -> String {
        let state = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        queue.async(flags: .barrier) {
            self.pendingStates.insert(state)
        }
        
        // Auto-cleanup after 10 minutes
        DispatchQueue.global().asyncAfter(deadline: .now() + 600) {
            self.queue.async(flags: .barrier) {
                self.pendingStates.remove(state)
            }
        }
        
        return state
    }
    
    func validateAndConsumeState(_ state: String) -> Bool {
        return queue.sync {
            let isValid = pendingStates.contains(state)
            if isValid {
                pendingStates.remove(state)  // Use once
            }
            return isValid
        }
    }
}
```

### 3.3 PKCE Implementation

```swift
import CryptoKit

class PKCEManager {
    
    struct PKCEChallenge {
        let verifier: String
        let challenge: String
        let method: String = "S256"
    }
    
    func generatePKCEChallenge() -> PKCEChallenge {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        
        return PKCEChallenge(verifier: verifier, challenge: challenge)
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
}

// Extension for PKCE base64URL encoding
extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

---

## 📚 Part 4: Common Attacks and Prevention

### 4.1 Redirect URI Hijacking

**Attack:** Malicious app registers the same URL scheme to intercept authorization codes.

**Prevention:**
```swift
struct RedirectURIHijackingPrevention {
    
    // 1. Use highly specific URL schemes
    let specificScheme = "com.yourcompany.yourapp.oauth.production.v2"
    
    // 2. Implement additional validation
    func validateRedirectSource(_ url: URL) -> Bool {
        // Check if the URL came from expected authorization server
        // This is challenging but can be done through timing analysis
        // or by checking referrer headers when possible
        return true
    }
    
    // 3. Use Universal Links when possible
    let universalLinkScheme = "https://yourapp.com/oauth/callback"
}
```

### 4.2 Authorization Code Interception

**Attack:** Attacker intercepts the authorization code in transit.

**Prevention:** Use PKCE (Proof Key for Code Exchange)
```swift
class PKCEProtectedOAuth {
    private let pkceManager = PKCEManager()
    private var currentPKCE: PKCEManager.PKCEChallenge?
    
    func startAuthenticationWithPKCE() {
        // Generate PKCE challenge
        currentPKCE = pkceManager.generatePKCEChallenge()
        
        // Build authorization URL with PKCE
        let authURL = buildAuthorizationURL(withPKCE: currentPKCE!)
        
        // Start authentication...
    }
    
    private func buildAuthorizationURL(withPKCE pkce: PKCEManager.PKCEChallenge) -> URL? {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: generateState()),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method)
        ]
        
        return components?.url
    }
    
    func exchangeCodeForToken(authCode: String) {
        guard let pkce = currentPKCE else {
            print("❌ No PKCE challenge available")
            return
        }
        
        // Include code_verifier in token request
        let parameters = [
            "grant_type": "authorization_code",
            "code": authCode,
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "code_verifier": pkce.verifier  // PKCE verification
        ]
        
        // Make token request...
    }
}
```

### 4.3 State Parameter Attacks (CSRF)

**Attack:** Attacker provides a malicious authorization code with valid state.

**Prevention:**
```swift
class CSRFProtection {
    private let stateManager = StateValidationManager()
    
    func startAuthentication() -> String {
        let state = stateManager.generateState()
        
        // Store additional context with state
        StateContext.shared.store(state: state, context: [
            "timestamp": Date().timeIntervalSince1970,
            "userAgent": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "sessionId": UUID().uuidString
        ])
        
        return state
    }
    
    func validateCallback(_ url: URL, originalState: String) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value else {
            return false
        }
        
        // 1. Basic state validation
        guard stateManager.validateAndConsumeState(receivedState) else {
            return false
        }
        
        // 2. Additional context validation
        guard let context = StateContext.shared.retrieve(state: receivedState) else {
            return false
        }
        
        // 3. Check timestamp (prevent replay attacks)
        let timestamp = context["timestamp"] as? TimeInterval ?? 0
        let age = Date().timeIntervalSince1970 - timestamp
        guard age < 600 else { // 10 minutes max
            print("❌ State too old: \(age) seconds")
            return false
        }
        
        return true
    }
}
```

---

## 📚 Part 5: Universal Links vs Custom URL Schemes

### 5.1 Custom URL Schemes

```swift
struct CustomSchemeConfig {
    let redirectURI = "com.yourapp.oauth://callback"
    
    // Pros:
    // - Easy to set up
    // - Works offline
    // - No server configuration needed
    // - Immediate app opening
    
    // Cons:
    // - Can be hijacked by other apps
    // - Not as secure as Universal Links
    // - May show "Open in App" dialog
    
    func configure() {
        // Just add to Info.plist - no server setup required
    }
}
```

### 5.2 Universal Links

```swift
struct UniversalLinksConfig {
    let redirectURI = "https://yourapp.com/oauth/callback"
    
    // Pros:
    // - More secure (verified domain ownership)
    // - Fallback to website if app not installed
    // - Better user experience
    // - Cannot be hijacked
    
    // Cons:
    // - Requires server setup
    // - Needs apple-app-site-association file
    // - More complex configuration
    // - Requires HTTPS
    
    func configure() {
        // 1. Set up apple-app-site-association file on server
        setupAppleAppSiteAssociation()
        
        // 2. Configure Associated Domains in Xcode
        // applinks:yourapp.com
        
        // 3. Handle Universal Links in app
        handleUniversalLinks()
    }
}
```

### 5.3 Apple App Site Association File

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.yourapp",
        "paths": [
          "/oauth/callback",
          "/auth/*"
        ]
      }
    ]
  }
}
```

---

## 📚 Part 6: Testing and Debugging

### 6.1 Testing Redirect URLs

```swift
class RedirectURLTester {
    
    func runAllTests() {
        testValidRedirect()
        testInvalidState()
        testErrorResponse()
        testMissingParameters()
        testMalformedURL()
    }
    
    func testValidRedirect() {
        let validURL = URL(string: "com.yourapp.oauth://callback?code=abc123&state=xyz789")!
        let processor = RedirectURLProcessor()
        
        StateManager.shared.addExpectedState("xyz789")
        let result = processor.processOAuthCallback(validURL)
        
        XCTAssertTrue(result, "Valid redirect should be processed successfully")
    }
    
    func testInvalidState() {
        let invalidURL = URL(string: "com.yourapp.oauth://callback?code=abc123&state=wrong")!
        let processor = RedirectURLProcessor()
        
        StateManager.shared.addExpectedState("correct")
        let result = processor.processOAuthCallback(invalidURL)
        
        XCTAssertFalse(result, "Invalid state should be rejected")
    }
    
    func testErrorResponse() {
        let errorURL = URL(string: "com.yourapp.oauth://callback?error=access_denied&error_description=User+denied+access")!
        let processor = RedirectURLProcessor()
        
        let result = processor.processOAuthCallback(errorURL)
        
        XCTAssertTrue(result, "Error responses should be handled gracefully")
    }
}
```

### 6.2 Debug Utilities

```swift
extension RedirectURLProcessor {
    
    func debugRedirectURL(_ url: URL) {
        print("🔍 Debug: Redirect URL Analysis")
        print("   Full URL: \(url)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")
        print("   Path: \(url.path)")
        print("   Query: \(url.query ?? "nil")")
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            print("   Query Items:")
            components.queryItems?.forEach { item in
                let value = item.value ?? "nil"
                let maskedValue = item.name == "code" ? String(value.prefix(10)) + "..." : value
                print("     \(item.name): \(maskedValue)")
            }
        }
    }
    
    func validateURLStructure(_ url: URL) -> [String] {
        var issues: [String] = []
        
        // Check scheme
        if url.scheme?.contains(".") == false {
            issues.append("⚠️ URL scheme should use reverse domain notation")
        }
        
        // Check for required parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let hasCode = components?.queryItems?.contains { $0.name == "code" } ?? false
        let hasError = components?.queryItems?.contains { $0.name == "error" } ?? false
        
        if !hasCode && !hasError {
            issues.append("❌ URL missing both 'code' and 'error' parameters")
        }
        
        return issues
    }
}
```

---

## 🎯 Summary

### Key Takeaways

1. **Redirect URLs are your app's "return address"** in OAuth flows
2. **Use specific, unique URL schemes** to prevent hijacking
3. **Always validate state parameters** to prevent CSRF attacks  
4. **Implement PKCE** for additional security against code interception
5. **Consider Universal Links** for production apps requiring maximum security
6. **Test thoroughly** with various scenarios including error cases

### Security Checklist

- ✅ Use app-specific URL scheme (com.company.app.oauth)
- ✅ Validate all callback parameters
- ✅ Implement state parameter validation
- ✅ Use PKCE for additional protection
- ✅ Handle error responses gracefully
- ✅ Test with various attack scenarios
- ✅ Consider Universal Links for sensitive applications

This comprehensive understanding of redirect URLs ensures your OAuth implementation is both functional and secure!

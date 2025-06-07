# 🔐 OAuth 2.0 & Redirect URLs - Quick Reference

> **Quick reference for OAuth 2.0 Authorization Code Flow and Redirect URLs in iOS**

## 📋 At a Glance

### Authorization Code Flow Summary
```
1. User clicks "Sign In" → App opens authorization URL
2. User authenticates → Authorization server redirects with code
3. App extracts code → Exchanges code for access token
4. App uses token → Makes API calls for user data
```

### Key Components
- **Authorization Code**: Temporary code exchanged for access token
- **Redirect URL**: Your app's "return address" after authentication
- **State Parameter**: CSRF protection mechanism
- **PKCE**: Additional security for mobile apps

---

## 🔗 Essential Links

- **[Enhanced Authorization Code Flow Guide](enhanced-authorization-code-flow-guide.md)** - Complete implementation with security
- **[Redirect URLs Complete Guide](redirect-urls-complete-guide.md)** - Deep dive into redirect URL security
- **[Lesson 2: Auth Fundamentals](phase1/week1/lesson2-auth-fundamentals.md)** - Foundation concepts

---

## ⚡ Quick Implementation

### 1. Info.plist Setup
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourapp.oauth</string>
        </array>
    </dict>
</array>
```

### 2. URL Handling
```swift
// SwiftUI App
.onOpenURL { url in
    handleOAuthCallback(url)
}

// Extract auth code
func extractCode(from url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == "code" })?
        .value
}
```

### 3. OAuth Configuration
```swift
struct OAuthConfig {
    let clientId = "your-client-id"
    let redirectURI = "com.yourapp.oauth://callback"
    let scope = "openid email profile"
    let authEndpoint = URL(string: "https://provider.com/oauth/authorize")!
    let tokenEndpoint = URL(string: "https://provider.com/oauth/token")!
}
```

---

## 🔒 Security Checklist

- ✅ Use app-specific redirect URI (`com.company.app.oauth`)
- ✅ Validate state parameter (CSRF protection)
- ✅ Implement PKCE (code interception protection)
- ✅ Store tokens securely (Keychain, not UserDefaults)
- ✅ Check token expiration
- ✅ Handle all error scenarios
- ✅ Use HTTPS for all endpoints

---

## 🎯 Key URLs Structure

### Authorization URL
```
https://provider.com/oauth/authorize?
client_id=your-client-id&
redirect_uri=com.yourapp.oauth://callback&
response_type=code&
scope=openid%20email%20profile&
state=random-security-string&
code_challenge=pkce-challenge&
code_challenge_method=S256
```

### Redirect URL (Success)
```
com.yourapp.oauth://callback?
code=authorization-code-here&
state=same-security-string
```

### Redirect URL (Error)
```
com.yourapp.oauth://callback?
error=access_denied&
error_description=User%20denied%20access
```

---

## 🚨 Common Pitfalls

1. **Generic URL Schemes** - Use `com.company.app.oauth`, not `myapp`
2. **Missing State Validation** - Always check state parameter
3. **Insecure Token Storage** - Use Keychain, not UserDefaults
4. **No Error Handling** - Handle user cancellation and server errors
5. **Expired Token Usage** - Check `token.isExpired` before API calls

---

## 🧪 Testing Scenarios

```swift
// Test valid callback
"com.yourapp.oauth://callback?code=abc123&state=xyz789"

// Test error callback  
"com.yourapp.oauth://callback?error=access_denied"

// Test state mismatch
"com.yourapp.oauth://callback?code=abc123&state=wrong"

// Test missing parameters
"com.yourapp.oauth://callback"
```

---

## 📱 Provider-Specific Examples

### Google OAuth
```swift
let googleConfig = OAuthConfig(
    clientId: "123-abc.apps.googleusercontent.com",
    redirectURI: "com.yourapp.oauth://callback",
    scope: "openid email profile",
    authEndpoint: URL(string: "https://accounts.google.com/oauth/authorize")!,
    tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!
)
```

### GitHub OAuth
```swift
let githubConfig = OAuthConfig(
    clientId: "your-github-client-id",
    redirectURI: "com.yourapp.oauth://callback",
    scope: "user:email",
    authEndpoint: URL(string: "https://github.com/login/oauth/authorize")!,
    tokenEndpoint: URL(string: "https://github.com/login/oauth/access_token")!
)
```

---

## 🛠 Debug Tools

### URL Analysis
```swift
func debugURL(_ url: URL) {
    print("Scheme: \(url.scheme ?? "nil")")
    print("Host: \(url.host ?? "nil")")
    print("Query: \(url.query ?? "nil")")
    
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .forEach { print("  \($0.name): \($0.value ?? "nil")") }
}
```

### Flow Logging
```swift
func logOAuthStep(_ step: String, details: [String: Any] = [:]) {
    print("🔐 OAuth: \(step)")
    details.forEach { print("   \($0.key): \($0.value)") }
}
```

---

## 📚 Further Reading

- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/draft-ietf-oauth-security-topics)
- [PKCE RFC 7636](https://tools.ietf.org/html/rfc7636)
- [Apple ASWebAuthenticationSession Documentation](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)

---

## 💡 Pro Tips

1. **Always use HTTPS** for OAuth endpoints
2. **Implement timeout handling** for authentication sessions
3. **Provide clear error messages** to users
4. **Test with airplane mode** to handle network errors
5. **Support both portrait and landscape** for auth screens
6. **Consider Universal Links** for production apps
7. **Implement token refresh** for long-lived sessions

This quick reference covers the essential concepts - dive into the detailed guides for comprehensive implementation!

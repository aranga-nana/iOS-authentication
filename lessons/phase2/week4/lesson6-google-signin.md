# Lesson 6: Google Sign-In Integration
**Phase 2, Week 4** | **Duration:** 6-8 hours | **Difficulty:** Intermediate

**Prerequisites**: Firebase Authentication basics, iOS app setup, completed Phase 2 Week 1-3 lessons

## 🎯 Learning Objectives
- Integrate Google Sign-In SDK with iOS app
- Configure Firebase for Google authentication
- Implement secure Google Sign-In flow
- Handle Google Sign-In errors and edge cases
- Understand Google Sign-In security considerations

---

## 📚 Theory Overview

### What is Google Sign-In?
Google Sign-In allows users to authenticate using their Google account credentials, providing a seamless user experience while maintaining security.

### Key Benefits:
- **User Convenience**: No need to remember another password
- **Security**: Leverages Google's robust authentication system
- **Trust**: Users trust Google's authentication
- **Reduced Friction**: Faster onboarding process

### Authentication Flow:
1. User taps "Sign in with Google"
2. Google Sign-In SDK opens authentication view
3. User enters Google credentials
4. Google returns ID token and access token
5. App exchanges tokens with Firebase
6. Firebase returns custom authentication token
7. User is authenticated in your app

---

## 🛠 Implementation Guide

### Step 1: Google Sign-In SDK Setup

#### 1.1 Install Google Sign-In SDK
Add to your `Podfile`:
```ruby
# Google Sign-In SDK
pod 'GoogleSignIn'
```

#### 1.2 Configure Firebase Console
1. Go to Firebase Console → Authentication → Sign-in method
2. Enable Google Sign-In provider
3. Download updated `GoogleService-Info.plist`
4. Add the plist file to your Xcode project

#### 1.3 Configure URL Scheme
Add to `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

### Step 2: Google Sign-In Manager Implementation

#### 2.1 Create GoogleSignInManager
```swift
import GoogleSignIn
import FirebaseAuth
import FirebaseCore

class GoogleSignInManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    init() {
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("Error: Could not find CLIENT_ID in GoogleService-Info.plist")
            return
        }
        
        guard let gidConfig = GIDConfiguration(clientID: clientId) else {
            print("Error: Could not create GIDConfiguration")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = gidConfig
    }
    
    /// Sign in with Google
    func signInWithGoogle() {
        guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
            self.errorMessage = "Unable to find root view controller"
            return
        }
        
        self.isLoading = true
        self.errorMessage = ""
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.handleGoogleSignInError(error)
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self?.errorMessage = "Failed to get ID token"
                    return
                }
                
                // Create Firebase credential
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                
                // Sign in to Firebase
                self?.signInToFirebase(with: credential)
            }
        }
    }
    
    /// Sign in to Firebase with Google credential
    private func signInToFirebase(with credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleFirebaseError(error)
                    return
                }
                
                guard let user = result?.user else {
                    self?.errorMessage = "Failed to get user information"
                    return
                }
                
                self?.isSignedIn = true
                self?.saveUserData(user)
                print("Google Sign-In successful: \(user.email ?? "No email")")
            }
        }
    }
    
    /// Save user data after successful authentication
    private func saveUserData(_ user: User) {
        let userData = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "lastSignIn": Date().timeIntervalSince1970
        ]
        
        // Save to UserDefaults or Keychain
        UserDefaults.standard.set(userData, forKey: "googleUser")
        
        // Optional: Save to backend/database
        // uploadUserToBackend(userData)
    }
    
    /// Sign out from Google and Firebase
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            
            self.isSignedIn = false
            UserDefaults.standard.removeObject(forKey: "googleUser")
            
            print("User signed out successfully")
        } catch {
            self.errorMessage = "Error signing out: \(error.localizedDescription)"
        }
    }
    
    /// Handle Google Sign-In specific errors
    private func handleGoogleSignInError(_ error: Error) {
        if let gidError = error as? GIDSignInError {
            switch gidError.code {
            case .canceled:
                self.errorMessage = "Sign-in was canceled"
            case .EMM:
                self.errorMessage = "Enterprise Mobility Management error"
            case .hasNoAuthInKeychain:
                self.errorMessage = "No authentication found in keychain"
            case .keychain:
                self.errorMessage = "Keychain error occurred"
            case .network:
                self.errorMessage = "Network error. Please check your connection."
            case .scopeNotGranted:
                self.errorMessage = "Required permissions not granted"
            case .unknown:
                self.errorMessage = "An unknown error occurred"
            @unknown default:
                self.errorMessage = "Unexpected error: \(error.localizedDescription)"
            }
        } else {
            self.errorMessage = error.localizedDescription
        }
    }
    
    /// Handle Firebase authentication errors
    private func handleFirebaseError(_ error: Error) {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .invalidCredential:
                self.errorMessage = "Invalid Google credentials"
            case .accountExistsWithDifferentCredential:
                self.errorMessage = "Account exists with different sign-in method"
            case .credentialAlreadyInUse:
                self.errorMessage = "This Google account is already linked to another user"
            case .operationNotAllowed:
                self.errorMessage = "Google Sign-In is not enabled"
            case .userDisabled:
                self.errorMessage = "This account has been disabled"
            case .userNotFound:
                self.errorMessage = "No account found"
            case .networkError:
                self.errorMessage = "Network error. Please try again."
            default:
                self.errorMessage = "Authentication failed: \(error.localizedDescription)"
            }
        } else {
            self.errorMessage = error.localizedDescription
        }
    }
    
    /// Check if user is already signed in
    func checkAuthenticationStatus() {
        if let currentUser = Auth.auth().currentUser {
            self.isSignedIn = true
            print("User already signed in: \(currentUser.email ?? "No email")")
        } else {
            self.isSignedIn = false
        }
    }
}
```

### Step 3: SwiftUI Implementation

#### 3.1 Google Sign-In Button Component
```swift
import SwiftUI
import GoogleSignIn

struct GoogleSignInButton: View {
    @ObservedObject var googleSignInManager: GoogleSignInManager
    
    var body: some View {
        Button(action: {
            googleSignInManager.signInWithGoogle()
        }) {
            HStack {
                Image("google_logo") // Add Google logo to Assets
                    .resizable()
                    .frame(width: 20, height: 20)
                
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .disabled(googleSignInManager.isLoading)
        .opacity(googleSignInManager.isLoading ? 0.6 : 1.0)
    }
}
```

#### 3.2 Main Authentication View
```swift
import SwiftUI

struct AuthenticationView: View {
    @StateObject private var googleSignInManager = GoogleSignInManager()
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Welcome")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                // Authentication Options
                VStack(spacing: 16) {
                    // Google Sign-In Button
                    GoogleSignInButton(googleSignInManager: googleSignInManager)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("or")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    
                    // Email Sign-In Button
                    NavigationLink(destination: EmailAuthView(authManager: authManager)) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.white)
                            
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Loading Indicator
                if googleSignInManager.isLoading {
                    ProgressView("Signing in...")
                        .scaleEffect(1.2)
                }
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Terms of Service") {
                            // Handle terms tap
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Text("and")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Privacy Policy") {
                            // Handle privacy tap
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Authentication Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(googleSignInManager.errorMessage)
            }
            .onChange(of: googleSignInManager.errorMessage) { errorMessage in
                if !errorMessage.isEmpty {
                    showingAlert = true
                }
            }
            .onAppear {
                googleSignInManager.checkAuthenticationStatus()
            }
        }
        .fullScreenCover(isPresented: $googleSignInManager.isSignedIn) {
            MainAppView()
        }
    }
}
```

### Step 4: UIKit Implementation (Alternative)

#### 4.1 UIKit Google Sign-In Button
```swift
import UIKit
import GoogleSignIn

class GoogleSignInViewController: UIViewController {
    private let googleSignInManager = GoogleSignInManager()
    private var signInButton: UIButton!
    private var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Google Sign-In Button
        signInButton = UIButton(type: .system)
        signInButton.setTitle("Continue with Google", for: .normal)
        signInButton.setTitleColor(.black, for: .normal)
        signInButton.backgroundColor = .white
        signInButton.layer.borderWidth = 1
        signInButton.layer.borderColor = UIColor.systemGray4.cgColor
        signInButton.layer.cornerRadius = 8
        signInButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        signInButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
        
        // Loading Indicator
        loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.hidesWhenStopped = true
        
        // Layout
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(signInButton)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            signInButton.centerX.constraint(equalTo: view.centerX),
            signInButton.centerY.constraint(equalTo: view.centerY),
            signInButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            signInButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            signInButton.heightAnchor.constraint(equalToConstant: 50),
            
            loadingIndicator.centerX.constraint(equalTo: view.centerX),
            loadingIndicator.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 20)
        ])
    }
    
    private func setupBindings() {
        // Observe loading state
        googleSignInManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                    self?.signInButton.isEnabled = false
                } else {
                    self?.loadingIndicator.stopAnimating()
                    self?.signInButton.isEnabled = true
                }
            }
            .store(in: &cancellables)
        
        // Observe errors
        googleSignInManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if !errorMessage.isEmpty {
                    self?.showAlert(title: "Error", message: errorMessage)
                }
            }
            .store(in: &cancellables)
        
        // Observe sign-in status
        googleSignInManager.$isSignedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSignedIn in
                if isSignedIn {
                    self?.navigateToMainApp()
                }
            }
            .store(in: &cancellables)
    }
    
    @objc private func googleSignInTapped() {
        googleSignInManager.signInWithGoogle()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func navigateToMainApp() {
        // Navigate to main app
        let mainVC = MainAppViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
```

### Step 5: Testing and Validation

#### 5.1 Unit Tests
```swift
import XCTest
@testable import YourApp

class GoogleSignInManagerTests: XCTestCase {
    var sut: GoogleSignInManager!
    
    override func setUp() {
        super.setUp()
        sut = GoogleSignInManager()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(sut.isSignedIn)
        XCTAssertTrue(sut.errorMessage.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSignOutResetsState() {
        // Given
        sut.isSignedIn = true
        
        // When
        sut.signOut()
        
        // Then
        XCTAssertFalse(sut.isSignedIn)
        XCTAssertTrue(sut.errorMessage.isEmpty)
    }
}
```

#### 5.2 Integration Testing Checklist
- [ ] Test Google Sign-In flow in simulator
- [ ] Test Google Sign-In flow on physical device
- [ ] Test network error scenarios
- [ ] Test cancelled sign-in flow
- [ ] Test sign-out functionality
- [ ] Verify token persistence
- [ ] Test app launch with existing session

---

## 🔐 Security Considerations

### Token Security
```swift
// Secure token storage example
class SecureTokenStorage {
    private let keychain = Keychain(service: "com.yourapp.tokens")
    
    func storeGoogleTokens(idToken: String, accessToken: String) {
        do {
            try keychain.set(idToken, key: "google_id_token")
            try keychain.set(accessToken, key: "google_access_token")
        } catch {
            print("Failed to store tokens: \(error)")
        }
    }
    
    func retrieveTokens() -> (idToken: String?, accessToken: String?) {
        let idToken = try? keychain.get("google_id_token")
        let accessToken = try? keychain.get("google_access_token")
        return (idToken, accessToken)
    }
    
    func clearTokens() {
        try? keychain.remove("google_id_token")
        try? keychain.remove("google_access_token")
    }
}
```

### Best Practices:
1. **Never store tokens in UserDefaults** - Use Keychain
2. **Validate tokens server-side** - Don't trust client-only validation
3. **Handle token refresh** - Google tokens expire
4. **Implement proper logout** - Clear all stored credentials
5. **Use HTTPS only** - For all network requests

---

## 🚀 Practice Exercises

### Exercise 1: Basic Integration (2 hours)
Implement Google Sign-In in a new iOS project with:
- Basic sign-in flow
- Error handling
- Simple success screen

### Exercise 2: Enhanced UX (2 hours)
Add to Exercise 1:
- Loading states
- Better error messages
- Custom button design
- Remember user preference

### Exercise 3: Advanced Features (3 hours)
Implement:
- Silent sign-in on app launch
- Account linking (if user has email account)
- Profile picture display
- Sign-in analytics

---

## 📝 Assignment: Complete Google Sign-In Integration

### Requirements:
1. **Setup** (30 min)
   - Configure Firebase project for Google Sign-In
   - Install and configure Google Sign-In SDK
   - Set up URL schemes

2. **Implementation** (3 hours)
   - Create GoogleSignInManager class
   - Implement SwiftUI authentication view
   - Add proper error handling
   - Implement sign-out functionality

3. **Testing** (1 hour)
   - Test sign-in flow
   - Test error scenarios
   - Verify token storage
   - Test app restart behavior

4. **Documentation** (30 min)
   - Document setup steps
   - Create troubleshooting guide
   - Document security considerations

### Deliverables:
- [ ] Working Google Sign-In implementation
- [ ] Comprehensive error handling
- [ ] Unit tests for GoogleSignInManager
- [ ] Setup and troubleshooting documentation

---

## 🔗 Resources

### Documentation:
- [Google Sign-In iOS Documentation](https://developers.google.com/identity/sign-in/ios)
- [Firebase Auth iOS Guide](https://firebase.google.com/docs/auth/ios/google-signin)
- [SwiftUI Authentication Patterns](https://developer.apple.com/documentation/swiftui)

### Sample Projects:
- [Google Sign-In Sample App](https://github.com/googlesamples/google-signin-ios)
- [Firebase Auth Samples](https://github.com/firebase/snippets-ios)

### Troubleshooting:
- [Common Google Sign-In Issues](https://developers.google.com/identity/sign-in/ios/troubleshooting)
- [Firebase Auth Troubleshooting](https://firebase.google.com/docs/auth/ios/errors)

---

## ✅ Lesson Completion Checklist

- [ ] Understand Google Sign-In authentication flow
- [ ] Configure Google Sign-In SDK and Firebase
- [ ] Implement GoogleSignInManager class
- [ ] Create SwiftUI authentication interface
- [ ] Add comprehensive error handling
- [ ] Implement secure token storage
- [ ] Test sign-in and sign-out flows
- [ ] Complete practice exercises
- [ ] Submit assignment project
- [ ] Review security best practices

**Estimated Time to Complete**: 6-8 hours  
**Next Lesson**: AWS Lambda Backend Setup

---

*Need help? Review the Firebase Authentication lesson or check the troubleshooting resources above.*

# 🔐 Lesson 4: Google Sign-In Integration

> **Phase 2, Week 3 - Advanced Google OAuth Implementation with Firebase**  
> **Duration**: 6-8 hours | **Level**: Intermediate  
> **Prerequisites**: Completed Lesson 3 (Firebase Auth Deep Dive), Google Cloud Console access, Firebase project setup

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Set up Google Sign-In SDK and configure OAuth credentials
- Implement Google Sign-In with Firebase Authentication integration
- Handle Google Sign-In errors and edge cases gracefully
- Build custom Google Sign-In UI components
- Manage Google user profiles and permissions
- Implement sign-out and account management for Google users
- Test Google Sign-In in both simulator and device environments

---

## 📚 Part 1: Google Cloud Console Setup (1.5 hours)

### 1.1 Google Cloud Project Configuration

**Step 1: Create/Configure Google Cloud Project**

1. Navigate to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing one
3. Enable required APIs:

```bash
# Enable Google Sign-In API
gcloud services enable googleapis.com
gcloud services enable identitytoolkit.googleapis.com
```

**Step 2: Configure OAuth Consent Screen**

1. Go to APIs & Services → OAuth consent screen
2. Choose "External" for user type
3. Fill in required information:

```
App name: iOS Auth Tutorial
User support email: your-email@example.com
Developer contact: your-email@example.com
Authorized domains: your-domain.com (if applicable)
Scopes: email, profile, openid
```

### 1.2 iOS OAuth Client Setup

**Create OAuth 2.0 Client ID:**

1. Go to APIs & Services → Credentials
2. Click "Create Credentials" → OAuth client ID
3. Choose "iOS" as application type
4. Configure iOS settings:

```
Name: iOS Auth App
Bundle ID: com.yourname.iosauth (match your Xcode project)
```

**Important Files Generated:**
- `GoogleService-Info.plist` (from Firebase Console)
- OAuth Client ID (from Google Cloud Console)

### 1.3 Firebase Console Configuration

**Enable Google Sign-In in Firebase:**

1. Go to Firebase Console → Authentication
2. Click "Sign-in method" tab
3. Enable "Google" provider
4. Add your OAuth client details:

```
Web SDK configuration:
- Web client ID: [from Google Cloud Console]
- Web client secret: [from Google Cloud Console]

iOS configuration:
- iOS client ID: [automatically configured via GoogleService-Info.plist]
```

---

## 📚 Part 2: iOS Project Configuration (1.5 hours)

### 2.1 Dependencies and SDK Setup

**Update Podfile:**

```ruby
# Add to your existing Podfile
platform :ios, '14.0'

target 'iOSAuthApp' do
  use_frameworks!
  
  # Firebase dependencies (existing)
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  
  # Google Sign-In
  pod 'GoogleSignIn', '~> 7.0'
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      end
    end
  end
end
```

**Install Dependencies:**

```bash
cd /path/to/your/ios/project
pod install --repo-update
```

### 2.2 Xcode Configuration

**Step 1: Add GoogleService-Info.plist**
1. Drag `GoogleService-Info.plist` to Xcode project
2. Ensure it's added to your target
3. Verify Bundle ID matches

**Step 2: Configure URL Schemes**
1. Go to Project Settings → Info → URL Types
2. Add new URL Type:

```
Identifier: GoogleSignIn
URL Schemes: YOUR_REVERSED_CLIENT_ID
```

Find `YOUR_REVERSED_CLIENT_ID` in `GoogleService-Info.plist`:
```xml
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.123456789-abc123def456.apps.googleusercontent.com</string>
```

### 2.3 App Configuration

**Update App.swift:**

```swift
import SwiftUI
import Firebase
import GoogleSignIn

@main
struct iOSAuthApp: App {
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist not found or CLIENT_ID missing")
        }
        
        guard let gidConfig = GIDConfiguration(clientID: clientId) else {
            fatalError("Failed to create GIDConfiguration")
        }
        
        GIDSignIn.sharedInstance.configuration = gidConfig
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
```

---

## 📚 Part 3: Google Sign-In Service Implementation (2 hours)

### 3.1 Google Authentication Models

Create `Models/GoogleAuthModels.swift`:

```swift
import Foundation
import GoogleSignIn
import FirebaseAuth

// MARK: - Google User Profile
struct GoogleUserProfile {
    let userId: String
    let email: String
    let fullName: String?
    let givenName: String?
    let familyName: String?
    let profileImageURL: URL?
    let idToken: String?
    let accessToken: String
    
    init(from user: GIDGoogleUser) {
        self.userId = user.userID ?? ""
        self.email = user.profile?.email ?? ""
        self.fullName = user.profile?.name
        self.givenName = user.profile?.givenName
        self.familyName = user.profile?.familyName
        self.profileImageURL = user.profile?.imageURL(withDimension: 200)
        self.idToken = user.idToken?.tokenString
        self.accessToken = user.accessToken.tokenString
    }
}

// MARK: - Google Sign-In Errors
enum GoogleSignInError: LocalizedError {
    case configurationError
    case userCancelled
    case networkError
    case invalidCredentials
    case firebaseIntegrationFailed(String)
    case noCurrentUser
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Google Sign-In configuration error. Please check your setup."
        case .userCancelled:
            return "Sign-in was cancelled by the user."
        case .networkError:
            return "Network error occurred during sign-in. Please check your connection."
        case .invalidCredentials:
            return "Invalid Google credentials. Please try again."
        case .firebaseIntegrationFailed(let message):
            return "Firebase integration failed: \(message)"
        case .noCurrentUser:
            return "No currently signed-in Google user found."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .configurationError:
            return "Check your GoogleService-Info.plist and URL schemes configuration."
        case .userCancelled:
            return "Please try signing in again."
        case .networkError:
            return "Check your internet connection and try again."
        case .invalidCredentials:
            return "Ensure you're using a valid Google account."
        case .firebaseIntegrationFailed:
            return "Check Firebase configuration or try again later."
        case .noCurrentUser:
            return "Please sign in with Google first."
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Google Sign-In State
enum GoogleSignInState {
    case signedOut
    case signingIn
    case signedIn(GoogleUserProfile)
    case error(GoogleSignInError)
    
    var isSignedIn: Bool {
        switch self {
        case .signedIn:
            return true
        default:
            return false
        }
    }
    
    var userProfile: GoogleUserProfile? {
        switch self {
        case .signedIn(let profile):
            return profile
        default:
            return nil
        }
    }
}
```

### 3.2 Google Sign-In Service

Create `Services/GoogleSignInService.swift`:

```swift
import Foundation
import GoogleSignIn
import FirebaseAuth
import Combine
import UIKit

// MARK: - Google Sign-In Service Protocol
protocol GoogleSignInServiceProtocol {
    var signInState: AnyPublisher<GoogleSignInState, Never> { get }
    var currentUser: GoogleUserProfile? { get }
    
    func signIn() async throws -> GoogleUserProfile
    func signOut() throws
    func disconnect() async throws
    func refreshTokens() async throws
    func hasCurrentUser() -> Bool
}

// MARK: - Google Sign-In Service Implementation
class GoogleSignInService: ObservableObject, GoogleSignInServiceProtocol {
    
    @Published private var _signInState = GoogleSignInState.signedOut
    
    var signInState: AnyPublisher<GoogleSignInState, Never> {
        $_signInState.eraseToAnyPublisher()
    }
    
    var currentUser: GoogleUserProfile? {
        guard let gidUser = GIDSignIn.sharedInstance.currentUser else {
            return nil
        }
        return GoogleUserProfile(from: gidUser)
    }
    
    init() {
        // Restore previous sign-in state
        restorePreviousSignIn()
    }
    
    // MARK: - Sign-In Methods
    func signIn() async throws -> GoogleUserProfile {
        _signInState = .signingIn
        
        do {
            // Get the presenting view controller
            guard let presentingViewController = await getPresentingViewController() else {
                throw GoogleSignInError.configurationError
            }
            
            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            
            // Create user profile
            let profile = GoogleUserProfile(from: user)
            
            // Integrate with Firebase
            try await integrateWithFirebase(user: user)
            
            _signInState = .signedIn(profile)
            return profile
            
        } catch {
            let googleError = mapError(error)
            _signInState = .error(googleError)
            throw googleError
        }
    }
    
    func signOut() throws {
        do {
            GIDSignIn.sharedInstance.signOut()
            
            // Also sign out from Firebase
            try Auth.auth().signOut()
            
            _signInState = .signedOut
        } catch {
            throw GoogleSignInError.unknown(error.localizedDescription)
        }
    }
    
    func disconnect() async throws {
        do {
            try await GIDSignIn.sharedInstance.disconnect()
            
            // Also sign out from Firebase
            try Auth.auth().signOut()
            
            _signInState = .signedOut
        } catch {
            throw GoogleSignInError.unknown(error.localizedDescription)
        }
    }
    
    func refreshTokens() async throws {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleSignInError.noCurrentUser
        }
        
        do {
            try await currentUser.refreshTokensIfNeeded()
        } catch {
            throw GoogleSignInError.unknown(error.localizedDescription)
        }
    }
    
    func hasCurrentUser() -> Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    // MARK: - Private Methods
    private func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            DispatchQueue.main.async {
                if let user = user {
                    let profile = GoogleUserProfile(from: user)
                    self?._signInState = .signedIn(profile)
                } else if let error = error {
                    let googleError = self?.mapError(error) ?? .unknown(error.localizedDescription)
                    self?._signInState = .error(googleError)
                } else {
                    self?._signInState = .signedOut
                }
            }
        }
    }
    
    @MainActor
    private func getPresentingViewController() async -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        return window.rootViewController
    }
    
    private func integrateWithFirebase(user: GIDGoogleUser) async throws {
        guard let idToken = user.idToken?.tokenString else {
            throw GoogleSignInError.invalidCredentials
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )
        
        do {
            let _ = try await Auth.auth().signIn(with: credential)
        } catch {
            throw GoogleSignInError.firebaseIntegrationFailed(error.localizedDescription)
        }
    }
    
    private func mapError(_ error: Error) -> GoogleSignInError {
        if let gidError = error as? GIDSignInError {
            switch gidError.code {
            case .canceled:
                return .userCancelled
            case .hasNoAuthInKeychain:
                return .noCurrentUser
            case .unknown:
                return .unknown(gidError.localizedDescription)
            default:
                return .unknown(gidError.localizedDescription)
            }
        }
        
        return .unknown(error.localizedDescription)
    }
}
```

### 3.3 Integrated Authentication Service

Create `Services/IntegratedAuthService.swift`:

```swift
import Foundation
import Combine
import FirebaseAuth

// MARK: - Integrated Authentication Service
class IntegratedAuthService: ObservableObject {
    
    @Published var isAuthenticated = false
    @Published var currentAuthProvider: AuthProvider = .none
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebaseAuthService: FirebaseAuthService
    private let googleSignInService: GoogleSignInService
    private var cancellables = Set<AnyCancellable>()
    
    enum AuthProvider {
        case none
        case firebase
        case google
    }
    
    struct UserProfile {
        let uid: String
        let email: String?
        let displayName: String?
        let photoURL: URL?
        let provider: AuthProvider
        let isEmailVerified: Bool
        
        init(from firebaseUser: User, provider: AuthProvider) {
            self.uid = firebaseUser.uid
            self.email = firebaseUser.email
            self.displayName = firebaseUser.displayName
            self.photoURL = firebaseUser.photoURL
            self.provider = provider
            self.isEmailVerified = firebaseUser.isEmailVerified
        }
    }
    
    init(
        firebaseAuthService: FirebaseAuthService = FirebaseAuthService(),
        googleSignInService: GoogleSignInService = GoogleSignInService()
    ) {
        self.firebaseAuthService = firebaseAuthService
        self.googleSignInService = googleSignInService
        
        setupAuthStateListeners()
    }
    
    // MARK: - Authentication Methods
    func signInWithGoogle() async {
        await performAuthAction {
            let _ = try await googleSignInService.signIn()
        }
    }
    
    func signInWithEmail(email: String, password: String) async {
        await performAuthAction {
            try await firebaseAuthService.signIn(email: email, password: password)
        }
    }
    
    func signUpWithEmail(email: String, password: String) async {
        await performAuthAction {
            try await firebaseAuthService.signUp(email: email, password: password)
        }
    }
    
    func signOut() {
        do {
            // Sign out from both services
            try firebaseAuthService.signOut()
            try googleSignInService.signOut()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
    
    func deleteAccount() async {
        await performAuthAction {
            // Delete from Firebase (this will also handle Google-linked accounts)
            try await firebaseAuthService.deleteAccount()
            
            // Disconnect from Google if it was a Google sign-in
            if currentAuthProvider == .google {
                try await googleSignInService.disconnect()
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupAuthStateListeners() {
        // Listen to Firebase auth state changes
        firebaseAuthService.authenticationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authState in
                self?.handleFirebaseAuthState(authState)
            }
            .store(in: &cancellables)
        
        // Listen to Google sign-in state changes
        googleSignInService.signInState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] googleState in
                self?.handleGoogleSignInState(googleState)
            }
            .store(in: &cancellables)
    }
    
    private func handleFirebaseAuthState(_ state: AuthenticationState) {
        switch state {
        case .signedIn(let user):
            isAuthenticated = true
            
            // Determine provider based on sign-in method
            let provider: AuthProvider = user.providerData.contains { $0.providerID == "google.com" } ? .google : .firebase
            currentAuthProvider = provider
            
            userProfile = UserProfile(from: user, provider: provider)
            
        case .signedOut:
            isAuthenticated = false
            currentAuthProvider = .none
            userProfile = nil
            
        case .undefined:
            // Keep current state during initialization
            break
        }
    }
    
    private func handleGoogleSignInState(_ state: GoogleSignInState) {
        switch state {
        case .signingIn:
            isLoading = true
            errorMessage = nil
            
        case .signedIn:
            isLoading = false
            errorMessage = nil
            
        case .error(let error):
            isLoading = false
            errorMessage = error.localizedDescription
            
        case .signedOut:
            // Handled by Firebase auth state
            isLoading = false
        }
    }
    
    private func performAuthAction(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

---

## 📚 Part 4: Google Sign-In UI Components (1.5 hours)

### 4.1 Custom Google Sign-In Button

Create `Views/Components/GoogleSignInButton.swift`:

```swift
import SwiftUI

// MARK: - Google Sign-In Button
struct GoogleSignInButton: View {
    let action: () -> Void
    var isLoading: Bool = false
    var isEnabled: Bool = true
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google Logo
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    GoogleLogo()
                        .frame(width: 20, height: 20)
                }
                
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Google Logo Component
struct GoogleLogo: View {
    var body: some View {
        HStack(spacing: 0) {
            // Simplified Google logo using SF Symbols and colors
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Alternative Google Sign-In Button (Official Style)
struct OfficialGoogleSignInButton: View {
    let action: () -> Void
    var isLoading: Bool = false
    var isEnabled: Bool = true
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google "G" Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                    
                    GoogleGLogo()
                        .frame(width: 18, height: 18)
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Text("Sign in with Google")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google Blue
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Google "G" Logo
struct GoogleGLogo: View {
    var body: some View {
        // Simple representation of Google's "G" logo
        ZStack {
            Circle()
                .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: 2)
            
            Path { path in
                path.move(to: CGPoint(x: 12, y: 9))
                path.addLine(to: CGPoint(x: 15, y: 9))
                path.addLine(to: CGPoint(x: 15, y: 11))
                path.addLine(to: CGPoint(x: 13, y: 11))
                path.addLine(to: CGPoint(x: 13, y: 13))
                path.addLine(to: CGPoint(x: 12, y: 13))
                path.closeSubpath()
            }
            .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
    }
}

// MARK: - Preview
struct GoogleSignInButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GoogleSignInButton(action: {})
            
            GoogleSignInButton(action: {}, isLoading: true)
            
            OfficialGoogleSignInButton(action: {})
            
            OfficialGoogleSignInButton(action: {}, isLoading: true)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
```

### 4.2 Enhanced Authentication View

Create `Views/EnhancedAuthView.swift`:

```swift
import SwiftUI

// MARK: - Enhanced Authentication View
struct EnhancedAuthView: View {
    @StateObject private var integratedAuth = IntegratedAuthService()
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    AuthHeaderView(isSignUp: isSignUp)
                    
                    // Google Sign-In Section
                    GoogleSignInSection()
                    
                    // Divider
                    DividerWithText("or")
                    
                    // Email/Password Section
                    EmailPasswordSection(
                        isSignUp: isSignUp,
                        email: $email,
                        password: $password,
                        confirmPassword: $confirmPassword
                    )
                    
                    // Action Buttons
                    ActionButtonsSection(
                        isSignUp: isSignUp,
                        email: email,
                        password: password,
                        confirmPassword: confirmPassword,
                        showingForgotPassword: $showingForgotPassword
                    )
                    
                    // Toggle Sign Up/In
                    ToggleAuthModeSection(isSignUp: $isSignUp)
                }
                .padding()
            }
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.large)
        }
        .environmentObject(integratedAuth)
        .overlay {
            if integratedAuth.isLoading {
                LoadingOverlay()
            }
        }
        .alert("Error", isPresented: .constant(integratedAuth.errorMessage != nil)) {
            Button("OK") {
                integratedAuth.errorMessage = nil
            }
        } message: {
            if let errorMessage = integratedAuth.errorMessage {
                Text(errorMessage)
            }
        }
        .fullScreenCover(isPresented: $integratedAuth.isAuthenticated) {
            AuthenticatedView()
                .environmentObject(integratedAuth)
        }
    }
}

// MARK: - Google Sign-In Section
struct GoogleSignInSection: View {
    @EnvironmentObject var integratedAuth: IntegratedAuthService
    
    var body: some View {
        VStack(spacing: 16) {
            GoogleSignInButton(
                action: {
                    Task {
                        await integratedAuth.signInWithGoogle()
                    }
                },
                isLoading: integratedAuth.isLoading && integratedAuth.currentAuthProvider == .google,
                isEnabled: !integratedAuth.isLoading
            )
            
            Text("Sign in quickly with your Google account")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Email Password Section
struct EmailPasswordSection: View {
    let isSignUp: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    
    var body: some View {
        VStack(spacing: 16) {
            CustomTextField(
                title: "Email",
                placeholder: "Enter your email",
                text: $email,
                keyboardType: .emailAddress,
                systemImage: "envelope"
            )
            
            CustomSecureField(
                title: "Password",
                placeholder: "Enter your password",
                text: $password,
                systemImage: "lock"
            )
            
            if isSignUp {
                CustomSecureField(
                    title: "Confirm Password",
                    placeholder: "Confirm your password",
                    text: $confirmPassword,
                    systemImage: "lock.shield"
                )
            }
        }
    }
}

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
    @EnvironmentObject var integratedAuth: IntegratedAuthService
    let isSignUp: Bool
    let email: String
    let password: String
    let confirmPassword: String
    @Binding var showingForgotPassword: Bool
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   !confirmPassword.isEmpty && 
                   password == confirmPassword &&
                   password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: performEmailAction) {
                HStack {
                    if integratedAuth.isLoading && integratedAuth.currentAuthProvider == .firebase {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || integratedAuth.isLoading)
            
            if !isSignUp {
                Button("Forgot Password?") {
                    showingForgotPassword = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
            }
        }
    }
    
    private func performEmailAction() {
        Task {
            if isSignUp {
                await integratedAuth.signUpWithEmail(email: email, password: password)
            } else {
                await integratedAuth.signInWithEmail(email: email, password: password)
            }
        }
    }
}

// MARK: - Toggle Auth Mode Section
struct ToggleAuthModeSection: View {
    @Binding var isSignUp: Bool
    
    var body: some View {
        HStack {
            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Button(isSignUp ? "Sign In" : "Sign Up") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSignUp.toggle()
                }
            }
            .font(.footnote)
            .fontWeight(.semibold)
        }
        .padding(.top)
    }
}

// MARK: - Divider with Text
struct DividerWithText: View {
    let text: String
    
    var body: some View {
        HStack {
            VStack { Divider() }
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            VStack { Divider() }
        }
    }
}

// MARK: - Authenticated View
struct AuthenticatedView: View {
    @EnvironmentObject var integratedAuth: IntegratedAuthService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // User Profile Section
                if let profile = integratedAuth.userProfile {
                    UserProfileCard(profile: profile)
                }
                
                // Account Actions
                AccountActionsView()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        integratedAuth.signOut()
                    }
                }
            }
        }
    }
}

// MARK: - User Profile Card
struct UserProfileCard: View {
    let profile: IntegratedAuthService.UserProfile
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: profile.photoURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            // User Info
            VStack(spacing: 8) {
                Text(profile.displayName ?? "No Name")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(profile.email ?? "No Email")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: providerIcon)
                        .foregroundColor(providerColor)
                    Text(providerText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !profile.isEmailVerified {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Email not verified")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var providerIcon: String {
        switch profile.provider {
        case .google:
            return "globe"
        case .firebase:
            return "envelope"
        case .none:
            return "questionmark"
        }
    }
    
    private var providerColor: Color {
        switch profile.provider {
        case .google:
            return .blue
        case .firebase:
            return .orange
        case .none:
            return .gray
        }
    }
    
    private var providerText: String {
        switch profile.provider {
        case .google:
            return "Signed in with Google"
        case .firebase:
            return "Signed in with Email"
        case .none:
            return "Unknown provider"
        }
    }
}

// MARK: - Account Actions View
struct AccountActionsView: View {
    @EnvironmentObject var integratedAuth: IntegratedAuthService
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Account Actions")
                .font(.headline)
            
            Button("Delete Account") {
                showingDeleteAlert = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await integratedAuth.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
}
```

---

## 📚 Part 5: Testing and Troubleshooting (1 hour)

### 5.1 Testing Google Sign-In

**Simulator Testing:**

```swift
// Add to your test file
import XCTest
@testable import YourApp

class GoogleSignInTests: XCTestCase {
    
    var googleService: GoogleSignInService!
    
    override func setUp() async throws {
        await super.setUp()
        googleService = GoogleSignInService()
    }
    
    func testGoogleSignInConfiguration() {
        // Test that Google Sign-In is properly configured
        XCTAssertNotNil(GIDSignIn.sharedInstance.configuration)
        XCTAssertNotNil(GIDSignIn.sharedInstance.configuration?.clientID)
    }
    
    func testHasCurrentUser() {
        // Test current user detection
        let hasUser = googleService.hasCurrentUser()
        // This will be false in testing environment
        XCTAssertFalse(hasUser)
    }
    
    func testUserProfileCreation() {
        // Create mock GIDGoogleUser for testing
        // Note: This requires creating mock objects or using Firebase Test Lab
    }
}
```

**Device Testing Checklist:**

1. ✅ GoogleService-Info.plist is properly configured
2. ✅ URL schemes match REVERSED_CLIENT_ID
3. ✅ Bundle ID matches OAuth client configuration
4. ✅ Internet connection is available
5. ✅ Google account is available on device

### 5.2 Common Issues and Solutions

**Issue 1: "No application found to handle URL scheme"**

```swift
// Solution: Check URL scheme configuration
// In Info.plist, ensure URL scheme matches REVERSED_CLIENT_ID exactly
```

**Issue 2: "The operation couldn't be completed"**

```swift
// Solution: Check Firebase configuration
// Ensure GoogleService-Info.plist is added to target
// Verify Firebase.configure() is called before Google Sign-In setup
```

**Issue 3: Sign-in works but Firebase integration fails**

```swift
// Solution: Check Firebase Authentication setup
// Enable Google sign-in method in Firebase Console
// Verify SHA-1 fingerprint is added (for Android) - not needed for iOS
```

### 5.3 Debug Configuration

Create `Utils/GoogleSignInDebugger.swift`:

```swift
import Foundation
import GoogleSignIn
import Firebase

// MARK: - Google Sign-In Debugger
class GoogleSignInDebugger {
    
    static func printConfiguration() {
        print("🔍 Google Sign-In Configuration Debug:")
        
        // Check Google Sign-In configuration
        if let config = GIDSignIn.sharedInstance.configuration {
            print("✅ GIDConfiguration found")
            print("   Client ID: \(config.clientID)")
            if let hostedDomain = config.hostedDomain {
                print("   Hosted Domain: \(hostedDomain)")
            }
        } else {
            print("❌ GIDConfiguration not found")
        }
        
        // Check Firebase configuration
        if let app = FirebaseApp.app() {
            print("✅ Firebase app configured")
            print("   Name: \(app.name)")
        } else {
            print("❌ Firebase app not configured")
        }
        
        // Check current user
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            print("✅ Current Google user found")
            print("   Email: \(currentUser.profile?.email ?? "N/A")")
            print("   ID: \(currentUser.userID ?? "N/A")")
        } else {
            print("ℹ️ No current Google user")
        }
        
        // Check Bundle ID
        if let bundleId = Bundle.main.bundleIdentifier {
            print("✅ Bundle ID: \(bundleId)")
        } else {
            print("❌ Bundle ID not found")
        }
        
        // Check GoogleService-Info.plist
        checkGoogleServiceInfo()
    }
    
    private static func checkGoogleServiceInfo() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            print("❌ GoogleService-Info.plist not found")
            return
        }
        
        print("✅ GoogleService-Info.plist found")
        
        if let clientId = plist["CLIENT_ID"] as? String {
            print("   CLIENT_ID: \(clientId)")
        } else {
            print("❌ CLIENT_ID not found in plist")
        }
        
        if let reversedClientId = plist["REVERSED_CLIENT_ID"] as? String {
            print("   REVERSED_CLIENT_ID: \(reversedClientId)")
        } else {
            print("❌ REVERSED_CLIENT_ID not found in plist")
        }
    }
}

// Usage in your app:
// GoogleSignInDebugger.printConfiguration()
```

---

## 🚀 Practical Exercises

### Exercise 1: Custom Google Button Styles (20 minutes)
Create three different Google Sign-In button styles:
- Minimalist (icon only)
- Corporate (wide with company branding)
- Accessibility-focused (high contrast, large text)

### Exercise 2: Error Handling Enhancement (25 minutes)
Implement advanced error handling:
- Retry mechanism for network errors
- Specific messaging for different error types
- Logging for debugging purposes

### Exercise 3: Profile Management (30 minutes)
Build a profile management screen that allows users to:
- View their Google profile information
- Refresh their profile data
- Manage connected accounts
- Download their data

---

## 📝 Summary

In this lesson, you learned:

✅ **Google Cloud Console Setup**
- OAuth 2.0 client configuration
- Firebase integration setup
- URL scheme configuration

✅ **iOS Implementation**
- Google Sign-In SDK integration
- Custom authentication service
- Firebase integration for unified auth

✅ **Advanced UI Components**
- Custom Google Sign-In buttons
- Integrated authentication flow
- Error handling and loading states

✅ **Testing and Debugging**
- Common issues and solutions
- Debug configuration tools
- Testing strategies

## 🔗 Additional Resources

- [Google Sign-In for iOS Documentation](https://developers.google.com/identity/sign-in/ios)
- [Firebase Auth with Google](https://firebase.google.com/docs/auth/ios/google-signin)
- [Google Identity Guidelines](https://developers.google.com/identity/branding-guidelines)
- [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/draft-ietf-oauth-security-topics)

## 🎯 Next Steps

- **Lesson 5**: Advanced Firebase Features and Security
- **Week 4**: AWS Backend Integration
- **Advanced Topics**: Multi-factor authentication, enterprise SSO

---

> **Note**: This lesson provides a comprehensive implementation of Google Sign-In with Firebase integration. The code examples follow iOS development best practices and include proper error handling, security considerations, and user experience optimizations.
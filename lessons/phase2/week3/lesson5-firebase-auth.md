# 🔥 Lesson 5: Firebase Authentication Integration

> **Phase 2, Week 3 - Firebase SDK Setup and Implementation**  
> **Duration**: 8 hours | **Level**: Beginner to Intermediate  
> **Prerequisites**: iOS basics, Authentication fundamentals, completed Phase 2 Week 1-2 lessons

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Set up Firebase SDK in iOS project
- Implement email/password authentication
- Handle authentication errors properly
- Manage user sessions and state
- Store Firebase tokens securely

---

## 📚 Part 1: Firebase SDK Setup (2 hours)

### 1.1 Firebase Project Creation

**Step 1: Create Firebase Project**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `ios-auth-tutorial`
4. Enable Google Analytics (optional)
5. Create project

**Step 2: Add iOS App**
1. Click "Add app" → iOS
2. Enter iOS bundle ID: `com.yourname.iosauth`
3. Enter app nickname: `iOS Auth App`
4. Download `GoogleService-Info.plist`

### 1.2 Xcode Project Setup

**Step 1: Create New iOS Project**
```bash
# Open Xcode and create new project
# Choose iOS → App
# Product Name: iOSAuthApp
# Interface: SwiftUI
# Language: Swift
```

**Step 2: Add Firebase SDK**
1. In Xcode: File → Add Package Dependencies
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Click "Add Package"
4. Select these products:
   - FirebaseAuth
   - FirebaseCore
   - GoogleSignIn (for later)

**Step 3: Configure Firebase**
```swift
// 1. Drag GoogleService-Info.plist to Xcode project
// 2. Add to target and ensure "Add to Target" is checked

// App.swift (SwiftUI) or AppDelegate.swift (UIKit)
import SwiftUI
import Firebase

@main
struct iOSAuthApp: App {
    
    // Initialize Firebase when app starts
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 1.3 Firebase Console Configuration

**Enable Authentication:**
1. Go to Firebase Console → Authentication
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password"
5. Enable "Google" (for later lesson)

**Set up Authentication Domain:**
1. Go to "Settings" tab
2. Add authorized domains if needed
3. Note the project configuration

**🏃‍♂️ Practice Exercise 1.1:**
```swift
// Create a simple Firebase connection test
import Firebase

class FirebaseTestManager {
    
    static func testFirebaseConnection() {
        // Check if Firebase is configured
        guard FirebaseApp.app() != nil else {
            print("❌ Firebase not configured")
            return
        }
        
        print("✅ Firebase configured successfully")
        print("Project ID: \(FirebaseApp.app()?.options.projectID ?? "Unknown")")
        
        // Test Auth service
        let auth = Auth.auth()
        print("✅ Firebase Auth available")
        print("Current user: \(auth.currentUser?.uid ?? "None")")
    }
}

// Call this in your app startup
FirebaseTestManager.testFirebaseConnection()
```

---

## 📚 Part 2: Email/Password Authentication (3 hours)

### 2.1 User Registration Implementation

**User Model:**
```swift
import Foundation
import Firebase

struct AppUser {
    let uid: String
    let email: String
    let displayName: String?
    let createdAt: Date
    let isEmailVerified: Bool
    
    init(from firebaseUser: User) {
        self.uid = firebaseUser.uid
        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName
        self.createdAt = firebaseUser.metadata.creationDate ?? Date()
        self.isEmailVerified = firebaseUser.isEmailVerified
    }
}
```

**Authentication Manager:**
```swift
import Foundation
import Firebase
import Combine

class AuthenticationManager: ObservableObject {
    
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.currentUser = AppUser(from: user)
                    self?.isAuthenticated = true
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Registration
    
    func register(email: String, password: String, displayName: String) {
        guard isValidEmail(email) else {
            setError("Please enter a valid email address")
            return
        }
        
        guard isValidPassword(password) else {
            setError("Password must be at least 6 characters long")
            return
        }
        
        isLoading = true
        clearError()
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.handleAuthError(error)
                    return
                }
                
                guard let user = result?.user else {
                    self?.setError("Failed to create user account")
                    return
                }
                
                // Update user profile with display name
                self?.updateUserProfile(user: user, displayName: displayName)
            }
        }
    }
    
    private func updateUserProfile(user: User, displayName: String) {
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        
        changeRequest.commitChanges { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to update profile: \(error.localizedDescription)")
                } else {
                    print("Profile updated successfully")
                    // Send email verification
                    self?.sendEmailVerification()
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) {
        guard isValidEmail(email) else {
            setError("Please enter a valid email address")
            return
        }
        
        guard !password.isEmpty else {
            setError("Please enter your password")
            return
        }
        
        isLoading = true
        clearError()
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.handleAuthError(error)
                    return
                }
                
                print("User signed in successfully")
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("User signed out successfully")
        } catch {
            setError("Failed to sign out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Email Verification
    
    func sendEmailVerification() {
        guard let user = Auth.auth().currentUser else {
            setError("No user is currently signed in")
            return
        }
        
        user.sendEmailVerification { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.setError("Failed to send verification email: \(error.localizedDescription)")
                } else {
                    print("Verification email sent successfully")
                }
            }
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) {
        guard isValidEmail(email) else {
            setError("Please enter a valid email address")
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleAuthError(error)
                } else {
                    print("Password reset email sent successfully")
                }
            }
        }
    }
    
    // MARK: - Validation Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }
    
    // MARK: - Error Handling
    
    private func handleAuthError(_ error: Error) {
        if let authError = error as NSError? {
            switch AuthErrorCode(rawValue: authError.code) {
            case .emailAlreadyInUse:
                setError("An account with this email already exists")
            case .weakPassword:
                setError("Password is too weak. Please choose a stronger password")
            case .invalidEmail:
                setError("Please enter a valid email address")
            case .userNotFound:
                setError("No account found with this email address")
            case .wrongPassword:
                setError("Incorrect password. Please try again")
            case .tooManyRequests:
                setError("Too many failed attempts. Please try again later")
            case .networkError:
                setError("Network error. Please check your connection")
            default:
                setError("Authentication failed: \(error.localizedDescription)")
            }
        } else {
            setError("An unexpected error occurred")
        }
    }
    
    private func setError(_ message: String) {
        self.errorMessage = message
    }
    
    private func clearError() {
        self.errorMessage = nil
    }
}
```

### 2.2 SwiftUI Authentication Views

**Registration View:**
```swift
import SwiftUI

struct RegistrationView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var showingLoginView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Join us today!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Form Fields
                VStack(spacing: 15) {
                    
                    // Display Name
                    CustomTextField(
                        title: "Full Name",
                        text: $displayName,
                        placeholder: "Enter your full name"
                    )
                    
                    // Email
                    CustomTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "Enter your email"
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    // Password
                    CustomSecureField(
                        title: "Password",
                        text: $password,
                        placeholder: "Enter your password"
                    )
                    
                    // Confirm Password
                    CustomSecureField(
                        title: "Confirm Password",
                        text: $confirmPassword,
                        placeholder: "Confirm your password"
                    )
                }
                
                // Error Message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Register Button
                Button(action: register) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(authManager.isLoading ? "Creating Account..." : "Create Account")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!isFormValid || authManager.isLoading)
                
                // Login Link
                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        showingLoginView = true
                    }
                    .foregroundColor(.blue)
                }
                .font(.footnote)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingLoginView) {
            LoginView()
        }
    }
    
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func register() {
        authManager.register(email: email, password: password, displayName: displayName)
    }
}

// Custom Text Field Component
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

// Custom Secure Field Component
struct CustomSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            SecureField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}
```

**Login View:**
```swift
import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegistrationView = false
    @State private var showingForgotPasswordAlert = false
    @State private var resetEmail = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Form Fields
                VStack(spacing: 15) {
                    
                    // Email
                    CustomTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "Enter your email"
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    
                    // Password
                    CustomSecureField(
                        title: "Password",
                        text: $password,
                        placeholder: "Enter your password"
                    )
                }
                
                // Forgot Password
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        showingForgotPasswordAlert = true
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
                
                // Error Message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Sign In Button
                Button(action: signIn) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(authManager.isLoading ? "Signing In..." : "Sign In")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!isFormValid || authManager.isLoading)
                
                // Register Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    
                    Button("Create Account") {
                        showingRegistrationView = true
                    }
                    .foregroundColor(.blue)
                }
                .font(.footnote)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingRegistrationView) {
            RegistrationView()
        }
        .alert("Reset Password", isPresented: $showingForgotPasswordAlert) {
            TextField("Email", text: $resetEmail)
            Button("Send Reset Email") {
                authManager.resetPassword(email: resetEmail)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        authManager.signIn(email: email, password: password)
    }
}
```

**🏃‍♂️ Practice Exercise 2.1:**
Build and test the registration and login views with Firebase.

---

## 📚 Part 3: User Session Management (2 hours)

### 3.1 Auth State Persistence

**Main App View:**
```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainAppView()
                    .environmentObject(authManager)
            } else {
                AuthenticationWrapperView()
                    .environmentObject(authManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

struct AuthenticationWrapperView: View {
    @State private var showingLogin = true
    
    var body: some View {
        if showingLogin {
            LoginView()
        } else {
            RegistrationView()
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // User Info
                if let user = authManager.currentUser {
                    VStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Welcome, \(user.displayName ?? "User")!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !user.isEmailVerified {
                            VStack(spacing: 10) {
                                Text("Please verify your email address")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Button("Send Verification Email") {
                                    authManager.sendEmailVerification()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
                
                // Sign Out Button
                Button("Sign Out") {
                    authManager.signOut()
                }
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}
```

### 3.2 Secure Token Storage

**Firebase Token Manager:**
```swift
import Foundation
import Firebase

class FirebaseTokenManager {
    
    static let shared = FirebaseTokenManager()
    private let keychain = KeychainManager()
    
    private init() {}
    
    // Get current Firebase ID token
    func getCurrentIDToken(completion: @escaping (Result<String, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(TokenError.noUser))
            return
        }
        
        user.getIDToken { token, error in
            if let error = error {
                completion(.failure(error))
            } else if let token = token {
                completion(.success(token))
            } else {
                completion(.failure(TokenError.noToken))
            }
        }
    }
    
    // Get Firebase ID token and store securely
    func getAndStoreIDToken(completion: @escaping (Result<String, Error>) -> Void) {
        getCurrentIDToken { [weak self] result in
            switch result {
            case .success(let token):
                // Store token securely
                do {
                    try self?.keychain.store(data: token.data(using: .utf8)!, key: "firebase_id_token")
                    completion(.success(token))
                } catch {
                    completion(.failure(error))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Retrieve stored token
    func getStoredIDToken() -> String? {
        do {
            let tokenData = try keychain.retrieve(key: "firebase_id_token")
            return String(data: tokenData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    // Clear stored tokens
    func clearStoredTokens() {
        try? keychain.delete(key: "firebase_id_token")
    }
    
    // Auto-refresh token if needed
    func refreshTokenIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(TokenError.noUser))
            return
        }
        
        // Force refresh token
        user.getIDToken(forcingRefresh: true) { token, error in
            if let error = error {
                completion(.failure(error))
            } else if let token = token {
                completion(.success(token))
            } else {
                completion(.failure(TokenError.noToken))
            }
        }
    }
}

enum TokenError: Error {
    case noUser
    case noToken
    case refreshFailed
}
```

**🏃‍♂️ Practice Exercise 3.1:**
Implement automatic token refresh in your app.

---

## 📚 Part 4: Error Handling and Validation (1 hour)

### 4.1 Comprehensive Error Handling

```swift
import Foundation
import Firebase

enum AuthenticationValidationError: Error, LocalizedError {
    case emptyEmail
    case invalidEmailFormat
    case emptyPassword
    case weakPassword
    case passwordMismatch
    case emptyDisplayName
    
    var errorDescription: String? {
        switch self {
        case .emptyEmail:
            return "Email address is required"
        case .invalidEmailFormat:
            return "Please enter a valid email address"
        case .emptyPassword:
            return "Password is required"
        case .weakPassword:
            return "Password must be at least 6 characters long"
        case .passwordMismatch:
            return "Passwords do not match"
        case .emptyDisplayName:
            return "Display name is required"
        }
    }
}

class InputValidator {
    
    static func validateRegistration(email: String, password: String, confirmPassword: String, displayName: String) throws {
        
        // Validate display name
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthenticationValidationError.emptyDisplayName
        }
        
        // Validate email
        try validateEmail(email)
        
        // Validate password
        try validatePassword(password)
        
        // Validate password confirmation
        guard password == confirmPassword else {
            throw AuthenticationValidationError.passwordMismatch
        }
    }
    
    static func validateLogin(email: String, password: String) throws {
        try validateEmail(email)
        
        guard !password.isEmpty else {
            throw AuthenticationValidationError.emptyPassword
        }
    }
    
    private static func validateEmail(_ email: String) throws {
        guard !email.isEmpty else {
            throw AuthenticationValidationError.emptyEmail
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            throw AuthenticationValidationError.invalidEmailFormat
        }
    }
    
    private static func validatePassword(_ password: String) throws {
        guard !password.isEmpty else {
            throw AuthenticationValidationError.emptyPassword
        }
        
        guard password.count >= 6 else {
            throw AuthenticationValidationError.weakPassword
        }
    }
}
```

### 4.2 Enhanced Authentication Manager with Validation

```swift
// Enhanced version of AuthenticationManager with validation
extension AuthenticationManager {
    
    func registerWithValidation(email: String, password: String, confirmPassword: String, displayName: String) {
        
        // Clear previous errors
        clearError()
        
        // Validate input
        do {
            try InputValidator.validateRegistration(
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                displayName: displayName
            )
        } catch {
            setError(error.localizedDescription)
            return
        }
        
        // Proceed with registration
        register(email: email, password: password, displayName: displayName)
    }
    
    func signInWithValidation(email: String, password: String) {
        
        // Clear previous errors
        clearError()
        
        // Validate input
        do {
            try InputValidator.validateLogin(email: email, password: password)
        } catch {
            setError(error.localizedDescription)
            return
        }
        
        // Proceed with sign in
        signIn(email: email, password: password)
    }
}
```

**🏃‍♂️ Practice Exercise 4.1:**
Add comprehensive validation to your authentication forms.

---

## ✅ Lesson Completion Checklist

- [ ] Firebase SDK integrated into iOS project
- [ ] Firebase project configured with Authentication
- [ ] Email/password registration implemented
- [ ] Email/password login implemented
- [ ] User session management working
- [ ] Firebase tokens stored securely
- [ ] Comprehensive error handling added
- [ ] Input validation implemented
- [ ] Auth state persistence working

---

## 📝 Assignment

**Create a complete authentication flow that includes:**
1. User registration with email verification
2. User login with proper error handling
3. Password reset functionality
4. Secure token storage and management
5. User profile display after login
6. Sign out functionality

**Bonus:** Add biometric authentication for returning users.

---

## 🔗 Next Lesson

**Lesson 4: Google Sign-In Integration** - We'll add Google Sign-In as a second authentication method.

---

## 📚 Additional Resources

### Firebase Documentation
- [Firebase Auth iOS Guide](https://firebase.google.com/docs/auth/ios/start)
- [Firebase Auth Best Practices](https://firebase.google.com/docs/auth/admin/best-practices)

### Security Resources
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)

### Sample Code
- [Firebase iOS Auth Samples](https://github.com/firebase/quickstart-ios/tree/master/authentication)

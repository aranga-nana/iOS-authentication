import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import LocalAuthentication
import CryptoKit

// MARK: - Authentication Manager

@MainActor
class AuthenticationManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AuthenticationManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var requiresBiometric = false
    
    // MARK: - Private Properties
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let biometricManager = BiometricAuthenticationManager()
    private let keychainManager = KeychainManager()
    private let apiManager = APIManager.shared
    
    // MARK: - Initialization
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Configuration
    func configureAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.handleUserSignIn(user)
                } else {
                    self?.handleUserSignOut()
                }
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await handleFirebaseAuthResult(result, authMethod: .email)
        } catch {
            handleAuthError(error, context: "Email Sign In")
        }
        
        isLoading = false
    }
    
    func signUpWithEmail(_ email: String, password: String, displayName: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name if provided
            if let displayName = displayName {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
            
            await handleFirebaseAuthResult(result, authMethod: .email)
        } catch {
            handleAuthError(error, context: "Email Sign Up")
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
            errorMessage = "Could not find presenting view controller"
            isLoading = false
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationError.googleSignInFailed("Failed to get ID token")
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            await handleFirebaseAuthResult(authResult, authMethod: .google)
            
        } catch {
            handleAuthError(error, context: "Google Sign In")
        }
        
        isLoading = false
    }
    
    // MARK: - Apple Sign-In
    func signInWithApple(_ authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Failed to get Apple ID credential"
            isLoading = false
            return
        }
        
        guard let nonce = generateNonce() else {
            errorMessage = "Failed to generate nonce"
            isLoading = false
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Failed to get ID token from Apple"
            isLoading = false
            return
        }
        
        do {
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            let result = try await Auth.auth().signIn(with: credential)
            await handleFirebaseAuthResult(result, authMethod: .apple)
            
        } catch {
            handleAuthError(error, context: "Apple Sign In")
        }
        
        isLoading = false
    }
    
    // MARK: - Biometric Authentication
    func authenticateWithBiometric() async -> Bool {
        do {
            let success = try await biometricManager.authenticate(reason: "Authenticate to access your account")
            if success {
                requiresBiometric = false
            }
            return success
        } catch {
            errorMessage = "Biometric authentication failed: \(error.localizedDescription)"
            return false
        }
    }
    
    func requireReAuthentication() {
        requiresBiometric = true
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        
        do {
            try Auth.auth().signOut()
            try await GIDSignIn.sharedInstance.signOut()
            
            // Clear stored tokens
            await clearStoredTokens()
            
            isAuthenticated = false
            currentUser = nil
            errorMessage = nil
            requiresBiometric = false
            
        } catch {
            handleAuthError(error, context: "Sign Out")
        }
        
        isLoading = false
    }
    
    // MARK: - Token Management
    func refreshTokenIfNeeded() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        
        do {
            _ = try await firebaseUser.getIDToken(forcingRefresh: true)
            print("✅ Firebase token refreshed successfully")
        } catch {
            print("❌ Error refreshing Firebase token: \(error)")
            handleAuthError(error, context: "Token Refresh")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleFirebaseAuthResult(_ result: AuthDataResult, authMethod: AuthenticationMethod) async {
        do {
            // Get Firebase ID token
            let idToken = try await result.user.getIDToken()
            
            // Register/login with backend
            let backendResult = try await registerOrLoginWithBackend(
                idToken: idToken,
                firebaseUser: result.user,
                authMethod: authMethod
            )
            
            // Store secure tokens
            await storeSecureTokens(
                firebaseToken: idToken,
                backendToken: backendResult.accessToken
            )
            
            // Update user state
            await handleUserSignIn(result.user)
            
        } catch {
            handleAuthError(error, context: "Backend Registration")
        }
    }
    
    private func handleUserSignIn(_ user: FirebaseAuth.User) async {
        currentUser = User(from: user)
        isAuthenticated = true
        
        // Configure biometric requirement if enabled
        if await biometricManager.isBiometricAvailable() {
            let biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
            if biometricEnabled {
                requiresBiometric = true
            }
        }
        
        print("✅ User signed in: \(user.uid)")
    }
    
    private func handleUserSignOut() {
        currentUser = nil
        isAuthenticated = false
        requiresBiometric = false
        print("👋 User signed out")
    }
    
    private func registerOrLoginWithBackend(
        idToken: String,
        firebaseUser: FirebaseAuth.User,
        authMethod: AuthenticationMethod
    ) async throws -> BackendAuthResponse {
        
        // First try to register (for new users)
        do {
            return try await apiManager.registerUser(
                idToken: idToken,
                userData: UserRegistrationData(
                    displayName: firebaseUser.displayName,
                    profilePicture: firebaseUser.photoURL?.absoluteString,
                    authMethod: authMethod.rawValue
                )
            )
        } catch APIError.userAlreadyExists {
            // User already exists, try login instead
            return try await apiManager.loginUser(idToken: idToken)
        }
    }
    
    private func storeSecureTokens(firebaseToken: String, backendToken: String) async {
        do {
            try keychainManager.store(firebaseToken, for: .firebaseToken)
            try keychainManager.store(backendToken, for: .backendToken)
            print("✅ Tokens stored securely")
        } catch {
            print("❌ Error storing tokens: \(error)")
        }
    }
    
    private func clearStoredTokens() async {
        do {
            try keychainManager.delete(.firebaseToken)
            try keychainManager.delete(.backendToken)
            print("✅ Stored tokens cleared")
        } catch {
            print("❌ Error clearing tokens: \(error)")
        }
    }
    
    private func handleAuthError(_ error: Error, context: String) {
        print("❌ Authentication error in \(context): \(error)")
        
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .networkError:
                errorMessage = "Network error. Please check your connection."
            case .userNotFound:
                errorMessage = "Account not found. Please check your credentials."
            case .wrongPassword:
                errorMessage = "Invalid password. Please try again."
            case .emailAlreadyInUse:
                errorMessage = "Email is already registered. Please sign in instead."
            case .weakPassword:
                errorMessage = "Password is too weak. Please choose a stronger password."
            case .invalidEmail:
                errorMessage = "Invalid email address format."
            default:
                errorMessage = "Authentication failed. Please try again."
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    private func generateNonce() -> String? {
        let nonce = UUID().uuidString
        return SHA256.hash(data: Data(nonce.utf8)).compactMap {
            String(format: "%02x", $0)
        }.joined()
    }
    
    deinit {
        guard let handle = authStateHandle else { return }
        Auth.auth().removeStateDidChangeListener(handle)
    }
}

// MARK: - Supporting Types

enum AuthenticationMethod: String, CaseIterable {
    case email = "email"
    case google = "google"
    case apple = "apple"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .google: return "Google"
        case .apple: return "Apple"
        }
    }
}

enum AuthenticationError: LocalizedError {
    case googleSignInFailed(String)
    case appleSignInFailed(String)
    case biometricNotAvailable
    case biometricAuthenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .appleSignInFailed(let message):
            return "Apple Sign-In failed: \(message)"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        }
    }
}

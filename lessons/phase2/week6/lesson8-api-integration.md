# Lesson 8: API Integration with iOS App
**Phase 2, Week 6** | **Duration:** 6-8 hours | **Difficulty:** Advanced

**Prerequisites**: AWS Lambda backend setup, iOS authentication views, completed Phase 2 Week 1-5 lessons

## 🎯 Learning Objectives
- Integrate iOS app with AWS Lambda backend APIs
- Implement secure API communication with proper error handling
- Create network managers for authentication operations
- Handle authentication tokens and session management
- Implement offline capabilities and data synchronization

---

## 📚 Theory Overview

### API Integration Architecture
```
iOS App → URLSession → API Gateway → Lambda Functions → DynamoDB
    ↓                                    ↓
Keychain Storage                 CloudWatch Logs
```

### Key Concepts:
- **RESTful API Communication**: HTTP methods, status codes, JSON payloads
- **Authentication Headers**: Bearer tokens, API keys
- **Error Handling**: Network errors, API errors, validation errors
- **Data Models**: Codable protocols, JSON serialization
- **Security**: HTTPS, token storage, request validation

---

## 🛠 Implementation Guide

### Step 1: Network Layer Foundation

#### 1.1 API Configuration
```swift
// Network/APIConfig.swift
import Foundation

struct APIConfig {
    static let baseURL = "https://your-api-id.execute-api.us-east-1.amazonaws.com/prod"
    static let timeout: TimeInterval = 30.0
    
    // API Endpoints
    enum Endpoints {
        case register
        case login
        case validate
        case profile
        case updateProfile
        
        var path: String {
            switch self {
            case .register:
                return "/auth/register"
            case .login:
                return "/auth/login"
            case .validate:
                return "/auth/validate"
            case .profile:
                return "/auth/profile"
            case .updateProfile:
                return "/auth/profile"
            }
        }
        
        var url: URL {
            return URL(string: APIConfig.baseURL + path)!
        }
    }
    
    // HTTP Methods
    enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
    }
    
    // Content Types
    enum ContentType: String {
        case json = "application/json"
        case formURLEncoded = "application/x-www-form-urlencoded"
    }
}
```

#### 1.2 Data Models
```swift
// Models/AuthModels.swift
import Foundation

// MARK: - Request Models
struct RegisterRequest: Codable {
    let email: String
    let password: String?
    let displayName: String
    let authProvider: String
    let firebaseUid: String?
    
    init(email: String, password: String? = nil, displayName: String, authProvider: String = "email", firebaseUid: String? = nil) {
        self.email = email
        self.password = password
        self.displayName = displayName
        self.authProvider = authProvider
        self.firebaseUid = firebaseUid
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String?
    let firebaseUid: String?
    let authProvider: String
    
    init(email: String, password: String? = nil, firebaseUid: String? = nil, authProvider: String = "email") {
        self.email = email
        self.password = password
        self.firebaseUid = firebaseUid
        self.authProvider = authProvider
    }
}

// MARK: - Response Models
struct User: Codable, Identifiable {
    let userId: String
    let email: String
    let displayName: String
    let authProvider: String
    let firebaseUid: String?
    let createdAt: String
    let updatedAt: String
    let isActive: Bool
    let profile: UserProfile
    let lastLoginAt: String?
    
    var id: String { userId }
}

struct UserProfile: Codable {
    let firstName: String
    let lastName: String
    let photoURL: String
    let phoneNumber: String
    
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

struct UserSession: Codable {
    let sessionId: String
    let expiresAt: TimeInterval
    
    var isExpired: Bool {
        return Date().timeIntervalSince1970 > expiresAt
    }
    
    var expirationDate: Date {
        return Date(timeIntervalSince1970: expiresAt)
    }
}

struct AuthResponse: Codable {
    let message: String
    let user: User
    let token: String?
    let session: UserSession?
}

struct APIError: Codable {
    let error: String
    let message: String?
    let details: String?
    
    var localizedDescription: String {
        return message ?? error
    }
}
```

### Step 2: Network Manager Implementation

#### 2.1 Base Network Manager
```swift
// Network/NetworkManager.swift
import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isConnected = true
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        
        // Monitor network connectivity
        monitorNetworkConnectivity()
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        endpoint: APIConfig.Endpoints,
        method: APIConfig.HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, APINetworkError> {
        
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Set default headers
        request.setValue(APIConfig.ContentType.json.rawValue, forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.ContentType.json.rawValue, forHTTPHeaderField: "Accept")
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APINetworkError.invalidResponse
                }
                
                // Log response for debugging
                self.logResponse(data: data, response: httpResponse, request: request)
                
                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 400:
                    let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    throw APINetworkError.badRequest(apiError?.localizedDescription ?? "Bad request")
                case 401:
                    let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    throw APINetworkError.unauthorized(apiError?.localizedDescription ?? "Unauthorized")
                case 403:
                    let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    throw APINetworkError.forbidden(apiError?.localizedDescription ?? "Forbidden")
                case 404:
                    throw APINetworkError.notFound
                case 409:
                    let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    throw APINetworkError.conflict(apiError?.localizedDescription ?? "Conflict")
                case 429:
                    throw APINetworkError.rateLimited
                case 500...599:
                    let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    throw APINetworkError.serverError(apiError?.localizedDescription ?? "Server error")
                default:
                    throw APINetworkError.unknown(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> APINetworkError in
                if let apiError = error as? APINetworkError {
                    return apiError
                } else if error is DecodingError {
                    return APINetworkError.decodingError(error.localizedDescription)
                } else {
                    return APINetworkError.networkError(error.localizedDescription)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    private func logResponse(data: Data, response: HTTPURLResponse, request: URLRequest) {
        #if DEBUG
        print("🌐 API Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        print("📊 Response Status: \(response.statusCode)")
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Response Body: \(jsonString)")
        }
        #endif
    }
    
    private func monitorNetworkConnectivity() {
        // Simple connectivity check - in production, use Network framework
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnectivity()
            }
            .store(in: &cancellables)
    }
    
    private func checkConnectivity() {
        // Implement proper network monitoring
        // For now, assume connected
        self.isConnected = true
    }
}

// MARK: - API Network Errors
enum APINetworkError: Error, LocalizedError {
    case networkError(String)
    case invalidResponse
    case decodingError(String)
    case badRequest(String)
    case unauthorized(String)
    case forbidden(String)
    case notFound
    case conflict(String)
    case rateLimited
    case serverError(String)
    case unknown(Int)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let message):
            return "Data parsing error: \(message)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .forbidden(let message):
            return "Forbidden: \(message)"
        case .notFound:
            return "Resource not found"
        case .conflict(let message):
            return "Conflict: \(message)"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let code):
            return "Unknown error (Code: \(code))"
        }
    }
}
```

#### 2.2 Authentication API Manager
```swift
// Network/AuthAPIManager.swift
import Foundation
import Combine

class AuthAPIManager: ObservableObject {
    private let networkManager = NetworkManager.shared
    private let tokenStorage = TokenStorage.shared
    
    // MARK: - User Registration
    func register(
        email: String,
        password: String? = nil,
        displayName: String,
        authProvider: String = "email",
        firebaseUid: String? = nil
    ) -> AnyPublisher<AuthResponse, APINetworkError> {
        
        guard isValidEmail(email) else {
            return Fail(error: APINetworkError.badRequest("Invalid email format"))
                .eraseToAnyPublisher()
        }
        
        if authProvider == "email" && (password == nil || !isValidPassword(password!)) {
            return Fail(error: APINetworkError.badRequest("Password must be at least 8 characters with uppercase, lowercase, number, and special character"))
                .eraseToAnyPublisher()
        }
        
        let request = RegisterRequest(
            email: email,
            password: password,
            displayName: displayName,
            authProvider: authProvider,
            firebaseUid: firebaseUid
        )
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            return Fail(error: APINetworkError.badRequest("Invalid request data"))
                .eraseToAnyPublisher()
        }
        
        return networkManager.request(
            endpoint: .register,
            method: .POST,
            body: requestData,
            responseType: AuthResponse.self
        )
        .handleEvents(receiveOutput: { [weak self] response in
            // Store authentication data on successful registration
            if let token = response.token {
                self?.tokenStorage.storeToken(token)
            }
            if let session = response.session {
                self?.tokenStorage.storeSession(session)
            }
            self?.tokenStorage.storeUser(response.user)
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - User Login
    func login(
        email: String,
        password: String? = nil,
        firebaseUid: String? = nil,
        authProvider: String = "email"
    ) -> AnyPublisher<AuthResponse, APINetworkError> {
        
        guard isValidEmail(email) else {
            return Fail(error: APINetworkError.badRequest("Invalid email format"))
                .eraseToAnyPublisher()
        }
        
        let request = LoginRequest(
            email: email,
            password: password,
            firebaseUid: firebaseUid,
            authProvider: authProvider
        )
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            return Fail(error: APINetworkError.badRequest("Invalid request data"))
                .eraseToAnyPublisher()
        }
        
        return networkManager.request(
            endpoint: .login,
            method: .POST,
            body: requestData,
            responseType: AuthResponse.self
        )
        .handleEvents(receiveOutput: { [weak self] response in
            // Store authentication data on successful login
            if let token = response.token {
                self?.tokenStorage.storeToken(token)
            }
            if let session = response.session {
                self?.tokenStorage.storeSession(session)
            }
            self?.tokenStorage.storeUser(response.user)
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - Token Validation
    func validateToken() -> AnyPublisher<AuthResponse, APINetworkError> {
        guard let token = tokenStorage.getToken() else {
            return Fail(error: APINetworkError.unauthorized("No authentication token found"))
                .eraseToAnyPublisher()
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        
        return networkManager.request(
            endpoint: .validate,
            method: .GET,
            headers: headers,
            responseType: AuthResponse.self
        )
        .handleEvents(receiveOutput: { [weak self] response in
            // Update stored user data
            self?.tokenStorage.storeUser(response.user)
            if let session = response.session {
                self?.tokenStorage.storeSession(session)
            }
        })
        .catch { [weak self] error -> AnyPublisher<AuthResponse, APINetworkError> in
            // Clear invalid tokens
            if case APINetworkError.unauthorized = error {
                self?.tokenStorage.clearAll()
            }
            return Fail(error: error).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Get User Profile
    func getUserProfile() -> AnyPublisher<AuthResponse, APINetworkError> {
        guard let token = tokenStorage.getToken() else {
            return Fail(error: APINetworkError.unauthorized("No authentication token found"))
                .eraseToAnyPublisher()
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        
        return networkManager.request(
            endpoint: .profile,
            method: .GET,
            headers: headers,
            responseType: AuthResponse.self
        )
    }
    
    // MARK: - Logout
    func logout() -> AnyPublisher<Void, Never> {
        return Future<Void, Never> { [weak self] promise in
            // Clear all stored authentication data
            self?.tokenStorage.clearAll()
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Validation Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters, with uppercase, lowercase, number, and special character
        let passwordRegex = #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$"#
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }
}
```

### Step 3: Token Storage Implementation

#### 3.1 Secure Token Storage
```swift
// Storage/TokenStorage.swift
import Foundation
import Security

class TokenStorage: ObservableObject {
    static let shared = TokenStorage()
    
    private let service = "com.yourapp.auth"
    private let userDefaultsKey = "currentUser"
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        loadStoredUser()
        checkAuthenticationStatus()
    }
    
    // MARK: - Token Management
    func storeToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token",
            kSecValueData as String: data
        ]
        
        // Delete existing token
        SecItemDelete(query as CFDictionary)
        
        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error storing token: \(status)")
        }
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Session Management
    func storeSession(_ session: UserSession) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(session) {
            UserDefaults.standard.set(data, forKey: "user_session")
        }
    }
    
    func getSession() -> UserSession? {
        guard let data = UserDefaults.standard.data(forKey: "user_session") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(UserSession.self, from: data)
    }
    
    func clearSession() {
        UserDefaults.standard.removeObject(forKey: "user_session")
    }
    
    // MARK: - User Data Management
    func storeUser(_ user: User) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = true
            }
        }
    }
    
    func getUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(User.self, from: data)
    }
    
    private func loadStoredUser() {
        currentUser = getUser()
    }
    
    // MARK: - Authentication Status
    func checkAuthenticationStatus() {
        let hasToken = getToken() != nil
        let hasUser = currentUser != nil
        let sessionValid = getSession()?.isExpired == false
        
        DispatchQueue.main.async {
            self.isAuthenticated = hasToken && hasUser && sessionValid
        }
    }
    
    // MARK: - Clear All Data
    func clearAll() {
        clearToken()
        clearSession()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
}
```

### Step 4: Authentication Manager Integration

#### 4.1 Enhanced Authentication Manager
```swift
// Managers/AuthenticationManager.swift
import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authAPI = AuthAPIManager()
    private let tokenStorage = TokenStorage.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        checkExistingAuthentication()
    }
    
    private func setupBindings() {
        tokenStorage.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        tokenStorage.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Registration
    func register(email: String, password: String, displayName: String) {
        isLoading = true
        errorMessage = ""
        
        authAPI.register(
            email: email,
            password: password,
            displayName: displayName
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] response in
                print("Registration successful: \(response.user.email)")
                // Authentication state will be updated through TokenStorage bindings
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Login
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        authAPI.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("Login successful: \(response.user.email)")
                    // Authentication state will be updated through TokenStorage bindings
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Google Sign-In Integration
    func handleGoogleSignIn(user: User, token: String, session: UserSession) {
        isLoading = true
        errorMessage = ""
        
        // Store authentication data
        tokenStorage.storeToken(token)
        tokenStorage.storeSession(session)
        tokenStorage.storeUser(user)
        
        // Sync with backend
        authAPI.register(
            email: user.email,
            displayName: user.displayName,
            authProvider: "google",
            firebaseUid: user.firebaseUid
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // If user already exists, that's OK for Google sign-in
                    if !error.localizedDescription.contains("already exists") {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            },
            receiveValue: { response in
                print("Google user synced with backend: \(response.user.email)")
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Token Validation
    func validateToken() {
        guard tokenStorage.getToken() != nil else {
            logout()
            return
        }
        
        authAPI.validateToken()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Token validation failed: \(error)")
                        self?.logout()
                    }
                },
                receiveValue: { response in
                    print("Token validated successfully")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Logout
    func logout() {
        isLoading = true
        
        authAPI.logout()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveValue: { [weak self] in
                    self?.isLoading = false
                    print("User logged out successfully")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Check Existing Authentication
    private func checkExistingAuthentication() {
        tokenStorage.checkAuthenticationStatus()
        
        if tokenStorage.isAuthenticated {
            validateToken()
        }
    }
    
    // MARK: - Refresh Authentication
    func refreshAuthentication() {
        if tokenStorage.isAuthenticated {
            validateToken()
        }
    }
}
```

### Step 5: SwiftUI Integration

#### 5.1 Updated Authentication View
```swift
// Views/AuthenticationView.swift
import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var googleSignInManager = GoogleSignInManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                AuthHeaderView()
                
                // Loading State
                if authManager.isLoading || googleSignInManager.isLoading {
                    LoadingView()
                } else {
                    // Authentication Options
                    VStack(spacing: 16) {
                        GoogleSignInButton(googleSignInManager: googleSignInManager)
                        
                        DividerView()
                        
                        NavigationLink(destination: EmailAuthView(authManager: authManager)) {
                            EmailSignInButton()
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                TermsAndPrivacyView()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: authManager.errorMessage) { errorMessage in
                if !errorMessage.isEmpty {
                    alertMessage = errorMessage
                    showingAlert = true
                }
            }
            .onChange(of: googleSignInManager.errorMessage) { errorMessage in
                if !errorMessage.isEmpty {
                    alertMessage = errorMessage
                    showingAlert = true
                }
            }
            .onReceive(googleSignInManager.$isSignedIn) { isSignedIn in
                if isSignedIn, let user = googleSignInManager.currentUser {
                    // Handle Google sign-in success
                    authManager.handleGoogleSignIn(
                        user: user,
                        token: googleSignInManager.authToken ?? "",
                        session: googleSignInManager.userSession ?? UserSession(sessionId: UUID().uuidString, expiresAt: Date().addingTimeInterval(86400).timeIntervalSince1970)
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $authManager.isAuthenticated) {
            MainAppView()
        }
    }
}

// MARK: - Supporting Views
struct AuthHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 40)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Signing in...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
}

struct DividerView: View {
    var body: some View {
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
    }
}

struct EmailSignInButton: View {
    var body: some View {
        HStack {
            Image(systemName: "envelope.fill")
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

struct TermsAndPrivacyView: View {
    var body: some View {
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
}
```

#### 5.2 Email Authentication View
```swift
// Views/EmailAuthView.swift
import SwiftUI

struct EmailAuthView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isLoginMode = true
    @State private var showingAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text(isLoginMode ? "Sign In" : "Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(isLoginMode ? "Welcome back!" : "Join us today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 16) {
                    // Email Field
                    CustomTextField(
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        icon: "envelope"
                    )
                    
                    // Display Name Field (Register only)
                    if !isLoginMode {
                        CustomTextField(
                            placeholder: "Display Name",
                            text: $displayName,
                            icon: "person"
                        )
                    }
                    
                    // Password Field
                    SecureTextField(
                        placeholder: "Password",
                        text: $password
                    )
                    
                    // Confirm Password Field (Register only)
                    if !isLoginMode {
                        SecureTextField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword
                        )
                    }
                    
                    // Submit Button
                    Button(action: submitForm) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(isLoginMode ? "Sign In" : "Create Account")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                }
                .padding(.horizontal, 20)
                
                // Mode Toggle
                HStack {
                    Text(isLoginMode ? "Don't have an account?" : "Already have an account?")
                        .foregroundColor(.secondary)
                    
                    Button(isLoginMode ? "Sign Up" : "Sign In") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLoginMode.toggle()
                            clearForm()
                        }
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
                .padding(.top, 16)
                
                Spacer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(authManager.errorMessage)
        }
        .onChange(of: authManager.errorMessage) { errorMessage in
            if !errorMessage.isEmpty {
                showingAlert = true
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   !confirmPassword.isEmpty && 
                   !displayName.isEmpty && 
                   password == confirmPassword &&
                   isValidEmail(email) &&
                   isValidPassword(password)
        }
    }
    
    private func submitForm() {
        if isLoginMode {
            authManager.login(email: email, password: password)
        } else {
            authManager.register(email: email, password: password, displayName: displayName)
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8 &&
               password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
               password.rangeOfCharacter(from: .lowercaseLetters) != nil &&
               password.rangeOfCharacter(from: .decimalDigits) != nil &&
               password.rangeOfCharacter(from: CharacterSet(charactersIn: "@$!%*?&")) != nil
    }
}

// MARK: - Custom UI Components
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SecureTextField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true
    
    var body: some View {
        HStack {
            Image(systemName: "lock")
                .foregroundColor(.gray)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
```

---

## 🧪 Testing Implementation

### Step 6: Unit Tests
```swift
// Tests/AuthAPIManagerTests.swift
import XCTest
import Combine
@testable import YourApp

class AuthAPIManagerTests: XCTestCase {
    var sut: AuthAPIManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = AuthAPIManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testRegisterWithValidData() {
        let expectation = XCTestExpectation(description: "Register user")
        
        sut.register(
            email: "test@example.com",
            password: "Password123!",
            displayName: "Test User"
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Registration failed: \(error)")
                }
            },
            receiveValue: { response in
                XCTAssertEqual(response.user.email, "test@example.com")
                XCTAssertEqual(response.user.displayName, "Test User")
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRegisterWithInvalidEmail() {
        let expectation = XCTestExpectation(description: "Invalid email error")
        
        sut.register(
            email: "invalid-email",
            password: "Password123!",
            displayName: "Test User"
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTAssertTrue(error.localizedDescription.contains("Invalid email"))
                    expectation.fulfill()
                }
            },
            receiveValue: { _ in
                XCTFail("Should have failed with invalid email")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
}
```

---

## 📝 Practice Exercises

### Exercise 1: Basic API Integration (3 hours)
1. Set up network manager and API models
2. Implement registration API call
3. Test with mock data and real API
4. Handle basic error scenarios

### Exercise 2: Authentication Flow (4 hours)
1. Integrate API calls with SwiftUI views
2. Implement token storage and retrieval
3. Add loading states and error handling
4. Test complete authentication flow

### Exercise 3: Advanced Features (6 hours)
1. Add token validation and refresh
2. Implement offline capabilities
3. Add network connectivity monitoring
4. Create comprehensive error handling

---

## ✅ Lesson Completion Checklist

- [ ] Understand RESTful API communication patterns
- [ ] Implement network manager with proper error handling
- [ ] Create data models with Codable protocol
- [ ] Set up secure token storage using Keychain
- [ ] Integrate API calls with authentication managers
- [ ] Update SwiftUI views with API integration
- [ ] Add loading states and error handling
- [ ] Implement token validation and refresh
- [ ] Test authentication flow end-to-end
- [ ] Handle network connectivity scenarios
- [ ] Write unit tests for API managers
- [ ] Complete practice exercises

**Estimated Time to Complete**: 6-8 hours  
**Next Lesson**: Security Best Practices

---

*Great job integrating your iOS app with the backend! Next, we'll focus on security best practices to ensure your authentication system is production-ready.*

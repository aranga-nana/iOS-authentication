# 📱 Lesson 1: iOS Development Basics

> **Phase 1, Week 1 - iOS Development Fundamentals**  
> **Duration**: 8 hours | **Level**: Beginner  
> **Prerequisites**: Basic programming knowledge

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Set up Xcode development environment
- Understand Swift fundamentals essential for iOS authentication
- Create your first iOS app with SwiftUI and UIKit
- Understand iOS app lifecycle and structure

---

## 📚 Part 1: Xcode Setup and Interface (2 hours)

### 1.1 Installing Xcode

**Step 1: Download Xcode**
```bash
# Option 1: App Store (Recommended)
# Search for "Xcode" in Mac App Store and install

# Option 2: Developer Portal
# Visit https://developer.apple.com/xcode/
# Download and install the latest version
```

**Step 2: Verify Installation**
```bash
# Check Xcode version
xcodebuild -version

# Expected output:
# Xcode 15.0
# Build version 15A240d
```

### 1.2 Xcode Interface Overview

**Key Components:**
- **Navigator Area**: Project files, search, issues
- **Editor Area**: Code editing and Interface Builder
- **Inspector Area**: Properties and attributes
- **Debug Area**: Console and variables
- **Toolbar**: Run, stop, and scheme selection

**🏃‍♂️ Practice Exercise 1.1:**
1. Open Xcode
2. Create a new project: File → New → Project
3. Choose iOS → App
4. Explore the interface components mentioned above

---

## 📚 Part 2: Swift Fundamentals (3 hours)

### 2.1 Variables and Optionals

```swift
// Variables and Constants
var userName: String = "John Doe"      // Mutable
let apiKey: String = "your-api-key"    // Immutable

// Optionals - Essential for authentication
var userEmail: String? = nil           // Can be nil
let userID: String? = "user123"        // Optional with value

// Unwrapping Optionals
if let email = userEmail {
    print("User email: \(email)")
} else {
    print("No email provided")
}

// Nil Coalescing
let displayName = userName ?? "Anonymous User"
```

### 2.2 Closures (Essential for Authentication Callbacks)

```swift
// Basic closure syntax
let loginCompletion: (Bool, Error?) -> Void = { success, error in
    if success {
        print("Login successful")
    } else {
        print("Login failed: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// Trailing closure syntax (common in Firebase)
Auth.auth().signIn(withEmail: email, password: password) { result, error in
    // Handle authentication result
    guard let user = result?.user, error == nil else {
        print("Authentication failed: \(error!.localizedDescription)")
        return
    }
    print("Successfully signed in user: \(user.uid)")
}
```

### 2.3 Protocols (Used extensively in authentication)

```swift
// Authentication protocol
protocol AuthenticationDelegate: AnyObject {
    func authenticationDidSucceed(user: User)
    func authenticationDidFail(error: Error)
}

// Implementation
class LoginViewController: UIViewController, AuthenticationDelegate {
    
    func authenticationDidSucceed(user: User) {
        DispatchQueue.main.async {
            // Update UI on main thread
            self.navigateToMainApp()
        }
    }
    
    func authenticationDidFail(error: Error) {
        DispatchQueue.main.async {
            self.showErrorAlert(message: error.localizedDescription)
        }
    }
}
```

**🏃‍♂️ Practice Exercise 2.1:**
Create a playground with these Swift concepts:

```swift
import UIKit

// Practice optionals
var authToken: String? = nil

func simulateLogin(success: Bool) {
    if success {
        authToken = "abc123token"
    }
}

// Test the function
simulateLogin(success: true)
if let token = authToken {
    print("Authentication token: \(token)")
}

// Practice closures
func performLogin(completion: @escaping (Bool) -> Void) {
    // Simulate async operation
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        completion(true)
    }
}

performLogin { success in
    print("Login result: \(success)")
}
```

---

## 📚 Part 3: SwiftUI vs UIKit Decision Matrix (2 hours)

### 3.1 SwiftUI Approach

**When to use SwiftUI:**
- New projects (iOS 13+)
- Rapid prototyping
- Cross-platform development (iOS, macOS, watchOS)
- Declarative UI preferred

**SwiftUI Authentication View Example:**

```swift
import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Logo
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Email Field
            VStack(alignment: .leading) {
                Text("Email")
                    .font(.headline)
                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password Field
            VStack(alignment: .leading) {
                Text("Password")
                    .font(.headline)
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Login Button
            Button(action: performLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Signing In..." : "Sign In")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            
            Spacer()
        }
        .padding()
        .alert("Authentication", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func performLogin() {
        isLoading = true
        
        // Simulate authentication process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            
            if email.contains("@") && password.count >= 6 {
                alertMessage = "Login successful!"
            } else {
                alertMessage = "Invalid credentials. Please try again."
            }
            showAlert = true
        }
    }
}

// Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
```

### 3.2 UIKit Approach

**When to use UIKit:**
- Supporting iOS 12 and below
- Complex custom UI requirements
- Team familiarity with UIKit
- Integration with existing UIKit codebase

**UIKit Authentication View Controller:**

```swift
import UIKit

class LoginViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    private var isLoading: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Configure logo
        logoImageView.image = UIImage(systemName: "lock.shield")
        logoImageView.tintColor = .systemBlue
        
        // Configure title
        titleLabel.text = "Welcome Back"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        
        // Configure text fields
        emailTextField.placeholder = "Enter your email"
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.borderStyle = .roundedRect
        
        passwordTextField.placeholder = "Enter your password"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.borderStyle = .roundedRect
        
        // Configure login button
        loginButton.setTitle("Sign In", for: .normal)
        loginButton.backgroundColor = .systemBlue
        loginButton.layer.cornerRadius = 10
        loginButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        
        // Add targets
        emailTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        updateUI()
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            let hasValidInput = !(self.emailTextField.text?.isEmpty ?? true) && 
                              !(self.passwordTextField.text?.isEmpty ?? true)
            
            self.loginButton.isEnabled = hasValidInput && !self.isLoading
            self.loginButton.alpha = self.loginButton.isEnabled ? 1.0 : 0.6
            
            if self.isLoading {
                self.activityIndicator.startAnimating()
                self.loginButton.setTitle("Signing In...", for: .normal)
            } else {
                self.activityIndicator.stopAnimating()
                self.loginButton.setTitle("Sign In", for: .normal)
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        performLogin()
    }
    
    @objc private func textFieldDidChange() {
        updateUI()
    }
    
    private func performLogin() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields")
            return
        }
        
        isLoading = true
        
        // Simulate authentication process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            
            if email.contains("@") && password.count >= 6 {
                self.showAlert(title: "Success", message: "Login successful!")
            } else {
                self.showAlert(title: "Error", message: "Invalid credentials. Please try again.")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

**🏃‍♂️ Practice Exercise 3.1:**
Create both SwiftUI and UIKit versions of a simple login screen and compare the approaches.

---

## 📚 Part 4: iOS App Lifecycle and Structure (1 hour)

### 4.1 App Lifecycle States

```swift
import UIKit

// AppDelegate.swift - Traditional lifecycle
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // App finished launching
        print("App did finish launching")
        
        // Initialize authentication state
        checkAuthenticationStatus()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // App became active
        print("App did become active")
        
        // Refresh authentication token if needed
        refreshAuthTokenIfNeeded()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // App will resign active
        print("App will resign active")
        
        // Save any pending authentication data
        saveAuthenticationState()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // App entered background
        print("App did enter background")
        
        // Clear sensitive data from memory
        clearSensitiveData()
    }
    
    // MARK: - Authentication Helpers
    private func checkAuthenticationStatus() {
        // Check if user is already authenticated
        if let _ = AuthenticationManager.shared.currentUser {
            // User is authenticated, show main app
            print("User already authenticated")
        } else {
            // Show login screen
            print("User needs to authenticate")
        }
    }
    
    private func refreshAuthTokenIfNeeded() {
        AuthenticationManager.shared.refreshTokenIfNeeded { result in
            switch result {
            case .success:
                print("Token refreshed successfully")
            case .failure(let error):
                print("Token refresh failed: \(error)")
            }
        }
    }
    
    private func saveAuthenticationState() {
        AuthenticationManager.shared.saveCurrentState()
    }
    
    private func clearSensitiveData() {
        // Clear any sensitive data from memory
        // Keep authentication tokens secure
        AuthenticationManager.shared.clearTemporaryData()
    }
}

// SceneDelegate.swift - Modern lifecycle (iOS 13+)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        // Determine initial view controller based on authentication state
        let initialViewController = determineInitialViewController()
        window?.rootViewController = initialViewController
        window?.makeKeyAndVisible()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Scene became active
        AuthenticationManager.shared.refreshTokenIfNeeded { _ in }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Scene will resign active
        AuthenticationManager.shared.saveCurrentState()
    }
    
    private func determineInitialViewController() -> UIViewController {
        if AuthenticationManager.shared.isUserAuthenticated {
            // Show main app
            return MainTabBarController()
        } else {
            // Show authentication flow
            return AuthenticationNavigationController()
        }
    }
}
```

### 4.2 SwiftUI App Structure

```swift
import SwiftUI

@main
struct AuthApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .onAppear {
                    authManager.checkAuthenticationStatus()
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

// Authentication Manager for SwiftUI
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    func checkAuthenticationStatus() {
        // Check authentication status
        // Update isAuthenticated accordingly
    }
}
```

**🏃‍♂️ Practice Exercise 4.1:**
Create a simple app that demonstrates the lifecycle methods and authentication state management.

---

## 🎯 Hands-On Project: "Hello Auth World"

Create a complete iOS project that demonstrates all concepts learned:

### Project Structure:
```
HelloAuthWorld/
├── HelloAuthWorld/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   └── HelloAuthWorldApp.swift (SwiftUI)
│   ├── Views/
│   │   ├── SwiftUI/
│   │   │   ├── LoginView.swift
│   │   │   └── ContentView.swift
│   │   └── UIKit/
│   │       └── LoginViewController.swift
│   ├── Models/
│   │   └── User.swift
│   └── Managers/
│       └── AuthenticationManager.swift
```

### Implementation Steps:

1. **Create new Xcode project**
2. **Implement User model**
3. **Create AuthenticationManager**
4. **Build SwiftUI login view**
5. **Build UIKit login view controller**
6. **Test both approaches**

---

## ✅ Lesson Completion Checklist

- [ ] Xcode installed and configured
- [ ] Understanding of Swift optionals, closures, and protocols
- [ ] Created SwiftUI login view
- [ ] Created UIKit login view controller
- [ ] Understanding of iOS app lifecycle
- [ ] Completed "Hello Auth World" project
- [ ] Can explain difference between SwiftUI and UIKit

---

## 📝 Assignment

**Create a simple authentication app that:**
1. Uses either SwiftUI or UIKit (your choice)
2. Has email and password fields
3. Validates input (email format, password length)
4. Shows loading state during "authentication"
5. Displays success/error messages
6. Implements proper app lifecycle methods

**Submit**: Screenshots of your app and code snippets showing key implementations.

---

## 🔗 Next Lesson

**Lesson 2: Authentication Fundamentals** - We'll dive deep into authentication concepts, token-based authentication, and OAuth 2.0 flows.

---

## 📚 Additional Resources

### Books
- "iOS Development with Swift" by Apple
- "SwiftUI by Tutorials" by raywenderlich.com

### Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Language Guide](https://docs.swift.org/swift-book/)

### Video Tutorials
- WWDC Sessions on iOS Development
- Stanford CS193p iOS Development Course

### Practice Platforms
- Swift Playgrounds (iPad/Mac)
- LeetCode Swift Problems
- HackerRank Swift Challenges

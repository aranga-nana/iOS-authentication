# Lesson 2: SwiftUI vs UIKit for Authentication
**Phase 2, Week 1** | **Duration:** 4-6 hours | **Difficulty:** Intermediate

## 🎯 Learning Objectives
By the end of this lesson, you will:
- Understand the key differences between SwiftUI and UIKit
- Know when to choose SwiftUI vs UIKit for authentication
- Implement the same authentication screen in both frameworks
- Understand the migration path between frameworks
- Make informed architectural decisions

## 📋 Prerequisites
- Completed Lesson 1: iOS UI Fundamentals
- Basic understanding of both SwiftUI and UIKit concepts
- Xcode project from previous lesson

## ⚖️ SwiftUI vs UIKit: Decision Matrix

### 🟢 Choose SwiftUI When:
- **New Projects**: Starting fresh with iOS 13+ target
- **Rapid Prototyping**: Need to build UI quickly
- **Simple to Medium Complexity**: Standard authentication flows
- **Cross-Platform**: Planning macOS, watchOS, tvOS versions
- **Team Familiarity**: Team is comfortable with declarative UI
- **Modern Stack**: Using latest iOS features and APIs

### 🟡 Choose UIKit When:
- **Legacy Support**: Need iOS 12 or earlier support
- **Complex Animations**: Advanced custom animations required
- **Fine-Grained Control**: Need precise layout control
- **Large Existing Codebase**: Significant UIKit investment
- **Third-Party Dependencies**: Libraries primarily UIKit-based
- **Performance Critical**: Maximum performance required

### 🔄 Hybrid Approach:
- Use UIKit for complex screens, SwiftUI for simple ones
- Embed SwiftUI views in UIKit using `UIHostingController`
- Embed UIKit views in SwiftUI using `UIViewRepresentable`

## 🔍 Side-by-Side Comparison

### 1. Login Screen Architecture

#### SwiftUI Approach
```swift
// SwiftUI: Declarative and State-Driven
struct LoginViewSwiftUI: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // UI declares what it should look like
            TextField("Email", text: $viewModel.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Sign In") {
                viewModel.signIn()
            }
            .disabled(viewModel.isLoading)
            
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .padding()
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// ViewModel (same for both approaches)
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func signIn() {
        isLoading = true
        // Authentication logic here
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            // Handle result
        }
    }
}
```

#### UIKit Approach
```swift
// UIKit: Imperative and Event-Driven
class LoginViewControllerUIKit: UIViewController {
    private let viewModel = LoginViewModel()
    
    // Outlets
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }
    
    private func setupUI() {
        // UI setup is imperative
        emailTextField.placeholder = "Email"
        emailTextField.keyboardType = .emailAddress
        emailTextField.borderStyle = .roundedRect
        
        passwordTextField.placeholder = "Password"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.borderStyle = .roundedRect
        
        signInButton.setTitle("Sign In", for: .normal)
        signInButton.backgroundColor = .systemBlue
        signInButton.layer.cornerRadius = 8
        
        loadingIndicator.hidesWhenStopped = true
    }
    
    private func bindViewModel() {
        // Manual binding setup
        emailTextField.addTarget(self, action: #selector(emailChanged), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
        
        // Observe view model changes
        viewModel.$isLoading.sink { [weak self] isLoading in
            DispatchQueue.main.async {
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                    self?.signInButton.isEnabled = false
                } else {
                    self?.loadingIndicator.stopAnimating()
                    self?.signInButton.isEnabled = true
                }
            }
        }.store(in: &cancellables)
        
        viewModel.$showError.sink { [weak self] showError in
            if showError {
                self?.showErrorAlert()
            }
        }.store(in: &cancellables)
    }
    
    @objc private func emailChanged() {
        viewModel.email = emailTextField.text ?? ""
    }
    
    @objc private func passwordChanged() {
        viewModel.password = passwordTextField.text ?? ""
    }
    
    @IBAction func signInTapped() {
        viewModel.signIn()
    }
    
    private func showErrorAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: viewModel.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
```

## 🛠️ Practical Implementation

### SwiftUI Authentication Flow

Create `Views/Authentication/SwiftUIFlow/`:

#### 1. SwiftUI Container View
```swift
// Views/Authentication/SwiftUIFlow/SwiftUIAuthFlow.swift
import SwiftUI

struct SwiftUIAuthFlow: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        NavigationView {
            if authManager.isAuthenticated {
                SwiftUIMainView()
            } else {
                SwiftUIWelcomeView()
            }
        }
        .environmentObject(authManager)
    }
}

struct SwiftUIWelcomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showLogin = false
    @State private var showSignUp = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Logo and branding
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("SwiftUI Auth")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            // Action buttons
            VStack(spacing: 16) {
                Button("Sign In") {
                    showLogin = true
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Create Account") {
                    showSignUp = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showLogin) {
            SwiftUILoginView()
        }
        .sheet(isPresented: $showSignUp) {
            SwiftUISignUpView()
        }
    }
}

// Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .semibold))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear)
            .foregroundColor(.blue)
            .font(.system(size: 16, weight: .semibold))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

#### 2. SwiftUI Login Implementation
```swift
// Views/Authentication/SwiftUIFlow/SwiftUILoginView.swift
import SwiftUI

struct SwiftUILoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sign In")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                }
                
                Section {
                    Button("Sign In") {
                        signIn()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button("Sign In with Google") {
                        signInWithGoogle()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Sign In with Apple") {
                        signInWithApple()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Welcome Back")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        // TODO: Implement Google Sign-In
        print("Google Sign-In tapped")
    }
    
    private func signInWithApple() {
        // TODO: Implement Apple Sign-In
        print("Apple Sign-In tapped")
    }
}
```

### UIKit Authentication Flow

Create `Views/Authentication/UIKitFlow/`:

#### 1. UIKit Storyboard Setup
```swift
// Views/Authentication/UIKitFlow/UIKitAuthCoordinator.swift
import UIKit

class UIKitAuthCoordinator {
    private weak var navigationController: UINavigationController?
    private let authManager = AuthenticationManager()
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        setupAuthObserver()
    }
    
    func start() {
        if authManager.isAuthenticated {
            showMainFlow()
        } else {
            showWelcomeScreen()
        }
    }
    
    private func setupAuthObserver() {
        // Observe authentication state changes
        authManager.$isAuthenticated.sink { [weak self] isAuthenticated in
            DispatchQueue.main.async {
                if isAuthenticated {
                    self?.showMainFlow()
                } else {
                    self?.showWelcomeScreen()
                }
            }
        }.store(in: &cancellables)
    }
    
    private func showWelcomeScreen() {
        let welcomeVC = UIKitWelcomeViewController()
        welcomeVC.coordinator = self
        navigationController?.setViewControllers([welcomeVC], animated: true)
    }
    
    private func showMainFlow() {
        let mainVC = UIKitMainViewController()
        navigationController?.setViewControllers([mainVC], animated: true)
    }
    
    func showLogin() {
        let loginVC = UIKitLoginViewController()
        loginVC.authManager = authManager
        loginVC.coordinator = self
        
        let navController = UINavigationController(rootViewController: loginVC)
        navigationController?.present(navController, animated: true)
    }
    
    func showSignUp() {
        let signUpVC = UIKitSignUpViewController()
        signUpVC.authManager = authManager
        signUpVC.coordinator = self
        
        let navController = UINavigationController(rootViewController: signUpVC)
        navigationController?.present(navController, animated: true)
    }
    
    func dismissAuth() {
        navigationController?.dismiss(animated: true)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
```

#### 2. UIKit Welcome Controller
```swift
// Views/Authentication/UIKitFlow/UIKitWelcomeViewController.swift
import UIKit

class UIKitWelcomeViewController: UIViewController {
    weak var coordinator: UIKitAuthCoordinator?
    
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let signInButton = UIButton(type: .system)
    private let signUpButton = UIButton(type: .system)
    private let stackView = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Logo
        logoImageView.image = UIImage(systemName: "lock.shield.fill")
        logoImageView.tintColor = .systemBlue
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 80)
        
        // Title
        titleLabel.text = "UIKit Auth"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        
        // Subtitle
        subtitleLabel.text = "Your secure authentication solution"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        // Sign In Button
        signInButton.setTitle("Sign In", for: .normal)
        signInButton.backgroundColor = .systemBlue
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        signInButton.layer.cornerRadius = 12
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        
        // Sign Up Button
        signUpButton.setTitle("Create Account", for: .normal)
        signUpButton.backgroundColor = .clear
        signUpButton.setTitleColor(.systemBlue, for: .normal)
        signUpButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        signUpButton.layer.cornerRadius = 12
        signUpButton.layer.borderWidth = 2
        signUpButton.layer.borderColor = UIColor.systemBlue.cgColor
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        
        // Stack View
        stackView.axis = .vertical
        stackView.spacing = 40
        stackView.alignment = .fill
        stackView.distribution = .fill
    }
    
    private func setupConstraints() {
        [logoImageView, titleLabel, subtitleLabel, signInButton, signUpButton, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let headerStack = UIStackView(arrangedSubviews: [logoImageView, titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 16
        headerStack.alignment = .center
        
        let buttonStack = UIStackView(arrangedSubviews: [signInButton, signUpButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(buttonStack)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            signInButton.heightAnchor.constraint(equalToConstant: 50),
            signUpButton.heightAnchor.constraint(equalToConstant: 50),
            
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    @objc private func signInTapped() {
        coordinator?.showLogin()
    }
    
    @objc private func signUpTapped() {
        coordinator?.showSignUp()
    }
}
```

## 🔄 Interoperability

### SwiftUI in UIKit
```swift
// Embedding SwiftUI in UIKit
class UIKitHostingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create SwiftUI view
        let swiftUIView = SwiftUILoginView()
        let hostingController = UIHostingController(rootView: swiftUIView)
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Setup constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
```

### UIKit in SwiftUI
```swift
// Embedding UIKit in SwiftUI
struct UIKitViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitLoginViewController {
        return UIKitLoginViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIKitLoginViewController, context: Context) {
        // Update the view controller when SwiftUI state changes
    }
}

// Usage in SwiftUI
struct ContentView: View {
    var body: some View {
        UIKitViewRepresentable()
    }
}
```

## 📊 Performance Comparison

### Memory Usage
- **SwiftUI**: Generally lower memory footprint
- **UIKit**: More memory for view controllers and delegates

### Build Time
- **SwiftUI**: Slower compilation with complex views
- **UIKit**: Faster compilation, especially with storyboards

### Runtime Performance
- **SwiftUI**: Automatic optimization, efficient updates
- **UIKit**: Manual optimization required, but more control

### Learning Curve
- **SwiftUI**: Steeper initial curve, faster development later
- **UIKit**: Gradual learning curve, more concepts to master

## 🎯 Best Practices

### Code Organization
```
Authentication/
├── SwiftUIFlow/
│   ├── Views/
│   ├── ViewModels/
│   └── Components/
├── UIKitFlow/
│   ├── ViewControllers/
│   ├── Views/
│   └── Coordinators/
└── Shared/
    ├── Models/
    ├── Services/
    └── Utilities/
```

### Architecture Patterns
- **SwiftUI**: MVVM with ObservableObject
- **UIKit**: MVVM-C (Coordinator) or VIPER
- **Shared**: Repository pattern for data layer

## 🧪 Testing Strategies

### SwiftUI Testing
```swift
import XCTest
import SwiftUI
import ViewInspector

class SwiftUILoginViewTests: XCTestCase {
    func testLoginButtonIsDisabled() throws {
        let view = SwiftUILoginView()
        let button = try view.inspect().find(button: "Sign In")
        XCTAssertTrue(try button.isDisabled())
    }
}
```

### UIKit Testing
```swift
import XCTest

class UIKitLoginViewControllerTests: XCTestCase {
    var viewController: UIKitLoginViewController!
    
    override func setUp() {
        super.setUp()
        viewController = UIKitLoginViewController()
        viewController.loadViewIfNeeded()
    }
    
    func testSignInButtonIsDisabled() {
        XCTAssertFalse(viewController.signInButton.isEnabled)
    }
}
```

## 📚 Key Takeaways

1. **SwiftUI Advantages**:
   - Declarative syntax is more intuitive
   - Automatic state management
   - Built-in animations and transitions
   - Cross-platform capabilities

2. **UIKit Advantages**:
   - Mature ecosystem and documentation
   - Fine-grained control over UI
   - Better debugging tools
   - Extensive third-party support

3. **Decision Factors**:
   - Team expertise and preferences
   - Project timeline and complexity
   - Target iOS versions
   - Performance requirements

## 🎯 Next Steps

In the next lesson, we'll cover:
- Form validation techniques
- Custom input validation
- Error handling patterns
- User experience improvements

Choose your preferred framework path for the remaining lessons, or implement both for comparison!

---

**🎉 Well Done!** You now understand the trade-offs between SwiftUI and UIKit for authentication interfaces and can make informed decisions for your projects.

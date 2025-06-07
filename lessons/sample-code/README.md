# iOS Authentication App - Complete Sample Code

This directory contains a complete, production-ready iOS authentication system implementing Firebase Auth + AWS backend with the following features:

## 🎯 Features
- **Email/Password Authentication**: Complete registration and login flow
- **Google Sign-In Integration**: Seamless OAuth 2.0 authentication
- **AWS Lambda Backend**: Serverless backend with DynamoDB storage
- **Secure Token Management**: Keychain storage with automatic refresh
- **SwiftUI Interface**: Modern, responsive user interface
- **Comprehensive Error Handling**: User-friendly error messages
- **Unit Testing**: Extensive test coverage
- **Security Best Practices**: Industry-standard security implementations

## 📁 Project Structure

```
iOSAuthApp/
├── App/
│   ├── iOSAuthAppApp.swift                 # App entry point
│   ├── ContentView.swift                   # Main app view
│   └── Info.plist                          # App configuration
├── Core/
│   ├── Authentication/
│   │   ├── Models/
│   │   │   ├── User.swift                  # User data models
│   │   │   ├── AuthModels.swift            # API request/response models
│   │   │   └── AuthError.swift             # Authentication error types
│   │   ├── Managers/
│   │   │   ├── AuthenticationManager.swift  # Main auth coordinator
│   │   │   ├── GoogleSignInManager.swift   # Google Sign-In handler
│   │   │   └── TokenStorage.swift          # Secure token storage
│   │   ├── Network/
│   │   │   ├── NetworkManager.swift        # Base network layer
│   │   │   ├── AuthAPIManager.swift        # Authentication API calls
│   │   │   └── APIConfig.swift             # API configuration
│   │   └── Views/
│   │       ├── AuthenticationView.swift    # Main auth view
│   │       ├── EmailAuthView.swift         # Email auth form
│   │       ├── GoogleSignInButton.swift    # Google sign-in button
│   │       └── Components/
│   │           ├── CustomTextField.swift   # Reusable text fields
│   │           ├── LoadingView.swift       # Loading indicator
│   │           └── ErrorView.swift         # Error display
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift             # Main app dashboard
│   │   └── ProfileView.swift               # User profile view
│   └── Onboarding/
│       ├── WelcomeView.swift               # Welcome screen
│       └── OnboardingView.swift            # App introduction
├── Shared/
│   ├── Extensions/
│   │   ├── String+Extensions.swift         # String utilities
│   │   ├── View+Extensions.swift           # SwiftUI view extensions
│   │   └── Color+Extensions.swift          # Color palette
│   ├── Utils/
│   │   ├── Validation.swift                # Input validation
│   │   ├── Constants.swift                 # App constants
│   │   └── Logger.swift                    # Logging utility
│   └── Resources/
│       ├── Assets.xcassets                 # Images and colors
│       └── Localizable.strings             # Localization
├── Tests/
│   ├── Unit/
│   │   ├── AuthenticationManagerTests.swift
│   │   ├── AuthAPIManagerTests.swift
│   │   ├── TokenStorageTests.swift
│   │   └── ValidationTests.swift
│   ├── Integration/
│   │   ├── AuthenticationFlowTests.swift
│   │   └── APIIntegrationTests.swift
│   └── UI/
│       ├── AuthenticationViewTests.swift
│       └── EmailAuthViewTests.swift
└── Backend/
    ├── Lambda/
    │   ├── user-registration/
    │   │   ├── index.js                    # Registration function
    │   │   ├── package.json                # Dependencies
    │   │   └── tests/
    │   ├── user-authentication/
    │   │   ├── index.js                    # Authentication function
    │   │   ├── package.json                # Dependencies
    │   │   └── tests/
    │   └── token-validation/
    │       ├── index.js                    # Token validation function
    │       ├── package.json                # Dependencies
    │       └── tests/
    ├── Infrastructure/
    │   ├── terraform/
    │   │   ├── main.tf                     # Main infrastructure
    │   │   ├── variables.tf                # Configuration variables
    │   │   ├── outputs.tf                  # Infrastructure outputs
    │   │   └── modules/
    │   │       ├── dynamodb/               # DynamoDB configuration
    │   │       ├── lambda/                 # Lambda configuration
    │   │       └── api-gateway/            # API Gateway setup
    │   └── scripts/
    │       ├── deploy.sh                   # Deployment script
    │       ├── setup-aws.sh                # AWS setup script
    │       └── test-api.sh                 # API testing script
    └── Documentation/
        ├── API.md                          # API documentation
        ├── SECURITY.md                     # Security guidelines
        └── DEPLOYMENT.md                   # Deployment guide
```

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ deployment target
- AWS CLI configured
- Firebase project set up
- Google Sign-In configured

### Setup Steps

1. **Clone and Setup iOS Project**
   ```bash
   # Clone the sample code
   git clone <repository-url>
   cd iOSAuthApp
   
   # Install dependencies
   pod install
   
   # Open workspace
   open iOSAuthApp.xcworkspace
   ```

2. **Configure Firebase**
   ```bash
   # Download GoogleService-Info.plist from Firebase Console
   # Add to Xcode project
   # Update URL schemes in Info.plist
   ```

3. **Deploy AWS Backend**
   ```bash
   cd Backend
   ./scripts/setup-aws.sh
   ./scripts/deploy.sh
   ```

4. **Update API Configuration**
   ```swift
   // Update APIConfig.swift with your API Gateway URL
   static let baseURL = "https://your-api-id.execute-api.region.amazonaws.com/prod"
   ```

## 📱 Key Features Implementation

### 1. Email/Password Authentication
```swift
// Complete registration flow with validation
func register(email: String, password: String, displayName: String) {
    // Input validation
    // API call to backend
    // Token storage
    // UI state management
}
```

### 2. Google Sign-In Integration
```swift
// Seamless Google OAuth flow
func signInWithGoogle() {
    // Google Sign-In SDK
    // Firebase credential exchange
    // Backend synchronization
    // Session management
}
```

### 3. Secure Token Management
```swift
// Keychain-based secure storage
class TokenStorage {
    // Store/retrieve auth tokens
    // Session management
    // Automatic token refresh
    // Secure cleanup
}
```

### 4. AWS Lambda Backend
```javascript
// Serverless authentication endpoints
exports.handler = async (event) => {
    // Request validation
    // DynamoDB operations
    // JWT token generation
    // Error handling
};
```

## 🔐 Security Features

- **Token Encryption**: All tokens stored in iOS Keychain
- **Input Validation**: Client and server-side validation
- **Rate Limiting**: API rate limiting implementation
- **HTTPS Only**: All communications encrypted
- **Session Management**: Automatic session expiration
- **Error Handling**: Secure error messages

## 🧪 Testing

### Run Unit Tests
```bash
# iOS Tests
xcodebuild test -workspace iOSAuthApp.xcworkspace -scheme iOSAuthApp -destination 'platform=iOS Simulator,name=iPhone 15'

# Lambda Tests
cd Backend/Lambda/user-registration
npm test
```

### Integration Testing
```bash
# API Integration Tests
cd Backend/scripts
./test-api.sh
```

## 📚 Usage Examples

### Basic Authentication Flow
```swift
// Initialize authentication manager
@StateObject private var authManager = AuthenticationManager()

// Register new user
authManager.register(
    email: "user@example.com",
    password: "SecurePassword123!",
    displayName: "John Doe"
)

// Login existing user
authManager.login(
    email: "user@example.com",
    password: "SecurePassword123!"
)

// Google Sign-In
googleSignInManager.signInWithGoogle()
```

### API Integration
```swift
// Network manager usage
let authAPI = AuthAPIManager()

authAPI.register(email: email, password: password, displayName: displayName)
    .sink(
        receiveCompletion: { completion in
            // Handle completion
        },
        receiveValue: { response in
            // Handle success
        }
    )
    .store(in: &cancellables)
```

## 🔧 Configuration

### Environment Variables
```bash
# AWS Configuration
export AWS_REGION=us-east-1
export JWT_SECRET=your-jwt-secret
export DYNAMODB_TABLE_PREFIX=auth-app

# Firebase Configuration
# Update GoogleService-Info.plist
```

### Build Configurations
```swift
// Debug vs Release configurations
#if DEBUG
static let baseURL = "https://dev-api.yourapp.com"
static let logLevel = .debug
#else
static let baseURL = "https://api.yourapp.com"
static let logLevel = .error
#endif
```

## 📖 Additional Resources

- **Lesson Materials**: Detailed step-by-step lessons in `/lessons` directory
- **API Documentation**: Complete API reference in `Backend/Documentation/API.md`
- **Security Guide**: Security best practices in `Backend/Documentation/SECURITY.md`
- **Deployment Guide**: Production deployment instructions in `Backend/Documentation/DEPLOYMENT.md`

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions and support:
- Review the lesson materials in the `/lessons` directory
- Check the troubleshooting guides
- Open an issue for bugs or feature requests
- Consult the API documentation for backend integration

---

**Note**: This is a complete, production-ready authentication system suitable for real-world iOS applications. All security best practices are implemented and the code follows iOS development standards.

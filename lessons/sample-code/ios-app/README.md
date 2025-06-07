# iOS Authentication App

Complete iOS application demonstrating Firebase Authentication integration with AWS backend.

## Project Structure

```
ios-app/
├── iOS-Auth-App/                 # Main app directory
│   ├── App/                      # App lifecycle
│   ├── Models/                   # Data models
│   ├── Services/                 # Business logic services
│   ├── ViewModels/               # MVVM view models
│   ├── Views/                    # SwiftUI views
│   ├── Utilities/                # Helper utilities
│   └── Resources/                # Assets, configs
├── iOS-Auth-AppTests/            # Unit tests
├── iOS-Auth-AppUITests/          # UI tests
└── Podfile                       # CocoaPods dependencies
```

## Features

### Authentication
- ✅ Firebase Email/Password Authentication
- ✅ Google Sign-In Integration
- ✅ Apple Sign-In Integration
- ✅ Biometric Authentication (Touch ID/Face ID)
- ✅ Token Management & Refresh
- ✅ Secure Token Storage (Keychain)

### Security
- ✅ Certificate Pinning
- ✅ API Request Signing
- ✅ Token Encryption
- ✅ Network Security
- ✅ Input Validation

### User Experience
- ✅ Modern SwiftUI Interface
- ✅ Dark Mode Support
- ✅ Accessibility Features
- ✅ Offline Support
- ✅ Error Handling
- ✅ Loading States

### Performance
- ✅ Memory Management
- ✅ Network Caching
- ✅ Battery Optimization
- ✅ Background App Refresh

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Firebase Project
- AWS API Gateway Endpoint

## Setup Instructions

1. **Clone and Install Dependencies**
   ```bash
   cd ios-app
   pod install
   open iOS-Auth-App.xcworkspace
   ```

2. **Configure Firebase**
   - Add `GoogleService-Info.plist` to the project
   - Configure URL schemes in Info.plist
   - Enable Authentication methods in Firebase Console

3. **Configure AWS Backend**
   - Update `Config.plist` with your API endpoint
   - Configure certificate pinning certificates

4. **Build and Run**
   - Select target device/simulator
   - Build and run the project

## Architecture

The app follows MVVM (Model-View-ViewModel) architecture with:

- **Models**: Data structures and API responses
- **Services**: Business logic and API communication
- **ViewModels**: UI state management and business logic
- **Views**: SwiftUI user interface components

## Testing

Run tests using Xcode or command line:
```bash
# Unit tests
xcodebuild test -workspace iOS-Auth-App.xcworkspace -scheme iOS-Auth-App -destination 'platform=iOS Simulator,name=iPhone 14'

# UI tests
xcodebuild test -workspace iOS-Auth-App.xcworkspace -scheme iOS-Auth-AppUITests -destination 'platform=iOS Simulator,name=iPhone 14'
```

## Deployment

1. **Update Bundle Identifier**
2. **Configure Signing & Capabilities**
3. **Archive and Upload to App Store**

For detailed implementation, see the source code files in this directory.

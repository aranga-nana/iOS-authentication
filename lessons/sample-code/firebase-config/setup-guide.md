# Firebase SDK Setup Guide

## Prerequisites
- Firebase project created at https://console.firebase.google.com/
- iOS app registered in Firebase project
- Google Cloud Console project linked for OAuth

## Step 1: Download Configuration Files

### 1.1 iOS Configuration
1. In Firebase Console, go to Project Settings
2. Select your iOS app
3. Download `GoogleService-Info.plist`
4. Add file to your Xcode project root

### 1.2 Firebase Configuration
```json
{
  "project_id": "your-project-id",
  "api_key": "your-api-key",
  "auth_domain": "your-project.firebaseapp.com",
  "storage_bucket": "your-project.appspot.com",
  "messaging_sender_id": "123456789",
  "app_id": "1:123456789:ios:abcdef123456",
  "client_id": "123456789-abcdef.apps.googleusercontent.com"
}
```

## Step 2: Podfile Configuration

```ruby
# Podfile
platform :ios, '17.0'

target 'iOSAuthApp' do
  use_frameworks!
  
  # Firebase
  pod 'Firebase/Auth'
  pod 'Firebase/Analytics'
  
  # Google Sign-In
  pod 'GoogleSignIn'
  
  # Additional utilities
  pod 'KeychainAccess'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
```

## Step 3: Info.plist Configuration

Add the following to your `Info.plist`:

```xml
<!-- URL Schemes for Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>com.googleusercontent.apps.123456789-abcdef</string>
        </array>
    </dict>
</array>

<!-- Google Services Configuration -->
<key>GOOGLE_APP_ID</key>
<string>1:123456789:ios:abcdef123456</string>

<!-- App Transport Security -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>googleapis.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
        <key>googleapis.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Step 4: Firebase Authentication Rules

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public read access to some collections
    match /public/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

```javascript
// Firebase Authentication Rules
{
  "rules": {
    ".read": false,
    ".write": false,
    "users": {
      "$user_id": {
        ".read": "$user_id === auth.uid",
        ".write": "$user_id === auth.uid",
        ".validate": "newData.hasChildren(['email', 'displayName'])"
      }
    }
  }
}
```

## Step 5: Environment Configuration

Create `Config.plist` for environment-specific settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_BASE_URL</key>
    <string>https://your-api-gateway-url.amazonaws.com/prod</string>
    <key>FIREBASE_PROJECT_ID</key>
    <string>your-firebase-project-id</string>
    <key>GOOGLE_CLIENT_ID</key>
    <string>your-google-client-id.apps.googleusercontent.com</string>
    <key>ENVIRONMENT</key>
    <string>development</string>
    <key>ENABLE_ANALYTICS</key>
    <true/>
    <key>ENABLE_DEBUGGING</key>
    <true/>
</dict>
</plist>
```

## Step 6: Firebase Functions (Optional)

If using Firebase Functions for additional backend logic:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Create custom token
exports.createCustomToken = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const uid = context.auth.uid;
  const additionalClaims = {
    customClaim: data.customValue
  };
  
  try {
    const customToken = await admin.auth().createCustomToken(uid, additionalClaims);
    return { token: customToken };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Error creating custom token');
  }
});

// User profile updates
exports.updateUserProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const uid = context.auth.uid;
  const { displayName, photoURL } = data;
  
  try {
    await admin.auth().updateUser(uid, {
      displayName: displayName,
      photoURL: photoURL
    });
    
    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Error updating profile');
  }
});
```

## Step 7: Testing Configuration

### 7.1 Unit Test Configuration
```javascript
// firebase.json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "functions": {
      "port": 5001
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions",
    "predeploy": [
      "npm --prefix functions run build"
    ]
  }
}
```

### 7.2 iOS Test Configuration
```swift
// FirebaseTestConfiguration.swift
import Firebase
import FirebaseAuth

class FirebaseTestConfiguration {
    static func configureForTesting() {
        // Use Firebase Auth emulator for testing
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        }
    }
}
```

## Step 8: Security Best Practices

### 8.1 App Check Configuration
```swift
// AppCheckConfiguration.swift
import Firebase
import FirebaseAppCheck

class AppCheckConfiguration {
    static func configure() {
        #if DEBUG
        // Use debug provider for development
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        // Use DeviceCheck provider for production
        let providerFactory = DeviceCheckProviderFactory()
        #endif
        
        AppCheck.setAppCheckProviderFactory(providerFactory)
    }
}
```

### 8.2 Network Security
```swift
// NetworkSecurityConfiguration.swift
import Network
import Security

class NetworkSecurityConfiguration {
    static func configureCertificatePinning() {
        // Certificate pinning configuration
        // Add your SSL certificates to the app bundle
        guard let certPath = Bundle.main.path(forResource: "firebase-cert", ofType: "cer"),
              let certData = NSData(contentsOfFile: certPath),
              let certificate = SecCertificateCreateWithData(nil, certData) else {
            fatalError("Failed to load certificate")
        }
        
        // Configure URLSession with certificate pinning
        // Implementation depends on your networking layer
    }
}
```

## Troubleshooting

### Common Issues

1. **GoogleService-Info.plist not found**
   - Ensure file is added to Xcode project
   - Check target membership
   - Verify file is in correct bundle

2. **Google Sign-In not working**
   - Verify URL scheme in Info.plist
   - Check REVERSED_CLIENT_ID value
   - Ensure OAuth client is configured in Google Cloud Console

3. **Firebase Auth errors**
   - Check internet connection
   - Verify API key is valid
   - Check Firebase project configuration

4. **Build errors**
   - Clean build folder (Cmd+Shift+K)
   - Update pod dependencies
   - Check iOS deployment target

### Debug Commands

```bash
# Check pod installation
pod install --verbose

# Verify Firebase configuration
firebase projects:list

# Test Firebase connectivity
firebase emulators:start

# Check Google OAuth configuration
gcloud auth list
```

## Additional Resources

- [Firebase iOS Setup Guide](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In iOS Guide](https://developers.google.com/identity/sign-in/ios)
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)

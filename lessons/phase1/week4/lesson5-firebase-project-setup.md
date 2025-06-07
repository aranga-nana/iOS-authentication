# 🔥 Lesson 5: Firebase Project Setup and Configuration

> **Phase 1, Week 4 - Firebase Deep Dive and Project Configuration**  
> **Duration**: 8 hours | **Level**: All Levels  
> **Prerequisites**: Completed Lessons 1-4, Firebase and AWS accounts created

## 🎯 Learning Objectives

By the end of this lesson, you will:
- Configure a complete Firebase project for iOS authentication
- Understand Firebase security rules and best practices
- Set up Firebase emulators for local development
- Implement Firebase Analytics and monitoring
- Create Firebase Cloud Functions for custom logic
- Integrate Firebase with iOS project structure

---

## 📚 Part 1: Firebase Project Configuration (2 hours)

### 1.1 Advanced Firebase Project Setup

**Create Production-Ready Firebase Project:**
```bash
# Create project with specific configuration
firebase projects:create ios-auth-production --display-name "iOS Auth System"

# Set as default project
firebase use ios-auth-production

# Initialize with all services
firebase init

# Select all relevant services:
# ✅ Firestore: Configure security rules and indexes
# ✅ Functions: Configure and deploy Cloud Functions
# ✅ Hosting: Configure files for Firebase Hosting
# ✅ Storage: Configure security rules for Cloud Storage
# ✅ Emulators: Set up local emulators for Firebase features
```

**Project Structure After Initialization:**
```
ios-auth-firebase/
├── .firebaserc              # Firebase project configuration
├── firebase.json            # Firebase service configuration
├── firestore.rules          # Firestore security rules
├── firestore.indexes.json   # Firestore composite indexes
├── storage.rules            # Cloud Storage security rules
├── functions/               # Cloud Functions directory
│   ├── package.json
│   ├── index.js
│   └── .eslintrc.js
├── public/                  # Hosting directory
└── .gitignore
```

### 1.2 Authentication Provider Configuration

**Enable Multiple Authentication Providers:**

1. **Email/Password Authentication:**
```bash
# Navigate to Firebase Console
# Authentication > Sign-in method > Email/Password > Enable
```

2. **Google Sign-In Configuration:**
```bash
# Download OAuth 2.0 configuration
# Authentication > Sign-in method > Google > Enable
# Add your app's bundle ID: com.yourcompany.iosauth
# Download updated GoogleService-Info.plist
```

3. **Apple Sign-In Configuration:**
```bash
# Authentication > Sign-in method > Apple > Enable
# Configure with your Apple Developer Team ID and Bundle ID
```

**Authentication Settings Configuration:**
```javascript
// firebase-config.js
const authConfig = {
  // Authorized domains for authentication
  authorizedDomains: [
    'localhost',
    'your-project.firebaseapp.com',
    'your-custom-domain.com'
  ],
  
  // Email verification settings
  emailVerification: {
    required: true,
    template: 'custom'
  },
  
  // Password policy
  passwordPolicy: {
    minLength: 8,
    requireUppercase: true,
    requireLowercase: true,
    requireNumbers: true,
    requireSymbols: true
  },
  
  // Session management
  sessionTimeout: 3600, // 1 hour
  
  // Multi-factor authentication
  mfa: {
    enabled: false, // Enable for production
    enforcementState: 'OPTIONAL'
  }
};
```

### 1.3 Email Templates Customization

**Customize Email Templates:**
1. Navigate to Authentication > Templates
2. Customize templates for:
   - Email verification
   - Password reset
   - Email address change

**Example Email Verification Template:**
```html
<!-- Email Verification Template -->
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Verify Your Email - iOS Auth App</title>
</head>
<body>
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2>Welcome to iOS Auth App!</h2>
        <p>Please verify your email address by clicking the link below:</p>
        <a href="%LINK%" style="background-color: #007AFF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
            Verify Email Address
        </a>
        <p>If you didn't create an account, you can safely ignore this email.</p>
        <p>Best regards,<br>iOS Auth App Team</p>
    </div>
</body>
</html>
```

**🏃‍♂️ Practice Exercise 1.1:**
Configure your Firebase project with all authentication providers and customize email templates.

---

## 📚 Part 2: Firestore Database Configuration (2 hours)

### 2.1 Firestore Security Rules

**Production-Ready Security Rules:**
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only access their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId
        && validateUserData(request.resource.data);
    }
    
    // Public data that authenticated users can read
    match /public/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && isAdmin(request.auth.uid);
    }
    
    // App configuration (read-only for authenticated users)
    match /config/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Only allow writes via Admin SDK
    }
    
    // User activity logs (write-only)
    match /userActivity/{userId}/logs/{logId} {
      allow write: if request.auth != null 
        && request.auth.uid == userId;
      allow read: if false; // Only readable via backend
    }
  }
  
  // Helper functions
  function validateUserData(data) {
    return data.keys().hasAll(['email', 'displayName', 'createdAt'])
      && data.email is string
      && data.displayName is string
      && data.createdAt is timestamp;
  }
  
  function isAdmin(uid) {
    return exists(/databases/$(database)/documents/admins/$(uid));
  }
}
```

### 2.2 Firestore Data Structure

**User Profile Document Structure:**
```javascript
// User profile document example
const userProfile = {
  // Basic information
  uid: 'firebase-user-id',
  email: 'user@example.com',
  emailVerified: true,
  displayName: 'John Doe',
  photoURL: 'https://example.com/photo.jpg',
  
  // Profile details
  profile: {
    firstName: 'John',
    lastName: 'Doe',
    dateOfBirth: '1990-01-01',
    phoneNumber: '+1234567890',
    bio: 'iOS developer',
    location: 'San Francisco, CA'
  },
  
  // App preferences
  preferences: {
    notifications: {
      push: true,
      email: false,
      sms: false
    },
    privacy: {
      profileVisible: true,
      contactInfoVisible: false
    },
    theme: 'auto', // 'light', 'dark', 'auto'
    language: 'en'
  },
  
  // Security information
  security: {
    lastPasswordChange: '2024-01-01T00:00:00Z',
    mfaEnabled: false,
    trustedDevices: []
  },
  
  // Metadata
  metadata: {
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
    lastLoginAt: '2024-01-01T00:00:00Z',
    loginCount: 42,
    version: 1
  }
};
```

### 2.3 Firestore Indexes

**Configure Composite Indexes:**
```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "metadata.createdAt",
          "order": "DESCENDING"
        },
        {
          "fieldPath": "emailVerified",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "userActivity",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": [
    {
      "collectionGroup": "users",
      "fieldPath": "email",
      "indexes": [
        {
          "order": "ASCENDING",
          "queryScope": "COLLECTION"
        }
      ]
    }
  ]
}
```

**🏃‍♂️ Practice Exercise 2.1:**
Create Firestore security rules and test them using the Firebase emulator.

---

## 📚 Part 3: Firebase Cloud Functions (2 hours)

### 3.1 Authentication Triggers

**User Creation Trigger:**
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Trigger when a new user is created
exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  const { uid, email, displayName, photoURL, emailVerified } = user;
  
  try {
    // Create user profile document
    await admin.firestore().collection('users').doc(uid).set({
      uid,
      email,
      emailVerified,
      displayName: displayName || '',
      photoURL: photoURL || '',
      profile: {
        firstName: '',
        lastName: '',
        dateOfBirth: null,
        phoneNumber: '',
        bio: '',
        location: ''
      },
      preferences: {
        notifications: {
          push: true,
          email: true,
          sms: false
        },
        privacy: {
          profileVisible: true,
          contactInfoVisible: false
        },
        theme: 'auto',
        language: 'en'
      },
      security: {
        lastPasswordChange: admin.firestore.FieldValue.serverTimestamp(),
        mfaEnabled: false,
        trustedDevices: []
      },
      metadata: {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        loginCount: 1,
        version: 1
      }
    });
    
    console.log(`User profile created for ${uid}`);
  } catch (error) {
    console.error('Error creating user profile:', error);
  }
});

// Trigger when a user is deleted
exports.deleteUserData = functions.auth.user().onDelete(async (user) => {
  const { uid } = user;
  
  try {
    // Delete user profile
    await admin.firestore().collection('users').doc(uid).delete();
    
    // Delete user activity logs
    const activityRef = admin.firestore()
      .collection('userActivity')
      .doc(uid);
    
    await deleteCollection(activityRef.collection('logs'));
    await activityRef.delete();
    
    console.log(`User data deleted for ${uid}`);
  } catch (error) {
    console.error('Error deleting user data:', error);
  }
});

// Helper function to delete a collection
async function deleteCollection(collectionRef, batchSize = 100) {
  const query = collectionRef.limit(batchSize);
  
  return new Promise((resolve, reject) => {
    deleteQueryBatch(query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(query, resolve) {
  const snapshot = await query.get();
  
  const batchSize = snapshot.size;
  if (batchSize === 0) {
    resolve();
    return;
  }
  
  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  
  // Recurse on the next process tick
  process.nextTick(() => {
    deleteQueryBatch(query, resolve);
  });
}
```

### 3.2 Custom Authentication Functions

**Email Verification Reminder:**
```javascript
// Send email verification reminder
exports.sendEmailVerificationReminder = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const { uid } = context.auth;
  
  try {
    // Check if email is already verified
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord.emailVerified) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Email is already verified'
      );
    }
    
    // Generate email verification link
    const link = await admin.auth().generateEmailVerificationLink(userRecord.email);
    
    // Send custom email (implement your email service here)
    await sendCustomEmail(userRecord.email, 'Email Verification Reminder', {
      displayName: userRecord.displayName || 'User',
      verificationLink: link
    });
    
    return { success: true, message: 'Verification email sent' };
  } catch (error) {
    console.error('Error sending verification reminder:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send verification email'
    );
  }
});

// Custom claims for role-based access
exports.setCustomClaims = functions.https.onCall(async (data, context) => {
  // Only admins can set custom claims
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set custom claims'
    );
  }
  
  const { uid, claims } = data;
  
  try {
    await admin.auth().setCustomUserClaims(uid, claims);
    return { success: true, message: 'Custom claims set successfully' };
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set custom claims'
    );
  }
});
```

### 3.3 Security and Validation Functions

**Token Validation for External APIs:**
```javascript
// Validate Firebase ID token for external API access
exports.validateTokenForAPI = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  try {
    // Extract token from Authorization header
    const authHeader = req.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    
    const idToken = authHeader.split('Bearer ')[1];
    
    // Verify the token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    
    // Check if user exists in Firestore
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(decodedToken.uid)
      .get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User profile not found' });
    }
    
    const userData = userDoc.data();
    
    // Return validated user information
    res.json({
      valid: true,
      user: {
        uid: decodedToken.uid,
        email: decodedToken.email,
        emailVerified: decodedToken.email_verified,
        displayName: userData.displayName,
        customClaims: decodedToken.customClaims || {}
      }
    });
  } catch (error) {
    console.error('Token validation error:', error);
    res.status(401).json({ 
      valid: false, 
      error: 'Invalid token' 
    });
  }
});
```

**🏃‍♂️ Practice Exercise 3.1:**
Deploy the Cloud Functions and test them using the Firebase emulator.

---

## 📚 Part 4: Firebase Analytics and Monitoring (1 hour)

### 4.1 Analytics Configuration

**Enable Firebase Analytics:**
```javascript
// Configure Analytics in iOS app
import FirebaseAnalytics

// Track authentication events
func trackAuthenticationEvent(method: String, success: Bool) {
    Analytics.logEvent("authentication_attempt", parameters: [
        "method": method,
        "success": success,
        "timestamp": Date().timeIntervalSince1970
    ])
}

// Track user engagement
func trackUserEngagement(action: String) {
    Analytics.logEvent("user_engagement", parameters: [
        "action": action,
        "user_id": Auth.auth().currentUser?.uid ?? "anonymous"
    ])
}
```

**Custom Analytics Events:**
```javascript
// Track authentication flow events
const analyticsEvents = {
  // User registration
  USER_REGISTRATION_STARTED: 'user_registration_started',
  USER_REGISTRATION_COMPLETED: 'user_registration_completed',
  
  // User login
  USER_LOGIN_STARTED: 'user_login_started', 
  USER_LOGIN_COMPLETED: 'user_login_completed',
  USER_LOGIN_FAILED: 'user_login_failed',
  
  // Password management
  PASSWORD_RESET_REQUESTED: 'password_reset_requested',
  PASSWORD_RESET_COMPLETED: 'password_reset_completed',
  
  // Email verification
  EMAIL_VERIFICATION_SENT: 'email_verification_sent',
  EMAIL_VERIFICATION_COMPLETED: 'email_verification_completed',
  
  // Profile management
  PROFILE_UPDATE_STARTED: 'profile_update_started',
  PROFILE_UPDATE_COMPLETED: 'profile_update_completed'
};
```

### 4.2 Performance Monitoring

**Firebase Performance SDK:**
```swift
// Configure Performance Monitoring
import FirebasePerformance

class PerformanceManager {
    
    func trackAuthenticationPerformance<T>(
        operation: String,
        block: () async throws -> T
    ) async throws -> T {
        let trace = Performance.startTrace(name: "auth_\(operation)")
        trace?.start()
        
        do {
            let result = try await block()
            trace?.setValue(1, forMetric: "success_count")
            return result
        } catch {
            trace?.setValue(1, forMetric: "error_count")
            throw error
        } finally {
            trace?.stop()
        }
    }
}

// Usage example
let performanceManager = PerformanceManager()

let user = try await performanceManager.trackAuthenticationPerformance(
    operation: "email_login"
) {
    try await Auth.auth().signIn(withEmail: email, password: password)
}
```

### 4.3 Error Tracking with Crashlytics

**Crashlytics Setup:**
```swift
import FirebaseCrashlytics

class ErrorTracker {
    
    static func recordAuthenticationError(
        _ error: Error,
        context: [String: Any] = [:]
    ) {
        Crashlytics.crashlytics().record(error: error)
        
        // Add custom context
        for (key, value) in context {
            Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        }
        
        // Log non-fatal error
        Crashlytics.crashlytics().log("Authentication error: \(error.localizedDescription)")
    }
    
    static func setUserContext(userId: String, email: String) {
        Crashlytics.crashlytics().setUserID(userId)
        Crashlytics.crashlytics().setCustomValue(email, forKey: "user_email")
    }
}
```

**🏃‍♂️ Practice Exercise 4.1:**
Configure Analytics and Crashlytics in your Firebase project and implement basic tracking.

---

## 📚 Part 5: Local Development with Emulators (30 minutes)

### 5.1 Firebase Emulator Suite

**Complete Emulator Configuration:**
```json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
    },
    "firestore": {
      "port": 8080
    },
    "hosting": {
      "port": 5000
    },
    "pubsub": {
      "port": 8085
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true,
      "port": 4000
    },
    "singleProjectMode": true
  }
}
```

**Emulator Development Workflow:**
```bash
# Start all emulators
firebase emulators:start

# Start specific emulators
firebase emulators:start --only auth,firestore,functions

# Import/export data
firebase emulators:export ./emulator-data
firebase emulators:start --import ./emulator-data

# Run tests against emulators
npm test
```

### 5.2 iOS App Configuration for Emulators

**Configure iOS App for Local Development:**
```swift
// Configure Firebase for emulator use
import Firebase
import FirebaseAuth
import FirebaseFirestore

class FirebaseConfig {
    
    static func configureForEnvironment() {
        FirebaseApp.configure()
        
        #if DEBUG
        // Use emulators in debug mode
        if isRunningOnSimulator() {
            configureEmulators()
        }
        #endif
    }
    
    private static func configureEmulators() {
        // Configure Auth emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        
        // Configure Firestore emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
    }
    
    private static func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
```

### 5.3 Testing with Emulators

**Unit Tests with Emulators:**
```swift
import XCTest
import FirebaseAuth
import FirebaseFirestore

class AuthenticationTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Configure emulators for testing
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
    }
    
    func testUserRegistration() async throws {
        let email = "test@example.com"
        let password = "testpassword123"
        
        // Test user registration
        let result = try await Auth.auth().createUser(
            withEmail: email,
            password: password
        )
        
        XCTAssertNotNil(result.user)
        XCTAssertEqual(result.user.email, email)
        XCTAssertFalse(result.user.isEmailVerified)
    }
}
```

**🏃‍♂️ Practice Exercise 5.1:**
Set up Firebase emulators and configure your iOS project to use them during development.

---

## ✅ Lesson Completion Checklist

- [ ] Firebase project configured with all authentication providers
- [ ] Firestore security rules implemented and tested
- [ ] Cloud Functions deployed for user lifecycle management
- [ ] Firebase Analytics and Crashlytics configured
- [ ] Emulator suite set up for local development
- [ ] iOS app configured to work with emulators
- [ ] Custom email templates created and configured
- [ ] Performance monitoring implemented
- [ ] Error tracking configured
- [ ] Testing infrastructure set up with emulators

---

## 📝 Assignment

**Complete Firebase Project Setup:**

1. **Authentication Configuration**: Set up all authentication providers (Email/Password, Google, Apple)
2. **Security Rules**: Implement comprehensive Firestore security rules
3. **Cloud Functions**: Deploy user lifecycle management functions
4. **Analytics Setup**: Configure Analytics and Crashlytics with custom events
5. **Email Templates**: Customize all authentication email templates
6. **Testing Environment**: Set up emulators and write basic tests
7. **Documentation**: Create setup documentation for your team

**Deliverables:**
- Working Firebase project with all features configured
- Firestore security rules that pass testing
- Deployed Cloud Functions with proper error handling
- iOS app configured for both production and development
- Test suite that runs against emulators
- Complete documentation of setup process

---

## 🔗 Next Lesson

**Lesson 6: Firebase Authentication Integration** (Phase 2) - We'll integrate Firebase Authentication into our iOS app with complete UI implementation.

---

## 📚 Additional Resources

### Firebase Documentation
- [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth)
- [Firestore Security Rules Reference](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Cloud Functions Samples](https://github.com/firebase/functions-samples)

### Testing Resources
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Testing Security Rules](https://firebase.google.com/docs/firestore/security/test-rules-emulator)
- [Unit Testing Cloud Functions](https://firebase.google.com/docs/functions/unit-testing)

### Best Practices
- [Firebase Security Best Practices](https://firebase.google.com/docs/firestore/security/rules-best-practices)
- [Cloud Functions Best Practices](https://firebase.google.com/docs/functions/tips)
- [Performance Monitoring Best Practices](https://firebase.google.com/docs/perf-mon/best-practices)

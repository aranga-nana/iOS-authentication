# Lesson 10: Testing, Documentation & Deployment
**Duration**: 12-16 hours  
**Phase**: 3 | **Week**: 8  
**Prerequisites**: Complete secure authentication system

## 🎯 Learning Objectives
- Implement comprehensive testing strategies for iOS and backend
- Create professional documentation for APIs and setup procedures
- Set up CI/CD pipelines for automated deployment
- Prepare for App Store submission and production deployment
- Understand monitoring and maintenance best practices

---

## 📚 Theory Overview

### Testing Pyramid for Mobile Authentication
```
                    ┌─────────────────┐
                    │   UI Tests      │ ← Few, Slow, Expensive
                    │   (10-20%)      │
                ┌───┴─────────────────┴───┐
                │  Integration Tests      │ ← Some, Medium Cost
                │     (20-30%)           │
            ┌───┴─────────────────────────┴───┐
            │      Unit Tests                 │ ← Many, Fast, Cheap
            │       (50-70%)                  │
            └─────────────────────────────────┘
```

### Documentation Types
- **API Documentation**: Endpoints, parameters, responses
- **Setup Documentation**: Installation and configuration
- **Architecture Documentation**: System design and flows
- **User Documentation**: Features and usage guides

### Deployment Strategies
- **Blue-Green Deployment**: Zero-downtime deployments
- **Canary Releases**: Gradual rollout to subset of users
- **Feature Flags**: Control feature visibility
- **Rolling Updates**: Incremental updates

---

## 🛠 Implementation Guide

### Step 1: Comprehensive Testing Implementation

#### 1.1 iOS Unit Tests
```swift
// Tests/AuthenticationManagerTests.swift
import XCTest
import Combine
@testable import YourApp

class AuthenticationManagerTests: XCTestCase {
    var authManager: AuthenticationManager!
    var mockNetworkManager: MockNetworkManager!
    var mockKeychainManager: MockKeychainManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockNetworkManager = MockNetworkManager()
        mockKeychainManager = MockKeychainManager()
        authManager = AuthenticationManager(
            networkManager: mockNetworkManager,
            keychainManager: mockKeychainManager
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        authManager = nil
        mockNetworkManager = nil
        mockKeychainManager = nil
        cancellables = nil
    }
    
    func testSuccessfulEmailPasswordSignIn() async throws {
        // Given
        let expectedUser = MockUser(id: "123", email: "test@example.com", displayName: "Test User")
        let expectedToken = "mock-token-123"
        
        mockNetworkManager.signInResult = .success(AuthResponse(
            user: expectedUser,
            accessToken: expectedToken,
            refreshToken: "refresh-token",
            idToken: "id-token"
        ))
        
        // When
        let result = try await authManager.signIn(
            email: "test@example.com",
            password: "password123"
        )
        
        // Then
        XCTAssertEqual(result.user.email, expectedUser.email)
        XCTAssertEqual(result.accessToken, expectedToken)
        XCTAssertTrue(authManager.isAuthenticated)
        
        // Verify keychain storage
        XCTAssertEqual(mockKeychainManager.storedAccessToken, expectedToken)
    }
    
    func testSignInWithInvalidCredentials() async {
        // Given
        mockNetworkManager.signInResult = .failure(AuthError.invalidCredentials)
        
        // When & Then
        do {
            _ = try await authManager.signIn(
                email: "test@example.com",
                password: "wrongpassword"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? AuthError, AuthError.invalidCredentials)
            XCTAssertFalse(authManager.isAuthenticated)
        }
    }
    
    func testTokenRefreshFlow() async throws {
        // Given
        let refreshToken = "valid-refresh-token"
        let newAccessToken = "new-access-token"
        
        mockKeychainManager.refreshToken = refreshToken
        mockNetworkManager.refreshTokenResult = .success(AuthResponse(
            user: MockUser(id: "123", email: "test@example.com"),
            accessToken: newAccessToken,
            refreshToken: "new-refresh-token",
            idToken: "new-id-token"
        ))
        
        // When
        let result = try await authManager.refreshToken()
        
        // Then
        XCTAssertEqual(result, newAccessToken)
        XCTAssertEqual(mockKeychainManager.storedAccessToken, newAccessToken)
    }
    
    func testAutoLogoutOnTokenExpiry() {
        // Given
        authManager.setAuthenticatedState(user: MockUser(id: "123"), token: "expired-token")
        let logoutExpectation = expectation(description: "User logged out")
        
        authManager.authStatePublisher
            .sink { state in
                if state == .unauthenticated {
                    logoutExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        authManager.handleTokenExpiry()
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(authManager.isAuthenticated)
    }
    
    func testConcurrentSignInRequests() async throws {
        // Given
        mockNetworkManager.signInDelay = 0.5 // Simulate network delay
        mockNetworkManager.signInResult = .success(AuthResponse(
            user: MockUser(id: "123", email: "test@example.com"),
            accessToken: "token",
            refreshToken: "refresh",
            idToken: "id"
        ))
        
        // When - Make concurrent sign-in requests
        async let result1 = authManager.signIn(email: "test@example.com", password: "password")
        async let result2 = authManager.signIn(email: "test@example.com", password: "password")
        async let result3 = authManager.signIn(email: "test@example.com", password: "password")
        
        let results = try await [result1, result2, result3]
        
        // Then - Only one network request should be made
        XCTAssertEqual(mockNetworkManager.signInCallCount, 1)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.user.email == "test@example.com" })
    }
}

// Mock implementations
class MockNetworkManager: NetworkManagerProtocol {
    var signInResult: Result<AuthResponse, Error> = .failure(NetworkError.unknown)
    var refreshTokenResult: Result<AuthResponse, Error> = .failure(NetworkError.unknown)
    var signInCallCount = 0
    var signInDelay: TimeInterval = 0
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        signInCallCount += 1
        
        if signInDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(signInDelay * 1_000_000_000))
        }
        
        switch signInResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
    
    func refreshToken(_ token: String) async throws -> AuthResponse {
        switch refreshTokenResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

class MockKeychainManager: KeychainManagerProtocol {
    var storedAccessToken: String?
    var storedRefreshToken: String?
    var storedIdToken: String?
    var refreshToken: String?
    
    func storeAccessToken(_ token: String) throws {
        storedAccessToken = token
    }
    
    func getAccessToken() -> String? {
        return storedAccessToken
    }
    
    func storeRefreshToken(_ token: String) throws {
        storedRefreshToken = token
    }
    
    func getRefreshToken() -> String? {
        return refreshToken
    }
    
    func clearAllTokens() throws {
        storedAccessToken = nil
        storedRefreshToken = nil
        storedIdToken = nil
    }
}
```

#### 1.2 Lambda Unit Tests
```javascript
// __tests__/user-registration.test.js
const AWSMock = require('aws-sdk-mock');
const AWS = require('aws-sdk');
const { handler } = require('../user-registration/index');

describe('User Registration Lambda Tests', () => {
    beforeEach(() => {
        AWSMock.setSDKInstance(AWS);
        process.env.JWT_SECRET = 'test-secret';
        process.env.USERS_TABLE = 'Users';
        process.env.SESSIONS_TABLE = 'UserSessions';
    });

    afterEach(() => {
        AWSMock.restore('DynamoDB.DocumentClient');
        delete process.env.JWT_SECRET;
        delete process.env.USERS_TABLE;
        delete process.env.SESSIONS_TABLE;
    });

    describe('Successful Registration', () => {
        test('should register new user with email and password', async () => {
            // Mock DynamoDB query (user doesn't exist)
            AWSMock.mock('DynamoDB.DocumentClient', 'query', (params, callback) => {
                callback(null, { Items: [] });
            });

            // Mock DynamoDB put (save user)
            AWSMock.mock('DynamoDB.DocumentClient', 'put', (params, callback) => {
                expect(params.TableName).toBe('Users');
                expect(params.Item.email).toBe('test@example.com');
                expect(params.Item.displayName).toBe('Test User');
                expect(params.Item.passwordHash).toBeDefined();
                callback(null, {});
            });

            const event = {
                body: JSON.stringify({
                    email: 'test@example.com',
                    password: 'SecurePass123!',
                    displayName: 'Test User',
                    authProvider: 'email'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(201);
            expect(body.message).toBe('User created successfully');
            expect(body.user.email).toBe('test@example.com');
            expect(body.user.passwordHash).toBeUndefined(); // Should not be in response
        });

        test('should register new user with Google authentication', async () => {
            // Mock DynamoDB query (user doesn't exist)
            AWSMock.mock('DynamoDB.DocumentClient', 'query', (params, callback) => {
                callback(null, { Items: [] });
            });

            // Mock DynamoDB put (save user)
            AWSMock.mock('DynamoDB.DocumentClient', 'put', (params, callback) => {
                expect(params.Item.firebaseUid).toBe('google-uid-123');
                expect(params.Item.authProvider).toBe('google');
                callback(null, {});
            });

            const event = {
                body: JSON.stringify({
                    email: 'test@gmail.com',
                    displayName: 'Test User',
                    authProvider: 'google',
                    firebaseUid: 'google-uid-123'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(201);
            expect(body.user.authProvider).toBe('google');
        });
    });

    describe('Validation Errors', () => {
        test('should return 400 for missing email', async () => {
            const event = {
                body: JSON.stringify({
                    password: 'password123',
                    displayName: 'Test User'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(400);
            expect(body.error).toBe('Email and password or Firebase UID required');
        });

        test('should return 400 for weak password', async () => {
            const event = {
                body: JSON.stringify({
                    email: 'test@example.com',
                    password: '123', // Too weak
                    displayName: 'Test User'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(400);
            expect(body.error).toContain('password');
        });

        test('should return 400 for invalid email format', async () => {
            const event = {
                body: JSON.stringify({
                    email: 'invalid-email',
                    password: 'SecurePass123!',
                    displayName: 'Test User'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(400);
            expect(body.error).toContain('email');
        });
    });

    describe('Duplicate User Handling', () => {
        test('should return 409 for existing user', async () => {
            // Mock DynamoDB query (user exists)
            AWSMock.mock('DynamoDB.DocumentClient', 'query', (params, callback) => {
                callback(null, { 
                    Items: [{ 
                        userId: 'existing-user-123',
                        email: 'test@example.com' 
                    }] 
                });
            });

            const event = {
                body: JSON.stringify({
                    email: 'test@example.com',
                    password: 'password123',
                    displayName: 'Test User'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(409);
            expect(body.error).toBe('User already exists');
        });
    });

    describe('Error Handling', () => {
        test('should handle DynamoDB errors gracefully', async () => {
            // Mock DynamoDB error
            AWSMock.mock('DynamoDB.DocumentClient', 'query', (params, callback) => {
                callback(new Error('DynamoDB service unavailable'), null);
            });

            const event = {
                body: JSON.stringify({
                    email: 'test@example.com',
                    password: 'password123',
                    displayName: 'Test User'
                })
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(500);
            expect(body.error).toBe('Internal server error');
        });

        test('should handle malformed JSON', async () => {
            const event = {
                body: 'invalid json'
            };

            const result = await handler(event);
            const body = JSON.parse(result.body);

            expect(result.statusCode).toBe(400);
            expect(body.error).toContain('Invalid JSON');
        });
    });
});
```

#### 1.3 Integration Tests
```swift
// Tests/IntegrationTests.swift
import XCTest
@testable import YourApp

class AuthenticationIntegrationTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testCompleteAuthenticationFlow() throws {
        // Test sign up flow
        testSignUpFlow()
        
        // Test sign out
        testSignOut()
        
        // Test sign in flow
        testSignInFlow()
        
        // Test authenticated state persistence
        testAuthStatePersistence()
    }
    
    private func testSignUpFlow() {
        // Navigate to sign up
        app.buttons["Sign Up"].tap()
        
        // Fill out form
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("integrationtest@example.com")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("TestPassword123!")
        
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        confirmPasswordField.tap()
        confirmPasswordField.typeText("TestPassword123!")
        
        let nameField = app.textFields["Display Name"]
        nameField.tap()
        nameField.typeText("Integration Test User")
        
        // Submit form
        app.buttons["Create Account"].tap()
        
        // Verify success
        let welcomeText = app.staticTexts["Welcome, Integration Test User!"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 10))
    }
    
    private func testSignOut() {
        app.buttons["Profile"].tap()
        app.buttons["Sign Out"].tap()
        
        // Verify back to login screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
    }
    
    private func testSignInFlow() {
        // Fill login form
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("integrationtest@example.com")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("TestPassword123!")
        
        app.buttons["Sign In"].tap()
        
        // Verify successful login
        let welcomeText = app.staticTexts["Welcome, Integration Test User!"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 10))
    }
    
    private func testAuthStatePersistence() {
        // Terminate and relaunch app
        app.terminate()
        app.launch()
        
        // Should still be logged in
        let welcomeText = app.staticTexts["Welcome, Integration Test User!"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
    }
    
    func testGoogleSignInFlow() throws {
        app.buttons["Sign in with Google"].tap()
        
        // Wait for Google sign-in web view
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 10))
        
        // This would require setting up test Google credentials
        // For now, just verify the web view appears
    }
    
    func testOfflineMode() throws {
        // Simulate offline mode
        app.launchArguments.append("--offline-mode")
        app.terminate()
        app.launch()
        
        // Verify offline message appears
        let offlineMessage = app.staticTexts["You're offline"]
        XCTAssertTrue(offlineMessage.waitForExistence(timeout: 5))
        
        // Try to sign in offline - should queue operation
        app.buttons["Sign In"].tap()
        
        let queuedMessage = app.staticTexts["Operation queued for when online"]
        XCTAssertTrue(queuedMessage.waitForExistence(timeout: 5))
    }
}
```

### Step 2: Comprehensive Documentation

#### 2.1 API Documentation
```markdown
<!-- docs/API_DOCUMENTATION.md -->
# iOS Authentication API Documentation

## Base URL
```
https://your-api-id.execute-api.us-east-1.amazonaws.com/prod
```

## Authentication
All protected endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <access_token>
```

## Endpoints

### 1. User Registration
**POST** `/auth/register`

Register a new user with email/password or Google authentication.

#### Request Body
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!", // Required for email auth
  "displayName": "John Doe",
  "authProvider": "email|google",
  "firebaseUid": "firebase-uid-here" // Required for Google auth
}
```

#### Success Response (201)
```json
{
  "message": "User created successfully",
  "user": {
    "userId": "uuid-v4",
    "email": "user@example.com",
    "displayName": "John Doe",
    "authProvider": "email",
    "isActive": true,
    "createdAt": "2025-06-07T10:30:00Z",
    "updatedAt": "2025-06-07T10:30:00Z"
  }
}
```

#### Error Responses
| Status | Error | Description |
|--------|-------|-------------|
| 400 | `Invalid email format` | Email is not valid |
| 400 | `Password too weak` | Password doesn't meet requirements |
| 409 | `User already exists` | User with email already registered |
| 500 | `Internal server error` | Server error occurred |

### 2. User Authentication
**POST** `/auth/login`

Authenticate existing user and receive access tokens.

#### Request Body
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!", // For email auth
  "authProvider": "email|google",
  "firebaseUid": "firebase-uid-here" // For Google auth
}
```

#### Success Response (200)
```json
{
  "message": "Authentication successful",
  "user": {
    "userId": "uuid-v4",
    "email": "user@example.com",
    "displayName": "John Doe",
    "authProvider": "email",
    "isActive": true
  },
  "token": "jwt-access-token",
  "refreshToken": "refresh-token-here",
  "expiresIn": 86400
}
```

#### Error Responses
| Status | Error | Description |
|--------|-------|-------------|
| 400 | `Missing credentials` | Email/password or Firebase UID required |
| 401 | `Invalid credentials` | Wrong email/password combination |
| 403 | `Account disabled` | User account is deactivated |
| 429 | `Too many attempts` | Rate limit exceeded |

### 3. Token Validation
**GET** `/auth/validate`

Validate access token and get user information.

#### Headers
```
Authorization: Bearer <access_token>
```

#### Success Response (200)
```json
{
  "message": "Token is valid",
  "user": {
    "userId": "uuid-v4",
    "email": "user@example.com",
    "displayName": "John Doe",
    "authProvider": "email",
    "isActive": true
  },
  "session": {
    "sessionId": "session-uuid",
    "expiresAt": "2025-06-08T10:30:00Z"
  }
}
```

#### Error Responses
| Status | Error | Description |
|--------|-------|-------------|
| 401 | `Missing token` | Authorization header not provided |
| 401 | `Invalid token` | Token is malformed or expired |
| 401 | `Session expired` | Session no longer valid |

## Rate Limiting
| Endpoint | Limit | Window |
|----------|-------|--------|
| `/auth/register` | 3 requests | 1 hour |
| `/auth/login` | 5 requests | 15 minutes |
| `/auth/validate` | 10 requests | 1 minute |

## Error Response Format
All error responses follow this format:
```json
{
  "error": "Error message",
  "details": "Additional details if available",
  "timestamp": "2025-06-07T10:30:00Z",
  "requestId": "uuid-v4"
}
```

## Security Considerations
- All requests must use HTTPS
- Passwords must be at least 8 characters with uppercase, lowercase, numbers, and symbols
- Tokens expire after 24 hours
- Rate limiting is enforced per IP address
- All sensitive data is encrypted in transit and at rest
```

#### 2.2 Setup Documentation
```markdown
<!-- docs/SETUP_GUIDE.md -->
# iOS Authentication System - Setup Guide

## Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later target
- AWS Account with CLI configured
- Firebase project set up
- Google Cloud Console project for OAuth

## iOS App Setup

### 1. Clone and Configure Project
```bash
git clone https://github.com/yourusername/ios-auth-app.git
cd ios-auth-app
```

### 2. Install Dependencies
```bash
# Install CocoaPods dependencies
pod install

# Open workspace (not project)
open iOSAuthApp.xcworkspace
```

### 3. Firebase Configuration
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add file to Xcode project root
3. Update `Info.plist` with URL schemes:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

### 4. Google Sign-In Setup
1. Create OAuth 2.0 Client ID in Google Cloud Console
2. Add iOS URL scheme to `Info.plist`
3. Update `GoogleService-Info.plist` with client ID

### 5. Environment Configuration
Create `Config.plist` with your settings:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_BASE_URL</key>
    <string>https://your-api-id.execute-api.us-east-1.amazonaws.com/prod</string>
    <key>ENVIRONMENT</key>
    <string>development</string>
</dict>
</plist>
```

## AWS Backend Setup

### 1. Configure AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

### 2. Deploy DynamoDB Tables
```bash
cd Backend/scripts
./create-dynamodb-tables.sh
```

### 3. Deploy Lambda Functions
```bash
# Update ROLE_ARN in deploy script
./deploy-lambdas.sh
```

### 4. Setup API Gateway
```bash
# Update configuration in script
./setup-api-gateway.sh
```

### 5. Configure Environment Variables
Set Lambda environment variables:
```bash
aws lambda update-function-configuration \
    --function-name user-registration \
    --environment Variables='{
        JWT_SECRET=your-super-secret-jwt-key,
        USERS_TABLE=Users,
        SESSIONS_TABLE=UserSessions
    }'
```

## Testing Setup

### 1. Run Unit Tests
```bash
# iOS Tests
xcodebuild test -workspace iOSAuthApp.xcworkspace -scheme iOSAuthApp

# Lambda Tests
cd Backend/Lambda/user-registration
npm test
```

### 2. Integration Testing
```bash
# Update API endpoint in test configuration
cd Backend/scripts
./run-integration-tests.sh
```

## Production Deployment

### 1. App Store Preparation
1. Update app version and build number
2. Configure App Store Connect
3. Upload build via Xcode or Transporter
4. Submit for review

### 2. AWS Production Setup
1. Create production AWS environment
2. Update environment variables
3. Configure custom domain
4. Enable CloudWatch monitoring

## Troubleshooting

### Common Issues

#### Firebase Configuration
**Error**: "GoogleService-Info.plist not found"
**Solution**: Ensure plist file is added to Xcode project bundle

#### AWS Lambda Deployment
**Error**: "Role does not exist"
**Solution**: Create IAM role with proper permissions:
```bash
aws iam create-role --role-name AuthLambdaExecutionRole --assume-role-policy-document file://trust-policy.json
```

#### API Gateway CORS
**Error**: "CORS policy blocked"
**Solution**: Configure CORS in API Gateway:
```bash
aws apigateway put-method --rest-api-id YOUR_API_ID --resource-id RESOURCE_ID --http-method OPTIONS --authorization-type NONE
```

### Support
- Check logs in Xcode Console for iOS issues
- Check CloudWatch Logs for Lambda issues
- Verify network connectivity and API endpoints
- Ensure all environment variables are set correctly

## Security Checklist
- [ ] HTTPS only in production
- [ ] Strong JWT secret configured
- [ ] Rate limiting enabled
- [ ] Input validation implemented
- [ ] Secrets not in source code
- [ ] Certificate pinning configured
- [ ] Keychain access properly configured
```

### Step 3: CI/CD Pipeline Setup

#### 3.1 GitHub Actions for iOS
```yaml
# .github/workflows/ios.yml
name: iOS CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  XCODE_VERSION: 15.0

jobs:
  test:
    name: Test iOS App
    runs-on: macos-14
    
    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
      
    - name: Select Xcode Version
      run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
      
    - name: Install CocoaPods
      run: |
        gem install cocoapods
        pod install
        
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -workspace iOSAuthApp.xcworkspace \
          -scheme iOSAuthApp \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData
          
    - name: Generate Test Report
      run: |
        xcparse --output-format json DerivedData/Logs/Test/*.xcresult > test_results.json
        
    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: test_results.json
        
    - name: Check Code Coverage
      run: |
        xcrun xccov view --report --json DerivedData/Logs/Test/*.xcresult > coverage.json
        COVERAGE=$(cat coverage.json | jq '.targets[] | select(.name=="iOSAuthApp") | .lineCoverage')
        echo "Code coverage: $COVERAGE"
        if (( $(echo "$COVERAGE < 0.8" | bc -l) )); then
          echo "Code coverage below 80%"
          exit 1
        fi

  security-scan:
    name: Security Scan
    runs-on: macos-14
    needs: test
    
    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
      
    - name: Run Security Scan
      run: |
        # Install security scanning tools
        brew install semgrep
        
        # Run static analysis
        semgrep --config=auto --json --output=security-report.json .
        
    - name: Upload Security Report
      uses: actions/upload-artifact@v3
      with:
        name: security-report
        path: security-report.json

  build:
    name: Build and Archive
    runs-on: macos-14
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
      
    - name: Install Certificates
      env:
        BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
        P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
        BUILD_PROVISION_PROFILE_BASE64: ${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}
      run: |
        # Create temporary keychain
        KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
        security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        security set-keychain-settings -lut 21600 build.keychain
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        
        # Import certificate
        echo $BUILD_CERTIFICATE_BASE64 | base64 --decode > certificate.p12
        security import certificate.p12 -k build.keychain -P $P12_PASSWORD -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain
        
        # Install provisioning profile
        echo $BUILD_PROVISION_PROFILE_BASE64 | base64 --decode > build_pp.mobileprovision
        mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
        cp build_pp.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles
        
    - name: Install CocoaPods
      run: |
        pod install
        
    - name: Build Archive
      run: |
        xcodebuild archive \
          -workspace iOSAuthApp.xcworkspace \
          -scheme iOSAuthApp \
          -destination generic/platform=iOS \
          -archivePath iOSAuthApp.xcarchive \
          CODE_SIGN_STYLE=Manual
          
    - name: Export IPA
      run: |
        xcodebuild -exportArchive \
          -archivePath iOSAuthApp.xcarchive \
          -exportPath . \
          -exportOptionsPlist ExportOptions.plist
          
    - name: Upload to TestFlight
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
      run: |
        xcrun altool --upload-app \
          --type ios \
          --file iOSAuthApp.ipa \
          --username "$APPLE_ID" \
          --password "$APPLE_PASSWORD"
```

#### 3.2 AWS Lambda CI/CD
```yaml
# .github/workflows/lambda.yml
name: Lambda CI/CD

on:
  push:
    branches: [ main, develop ]
    paths: [ 'Backend/Lambda/**' ]
  pull_request:
    branches: [ main ]
    paths: [ 'Backend/Lambda/**' ]

jobs:
  test:
    name: Test Lambda Functions
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
      
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: Backend/Lambda/package-lock.json
        
    - name: Install Dependencies
      run: |
        cd Backend/Lambda
        npm ci
        
    - name: Run Unit Tests
      run: |
        cd Backend/Lambda
        npm test -- --coverage --verbose
        
    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        directory: Backend/Lambda/coverage
        
    - name: Security Scan
      run: |
        cd Backend/Lambda
        npm audit --audit-level high
        
  deploy-dev:
    name: Deploy to Development
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/develop'
    environment: development
    
    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
      
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
        
    - name: Deploy Lambda Functions
      run: |
        cd Backend/scripts
        chmod +x deploy-lambdas.sh
        ./deploy-lambdas.sh dev
        
    - name: Run Integration Tests
      run: |
        cd Backend/scripts
        chmod +x integration-tests.sh
        ./integration-tests.sh dev
        
  deploy-prod:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
    - name: Checkout Code
      uses: actions/checkout@v3
      
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
        aws-region: us-east-1
        
    - name: Deploy with Blue-Green Strategy
      run: |
        cd Backend/scripts
        chmod +x blue-green-deploy.sh
        ./blue-green-deploy.sh
        
    - name: Smoke Tests
      run: |
        cd Backend/scripts
        chmod +x smoke-tests.sh
        ./smoke-tests.sh
        
    - name: Update CloudFormation
      run: |
        aws cloudformation deploy \
          --template-file Backend/cloudformation/infrastructure.yaml \
          --stack-name ios-auth-prod \
          --parameter-overrides Environment=production \
          --capabilities CAPABILITY_IAM
```

### Step 4: Monitoring and Alerting

#### 4.1 CloudWatch Monitoring Setup
```javascript
// monitoring/cloudwatch-setup.js
const AWS = require('aws-sdk');
const cloudWatch = new AWS.CloudWatch();

class MonitoringSetup {
    static async createDashboard() {
        const dashboardBody = {
            widgets: [
                {
                    type: "metric",
                    properties: {
                        metrics: [
                            ["iOS-Auth-App", "Successes", "FunctionName", "user-registration"],
                            [".", "Errors", ".", "."],
                            [".", "ExecutionDuration", ".", "."]
                        ],
                        period: 300,
                        stat: "Sum",
                        region: "us-east-1",
                        title: "User Registration Metrics"
                    }
                },
                {
                    type: "metric",
                    properties: {
                        metrics: [
                            ["AWS/Lambda", "Invocations", "FunctionName", "user-authentication"],
                            [".", "Errors", ".", "."],
                            [".", "Duration", ".", "."]
                        ],
                        period: 300,
                        stat: "Average",
                        region: "us-east-1",
                        title: "Authentication Performance"
                    }
                }
            ]
        };

        const params = {
            DashboardName: 'iOS-Auth-Dashboard',
            DashboardBody: JSON.stringify(dashboardBody)
        };

        try {
            await cloudWatch.putDashboard(params).promise();
            console.log('Dashboard created successfully');
        } catch (error) {
            console.error('Failed to create dashboard:', error);
        }
    }

    static async createAlarms() {
        const alarms = [
            {
                AlarmName: 'High-Error-Rate',
                ComparisonOperator: 'GreaterThanThreshold',
                EvaluationPeriods: 2,
                MetricName: 'Errors',
                Namespace: 'iOS-Auth-App',
                Period: 300,
                Statistic: 'Sum',
                Threshold: 10,
                ActionsEnabled: true,
                AlarmActions: [process.env.SNS_TOPIC_ARN],
                AlarmDescription: 'Alert when error rate is high',
                Dimensions: [
                    {
                        Name: 'FunctionName',
                        Value: 'user-authentication'
                    }
                ]
            },
            {
                AlarmName: 'Slow-Response-Time',
                ComparisonOperator: 'GreaterThanThreshold',
                EvaluationPeriods: 2,
                MetricName: 'ExecutionDuration',
                Namespace: 'iOS-Auth-App',
                Period: 300,
                Statistic: 'Average',
                Threshold: 5000,
                ActionsEnabled: true,
                AlarmActions: [process.env.SNS_TOPIC_ARN],
                AlarmDescription: 'Alert when response time is slow'
            }
        ];

        for (const alarm of alarms) {
            try {
                await cloudWatch.putMetricAlarm(alarm).promise();
                console.log(`Alarm ${alarm.AlarmName} created successfully`);
            } catch (error) {
                console.error(`Failed to create alarm ${alarm.AlarmName}:`, error);
            }
        }
    }
}

module.exports = MonitoringSetup;
```

---

## 📊 Testing and Validation

### Test Coverage Requirements
- **Unit Tests**: Minimum 80% code coverage
- **Integration Tests**: All critical authentication flows
- **UI Tests**: Complete user journey testing
- **Performance Tests**: Response time under 2 seconds
- **Security Tests**: OWASP top 10 validation

### Production Readiness Checklist
- [ ] **Functionality**: All features working as expected
- [ ] **Performance**: Load testing completed successfully
- [ ] **Security**: Security audit passed
- [ ] **Monitoring**: Alerts and dashboards configured
- [ ] **Documentation**: Complete and up-to-date
- [ ] **Backup**: Data backup strategy implemented
- [ ] **Recovery**: Disaster recovery plan tested

---

## 📝 Practice Exercises

### Exercise 1: Test Implementation (6 hours)
1. Write comprehensive unit tests for all authentication managers
2. Implement integration tests for API endpoints
3. Create UI tests for complete user flows
4. Set up performance testing with baseline metrics

### Exercise 2: Documentation Creation (4 hours)
1. Create API documentation with examples
2. Write setup guide for new developers
3. Document architecture and design decisions
4. Create troubleshooting guide

### Exercise 3: CI/CD Pipeline (6 hours)
1. Set up GitHub Actions for automated testing
2. Implement automated deployment to staging
3. Create blue-green deployment strategy
4. Set up monitoring and alerting

---

## 📊 Final Assignment: Production Deployment

### Requirements:
1. **Complete Testing Suite** (6 hours)
   - Unit tests with 85%+ coverage
   - Integration tests for all endpoints
   - UI tests for critical user flows
   - Performance benchmarks documented

2. **Professional Documentation** (4 hours)
   - API documentation with interactive examples
   - Complete setup and deployment guide
   - Architecture documentation with diagrams
   - User manual and troubleshooting guide

3. **Production Deployment** (6 hours)
   - Set up production AWS environment
   - Deploy using CI/CD pipeline
   - Configure monitoring and alerting
   - Perform production smoke tests

### Deliverables:
- [ ] Complete test suite with reports
- [ ] Professional documentation set
- [ ] Working CI/CD pipeline
- [ ] Production deployment with monitoring
- [ ] Security audit report
- [ ] Performance benchmarks
- [ ] User acceptance testing results

---

## ✅ Lesson Completion Checklist

- [ ] Implement comprehensive unit tests for iOS and Lambda
- [ ] Create integration tests for complete authentication flow
- [ ] Set up UI tests for critical user journeys
- [ ] Write professional API documentation
- [ ] Create detailed setup and deployment guides
- [ ] Implement CI/CD pipeline with automated testing
- [ ] Set up production monitoring and alerting
- [ ] Conduct security audit and penetration testing
- [ ] Perform load testing and performance optimization
- [ ] Deploy to production environment successfully
- [ ] Validate all functionality in production
- [ ] Document lessons learned and best practices

**Estimated Time to Complete**: 12-16 hours  
**Congratulations!** You've built a production-ready iOS authentication system!

---

## 🎉 Course Completion

**You have successfully completed the iOS Authentication System course!**

### What You've Accomplished:
- ✅ Built a complete iOS authentication app with SwiftUI
- ✅ Implemented Firebase Auth with Google Sign-In
- ✅ Created scalable AWS backend with Lambda and DynamoDB  
- ✅ Applied security best practices and performance optimization
- ✅ Set up comprehensive testing and monitoring
- ✅ Deployed to production with CI/CD pipeline

### Next Steps:
1. **Expand Features**: Add social logins, 2FA, profile management
2. **Scale Architecture**: Implement microservices, caching layers
3. **Mobile Platform**: Adapt for Android development
4. **Advanced Security**: Add biometric auth, advanced threat detection
5. **Portfolio**: Showcase your project in interviews and GitHub

**Keep building amazing apps! 🚀**

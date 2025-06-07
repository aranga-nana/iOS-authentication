# Lesson 9: Security & Performance Optimization
**Duration**: 15-20 hours  
**Phase**: 3 | **Week**: 7  
**Prerequisites**: Complete authentication system working

## 🎯 Learning Objectives
- Implement advanced security hardening techniques
- Optimize application performance and user experience
- Add comprehensive error handling and recovery
- Implement offline capabilities and data synchronization
- Understand security testing and vulnerability assessment

---

## 📚 Theory Overview

### Security Hardening Principles
- **Defense in Depth**: Multiple layers of security controls
- **Zero Trust Architecture**: Never trust, always verify
- **Principle of Least Privilege**: Minimal access rights
- **Security by Design**: Built-in, not bolted-on security

### Performance Optimization Areas
```
┌─────────────────┬──────────────────┬─────────────────┐
│ iOS App Layer   │ Network Layer    │ Backend Layer   │
├─────────────────┼──────────────────┼─────────────────┤
│ • Memory Mgmt   │ • Request Batching│ • Lambda Tuning │
│ • UI Rendering  │ • Caching        │ • DB Optimization│
│ • Data Storage  │ • Compression    │ • Cold Start Fix │
│ • Battery Life  │ • CDN Usage      │ • Monitoring    │
└─────────────────┴──────────────────┴─────────────────┘
```

---

## 🛠 Implementation Guide

### Step 1: Advanced Security Implementation

#### 1.1 Certificate Pinning
```swift
// Network/CertificatePinning.swift
import Foundation
import Network

class CertificatePinningManager: NSObject {
    static let shared = CertificatePinningManager()
    
    private let pinnedCertificates: [String: [SecCertificate]] = [
        "your-api-domain.com": [loadCertificate(name: "api-cert")]
    ]
    
    private static func loadCertificate(name: String) -> SecCertificate? {
        guard let certPath = Bundle.main.path(forResource: name, ofType: "cer"),
              let certData = NSData(contentsOfFile: certPath),
              let certificate = SecCertificateCreateWithData(nil, certData) else {
            return nil
        }
        return certificate
    }
    
    func validateCertificate(for host: String, certificates: [SecCertificate]) -> Bool {
        guard let pinnedCerts = pinnedCertificates[host] else {
            print("⚠️ No pinned certificates for host: \(host)")
            return false
        }
        
        for cert in certificates {
            let certData = SecCertificateCopyData(cert)
            
            for pinnedCert in pinnedCerts {
                let pinnedCertData = SecCertificateCopyData(pinnedCert)
                if CFEqual(certData, pinnedCertData) {
                    return true
                }
            }
        }
        
        print("⚠️ Certificate validation failed for: \(host)")
        return false
    }
}

// Updated NetworkManager with Certificate Pinning
extension NetworkManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, 
                   didReceive challenge: URLAuthenticationChallenge, 
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get server certificates
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        var certificates: [SecCertificate] = []
        
        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                certificates.append(certificate)
            }
        }
        
        // Validate with pinned certificates
        let host = challenge.protectionSpace.host
        if CertificatePinningManager.shared.validateCertificate(for: host, certificates: certificates) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

#### 1.2 Enhanced Token Security
```swift
// Security/TokenSecurityManager.swift
import Foundation
import CryptoKit

class TokenSecurityManager {
    static let shared = TokenSecurityManager()
    
    private let keychain = KeychainManager.shared
    private let biometricAuth = BiometricAuthManager.shared
    
    // Token refresh with automatic retry and backoff
    @MainActor
    func refreshTokenWithRetry(maxRetries: Int = 3) async throws -> String {
        var lastError: Error?
        var delay: TimeInterval = 1.0
        
        for attempt in 1...maxRetries {
            do {
                return try await refreshToken()
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    print("Token refresh attempt \(attempt) failed, retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2 // Exponential backoff
                }
            }
        }
        
        throw lastError ?? AuthError.tokenRefreshFailed
    }
    
    private func refreshToken() async throws -> String {
        guard let refreshToken = keychain.getRefreshToken() else {
            throw AuthError.noRefreshToken
        }
        
        let request = AuthRequest.refreshToken(refreshToken: refreshToken)
        let response: AuthResponse = try await NetworkManager.shared.perform(request)
        
        // Store new tokens securely
        try await storeTokensSecurely(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            idToken: response.idToken
        )
        
        return response.accessToken
    }
    
    // Secure token storage with encryption
    private func storeTokensSecurely(accessToken: String, 
                                   refreshToken: String?, 
                                   idToken: String?) async throws {
        
        // Encrypt tokens before storage
        let encryptedAccessToken = try encryptToken(accessToken)
        try keychain.storeAccessToken(encryptedAccessToken)
        
        if let refreshToken = refreshToken {
            let encryptedRefreshToken = try encryptToken(refreshToken)
            try keychain.storeRefreshToken(encryptedRefreshToken)
        }
        
        if let idToken = idToken {
            let encryptedIdToken = try encryptToken(idToken)
            try keychain.storeIdToken(encryptedIdToken)
        }
        
        // Store encryption key with biometric protection
        try await storeMasterKeyWithBiometrics()
    }
    
    private func encryptToken(_ token: String) throws -> String {
        let key = try getMasterKey()
        let data = Data(token.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined?.base64EncodedString() ?? ""
    }
    
    private func decryptToken(_ encryptedToken: String) throws -> String {
        let key = try getMasterKey()
        guard let data = Data(base64Encoded: encryptedToken) else {
            throw SecurityError.decryptionFailed
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return String(data: decryptedData, encoding: .utf8) ?? ""
    }
    
    private func getMasterKey() throws -> SymmetricKey {
        // Implementation would retrieve or generate master key
        // This is a simplified version
        let keyData = Data("your-master-key-here".utf8)
        return SymmetricKey(data: keyData)
    }
    
    private func storeMasterKeyWithBiometrics() async throws {
        // Store master key with biometric protection
        // Implementation depends on your biometric authentication setup
    }
}
```

#### 1.3 API Security Hardening
```javascript
// lambda/security/api-security.js
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const crypto = require('crypto');

class APISecurityManager {
    static createSecurityHeaders() {
        return {
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block',
            'Content-Security-Policy': "default-src 'self'",
            'Referrer-Policy': 'strict-origin-when-cross-origin'
        };
    }
    
    static validateRequest(event) {
        const validationErrors = [];
        
        // Check request size
        if (event.body && Buffer.byteLength(event.body, 'utf8') > 1024 * 1024) {
            validationErrors.push('Request too large');
        }
        
        // Validate Content-Type
        const contentType = event.headers['Content-Type'] || event.headers['content-type'];
        if (contentType && !contentType.includes('application/json')) {
            validationErrors.push('Invalid content type');
        }
        
        // Check for suspicious patterns
        if (this.containsSuspiciousPatterns(event.body)) {
            validationErrors.push('Suspicious request content');
        }
        
        return validationErrors;
    }
    
    static containsSuspiciousPatterns(body) {
        if (!body) return false;
        
        const suspiciousPatterns = [
            /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
            /javascript:/gi,
            /vbscript:/gi,
            /on\w+\s*=/gi,
            /eval\s*\(/gi,
            /union\s+select/gi,
            /drop\s+table/gi
        ];
        
        return suspiciousPatterns.some(pattern => pattern.test(body));
    }
    
    static async checkRateLimit(identifier, action = 'default') {
        const key = `rate_limit:${action}:${identifier}`;
        const limits = {
            login: { max: 5, window: 15 * 60 * 1000 }, // 5 attempts per 15 minutes
            register: { max: 3, window: 60 * 60 * 1000 }, // 3 attempts per hour
            default: { max: 10, window: 60 * 1000 } // 10 requests per minute
        };
        
        const limit = limits[action] || limits.default;
        
        // This would use Redis or DynamoDB for production
        // Simplified implementation for demonstration
        return this.checkRateLimitInDynamoDB(key, limit);
    }
    
    static async checkRateLimitInDynamoDB(key, limit) {
        const AWS = require('aws-sdk');
        const dynamodb = new AWS.DynamoDB.DocumentClient();
        const now = Date.now();
        const windowStart = now - limit.window;
        
        try {
            // Get current attempts
            const result = await dynamodb.get({
                TableName: 'RateLimits',
                Key: { key }
            }).promise();
            
            let attempts = 0;
            let lastReset = now;
            
            if (result.Item) {
                attempts = result.Item.attempts || 0;
                lastReset = result.Item.lastReset || now;
                
                // Reset if window has passed
                if (lastReset < windowStart) {
                    attempts = 0;
                    lastReset = now;
                }
            }
            
            // Check limit
            if (attempts >= limit.max) {
                return { allowed: false, remainingAttempts: 0 };
            }
            
            // Increment attempts
            attempts++;
            await dynamodb.put({
                TableName: 'RateLimits',
                Item: {
                    key,
                    attempts,
                    lastReset,
                    expiresAt: Math.floor((now + limit.window) / 1000)
                }
            }).promise();
            
            return { 
                allowed: true, 
                remainingAttempts: limit.max - attempts 
            };
            
        } catch (error) {
            console.error('Rate limit check failed:', error);
            return { allowed: true, remainingAttempts: limit.max }; // Fail open
        }
    }
}

module.exports = APISecurityManager;
```

### Step 2: Performance Optimization

#### 2.1 iOS App Performance
```swift
// Performance/PerformanceOptimizer.swift
import Foundation
import Combine

class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private var performanceMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "performance.metrics", qos: .utility)
    
    // Network request optimization with caching
    func optimizeNetworkRequests() {
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024, // 50MB memory
                           diskCapacity: 100 * 1024 * 1024,   // 100MB disk
                           diskPath: "network_cache")
        URLCache.shared = cache
    }
    
    // Image loading optimization
    func optimizeImageLoading() {
        // Configure image cache and lazy loading
        ImageCache.shared.configure(
            memoryLimit: 100 * 1024 * 1024, // 100MB
            diskLimit: 500 * 1024 * 1024    // 500MB
        )
    }
    
    // Memory management optimization
    func optimizeMemoryUsage() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        ImageCache.shared.clearCache()
        
        // Clear unused data
        AuthenticationManager.shared.clearCachedData()
        
        print("🧹 Memory warning handled - caches cleared")
    }
    
    // Performance monitoring
    func startPerformanceTracking(operation: String) {
        metricsQueue.async {
            self.performanceMetrics[operation] = CFAbsoluteTimeGetCurrent()
        }
    }
    
    func endPerformanceTracking(operation: String) {
        metricsQueue.async {
            guard let startTime = self.performanceMetrics[operation] else { return }
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            print("⏱️ Performance: \(operation) took \(String(format: "%.3f", duration))s")
            
            // Log to analytics if needed
            AnalyticsManager.shared.trackPerformance(operation: operation, duration: duration)
            
            self.performanceMetrics.removeValue(forKey: operation)
        }
    }
    
    // Battery optimization
    func optimizeBatteryUsage() {
        // Reduce background refresh
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourapp.refresh", using: nil) { task in
                self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Minimal background work
        Task {
            do {
                try await AuthenticationManager.shared.refreshTokenIfNeeded()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
}
```

#### 2.2 Backend Performance Optimization
```javascript
// lambda/performance/lambda-optimizer.js
const AWS = require('aws-sdk');

class LambdaOptimizer {
    static warmupFunctions = new Set();
    
    // Cold start mitigation
    static async warmupFunction(functionName) {
        if (this.warmupFunctions.has(functionName)) return;
        
        const lambda = new AWS.Lambda();
        
        try {
            await lambda.invoke({
                FunctionName: functionName,
                InvocationType: 'Event',
                Payload: JSON.stringify({ warmup: true })
            }).promise();
            
            this.warmupFunctions.add(functionName);
            console.log(`🔥 Warmed up function: ${functionName}`);
        } catch (error) {
            console.error(`Failed to warm up ${functionName}:`, error);
        }
    }
    
    // Connection pooling for DynamoDB
    static createOptimizedDynamoClient() {
        return new AWS.DynamoDB.DocumentClient({
            maxRetries: 3,
            retryDelayOptions: {
                customBackoff: function(retryCount) {
                    return Math.pow(2, retryCount) * 100;
                }
            },
            httpOptions: {
                connectTimeout: 3000,
                timeout: 5000,
                agent: new AWS.NodeHttpClient({
                    keepAlive: true,
                    rejectUnauthorized: true,
                    secureProtocol: 'TLSv1_2_method'
                })
            }
        });
    }
    
    // Query optimization
    static optimizeQueries() {
        return {
            // Use consistent reads only when necessary
            consistentRead: false,
            
            // Project only needed attributes
            projectionExpression: '#userId, #email, #displayName, #isActive, #createdAt',
            expressionAttributeNames: {
                '#userId': 'userId',
                '#email': 'email',
                '#displayName': 'displayName',
                '#isActive': 'isActive',
                '#createdAt': 'createdAt'
            },
            
            // Use pagination for large result sets
            limit: 25
        };
    }
    
    // Caching layer
    static cache = new Map();
    static cacheExiry = new Map();
    
    static async getWithCache(key, fetchFunction, ttlSeconds = 300) {
        const now = Date.now();
        const expiry = this.cacheExiry.get(key);
        
        // Return cached value if not expired
        if (this.cache.has(key) && expiry && now < expiry) {
            return this.cache.get(key);
        }
        
        // Fetch fresh data
        try {
            const value = await fetchFunction();
            this.cache.set(key, value);
            this.cacheExiry.set(key, now + (ttlSeconds * 1000));
            return value;
        } catch (error) {
            // Return stale cache on error if available
            if (this.cache.has(key)) {
                console.warn(`Using stale cache for ${key} due to error:`, error);
                return this.cache.get(key);
            }
            throw error;
        }
    }
    
    static clearCache(pattern = null) {
        if (pattern) {
            for (const key of this.cache.keys()) {
                if (key.includes(pattern)) {
                    this.cache.delete(key);
                    this.cacheExiry.delete(key);
                }
            }
        } else {
            this.cache.clear();
            this.cacheExiry.clear();
        }
    }
}

module.exports = LambdaOptimizer;
```

### Step 3: Comprehensive Error Handling

#### 3.1 Advanced Error Management
```swift
// Error/ErrorManager.swift
import Foundation
import Combine

enum AppError: LocalizedError {
    case network(NetworkError)
    case authentication(AuthError)
    case security(SecurityError)
    case performance(PerformanceError)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .authentication(let error):
            return error.localizedDescription
        case .security(let error):
            return error.localizedDescription
        case .performance(let error):
            return error.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .network(.noConnection):
            return "Please check your internet connection and try again."
        case .network(.timeout):
            return "The request timed out. Please try again."
        case .authentication(.invalidCredentials):
            return "Invalid email or password. Please try again."
        case .authentication(.accountLocked):
            return "Your account has been temporarily locked for security reasons."
        case .security(.certificateValidationFailed):
            return "Security verification failed. Please ensure you're on a secure network."
        default:
            return "Something went wrong. Please try again later."
        }
    }
    
    var shouldRetry: Bool {
        switch self {
        case .network(.timeout), .network(.serverError):
            return true
        case .authentication(.tokenExpired):
            return true
        default:
            return false
        }
    }
}

class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    private var retryActions: [String: () async throws -> Void] = [:]
    
    func handle(error: Error, context: String = "", retryAction: (() async throws -> Void)? = nil) {
        let appError = mapToAppError(error)
        
        // Log error for debugging
        logError(appError, context: context)
        
        // Store retry action if provided
        if let retryAction = retryAction {
            retryActions[context] = retryAction
        }
        
        // Show error to user
        DispatchQueue.main.async {
            self.currentError = appError
            self.isShowingError = true
        }
        
        // Send to crash reporting service
        CrashReportingService.shared.recordError(appError, context: context)
    }
    
    private func mapToAppError(_ error: Error) -> AppError {
        switch error {
        case let networkError as NetworkError:
            return .network(networkError)
        case let authError as AuthError:
            return .authentication(authError)
        case let securityError as SecurityError:
            return .security(securityError)
        case let performanceError as PerformanceError:
            return .performance(performanceError)
        default:
            return .unknown(error)
        }
    }
    
    private func logError(_ error: AppError, context: String) {
        let errorInfo = [
            "error": error.localizedDescription,
            "context": context,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        print("🔴 Error: \(errorInfo)")
        
        // Send to logging service
        LoggingService.shared.logError(errorInfo)
    }
    
    func retry(context: String) async {
        guard let retryAction = retryActions[context] else { return }
        
        do {
            try await retryAction()
            DispatchQueue.main.async {
                self.isShowingError = false
                self.currentError = nil
            }
            retryActions.removeValue(forKey: context)
        } catch {
            handle(error: error, context: context, retryAction: retryAction)
        }
    }
    
    func dismiss() {
        DispatchQueue.main.async {
            self.isShowingError = false
            self.currentError = nil
        }
    }
}
```

#### 3.2 Offline Capability Implementation
```swift
// Offline/OfflineManager.swift
import Foundation
import Combine
import Network

class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOnline = true
    @Published var pendingOperations: [OfflineOperation] = []
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "network.monitor")
    private let operationsQueue = DispatchQueue(label: "offline.operations")
    
    private let userDefaults = UserDefaults.standard
    private let offlineStorageKey = "pending_offline_operations"
    
    init() {
        setupNetworkMonitoring()
        loadPendingOperations()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // Process pending operations when coming back online
                if !wasOnline && path.status == .satisfied {
                    self?.processPendingOperations()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    func addOfflineOperation(_ operation: OfflineOperation) {
        operationsQueue.async {
            DispatchQueue.main.async {
                self.pendingOperations.append(operation)
                self.savePendingOperations()
            }
        }
    }
    
    private func processPendingOperations() {
        guard isOnline else { return }
        
        operationsQueue.async {
            let operations = self.pendingOperations
            
            for operation in operations {
                Task {
                    do {
                        try await operation.execute()
                        DispatchQueue.main.async {
                            self.pendingOperations.removeAll { $0.id == operation.id }
                            self.savePendingOperations()
                        }
                    } catch {
                        print("Failed to execute offline operation: \(error)")
                        // Keep operation in queue for retry
                    }
                }
            }
        }
    }
    
    private func savePendingOperations() {
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            userDefaults.set(data, forKey: offlineStorageKey)
        } catch {
            print("Failed to save pending operations: \(error)")
        }
    }
    
    private func loadPendingOperations() {
        guard let data = userDefaults.data(forKey: offlineStorageKey) else { return }
        
        do {
            pendingOperations = try JSONDecoder().decode([OfflineOperation].self, from: data)
        } catch {
            print("Failed to load pending operations: \(error)")
        }
    }
}

struct OfflineOperation: Codable, Identifiable {
    let id = UUID()
    let type: OperationType
    let data: Data
    let timestamp: Date
    
    enum OperationType: String, Codable {
        case updateProfile
        case refreshToken
        case syncData
    }
    
    func execute() async throws {
        switch type {
        case .updateProfile:
            // Execute profile update
            break
        case .refreshToken:
            try await AuthenticationManager.shared.refreshToken()
        case .syncData:
            // Execute data sync
            break
        }
    }
}
```

### Step 4: Performance Monitoring and Analytics

#### 4.1 Performance Monitoring System
```swift
// Analytics/PerformanceMonitor.swift
import Foundation
import os.log

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.yourapp.performance", category: "monitoring")
    private var activeOperations: [String: Date] = [:]
    private let metricsQueue = DispatchQueue(label: "performance.metrics")
    
    func startOperation(_ operation: String) {
        metricsQueue.async {
            self.activeOperations[operation] = Date()
            self.logger.info("🚀 Started operation: \(operation)")
        }
    }
    
    func endOperation(_ operation: String, success: Bool = true) {
        metricsQueue.async {
            guard let startTime = self.activeOperations[operation] else {
                self.logger.warning("⚠️ No start time found for operation: \(operation)")
                return
            }
            
            let duration = Date().timeIntervalSince(startTime)
            self.activeOperations.removeValue(forKey: operation)
            
            let status = success ? "✅" : "❌"
            self.logger.info("\(status) Completed operation: \(operation) in \(String(format: "%.3f", duration))s")
            
            // Send to analytics
            self.recordPerformanceMetric(
                operation: operation,
                duration: duration,
                success: success
            )
        }
    }
    
    private func recordPerformanceMetric(operation: String, duration: TimeInterval, success: Bool) {
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            success: success,
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion
        )
        
        // Send to analytics service
        AnalyticsService.shared.track(metric)
        
        // Alert if performance is poor
        if duration > 5.0 {
            logger.warning("🐌 Slow operation detected: \(operation) took \(duration)s")
        }
    }
}

struct PerformanceMetric: Codable {
    let operation: String
    let duration: TimeInterval
    let success: Bool
    let timestamp: Date
    let appVersion: String
    let deviceModel: String
    let osVersion: String
}
```

#### 4.2 Lambda Performance Monitoring
```javascript
// lambda/monitoring/performance-monitor.js
const AWS = require('aws-sdk');
const cloudWatch = new AWS.CloudWatch();

class LambdaPerformanceMonitor {
    static async recordMetric(metricName, value, unit = 'Count', dimensions = {}) {
        const params = {
            Namespace: 'iOS-Auth-App',
            MetricData: [{
                MetricName: metricName,
                Value: value,
                Unit: unit,
                Timestamp: new Date(),
                Dimensions: Object.entries(dimensions).map(([Name, Value]) => ({ Name, Value }))
            }]
        };
        
        try {
            await cloudWatch.putMetricData(params).promise();
        } catch (error) {
            console.error('Failed to record metric:', error);
        }
    }
    
    static async recordExecutionTime(functionName, startTime) {
        const duration = Date.now() - startTime;
        
        await this.recordMetric('ExecutionDuration', duration, 'Milliseconds', {
            FunctionName: functionName
        });
        
        // Alert on slow executions
        if (duration > 5000) {
            console.warn(`🐌 Slow execution: ${functionName} took ${duration}ms`);
            await this.recordMetric('SlowExecution', 1, 'Count', {
                FunctionName: functionName
            });
        }
    }
    
    static async recordError(functionName, errorType, errorMessage) {
        await this.recordMetric('Errors', 1, 'Count', {
            FunctionName: functionName,
            ErrorType: errorType
        });
        
        console.error(`❌ Error in ${functionName}: ${errorType} - ${errorMessage}`);
    }
    
    static async recordSuccess(functionName) {
        await this.recordMetric('Successes', 1, 'Count', {
            FunctionName: functionName
        });
    }
    
    static createMonitoringWrapper(functionHandler, functionName) {
        return async (event, context) => {
            const startTime = Date.now();
            
            try {
                const result = await functionHandler(event, context);
                
                await this.recordExecutionTime(functionName, startTime);
                await this.recordSuccess(functionName);
                
                return result;
            } catch (error) {
                await this.recordExecutionTime(functionName, startTime);
                await this.recordError(functionName, error.name, error.message);
                
                throw error;
            }
        };
    }
}

module.exports = LambdaPerformanceMonitor;
```

---

## 📊 Testing and Validation

### Security Testing Checklist
- [ ] **Certificate Pinning Test**: Verify SSL pinning works correctly
- [ ] **Token Security Test**: Ensure tokens are encrypted and secure
- [ ] **Rate Limiting Test**: Verify API rate limiting is effective
- [ ] **Input Validation Test**: Test against injection attacks
- [ ] **Authentication Bypass Test**: Attempt to bypass auth mechanisms

### Performance Testing Scenarios
```swift
// Tests/PerformanceTests.swift
import XCTest
@testable import YourApp

class PerformanceTests: XCTestCase {
    
    func testLoginPerformance() {
        measure {
            // Measure login performance
            let expectation = self.expectation(description: "Login completed")
            
            Task {
                do {
                    try await AuthenticationManager.shared.signIn(
                        email: "test@example.com",
                        password: "password123"
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Login failed: \(error)")
                }
            }
            
            waitForExpectations(timeout: 5.0)
        }
    }
    
    func testMemoryUsage() {
        // Test memory usage during authentication flows
        let startMemory = getMemoryUsage()
        
        // Perform multiple auth operations
        for _ in 1...100 {
            let user = MockUser()
            AuthenticationManager.shared.processUser(user)
        }
        
        let endMemory = getMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory usage increased by more than 50MB")
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
```

---

## 📝 Practice Exercises

### Exercise 1: Security Implementation (6 hours)
1. Implement certificate pinning for your API endpoints
2. Add token encryption using iOS Keychain
3. Implement rate limiting on Lambda functions
4. Add input validation and sanitization

### Exercise 2: Performance Optimization (8 hours)
1. Optimize network requests with caching
2. Implement Lambda cold start mitigation
3. Add performance monitoring to all critical paths
4. Optimize memory usage in iOS app

### Exercise 3: Error Handling Enhancement (4 hours)
1. Implement comprehensive error handling system
2. Add offline capability with operation queuing
3. Create user-friendly error messages
4. Add automatic retry mechanisms

---

## 📊 Assignment: Security & Performance Audit

### Requirements:
1. **Security Audit** (8 hours)
   - Conduct certificate pinning implementation
   - Implement token encryption and secure storage
   - Add comprehensive input validation
   - Perform penetration testing basics

2. **Performance Optimization** (6 hours)
   - Optimize app startup time and memory usage
   - Implement network request caching and batching
   - Add Lambda performance monitoring
   - Optimize database queries

3. **Error Handling** (4 hours)
   - Implement offline-first architecture
   - Add comprehensive error recovery
   - Create user-friendly error experiences
   - Add logging and monitoring

### Deliverables:
- [ ] Security audit report with implemented fixes
- [ ] Performance test results showing improvements
- [ ] Error handling documentation and test cases
- [ ] Monitoring dashboard showing key metrics

---

## ✅ Lesson Completion Checklist

- [ ] Implement certificate pinning for API security
- [ ] Add advanced token security with encryption
- [ ] Set up comprehensive rate limiting
- [ ] Optimize iOS app performance and memory usage
- [ ] Implement Lambda cold start mitigation
- [ ] Add performance monitoring and alerting
- [ ] Create robust error handling system
- [ ] Implement offline capability with sync
- [ ] Conduct security testing and validation
- [ ] Set up performance testing suite
- [ ] Document security and performance improvements

**Estimated Time to Complete**: 15-20 hours  
**Next Lesson**: Testing, Documentation & Deployment

---

*Ready to deploy your secure and optimized authentication system? Continue to the final lesson on testing and deployment!*

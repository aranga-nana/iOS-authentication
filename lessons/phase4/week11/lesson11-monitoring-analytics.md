# Lesson 11: Advanced Monitoring & Analytics

**Duration:** 3 hours  
**Level:** Advanced  
**Prerequisites:** Completion of Phases 1-3

## Learning Objectives

By the end of this lesson, you will be able to:
- Implement comprehensive application monitoring and analytics
- Set up AWS CloudWatch for backend monitoring
- Integrate Firebase Analytics and Crashlytics
- Create custom dashboards and alerts
- Monitor application performance and user behavior
- Implement business intelligence and user analytics

## 1. Backend Monitoring with AWS CloudWatch

### 1.1 CloudWatch Setup

Let's enhance our Terraform configuration to include comprehensive monitoring:

```hcl
# modules/monitoring/cloudwatch.tf
resource "aws_cloudwatch_dashboard" "auth_app_dashboard" {
  dashboard_name = "${var.project_name}-auth-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-auth-handler"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-auth-handler"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-auth-handler"],
            ["AWS/Lambda", "Throttles", "FunctionName", "${var.project_name}-auth-handler"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Performance Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${var.project_name}-auth-api"],
            ["AWS/ApiGateway", "Latency", "ApiName", "${var.project_name}-auth-api"],
            ["AWS/ApiGateway", "4XXError", "ApiName", "${var.project_name}-auth-api"],
            ["AWS/ApiGateway", "5XXError", "ApiName", "${var.project_name}-auth-api"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "${var.project_name}-users"],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", "${var.project_name}-users"],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "${var.project_name}-users", "Operation", "GetItem"],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "${var.project_name}-users", "Operation", "PutItem"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Performance"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.project_name}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Lambda function error rate is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = "${var.project_name}-auth-handler"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "${var.project_name}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "API Gateway latency is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = "${var.project_name}-auth-api"
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  alarm_name          = "${var.project_name}-dynamodb-read-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ReadThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "DynamoDB read throttling detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TableName = "${var.project_name}-users"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Custom Metrics
resource "aws_cloudwatch_log_metric_filter" "auth_failures" {
  name           = "${var.project_name}-auth-failures"
  log_group_name = "/aws/lambda/${var.project_name}-auth-handler"
  pattern        = "[timestamp, request_id, \"AUTHENTICATION_FAILED\", ...]"

  metric_transformation {
    name      = "AuthenticationFailures"
    namespace = "${var.project_name}/Auth"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "new_user_registrations" {
  name           = "${var.project_name}-new-registrations"
  log_group_name = "/aws/lambda/${var.project_name}-auth-handler"
  pattern        = "[timestamp, request_id, \"USER_REGISTERED\", ...]"

  metric_transformation {
    name      = "NewUserRegistrations"
    namespace = "${var.project_name}/Auth"
    value     = "1"
  }
}
```

### 1.2 Enhanced Lambda Logging

Update your Lambda functions to include structured logging:

```javascript
// aws-lambda/monitoring/logger.js
const winston = require('winston');

class Logger {
    constructor() {
        this.logger = winston.createLogger({
            level: process.env.LOG_LEVEL || 'info',
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.errors({ stack: true }),
                winston.format.json()
            ),
            defaultMeta: {
                service: 'auth-service',
                version: process.env.APP_VERSION || '1.0.0',
                environment: process.env.ENVIRONMENT || 'production'
            },
            transports: [
                new winston.transports.Console()
            ]
        });
    }

    // Authentication Events
    logAuthenticationAttempt(userId, method, success, metadata = {}) {
        const event = {
            event_type: 'AUTHENTICATION_ATTEMPT',
            user_id: userId,
            auth_method: method,
            success: success,
            timestamp: new Date().toISOString(),
            metadata: metadata
        };

        if (success) {
            this.logger.info('Authentication successful', event);
        } else {
            this.logger.warn('Authentication failed', event);
        }
    }

    logUserRegistration(userId, method, metadata = {}) {
        this.logger.info('User registered', {
            event_type: 'USER_REGISTERED',
            user_id: userId,
            auth_method: method,
            timestamp: new Date().toISOString(),
            metadata: metadata
        });
    }

    logApiRequest(requestId, method, path, statusCode, duration, userId = null) {
        const logData = {
            event_type: 'API_REQUEST',
            request_id: requestId,
            method: method,
            path: path,
            status_code: statusCode,
            duration_ms: duration,
            timestamp: new Date().toISOString()
        };

        if (userId) {
            logData.user_id = userId;
        }

        if (statusCode >= 400) {
            this.logger.error('API request failed', logData);
        } else {
            this.logger.info('API request completed', logData);
        }
    }

    logSecurityEvent(eventType, severity, details) {
        this.logger.warn('Security event detected', {
            event_type: 'SECURITY_EVENT',
            security_event_type: eventType,
            severity: severity,
            details: details,
            timestamp: new Date().toISOString()
        });
    }

    logPerformanceMetric(operation, duration, metadata = {}) {
        this.logger.info('Performance metric', {
            event_type: 'PERFORMANCE_METRIC',
            operation: operation,
            duration_ms: duration,
            timestamp: new Date().toISOString(),
            metadata: metadata
        });
    }

    logError(error, context = {}) {
        this.logger.error('Application error', {
            event_type: 'APPLICATION_ERROR',
            error_message: error.message,
            error_stack: error.stack,
            context: context,
            timestamp: new Date().toISOString()
        });
    }
}

module.exports = new Logger();
```

### 1.3 Performance Monitoring Middleware

```javascript
// aws-lambda/middleware/performanceMonitor.js
const logger = require('../monitoring/logger');

class PerformanceMonitor {
    static middleware() {
        return async (event, context, next) => {
            const startTime = Date.now();
            const requestId = context.awsRequestId;
            
            // Extract request information
            const method = event.httpMethod;
            const path = event.resource;
            const userAgent = event.headers ? event.headers['User-Agent'] : 'Unknown';
            const sourceIp = event.requestContext?.identity?.sourceIp;

            try {
                // Log request start
                logger.logApiRequest(requestId, method, path, 0, 0);

                // Execute the actual handler
                const result = await next();
                
                const duration = Date.now() - startTime;
                const statusCode = result.statusCode || 200;

                // Log successful completion
                logger.logApiRequest(requestId, method, path, statusCode, duration);

                // Log performance metrics
                logger.logPerformanceMetric('api_request', duration, {
                    method: method,
                    path: path,
                    status_code: statusCode,
                    user_agent: userAgent,
                    source_ip: sourceIp
                });

                return result;
            } catch (error) {
                const duration = Date.now() - startTime;
                
                // Log error
                logger.logError(error, {
                    request_id: requestId,
                    method: method,
                    path: path,
                    duration_ms: duration,
                    user_agent: userAgent,
                    source_ip: sourceIp
                });

                // Log failed request
                logger.logApiRequest(requestId, method, path, 500, duration);

                throw error;
            }
        };
    }

    static trackDatabaseOperation(operation, tableName) {
        return async (params, callback) => {
            const startTime = Date.now();
            
            try {
                const result = await callback(params);
                const duration = Date.now() - startTime;

                logger.logPerformanceMetric('database_operation', duration, {
                    operation: operation,
                    table_name: tableName,
                    success: true
                });

                return result;
            } catch (error) {
                const duration = Date.now() - startTime;

                logger.logPerformanceMetric('database_operation', duration, {
                    operation: operation,
                    table_name: tableName,
                    success: false,
                    error: error.message
                });

                throw error;
            }
        };
    }
}

module.exports = PerformanceMonitor;
```

## 2. iOS App Analytics with Firebase

### 2.1 Firebase Analytics Integration

Update your iOS app to include comprehensive analytics:

```swift
// Services/AnalyticsManager.swift
import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    private init() {
        configure()
    }
    
    private func configure() {
        // Configure analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Configure Crashlytics
        Crashlytics.crashlytics().setUserID("anonymous")
    }
    
    // MARK: - Authentication Events
    
    func trackSignUp(method: String, success: Bool) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        if success {
            // Track conversion
            Analytics.logEvent("user_registered", parameters: [
                "registration_method": method
            ])
        }
    }
    
    func trackLogin(method: String, success: Bool) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        if !success {
            // Track authentication failures
            trackCustomEvent("authentication_failed", parameters: [
                "method": method,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    func trackLogout() {
        Analytics.logEvent("logout", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Interaction Events
    
    func trackScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackButtonTap(_ buttonName: String, screenName: String) {
        Analytics.logEvent("button_tap", parameters: [
            "button_name": buttonName,
            "screen_name": screenName,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackFormSubmission(_ formName: String, success: Bool, errors: [String]? = nil) {
        var parameters: [String: Any] = [
            "form_name": formName,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let errors = errors, !errors.isEmpty {
            parameters["validation_errors"] = errors.joined(separator: ",")
        }
        
        Analytics.logEvent("form_submission", parameters: parameters)
    }
    
    // MARK: - Security Events
    
    func trackBiometricAuthentication(success: Bool, biometricType: String) {
        Analytics.logEvent("biometric_auth", parameters: [
            "success": success,
            "biometric_type": biometricType,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackSecurityEvent(_ eventType: String, severity: String, details: [String: Any]? = nil) {
        var parameters: [String: Any] = [
            "event_type": eventType,
            "severity": severity,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let details = details {
            for (key, value) in details {
                parameters[key] = value
            }
        }
        
        Analytics.logEvent("security_event", parameters: parameters)
    }
    
    // MARK: - Performance Events
    
    func trackAppLaunchTime(_ launchTime: TimeInterval) {
        Analytics.logEvent("app_launch_time", parameters: [
            "launch_time_seconds": launchTime,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAPICallPerformance(endpoint: String, duration: TimeInterval, success: Bool) {
        Analytics.logEvent("api_performance", parameters: [
            "endpoint": endpoint,
            "duration_seconds": duration,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackNetworkError(endpoint: String, errorCode: Int, errorMessage: String) {
        Analytics.logEvent("network_error", parameters: [
            "endpoint": endpoint,
            "error_code": errorCode,
            "error_message": errorMessage,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Behavior Events
    
    func trackFeatureUsage(_ featureName: String, context: [String: Any]? = nil) {
        var parameters: [String: Any] = [
            "feature_name": featureName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let context = context {
            for (key, value) in context {
                parameters[key] = value
            }
        }
        
        Analytics.logEvent("feature_usage", parameters: parameters)
    }
    
    func trackUserPreferenceChange(_ preference: String, oldValue: String, newValue: String) {
        Analytics.logEvent("preference_change", parameters: [
            "preference": preference,
            "old_value": oldValue,
            "new_value": newValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Error Tracking
    
    func trackError(_ error: Error, context: [String: Any]? = nil) {
        // Log to Firebase Crashlytics
        var userInfo: [String: Any] = [:]
        if let context = context {
            userInfo = context
        }
        
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
        
        // Also log as analytics event
        Analytics.logEvent("app_error", parameters: [
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "error_description": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackCrash(_ crashInfo: [String: Any]) {
        Crashlytics.crashlytics().log("Crash detected: \(crashInfo)")
        
        // Set custom keys for crash analysis
        for (key, value) in crashInfo {
            Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        }
    }
    
    // MARK: - User Properties
    
    func setUserProperties(userId: String?, email: String?, accountType: String?) {
        if let userId = userId {
            Analytics.setUserID(userId)
            Crashlytics.crashlytics().setUserID(userId)
        }
        
        if let email = email {
            Crashlytics.crashlytics().setCustomValue(email, forKey: "email")
        }
        
        if let accountType = accountType {
            Analytics.setUserProperty(accountType, forName: "account_type")
        }
    }
    
    // MARK: - Custom Events
    
    func trackCustomEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        var eventParameters: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let parameters = parameters {
            for (key, value) in parameters {
                eventParameters[key] = value
            }
        }
        
        Analytics.logEvent(eventName, parameters: eventParameters)
    }
    
    // MARK: - A/B Testing Support
    
    func trackExperimentParticipation(experimentId: String, variant: String) {
        Analytics.logEvent("experiment_participation", parameters: [
            "experiment_id": experimentId,
            "variant": variant,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackConversionEvent(experimentId: String, variant: String, conversionType: String) {
        Analytics.logEvent("experiment_conversion", parameters: [
            "experiment_id": experimentId,
            "variant": variant,
            "conversion_type": conversionType,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}
```

### 2.2 Analytics Integration in Views

Update your SwiftUI views to include analytics tracking:

```swift
// Views/LoginView.swift - Add analytics tracking
struct LoginView: View {
    // ...existing code...
    
    var body: some View {
        VStack(spacing: 20) {
            // ...existing UI code...
        }
        .onAppear {
            AnalyticsManager.shared.trackScreenView("login_screen")
        }
    }
    
    private func signInWithEmail() {
        AnalyticsManager.shared.trackButtonTap("email_signin", screenName: "login_screen")
        
        // Start tracking form submission
        let startTime = Date()
        
        Task {
            do {
                await authManager.signInWithEmail(email, password: password)
                
                // Track successful login
                AnalyticsManager.shared.trackLogin(method: "email", success: true)
                AnalyticsManager.shared.trackFormSubmission("login_form", success: true)
                
                // Track performance
                let duration = Date().timeIntervalSince(startTime)
                AnalyticsManager.shared.trackAPICallPerformance(
                    endpoint: "auth/login",
                    duration: duration,
                    success: true
                )
            } catch {
                // Track failed login
                AnalyticsManager.shared.trackLogin(method: "email", success: false)
                AnalyticsManager.shared.trackFormSubmission(
                    "login_form",
                    success: false,
                    errors: [error.localizedDescription]
                )
                AnalyticsManager.shared.trackError(error, context: [
                    "screen": "login",
                    "action": "email_signin"
                ])
            }
        }
    }
    
    private func signInWithGoogle() {
        AnalyticsManager.shared.trackButtonTap("google_signin", screenName: "login_screen")
        
        Task {
            do {
                await authManager.signInWithGoogle()
                AnalyticsManager.shared.trackLogin(method: "google", success: true)
            } catch {
                AnalyticsManager.shared.trackLogin(method: "google", success: false)
                AnalyticsManager.shared.trackError(error, context: [
                    "screen": "login",
                    "action": "google_signin"
                ])
            }
        }
    }
}
```

## 3. Business Intelligence Dashboard

### 3.1 Custom Analytics Dashboard

Create a comprehensive analytics dashboard using AWS QuickSight or build a custom solution:

```javascript
// aws-lambda/analytics/dashboardData.js
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

class DashboardAnalytics {
    constructor() {
        this.tableName = process.env.USERS_TABLE;
        this.analyticsTable = process.env.ANALYTICS_TABLE;
    }

    // User Growth Metrics
    async getUserGrowthMetrics(timeRange = '7d') {
        const endDate = new Date();
        const startDate = new Date();
        
        switch (timeRange) {
            case '7d':
                startDate.setDate(endDate.getDate() - 7);
                break;
            case '30d':
                startDate.setDate(endDate.getDate() - 30);
                break;
            case '90d':
                startDate.setDate(endDate.getDate() - 90);
                break;
        }

        const params = {
            TableName: this.analyticsTable,
            KeyConditionExpression: 'event_type = :eventType AND #timestamp BETWEEN :startDate AND :endDate',
            ExpressionAttributeNames: {
                '#timestamp': 'timestamp'
            },
            ExpressionAttributeValues: {
                ':eventType': 'USER_REGISTERED',
                ':startDate': startDate.toISOString(),
                ':endDate': endDate.toISOString()
            }
        };

        try {
            const result = await dynamodb.query(params).promise();
            
            // Group by date
            const dailySignups = {};
            result.Items.forEach(item => {
                const date = item.timestamp.split('T')[0];
                dailySignups[date] = (dailySignups[date] || 0) + 1;
            });

            return {
                totalSignups: result.Items.length,
                dailySignups: dailySignups,
                timeRange: timeRange
            };
        } catch (error) {
            console.error('Error fetching user growth metrics:', error);
            throw error;
        }
    }

    // Authentication Analytics
    async getAuthenticationMetrics(timeRange = '7d') {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - parseInt(timeRange.replace('d', '')));

        const params = {
            TableName: this.analyticsTable,
            KeyConditionExpression: 'event_type = :eventType AND #timestamp BETWEEN :startDate AND :endDate',
            ExpressionAttributeNames: {
                '#timestamp': 'timestamp'
            },
            ExpressionAttributeValues: {
                ':eventType': 'AUTHENTICATION_ATTEMPT',
                ':startDate': startDate.toISOString(),
                ':endDate': endDate.toISOString()
            }
        };

        try {
            const result = await dynamodb.query(params).promise();
            
            const authStats = {
                total: result.Items.length,
                successful: result.Items.filter(item => item.success).length,
                failed: result.Items.filter(item => !item.success).length,
                methods: {},
                hourlyDistribution: {}
            };

            // Calculate success rate
            authStats.successRate = authStats.total > 0 
                ? (authStats.successful / authStats.total * 100).toFixed(2)
                : 0;

            // Group by authentication method
            result.Items.forEach(item => {
                const method = item.auth_method || 'email';
                if (!authStats.methods[method]) {
                    authStats.methods[method] = { total: 0, successful: 0, failed: 0 };
                }
                authStats.methods[method].total++;
                if (item.success) {
                    authStats.methods[method].successful++;
                } else {
                    authStats.methods[method].failed++;
                }

                // Hourly distribution
                const hour = new Date(item.timestamp).getHours();
                authStats.hourlyDistribution[hour] = (authStats.hourlyDistribution[hour] || 0) + 1;
            });

            return authStats;
        } catch (error) {
            console.error('Error fetching authentication metrics:', error);
            throw error;
        }
    }

    // Performance Metrics
    async getPerformanceMetrics(timeRange = '7d') {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - parseInt(timeRange.replace('d', '')));

        const params = {
            TableName: this.analyticsTable,
            KeyConditionExpression: 'event_type = :eventType AND #timestamp BETWEEN :startDate AND :endDate',
            ExpressionAttributeNames: {
                '#timestamp': 'timestamp'
            },
            ExpressionAttributeValues: {
                ':eventType': 'PERFORMANCE_METRIC',
                ':startDate': startDate.toISOString(),
                ':endDate': endDate.toISOString()
            }
        };

        try {
            const result = await dynamodb.query(params).promise();
            
            const performanceStats = {
                apiRequests: {
                    total: 0,
                    averageLatency: 0,
                    p95Latency: 0,
                    errorRate: 0
                },
                databaseOperations: {
                    total: 0,
                    averageLatency: 0,
                    errorRate: 0
                }
            };

            const apiRequests = result.Items.filter(item => item.operation === 'api_request');
            const dbOperations = result.Items.filter(item => item.operation === 'database_operation');

            // API Performance
            if (apiRequests.length > 0) {
                const latencies = apiRequests.map(item => item.duration_ms).sort((a, b) => a - b);
                const errors = apiRequests.filter(item => item.metadata && item.metadata.status_code >= 400);
                
                performanceStats.apiRequests.total = apiRequests.length;
                performanceStats.apiRequests.averageLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
                performanceStats.apiRequests.p95Latency = latencies[Math.floor(latencies.length * 0.95)];
                performanceStats.apiRequests.errorRate = (errors.length / apiRequests.length * 100).toFixed(2);
            }

            // Database Performance
            if (dbOperations.length > 0) {
                const dbLatencies = dbOperations.map(item => item.duration_ms);
                const dbErrors = dbOperations.filter(item => item.metadata && !item.metadata.success);
                
                performanceStats.databaseOperations.total = dbOperations.length;
                performanceStats.databaseOperations.averageLatency = dbLatencies.reduce((a, b) => a + b, 0) / dbLatencies.length;
                performanceStats.databaseOperations.errorRate = (dbErrors.length / dbOperations.length * 100).toFixed(2);
            }

            return performanceStats;
        } catch (error) {
            console.error('Error fetching performance metrics:', error);
            throw error;
        }
    }

    // User Engagement Metrics
    async getUserEngagementMetrics(timeRange = '7d') {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - parseInt(timeRange.replace('d', '')));

        // Get active users
        const activeUsersParams = {
            TableName: this.tableName,
            FilterExpression: 'last_login_at BETWEEN :startDate AND :endDate',
            ExpressionAttributeValues: {
                ':startDate': startDate.toISOString(),
                ':endDate': endDate.toISOString()
            }
        };

        try {
            const activeUsersResult = await dynamodb.scan(activeUsersParams).promise();
            
            // Get feature usage data
            const featureUsageParams = {
                TableName: this.analyticsTable,
                KeyConditionExpression: 'event_type = :eventType AND #timestamp BETWEEN :startDate AND :endDate',
                ExpressionAttributeNames: {
                    '#timestamp': 'timestamp'
                },
                ExpressionAttributeValues: {
                    ':eventType': 'feature_usage',
                    ':startDate': startDate.toISOString(),
                    ':endDate': endDate.toISOString()
                }
            };

            const featureUsageResult = await dynamodb.query(featureUsageParams).promise();

            const engagementStats = {
                activeUsers: activeUsersResult.Items.length,
                featureUsage: {},
                userSessions: {},
                retentionRate: 0
            };

            // Analyze feature usage
            featureUsageResult.Items.forEach(item => {
                const feature = item.feature_name;
                engagementStats.featureUsage[feature] = (engagementStats.featureUsage[feature] || 0) + 1;
            });

            // Calculate retention rate (simplified)
            const retentionPeriodStart = new Date();
            retentionPeriodStart.setDate(endDate.getDate() - 14);
            
            const retentionParams = {
                TableName: this.tableName,
                FilterExpression: 'created_at BETWEEN :retentionStart AND :startDate',
                ExpressionAttributeValues: {
                    ':retentionStart': retentionPeriodStart.toISOString(),
                    ':startDate': startDate.toISOString()
                }
            };

            const retentionResult = await dynamodb.scan(retentionParams).promise();
            const newUsers = retentionResult.Items.length;
            const retainedUsers = retentionResult.Items.filter(user => 
                user.last_login_at && new Date(user.last_login_at) >= startDate
            ).length;

            engagementStats.retentionRate = newUsers > 0 
                ? (retainedUsers / newUsers * 100).toFixed(2)
                : 0;

            return engagementStats;
        } catch (error) {
            console.error('Error fetching engagement metrics:', error);
            throw error;
        }
    }

    // Security Metrics
    async getSecurityMetrics(timeRange = '7d') {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - parseInt(timeRange.replace('d', '')));

        const params = {
            TableName: this.analyticsTable,
            KeyConditionExpression: 'event_type = :eventType AND #timestamp BETWEEN :startDate AND :endDate',
            ExpressionAttributeNames: {
                '#timestamp': 'timestamp'
            },
            ExpressionAttributeValues: {
                ':eventType': 'SECURITY_EVENT',
                ':startDate': startDate.toISOString(),
                ':endDate': endDate.toISOString()
            }
        };

        try {
            const result = await dynamodb.query(params).promise();
            
            const securityStats = {
                totalEvents: result.Items.length,
                eventTypes: {},
                severityLevels: {},
                suspiciousIPs: {},
                timeline: {}
            };

            result.Items.forEach(item => {
                // Event types
                const eventType = item.security_event_type;
                securityStats.eventTypes[eventType] = (securityStats.eventTypes[eventType] || 0) + 1;

                // Severity levels
                const severity = item.severity;
                securityStats.severityLevels[severity] = (securityStats.severityLevels[severity] || 0) + 1;

                // Suspicious IPs (if available)
                if (item.details && item.details.source_ip) {
                    const ip = item.details.source_ip;
                    securityStats.suspiciousIPs[ip] = (securityStats.suspiciousIPs[ip] || 0) + 1;
                }

                // Timeline
                const date = item.timestamp.split('T')[0];
                securityStats.timeline[date] = (securityStats.timeline[date] || 0) + 1;
            });

            return securityStats;
        } catch (error) {
            console.error('Error fetching security metrics:', error);
            throw error;
        }
    }
}

module.exports = DashboardAnalytics;
```

## 4. Real-time Monitoring Setup

### 4.1 CloudWatch Real-time Dashboard

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Duration", "FunctionName", "auth-handler", { "stat": "Average" }],
          [".", "Errors", ".", ".", { "stat": "Sum" }],
          [".", "Invocations", ".", ".", { "stat": "Sum" }]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "Lambda Performance - Real Time",
        "period": 60,
        "annotations": {
          "horizontal": [
            {
              "label": "Error Threshold",
              "value": 5
            }
          ]
        }
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/lambda/auth-handler'\n| fields @timestamp, @message\n| filter @message like /AUTHENTICATION_FAILED/\n| sort @timestamp desc\n| limit 50",
        "region": "us-east-1",
        "title": "Recent Authentication Failures",
        "view": "table"
      }
    }
  ]
}
```

## 5. Practical Exercises

### Exercise 1: Set Up Comprehensive Monitoring
1. Deploy the enhanced monitoring Terraform configuration
2. Configure CloudWatch dashboards
3. Set up SNS alerts for critical metrics
4. Test alert notifications

### Exercise 2: Implement Analytics Tracking
1. Integrate Firebase Analytics in your iOS app
2. Add custom event tracking to key user actions
3. Implement error tracking with Crashlytics
4. Set up user property tracking

### Exercise 3: Create Performance Monitoring
1. Add performance monitoring middleware to Lambda functions
2. Implement structured logging
3. Set up custom CloudWatch metrics
4. Create performance dashboards

### Exercise 4: Build Analytics Dashboard
1. Create a dashboard API using the DashboardAnalytics class
2. Build a simple web interface to display metrics
3. Implement real-time data updates
4. Add export functionality for reports

## 6. Testing and Validation

### 6.1 Monitoring Tests
```bash
# Test CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=auth-handler \
  --statistics Average \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-02T00:00:00Z \
  --period 3600

# Test custom metrics
aws logs filter-log-events \
  --log-group-name /aws/lambda/auth-handler \
  --filter-pattern "AUTHENTICATION_FAILED"
```

### 6.2 Analytics Validation
```javascript
// Test analytics data collection
const testAnalytics = async () => {
    const analytics = new DashboardAnalytics();
    
    try {
        const userGrowth = await analytics.getUserGrowthMetrics('7d');
        console.log('User Growth:', userGrowth);
        
        const authMetrics = await analytics.getAuthenticationMetrics('7d');
        console.log('Auth Metrics:', authMetrics);
        
        const performance = await analytics.getPerformanceMetrics('7d');
        console.log('Performance:', performance);
    } catch (error) {
        console.error('Analytics test failed:', error);
    }
};
```

## 7. Production Deployment

### 7.1 Monitoring Deployment Checklist
- [ ] CloudWatch dashboards configured
- [ ] Alerts and notifications set up
- [ ] Log aggregation working
- [ ] Custom metrics collecting data
- [ ] Performance monitoring active
- [ ] Security event tracking enabled

### 7.2 Analytics Deployment Checklist
- [ ] Firebase Analytics integrated
- [ ] Event tracking implemented
- [ ] Error reporting configured
- [ ] User properties set up
- [ ] Custom events defined
- [ ] Dashboard API deployed

## Summary

In this lesson, we implemented comprehensive monitoring and analytics for our authentication system:

1. **Backend Monitoring**: CloudWatch dashboards, alarms, and custom metrics
2. **iOS Analytics**: Firebase Analytics integration with custom event tracking
3. **Performance Monitoring**: Real-time performance metrics and alerts
4. **Business Intelligence**: Custom analytics dashboard with key metrics
5. **Security Monitoring**: Security event tracking and alerting

This monitoring and analytics setup provides visibility into:
- User behavior and engagement
- System performance and reliability
- Security events and threats
- Business metrics and growth

**Next Steps:**
- Review monitoring data regularly
- Set up automated reports
- Implement A/B testing based on analytics
- Optimize performance based on metrics
- Enhance security based on monitoring insights

**Continue to:** [Lesson 10: Infrastructure as Code & DevOps](lesson10-infrastructure-devops.md)

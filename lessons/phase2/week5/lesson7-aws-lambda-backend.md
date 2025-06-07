# Lesson 7: AWS Lambda Backend with SAM
**Phase 2, Week 5** | **Duration:** 8-10 hours | **Difficulty:** Advanced

**Prerequisites**: Basic AWS knowledge, Firebase Authentication, completed Phase 2 Week 1-4 lessons

## 🎯 Learning Objectives
- Set up AWS Lambda functions using AWS SAM (Serverless Application Model)
- Create API Gateway endpoints with SAM templates
- Implement DynamoDB for user data storage using Infrastructure as Code
- Configure Lambda environment variables and permissions declaratively
- Understand serverless architecture patterns and SAM best practices

---

## 📚 Theory Overview

### What is AWS SAM?
AWS SAM (Serverless Application Model) is an open-source framework for building serverless applications on AWS. It provides:
- **Infrastructure as Code**: Define your entire serverless application in YAML/JSON
- **Local Development**: Test Lambda functions locally before deployment
- **Built-in Best Practices**: Security, monitoring, and performance optimizations
- **Simplified Syntax**: Abstracts complex CloudFormation templates

### Architecture Overview:
```
iOS App → API Gateway → Lambda Functions → DynamoDB
                    ↓                   ↓
               CloudWatch Logs    Application Insights
                    ↓
               X-Ray Tracing
```

### SAM vs Alternatives:
| Tool | Use Case | Learning Curve | Features |
|------|----------|----------------|----------|
| **AWS SAM** | AWS-native serverless | Medium | Built-in best practices, local testing |
| Serverless Framework | Multi-cloud | Medium | Plugin ecosystem, mature |
| CDK | Complex infrastructure | High | Full programming languages |
| Manual CloudFormation | Enterprise control | High | Maximum flexibility |

### Key Benefits:
- **Infrastructure as Code**: Version control your entire stack
- **Local Development**: Debug Lambda functions on your machine
- **Automatic IAM**: SAM generates minimal required permissions
- **Built-in Monitoring**: CloudWatch, X-Ray, and Application Insights

---

## 🛠 Implementation Guide

### Step 1: SAM Setup and Installation

#### 1.1 Install AWS SAM CLI
```bash
# macOS (using Homebrew)
brew install aws-sam-cli

# Windows (using Chocolatey)
choco install aws-sam-cli

# Linux (using pip)
pip install aws-sam-cli

# Verify installation
sam --version
```

#### 1.2 AWS CLI Configuration
```bash
# Install AWS CLI if not already installed
brew install awscli

# Configure AWS CLI
aws configure
# Enter your Access Key ID, Secret Access Key, Region (us-east-1), and Output format (json)

# Verify configuration
aws sts get-caller-identity
```

#### 1.3 Create SAM Project Structure
```bash
# Create project directory
mkdir ios-auth-backend
cd ios-auth-backend

# Initialize SAM application
sam init --runtime nodejs18.x --name ios-auth-backend --app-template hello-world

# Or use our custom template
mkdir ios-auth-backend
cd ios-auth-backend
```

### Step 2: SAM Template Configuration

#### 2.1 Create template.yaml
```yaml
# template.yaml - SAM template for iOS Authentication Backend
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: iOS Authentication Backend with Firebase integration

# Global configuration for all functions
Globals:
  Function:
    Timeout: 30
    MemorySize: 512
    Runtime: nodejs18.x
    Architectures:
      - x86_64
    Environment:
      Variables:
        STAGE: !Ref Stage
        USERS_TABLE: !Ref UsersTable
        JWT_SECRET: !Ref JWTSecret
        FIREBASE_PROJECT_ID: !Ref FirebaseProjectId
        FIREBASE_CLIENT_EMAIL: !Ref FirebaseClientEmail
        FIREBASE_PRIVATE_KEY: !Ref FirebasePrivateKey
        LOG_LEVEL: !Ref LogLevel
    Tracing: Active  # Enable X-Ray tracing
  Api:
    TracingConfig:
      TracingEnabled: true
    Cors:
      AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"
      AllowHeaders: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
      AllowOrigin: "'*'"

# Parameters for environment-specific configuration
Parameters:
  Stage:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
    Description: Environment stage
  
  JWTSecret:
    Type: String
    NoEcho: true
    Description: JWT secret key for token signing
    MinLength: 32
  
  FirebaseProjectId:
    Type: String
    Description: Firebase project ID
  
  FirebaseClientEmail:
    Type: String
    Description: Firebase service account client email
  
  FirebasePrivateKey:
    Type: String
    NoEcho: true
    Description: Firebase service account private key
  
  LogLevel:
    Type: String
    Default: info
    AllowedValues: [error, warn, info, debug]
    Description: Application log level

# Resources definition
Resources:
  # API Gateway
  AuthApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Stage
      Description: iOS Authentication API
      AccessLogSetting:
        DestinationArn: !GetAtt ApiGatewayLogGroup.Arn
      MethodSettings:
        - ResourcePath: '/*'
          HttpMethod: '*'
          LoggingLevel: INFO
          DataTraceEnabled: true
          MetricsEnabled: true

  # Lambda Functions
  RegisterUserFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: ./
      Handler: userFunctions.registerUser
      Description: Register new user account
      ReservedConcurrencyLimit: 10
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UsersTable
      Events:
        RegisterUser:
          Type: Api
          Properties:
            RestApiId: !Ref AuthApi
            Path: /auth/register
            Method: post

  LoginUserFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: ./
      Handler: userFunctions.loginUser
      Description: User login authentication
      ReservedConcurrencyLimit: 20
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref UsersTable
      Events:
        LoginUser:
          Type: Api
          Properties:
            RestApiId: !Ref AuthApi
            Path: /auth/login
            Method: post

  GetUserProfileFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: ./
      Handler: userFunctions.getUserProfile
      Description: Get user profile information
      ReservedConcurrencyLimit: 5
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref UsersTable
      Events:
        GetUserProfile:
          Type: Api
          Properties:
            RestApiId: !Ref AuthApi
            Path: /users/{userId}
            Method: get

  # DynamoDB Table
  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${AWS::StackName}-users-${Stage}'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
        - AttributeName: email
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: EmailIndex
          KeySchema:
            - AttributeName: email
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      SSESpecification:
        SSEEnabled: true

  # CloudWatch Log Group
  ApiGatewayLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/apigateway/${AWS::StackName}-${Stage}'
      RetentionInDays: 30

# Outputs
Outputs:
  AuthApiEndpoint:
    Description: "API Gateway endpoint URL"
    Value: !Sub "https://${AuthApi}.execute-api.${AWS::Region}.amazonaws.com/${Stage}/"
  
  UsersTableName:
    Description: "DynamoDB Users table name"
    Value: !Ref UsersTable
```

### Step 3: Lambda Function Implementation

#### 3.1 Create Package.json for Dependencies
```json
{
  "name": "ios-auth-lambda-functions",
  "version": "1.0.0",
  "description": "AWS Lambda functions for iOS authentication system with Firebase and DynamoDB",
  "main": "index.js",
  "scripts": {
    "test": "jest",
    "lint": "eslint .",
    "format": "prettier --write .",
    "build": "npm run lint && npm run test",
    "deploy": "sam deploy",
    "build-sam": "sam build",
    "local": "sam local start-api",
    "validate": "sam validate"
  },
  "dependencies": {
    "aws-sdk": "^2.1497.0",
    "firebase-admin": "^11.11.1",
    "jsonwebtoken": "^9.0.2",
    "uuid": "^9.0.1",
    "validator": "^13.11.0",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "eslint": "^8.54.0",
    "prettier": "^3.1.0",
    "@types/jest": "^29.5.8"
  }
}
```

#### 3.2 Create Environment Variables Template
```json
// env.json.example - Environment variables for local development
{
  "RegisterUserFunction": {
    "STAGE": "local",
    "USERS_TABLE": "ios-auth-backend-users-local",
    "JWT_SECRET": "your-super-secret-jwt-key-here-minimum-32-characters",
    "JWT_EXPIRES_IN": "24h",
    "FIREBASE_PROJECT_ID": "your-firebase-project-id",
    "FIREBASE_CLIENT_EMAIL": "firebase-service-account@your-project.iam.gserviceaccount.com",
    "FIREBASE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nYOUR_FIREBASE_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----",
    "LOG_LEVEL": "debug"
  },
  "LoginUserFunction": {
    "STAGE": "local",
    "USERS_TABLE": "ios-auth-backend-users-local",
    "JWT_SECRET": "your-super-secret-jwt-key-here-minimum-32-characters",
    "JWT_EXPIRES_IN": "24h",
    "FIREBASE_PROJECT_ID": "your-firebase-project-id",
    "FIREBASE_CLIENT_EMAIL": "firebase-service-account@your-project.iam.gserviceaccount.com",
    "FIREBASE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nYOUR_FIREBASE_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----",
    "LOG_LEVEL": "debug"
  }
}
```

#### 3.3 Create User Registration Function
```javascript
// userFunctions.js
const AWS = require('aws-sdk');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const validator = require('validator');
const winston = require('winston');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient({
  region: process.env.AWS_REGION || 'us-east-1',
  maxRetries: 3,
  retryDelayOptions: {
    customBackoff: function(retryCount) {
      return Math.pow(2, retryCount) * 100;
    }
  }
});

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')
    })
  });
}

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

// Constants
const USERS_TABLE = process.env.USERS_TABLE;
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

// Utility functions
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,HEAD,OPTIONS,POST,PUT,DELETE',
  'Content-Type': 'application/json'
};

const createResponse = (statusCode, body, headers = {}) => ({
  statusCode,
  headers: { ...corsHeaders, ...headers },
  body: JSON.stringify(body)
});

// Register User Function
exports.registerUser = async (event) => {
  try {
    logger.info('Register user request received', { 
      requestId: event.requestContext?.requestId 
    });

    // Parse request body
    const { idToken, userData } = JSON.parse(event.body);

    // Validate Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const { uid, email, name, picture } = decodedToken;

    // Create user record
    const userId = uuidv4();
    const timestamp = new Date().toISOString();
    
    const userRecord = {
      userId,
      firebaseUid: uid,
      email,
      displayName: userData?.displayName || name,
      profilePicture: userData?.profilePicture || picture,
      createdAt: timestamp,
      updatedAt: timestamp,
      lastLoginAt: timestamp,
      isActive: true,
      preferences: userData?.preferences || {}
    };

    // Save to DynamoDB
    await dynamodb.put({
      TableName: USERS_TABLE,
      Item: userRecord,
      ConditionExpression: 'attribute_not_exists(userId)'
    }).promise();

    // Generate JWT token
    const jwtToken = jwt.sign(
      { userId, email, firebaseUid: uid },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    logger.info('User registered successfully', { userId, email });

    return createResponse(201, {
      success: true,
      message: 'User registered successfully',
      data: {
        userId,
        email,
        displayName: userRecord.displayName,
        profilePicture: userRecord.profilePicture,
        token: jwtToken
      }
    });

  } catch (error) {
    logger.error('Registration failed', { error: error.message, stack: error.stack });
    
    if (error.code === 'ConditionalCheckFailedException') {
      return createResponse(409, {
        error: true,
        message: 'User already exists'
      });
    }

    return createResponse(500, {
      error: true,
      message: 'Internal server error'
    });
  }
};

// Login User Function
exports.loginUser = async (event) => {
  try {
    logger.info('Login request received', { 
      requestId: event.requestContext?.requestId 
    });

    const { idToken } = JSON.parse(event.body);

    // Validate Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const { uid, email } = decodedToken;

    // Find user by Firebase UID
    const result = await dynamodb.scan({
      TableName: USERS_TABLE,
      FilterExpression: 'firebaseUid = :uid',
      ExpressionAttributeValues: {
        ':uid': uid
      }
    }).promise();

    if (result.Items.length === 0) {
      return createResponse(404, {
        error: true,
        message: 'User not found'
      });
    }

    const user = result.Items[0];

    // Update last login timestamp
    await dynamodb.update({
      TableName: USERS_TABLE,
      Key: { userId: user.userId },
      UpdateExpression: 'SET lastLoginAt = :timestamp',
      ExpressionAttributeValues: {
        ':timestamp': new Date().toISOString()
      }
    }).promise();

    // Generate JWT token
    const jwtToken = jwt.sign(
      { userId: user.userId, email: user.email, firebaseUid: uid },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    logger.info('User logged in successfully', { userId: user.userId, email });

    return createResponse(200, {
      success: true,
      message: 'Login successful',
      data: {
        userId: user.userId,
        email: user.email,
        displayName: user.displayName,
        profilePicture: user.profilePicture,
        token: jwtToken
      }
    });

  } catch (error) {
    logger.error('Login failed', { error: error.message, stack: error.stack });
    
    return createResponse(500, {
      error: true,
      message: 'Internal server error'
    });
  }
};

// Get User Profile Function
exports.getUserProfile = async (event) => {
  try {
    const { userId } = event.pathParameters;
    
    // Get user from DynamoDB
    const result = await dynamodb.get({
      TableName: USERS_TABLE,
      Key: { userId }
    }).promise();

    if (!result.Item) {
      return createResponse(404, {
        error: true,
        message: 'User not found'
      });
    }

    const user = result.Item;
    
    return createResponse(200, {
      success: true,
      data: {
        userId: user.userId,
        email: user.email,
        displayName: user.displayName,
        profilePicture: user.profilePicture,
        preferences: user.preferences,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt
      }
    });

  } catch (error) {
    logger.error('Get profile failed', { error: error.message, stack: error.stack });
    
    return createResponse(500, {
      error: true,
      message: 'Internal server error'
    });
  }
};
```

### Step 4: SAM Configuration and Deployment

#### 4.1 Create SAM Configuration File
```toml
# samconfig.toml
version = 0.1

[default]
[default.global.parameters]
stack_name = "ios-auth-backend"

[default.build.parameters]
cached = true
parallel = true

[default.validate.parameters]
lint = true

[default.deploy.parameters]
capabilities = "CAPABILITY_IAM"
confirm_changeset = true
resolve_s3 = true
s3_prefix = "ios-auth-backend"
region = "us-east-1"

[dev]
[dev.deploy.parameters]
stack_name = "ios-auth-backend-dev"
parameter_overrides = [
    "Stage=dev",
    "LogLevel=debug"
]

[staging]
[staging.deploy.parameters]
stack_name = "ios-auth-backend-staging"
parameter_overrides = [
    "Stage=staging",
    "LogLevel=info"
]

[prod]
[prod.deploy.parameters]
stack_name = "ios-auth-backend-prod"
parameter_overrides = [
    "Stage=prod",
    "LogLevel=warn"
]
```

#### 4.2 Local Development and Testing
```bash
# Install dependencies
npm install

# Validate SAM template
sam validate

# Build the application
sam build

# Start local API Gateway
sam local start-api --env-vars env.json

# Test specific function locally
sam local invoke RegisterUserFunction --event events/register-event.json

# Generate sample events for testing
sam local generate-event apigateway aws-proxy --path /auth/register --method POST
```

#### 4.3 Create Test Events
```json
// events/register-event.json
{
  "httpMethod": "POST",
  "path": "/auth/register",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"idToken\":\"your-firebase-id-token\",\"userData\":{\"displayName\":\"John Doe\",\"preferences\":{\"notifications\":true}}}"
}
```

#### 4.4 Deploy to AWS
```bash
# Deploy to development environment
sam deploy --config-env dev \
  --parameter-overrides \
    JWTSecret="your-super-secret-jwt-key-minimum-32-characters" \
    FirebaseProjectId="your-firebase-project-id" \
    FirebaseClientEmail="your-service-account@project.iam.gserviceaccount.com" \
    FirebasePrivateKey="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----"

# Deploy to production
sam deploy --config-env prod \
  --parameter-overrides \
    JWTSecret="your-production-jwt-secret" \
    FirebaseProjectId="your-firebase-project-id" \
    FirebaseClientEmail="your-service-account@project.iam.gserviceaccount.com" \
    FirebasePrivateKey="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_HERE\n-----END PRIVATE KEY-----"
```

### Step 5: Testing and Monitoring

#### 5.1 Unit Testing with Jest
```javascript
// userFunctions.test.js
const AWS = require('aws-sdk-mock');
const { registerUser, loginUser, getUserProfile } = require('./userFunctions');

// Mock AWS services
AWS.mock('DynamoDB.DocumentClient', 'put', (params, callback) => {
  callback(null, { ConsumedCapacity: { TableName: 'test-table' } });
});

AWS.mock('DynamoDB.DocumentClient', 'scan', (params, callback) => {
  callback(null, {
    Items: [{
      userId: 'test-user-id',
      email: 'test@example.com',
      firebaseUid: 'test-firebase-uid',
      displayName: 'Test User'
    }]
  });
});

describe('Lambda Functions', () => {
  beforeEach(() => {
    process.env.USERS_TABLE = 'test-users-table';
    process.env.JWT_SECRET = 'test-secret-key-minimum-32-characters';
    process.env.FIREBASE_PROJECT_ID = 'test-project';
    process.env.FIREBASE_CLIENT_EMAIL = 'test@test.iam.gserviceaccount.com';
    process.env.FIREBASE_PRIVATE_KEY = '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----';
  });

  describe('registerUser', () => {
    test('should register a new user successfully', async () => {
      const event = {
        body: JSON.stringify({
          idToken: 'valid-test-token',
          userData: {
            displayName: 'Test User',
            preferences: { notifications: true }
          }
        }),
        requestContext: { requestId: 'test-request-id' }
      };

      const result = await registerUser(event);
      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(201);
      expect(body.success).toBe(true);
      expect(body.data).toHaveProperty('userId');
      expect(body.data).toHaveProperty('token');
    });

    test('should handle invalid request body', async () => {
      const event = {
        body: JSON.stringify({}),
        requestContext: { requestId: 'test-request-id' }
      };

      const result = await registerUser(event);
      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(500);
      expect(body.error).toBe(true);
    });
  });

  describe('loginUser', () => {
    test('should authenticate user successfully', async () => {
      const event = {
        body: JSON.stringify({
          idToken: 'valid-test-token'
        }),
        requestContext: { requestId: 'test-request-id' }
      };

      const result = await loginUser(event);
      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data).toHaveProperty('token');
    });
  });
});
```

#### 5.2 Local Testing Commands
```bash
# Run unit tests
npm test

# Run tests with coverage
npm run test:coverage

# Test individual function locally
sam local invoke RegisterUserFunction -e events/register-event.json

# Start local API for testing
sam local start-api --env-vars env.json --port 3000

# Test API endpoints locally
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"idToken":"test-token","userData":{"displayName":"Test User"}}'
```

#### 5.3 Create Test Events
```json
// events/register-event.json
{
  "httpMethod": "POST",
  "path": "/auth/register",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"idToken\":\"test-firebase-token\",\"userData\":{\"displayName\":\"John Doe\",\"preferences\":{\"notifications\":true}}}",
  "requestContext": {
    "requestId": "test-request-123"
  }
}
```

```json
// events/login-event.json
{
  "httpMethod": "POST",
  "path": "/auth/login",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"idToken\":\"test-firebase-token\"}",
  "requestContext": {
    "requestId": "test-request-456"
  }
}
```

#### 5.4 Monitoring and Observability
```bash
# View CloudWatch logs
sam logs -n RegisterUserFunction --stack-name ios-auth-backend-dev --tail

# View X-Ray traces
aws xray get-trace-summaries --time-range-type TimeRangeByStartTime \
  --start-time 2024-01-01T00:00:00 --end-time 2024-01-02T00:00:00

# Monitor API Gateway metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=ios-auth-backend-AuthApi \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Step 6: Production Deployment and Security

#### 6.1 Environment-Specific Deployments
```bash
# Deploy to development
sam deploy --config-env dev \
  --parameter-overrides \
    JWTSecret="dev-jwt-secret-minimum-32-characters" \
    FirebaseProjectId="your-dev-firebase-project" \
    FirebaseClientEmail="dev-service@project.iam.gserviceaccount.com" \
    FirebasePrivateKey="$(cat dev-firebase-key.pem)"

# Deploy to staging
sam deploy --config-env staging \
  --parameter-overrides \
    JWTSecret="staging-jwt-secret-minimum-32-characters" \
    FirebaseProjectId="your-staging-firebase-project" \
    FirebaseClientEmail="staging-service@project.iam.gserviceaccount.com" \
    FirebasePrivateKey="$(cat staging-firebase-key.pem)"

# Deploy to production
sam deploy --config-env prod \
  --parameter-overrides \
    JWTSecret="production-jwt-secret-minimum-32-characters" \
    FirebaseProjectId="your-prod-firebase-project" \
    FirebaseClientEmail="prod-service@project.iam.gserviceaccount.com" \
    FirebasePrivateKey="$(cat prod-firebase-key.pem)"
```

#### 6.2 Security Best Practices Implementation
```yaml
# Add to template.yaml - Enhanced security configuration
Resources:
  # WAF for API Gateway
  WebACL:
    Type: AWS::WAFv2::WebACL
    Properties:
      Name: !Sub '${AWS::StackName}-waf'
      Scope: REGIONAL
      DefaultAction:
        Allow: {}
      Rules:
        - Name: RateLimitRule
          Priority: 1
          Statement:
            RateBasedStatement:
              Limit: 2000
              AggregateKeyType: IP
          Action:
            Block: {}
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: RateLimitRule

  # Associate WAF with API Gateway
  WebACLAssociation:
    Type: AWS::WAFv2::WebACLAssociation
    Properties:
      ResourceArn: !Sub 'arn:aws:apigateway:${AWS::Region}::/restapis/${AuthApi}/stages/${Stage}'
      WebACLArn: !GetAtt WebACL.Arn

  # Enhanced API Gateway with security
  AuthApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Stage
      TracingConfig:
        TracingEnabled: true
      AccessLogSetting:
        DestinationArn: !GetAtt ApiGatewayLogGroup.Arn
        Format: >
          {
            "requestId": "$context.requestId",
            "ip": "$context.identity.sourceIp",
            "caller": "$context.identity.caller",
            "user": "$context.identity.user",
            "requestTime": "$context.requestTime",
            "httpMethod": "$context.httpMethod",
            "resourcePath": "$context.resourcePath",
            "status": "$context.status",
            "protocol": "$context.protocol",
            "responseLength": "$context.responseLength"
          }
      MethodSettings:
        - ResourcePath: '/*'
          HttpMethod: '*'
          LoggingLevel: INFO
          DataTraceEnabled: true
          MetricsEnabled: true
          ThrottlingBurstLimit: 500
          ThrottlingRateLimit: 100

  # Secrets Manager for sensitive configuration
  FirebaseCredentials:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub '${AWS::StackName}-firebase-credentials'
      Description: Firebase service account credentials
      SecretString: !Sub |
        {
          "projectId": "${FirebaseProjectId}",
          "clientEmail": "${FirebaseClientEmail}",
          "privateKey": "${FirebasePrivateKey}"
        }

  JWTSecretStore:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub '${AWS::StackName}-jwt-secret'
      Description: JWT signing secret
      SecretString: !Ref JWTSecret
```

#### 6.3 Performance Optimization
```javascript
// Enhanced userFunctions.js with performance optimizations
const AWS = require('aws-sdk');
const admin = require('firebase-admin');

// Connection pooling and reuse
const dynamodb = new AWS.DynamoDB.DocumentClient({
  region: process.env.AWS_REGION || 'us-east-1',
  maxRetries: 3,
  retryDelayOptions: {
    customBackoff: function(retryCount) {
      return Math.pow(2, retryCount) * 100;
    }
  },
  httpOptions: {
    connectTimeout: 3000,
    timeout: 5000
  }
});

// Initialize Firebase once outside handler
let firebaseInitialized = false;
const initializeFirebase = () => {
  if (!firebaseInitialized && !admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')
      })
    });
    firebaseInitialized = true;
  }
};

// Optimized register function with caching
exports.registerUser = async (event) => {
  initializeFirebase();
  
  try {
    logger.info('Register user request received', { 
      requestId: event.requestContext?.requestId,
      timestamp: Date.now()
    });

    const { idToken, userData } = JSON.parse(event.body);

    // Verify Firebase token with error handling
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken, true);
    } catch (firebaseError) {
      logger.error('Firebase token verification failed', { 
        error: firebaseError.message,
        requestId: event.requestContext?.requestId
      });
      return createResponse(401, {
        error: true,
        message: 'Invalid authentication token'
      });
    }

    const { uid, email, name, picture } = decodedToken;

    // Check for existing user efficiently
    const existingUserCheck = await dynamodb.query({
      TableName: USERS_TABLE,
      IndexName: 'EmailIndex',
      KeyConditionExpression: 'email = :email',
      ExpressionAttributeValues: {
        ':email': email
      },
      Limit: 1
    }).promise();

    if (existingUserCheck.Items && existingUserCheck.Items.length > 0) {
      return createResponse(409, {
        error: true,
        message: 'User already exists'
      });
    }

    // Create optimized user record
    const userId = uuidv4();
    const timestamp = new Date().toISOString();
    
    const userRecord = {
      userId,
      firebaseUid: uid,
      email,
      displayName: userData?.displayName || name || '',
      profilePicture: userData?.profilePicture || picture || '',
      createdAt: timestamp,
      updatedAt: timestamp,
      lastLoginAt: timestamp,
      isActive: true,
      preferences: userData?.preferences || {},
      // Add fields for performance tracking
      loginCount: 1,
      lastIpAddress: event.requestContext?.identity?.sourceIp || '',
      userAgent: event.headers?.['User-Agent'] || ''
    };

    // Batch write for better performance
    await dynamodb.put({
      TableName: USERS_TABLE,
      Item: userRecord,
      ConditionExpression: 'attribute_not_exists(userId)'
    }).promise();

    // Generate JWT token
    const jwtToken = jwt.sign(
      { 
        userId, 
        email, 
        firebaseUid: uid,
        iat: Math.floor(Date.now() / 1000)
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    logger.info('User registered successfully', { 
      userId, 
      email,
      executionTime: Date.now() - (event.requestContext?.requestTimeEpoch || Date.now())
    });

    return createResponse(201, {
      success: true,
      message: 'User registered successfully',
      data: {
        userId,
        email,
        displayName: userRecord.displayName,
        profilePicture: userRecord.profilePicture,
        token: jwtToken,
        expiresIn: JWT_EXPIRES_IN
      }
    });

  } catch (error) {
    logger.error('Registration failed', { 
      error: error.message, 
      stack: error.stack,
      requestId: event.requestContext?.requestId
    });
    
    if (error.code === 'ConditionalCheckFailedException') {
      return createResponse(409, {
        error: true,
        message: 'User already exists'
      });
    }

    return createResponse(500, {
      error: true,
      message: 'Internal server error'
    });
  }
};
```

#### 2.2 Create Sessions Table
```javascript
// sessions-table-schema.js
const createSessionsTable = async () => {
    const params = {
        TableName: 'UserSessions',
        KeySchema: [
            {
                AttributeName: 'sessionId',
                KeyType: 'HASH'
            }
        ],
        AttributeDefinitions: [
            {
                AttributeName: 'sessionId',
                AttributeType: 'S'
            },
            {
                AttributeName: 'userId',
                AttributeType: 'S'
            }
        ],
        GlobalSecondaryIndexes: [
            {
                IndexName: 'UserIdIndex',
                KeySchema: [
                    {
                        AttributeName: 'userId',
                        KeyType: 'HASH'
                    }
                ],
                Projection: {
                    ProjectionType: 'ALL'
                },
                BillingMode: 'PAY_PER_REQUEST'
            }
        ],
        BillingMode: 'PAY_PER_REQUEST',
        TimeToLiveSpecification: {
            AttributeName: 'expiresAt',
            Enabled: true
        }
    };

    try {
        const result = await dynamodb.createTable(params).promise();
        console.log('Sessions table created successfully:', result);
    } catch (error) {
        console.error('Error creating sessions table:', error);
    }
};

createSessionsTable();
```

### Step 3: Lambda Functions Implementation

#### 3.1 User Registration Function
```javascript
// user-registration/index.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Registration event:', JSON.stringify(event, null, 2));
    
    try {
        // Parse request body
        const body = JSON.parse(event.body);
        const { email, password, displayName, authProvider, firebaseUid } = body;
        
        // Validate input
        if (!email || (!password && !firebaseUid)) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Email and password or Firebase UID required'
                })
            };
        }
        
        // Check if user already exists
        const existingUser = await getUserByEmail(email);
        if (existingUser) {
            return {
                statusCode: 409,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'User already exists'
                })
            };
        }
        
        // Create user
        const userId = uuidv4();
        const now = new Date().toISOString();
        
        const user = {
            userId,
            email,
            displayName: displayName || '',
            authProvider: authProvider || 'email',
            firebaseUid: firebaseUid || null,
            createdAt: now,
            updatedAt: now,
            isActive: true,
            profile: {
                firstName: '',
                lastName: '',
                photoURL: '',
                phoneNumber: ''
            }
        };
        
        // Hash password if provided
        if (password) {
            const saltRounds = 12;
            user.passwordHash = await bcrypt.hash(password, saltRounds);
        }
        
        // Save to DynamoDB
        await dynamodb.put({
            TableName: 'Users',
            Item: user,
            ConditionExpression: 'attribute_not_exists(userId)'
        }).promise();
        
        // Remove sensitive data from response
        const { passwordHash, ...safeUser } = user;
        
        return {
            statusCode: 201,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                message: 'User created successfully',
                user: safeUser
            })
        };
        
    } catch (error) {
        console.error('Registration error:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};

// Helper function to get user by email
async function getUserByEmail(email) {
    try {
        const result = await dynamodb.query({
            TableName: 'Users',
            IndexName: 'EmailIndex',
            KeyConditionExpression: 'email = :email',
            ExpressionAttributeValues: {
                ':email': email
            }
        }).promise();
        
        return result.Items.length > 0 ? result.Items[0] : null;
    } catch (error) {
        console.error('Error querying user by email:', error);
        return null;
    }
}
```

#### 3.2 User Authentication Function
```javascript
// user-authentication/index.js
const AWS = require('aws-sdk');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Authentication event:', JSON.stringify(event, null, 2));
    
    try {
        const body = JSON.parse(event.body);
        const { email, password, firebaseUid, authProvider } = body;
        
        // Validate input
        if (!email || (!password && !firebaseUid)) {
            return createResponse(400, {
                error: 'Email and password or Firebase UID required'
            });
        }
        
        // Get user from database
        const user = await getUserByEmail(email);
        if (!user) {
            return createResponse(401, {
                error: 'Invalid credentials'
            });
        }
        
        // Verify credentials
        let isValidAuth = false;
        
        if (authProvider === 'google' && firebaseUid) {
            // For Google sign-in, verify Firebase UID
            isValidAuth = user.firebaseUid === firebaseUid;
        } else if (password && user.passwordHash) {
            // For email/password, verify password
            isValidAuth = await bcrypt.compare(password, user.passwordHash);
        }
        
        if (!isValidAuth) {
            return createResponse(401, {
                error: 'Invalid credentials'
            });
        }
        
        // Check if user is active
        if (!user.isActive) {
            return createResponse(403, {
                error: 'Account is disabled'
            });
        }
        
        // Create session
        const session = await createUserSession(user.userId);
        
        // Generate JWT token
        const token = generateJWT(user, session);
        
        // Update last login
        await updateLastLogin(user.userId);
        
        // Remove sensitive data
        const { passwordHash, ...safeUser } = user;
        
        return createResponse(200, {
            message: 'Authentication successful',
            user: safeUser,
            token,
            session: {
                sessionId: session.sessionId,
                expiresAt: session.expiresAt
            }
        });
        
    } catch (error) {
        console.error('Authentication error:', error);
        return createResponse(500, {
            error: 'Internal server error',
            message: error.message
        });
    }
};

// Helper functions
async function getUserByEmail(email) {
    try {
        const result = await dynamodb.query({
            TableName: 'Users',
            IndexName: 'EmailIndex',
            KeyConditionExpression: 'email = :email',
            ExpressionAttributeValues: {
                ':email': email
            }
        }).promise();
        
        return result.Items.length > 0 ? result.Items[0] : null;
    } catch (error) {
        console.error('Error querying user:', error);
        return null;
    }
}

async function createUserSession(userId) {
    const sessionId = uuidv4();
    const now = Date.now();
    const expiresAt = now + (24 * 60 * 60 * 1000); // 24 hours
    
    const session = {
        sessionId,
        userId,
        createdAt: now,
        expiresAt,
        isActive: true
    };
    
    await dynamodb.put({
        TableName: 'UserSessions',
        Item: session
    }).promise();
    
    return session;
}

function generateJWT(user, session) {
    const payload = {
        userId: user.userId,
        email: user.email,
        sessionId: session.sessionId,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(session.expiresAt / 1000)
    };
    
    return jwt.sign(payload, process.env.JWT_SECRET || 'default-secret');
}

async function updateLastLogin(userId) {
    try {
        await dynamodb.update({
            TableName: 'Users',
            Key: { userId },
            UpdateExpression: 'SET lastLoginAt = :now',
            ExpressionAttributeValues: {
                ':now': new Date().toISOString()
            }
        }).promise();
    } catch (error) {
        console.error('Error updating last login:', error);
    }
}

function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}
```

#### 3.3 Token Validation Function
```javascript
// token-validation/index.js
const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Token validation event:', JSON.stringify(event, null, 2));
    
    try {
        // Extract token from Authorization header
        const authHeader = event.headers.Authorization || event.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return createResponse(401, {
                error: 'Missing or invalid authorization header'
            });
        }
        
        const token = authHeader.substring(7); // Remove 'Bearer ' prefix
        
        // Verify JWT token
        let decoded;
        try {
            decoded = jwt.verify(token, process.env.JWT_SECRET || 'default-secret');
        } catch (jwtError) {
            return createResponse(401, {
                error: 'Invalid token',
                details: jwtError.message
            });
        }
        
        // Check if session is still active
        const session = await getSession(decoded.sessionId);
        if (!session || !session.isActive) {
            return createResponse(401, {
                error: 'Session expired or invalid'
            });
        }
        
        // Check if session has expired
        if (Date.now() > session.expiresAt) {
            await deactivateSession(decoded.sessionId);
            return createResponse(401, {
                error: 'Session expired'
            });
        }
        
        // Get user information
        const user = await getUser(decoded.userId);
        if (!user || !user.isActive) {
            return createResponse(401, {
                error: 'User not found or inactive'
            });
        }
        
        // Remove sensitive data
        const { passwordHash, ...safeUser } = user;
        
        return createResponse(200, {
            message: 'Token is valid',
            user: safeUser,
            session: {
                sessionId: session.sessionId,
                expiresAt: session.expiresAt
            }
        });
        
    } catch (error) {
        console.error('Token validation error:', error);
        return createResponse(500, {
            error: 'Internal server error',
            message: error.message
        });
    }
};

// Helper functions
async function getSession(sessionId) {
    try {
        const result = await dynamodb.get({
            TableName: 'UserSessions',
            Key: { sessionId }
        }).promise();
        
        return result.Item || null;
    } catch (error) {
        console.error('Error getting session:', error);
        return null;
    }
}

async function getUser(userId) {
    try {
        const result = await dynamodb.get({
            TableName: 'Users',
            Key: { userId }
        }).promise();
        
        return result.Item || null;
    } catch (error) {
        console.error('Error getting user:', error);
        return null;
    }
}

async function deactivateSession(sessionId) {
    try {
        await dynamodb.update({
            TableName: 'UserSessions',
            Key: { sessionId },
            UpdateExpression: 'SET isActive = :false',
            ExpressionAttributeValues: {
                ':false': false
            }
        }).promise();
    } catch (error) {
        console.error('Error deactivating session:', error);
    }
}

function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}
```

### Step 4: Deployment Scripts

#### 4.1 Package and Deploy Script
```bash
#!/bin/bash
# deploy-lambdas.sh

# Configuration
REGION="us-east-1"
ROLE_ARN="arn:aws:iam::YOUR-ACCOUNT-ID:role/AuthLambdaExecutionRole"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Lambda deployment...${NC}"

# Function to deploy a Lambda function
deploy_function() {
    local function_name=$1
    local directory=$2
    local handler=$3
    
    echo -e "${YELLOW}Deploying $function_name...${NC}"
    
    # Navigate to function directory
    cd $directory
    
    # Install dependencies
    npm install
    
    # Create deployment package
    zip -r "../${function_name}.zip" . -x "*.git*" "node_modules/.cache/*"
    
    # Navigate back
    cd ..
    
    # Check if function exists
    if aws lambda get-function --function-name $function_name --region $REGION &>/dev/null; then
        # Update existing function
        echo "Updating existing function..."
        aws lambda update-function-code \
            --function-name $function_name \
            --zip-file fileb://${function_name}.zip \
            --region $REGION
            
        aws lambda update-function-configuration \
            --function-name $function_name \
            --handler $handler \
            --runtime nodejs18.x \
            --timeout 30 \
            --memory-size 256 \
            --region $REGION \
            --environment Variables='{JWT_SECRET=your-jwt-secret-key}'
    else
        # Create new function
        echo "Creating new function..."
        aws lambda create-function \
            --function-name $function_name \
            --runtime nodejs18.x \
            --role $ROLE_ARN \
            --handler $handler \
            --zip-file fileb://${function_name}.zip \
            --timeout 30 \
            --memory-size 256 \
            --region $REGION \
            --environment Variables='{JWT_SECRET=your-jwt-secret-key}'
    fi
    
    # Clean up
    rm ${function_name}.zip
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $function_name deployed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to deploy $function_name${NC}"
        exit 1
    fi
}

# Deploy all functions
deploy_function "user-registration" "user-registration" "index.handler"
deploy_function "user-authentication" "user-authentication" "index.handler"
deploy_function "token-validation" "token-validation" "index.handler"

echo -e "${GREEN}All Lambda functions deployed successfully!${NC}"
```

#### 4.2 API Gateway Setup Script
```bash
#!/bin/bash
# setup-api-gateway.sh

REGION="us-east-1"
API_NAME="ios-auth-api"

echo "Setting up API Gateway..."

# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name $API_NAME \
    --description "iOS Authentication API" \
    --region $REGION \
    --query 'id' \
    --output text)

echo "Created API with ID: $API_ID"

# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[0].id' \
    --output text)

# Create auth resource
AUTH_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "auth" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create register endpoint
REGISTER_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $AUTH_RESOURCE_ID \
    --path-part "register" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create login endpoint
LOGIN_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $AUTH_RESOURCE_ID \
    --path-part "login" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create validate endpoint
VALIDATE_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $AUTH_RESOURCE_ID \
    --path-part "validate" \
    --region $REGION \
    --query 'id' \
    --output text)

echo "Created all resources. Setting up methods..."

# Function to create method and integration
setup_method() {
    local resource_id=$1
    local http_method=$2
    local lambda_function=$3
    
    # Create method
    aws apigateway put-method \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method $http_method \
        --authorization-type "NONE" \
        --region $REGION
    
    # Set up integration
    aws apigateway put-integration \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method $http_method \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$lambda_function/invocations" \
        --region $REGION
    
    # Add Lambda permission
    aws lambda add-permission \
        --function-name $lambda_function \
        --statement-id "apigateway-invoke-$lambda_function" \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/*" \
        --region $REGION
    
    # Set up CORS
    aws apigateway put-method \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method OPTIONS \
        --authorization-type "NONE" \
        --region $REGION
    
    aws apigateway put-integration \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method OPTIONS \
        --type MOCK \
        --integration-http-method OPTIONS \
        --request-templates '{"application/json":"{\"statusCode\":200}"}' \
        --region $REGION
    
    aws apigateway put-method-response \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method OPTIONS \
        --status-code 200 \
        --response-parameters method.response.header.Access-Control-Allow-Headers=false,method.response.header.Access-Control-Allow-Methods=false,method.response.header.Access-Control-Allow-Origin=false \
        --region $REGION
    
    aws apigateway put-integration-response \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method OPTIONS \
        --status-code 200 \
        --response-parameters method.response.header.Access-Control-Allow-Headers="'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",method.response.header.Access-Control-Allow-Methods="'GET,POST,OPTIONS'",method.response.header.Access-Control-Allow-Origin="'*'" \
        --region $REGION
}

# Set up all methods
setup_method $REGISTER_RESOURCE_ID "POST" "user-registration"
setup_method $LOGIN_RESOURCE_ID "POST" "user-authentication"
setup_method $VALIDATE_RESOURCE_ID "GET" "token-validation"

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name "prod" \
    --stage-description "Production stage" \
    --description "Initial deployment" \
    --region $REGION

echo "API Gateway setup complete!"
echo "API URL: https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
```

### Step 5: Environment Configuration

#### 5.1 Environment Variables Setup
```javascript
// config/environment.js
const environments = {
    development: {
        JWT_SECRET: 'dev-jwt-secret-key-change-in-production',
        DYNAMODB_REGION: 'us-east-1',
        USERS_TABLE: 'Users',
        SESSIONS_TABLE: 'UserSessions',
        TOKEN_EXPIRY: 24 * 60 * 60 * 1000, // 24 hours
        BCRYPT_ROUNDS: 12
    },
    production: {
        JWT_SECRET: process.env.JWT_SECRET,
        DYNAMODB_REGION: process.env.AWS_REGION,
        USERS_TABLE: process.env.USERS_TABLE || 'Users',
        SESSIONS_TABLE: process.env.SESSIONS_TABLE || 'UserSessions',
        TOKEN_EXPIRY: 24 * 60 * 60 * 1000,
        BCRYPT_ROUNDS: 12
    }
};

const env = process.env.NODE_ENV || 'development';
module.exports = environments[env];
```

#### 5.2 Package.json for Lambda Functions
```json
{
  "name": "ios-auth-lambda",
  "version": "1.0.0",
  "description": "AWS Lambda functions for iOS authentication",
  "main": "index.js",
  "scripts": {
    "test": "jest",
    "deploy": "./deploy-lambdas.sh"
  },
  "dependencies": {
    "aws-sdk": "^2.1480.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "aws-sdk-mock": "^5.8.0"
  },
  "keywords": [
    "aws",
    "lambda",
    "authentication",
    "ios"
  ],
  "author": "Your Name",
  "license": "MIT"
}
```

---

## 🧪 Testing and Validation

### Step 6: Testing Lambda Functions

#### 6.1 Unit Tests
```javascript
// __tests__/user-registration.test.js
const AWSMock = require('aws-sdk-mock');
const AWS = require('aws-sdk');
const { handler } = require('../user-registration/index');

describe('User Registration Lambda', () => {
    beforeEach(() => {
        AWSMock.setSDKInstance(AWS);
    });

    afterEach(() => {
        AWSMock.restore('DynamoDB.DocumentClient');
    });

    test('should register new user successfully', async () => {
        // Mock DynamoDB query (user doesn't exist)
        AWSMock.mock('DynamoDB.DocumentClient', 'query', (params, callback) => {
            callback(null, { Items: [] });
        });

        // Mock DynamoDB put (save user)
        AWSMock.mock('DynamoDB.DocumentClient', 'put', (params, callback) => {
            callback(null, {});
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

        expect(result.statusCode).toBe(201);
        expect(body.message).toBe('User created successfully');
        expect(body.user.email).toBe('test@example.com');
    });

    test('should return error for existing user', async () => {
        // Mock DynamoDB query (user exists)
        AWSMock.mock('DynamoDB.DocumentClient', 'query', (params, callback) => {
            callback(null, { 
                Items: [{ 
                    userId: '123',
                    email: 'test@example.com' 
                }] 
            });
        });

        const event = {
            body: JSON.stringify({
                email: 'test@example.com',
                password: 'password123'
            })
        };

        const result = await handler(event);
        const body = JSON.parse(result.body);

        expect(result.statusCode).toBe(409);
        expect(body.error).toBe('User already exists');
    });
});
```

#### 6.2 Integration Tests
```javascript
// __tests__/integration.test.js
const axios = require('axios');

const API_BASE_URL = 'https://your-api-id.execute-api.us-east-1.amazonaws.com/prod';

describe('Authentication API Integration Tests', () => {
    let authToken;
    const testUser = {
        email: `test-${Date.now()}@example.com`,
        password: 'TestPassword123!',
        displayName: 'Test User'
    };

    test('should register new user', async () => {
        const response = await axios.post(`${API_BASE_URL}/auth/register`, testUser);
        
        expect(response.status).toBe(201);
        expect(response.data.message).toBe('User created successfully');
        expect(response.data.user.email).toBe(testUser.email);
    });

    test('should authenticate user', async () => {
        const response = await axios.post(`${API_BASE_URL}/auth/login`, {
            email: testUser.email,
            password: testUser.password
        });
        
        expect(response.status).toBe(200);
        expect(response.data.message).toBe('Authentication successful');
        expect(response.data.token).toBeDefined();
        
        authToken = response.data.token;
    });

    test('should validate token', async () => {
        const response = await axios.get(`${API_BASE_URL}/auth/validate`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });
        
        expect(response.status).toBe(200);
        expect(response.data.message).toBe('Token is valid');
        expect(response.data.user.email).toBe(testUser.email);
    });
});
```

---

## 🔐 Security Best Practices

### Security Configuration
```javascript
// security/security-utils.js
const crypto = require('crypto');

class SecurityUtils {
    // Generate secure random string
    static generateSecureToken(length = 32) {
        return crypto.randomBytes(length).toString('hex');
    }
    
    // Hash sensitive data
    static hashData(data, salt) {
        return crypto.pbkdf2Sync(data, salt, 10000, 64, 'sha512').toString('hex');
    }
    
    // Sanitize user input
    static sanitizeInput(input) {
        if (typeof input !== 'string') return input;
        return input.trim().replace(/[<>]/g, '');
    }
    
    // Validate email format
    static isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    
    // Check password strength
    static isStrongPassword(password) {
        if (password.length < 8) return false;
        if (!/[A-Z]/.test(password)) return false;
        if (!/[a-z]/.test(password)) return false;
        if (!/[0-9]/.test(password)) return false;
        if (!/[!@#$%^&*]/.test(password)) return false;
        return true;
    }
    
    // Rate limiting check
    static async checkRateLimit(identifier, maxAttempts = 5, windowMs = 900000) {
        // Implementation would depend on your caching solution
        // This is a placeholder for rate limiting logic
        return true;
    }
}

module.exports = SecurityUtils;
```

---

## 📝 Practice Exercises

### Exercise 1: Basic Setup (3 hours)
1. Set up AWS CLI and configure credentials
2. Create DynamoDB tables using AWS CLI
3. Deploy a simple Lambda function
4. Test function using AWS Console

### Exercise 2: API Integration (4 hours)
1. Set up API Gateway with one endpoint
2. Connect Lambda function to API Gateway
3. Test API using Postman or curl
4. Add proper CORS configuration

### Exercise 3: Full Implementation (6 hours)
1. Implement all three Lambda functions
2. Set up complete API Gateway configuration
3. Add comprehensive error handling
4. Write and run unit tests

---

## 📊 Assignment: Complete Backend Setup

### Requirements:
1. **AWS Setup** (2 hours)
   - Configure AWS CLI and IAM roles
   - Create DynamoDB tables with proper indexes
   - Set up Lambda execution environment

2. **Lambda Implementation** (4 hours)
   - Implement user registration function
   - Implement authentication function
   - Implement token validation function
   - Add comprehensive error handling

3. **API Gateway Configuration** (2 hours)
   - Create REST API with proper endpoints
   - Configure CORS for iOS app integration
   - Set up proper response formats

4. **Testing** (2 hours)
   - Write unit tests for Lambda functions
   - Perform integration testing
   - Test error scenarios and edge cases

### Deliverables:
- [ ] Working Lambda functions deployed to AWS
- [ ] API Gateway configured with all endpoints
- [ ] DynamoDB tables with sample data
- [ ] Unit tests with good coverage
- [ ] Integration test results
- [ ] API documentation

---

## ✅ Lesson Completion Checklist

- [ ] Understand serverless architecture concepts
- [ ] Set up AWS CLI and IAM permissions
- [ ] Create and configure DynamoDB tables
- [ ] Implement user registration Lambda function
- [ ] Implement authentication Lambda function
- [ ] Implement token validation Lambda function
- [ ] Set up API Gateway with proper endpoints
- [ ] Configure CORS and security headers
- [ ] Write comprehensive unit tests
- [ ] Perform integration testing
- [ ] Deploy and test in AWS environment
- [ ] Document API endpoints and usage

**Estimated Time to Complete**: 8-10 hours  
**Next Lesson**: API Integration with iOS App

---

*Ready to connect your iOS app to the backend? Continue to the next lesson on API integration!*

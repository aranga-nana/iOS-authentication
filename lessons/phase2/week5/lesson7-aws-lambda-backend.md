# Lesson 7: AWS Lambda Backend Setup
**Phase 2, Week 5** | **Duration:** 8-10 hours | **Difficulty:** Advanced

**Prerequisites**: Basic AWS knowledge, Firebase Authentication, completed Phase 2 Week 1-4 lessons

## 🎯 Learning Objectives
- Set up AWS Lambda functions for authentication backend
- Create API Gateway endpoints for iOS app communication
- Implement DynamoDB for user data storage
- Configure Lambda environment variables and permissions
- Understand serverless architecture patterns

---

## 📚 Theory Overview

### What is AWS Lambda?
AWS Lambda is a serverless compute service that runs code in response to events without managing servers. Perfect for:
- **Authentication processing**
- **User profile management**
- **Token validation**
- **Business logic execution**

### Architecture Overview:
```
iOS App → API Gateway → Lambda Functions → DynamoDB
                    ↓
               CloudWatch Logs
```

### Key Benefits:
- **Serverless**: No server management
- **Auto-scaling**: Handles traffic spikes automatically
- **Cost-effective**: Pay only for execution time
- **Integration**: Works seamlessly with other AWS services

---

## 🛠 Implementation Guide

### Step 1: AWS Setup and Configuration

#### 1.1 AWS CLI Installation and Configuration
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Configure AWS CLI
aws configure
# Enter your Access Key ID, Secret Access Key, Region, and Output format
```

#### 1.2 Create IAM Role for Lambda
```bash
# Create trust policy for Lambda
cat > lambda-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name AuthLambdaExecutionRole \
  --assume-role-policy-document file://lambda-trust-policy.json

# Attach basic execution policy
aws iam attach-role-policy \
  --role-name AuthLambdaExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Attach DynamoDB access policy
aws iam attach-role-policy \
  --role-name AuthLambdaExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
```

### Step 2: DynamoDB Table Setup

#### 2.1 Create Users Table
```javascript
// users-table-schema.js
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB();

const createUsersTable = async () => {
    const params = {
        TableName: 'Users',
        KeySchema: [
            {
                AttributeName: 'userId',
                KeyType: 'HASH' // Partition key
            }
        ],
        AttributeDefinitions: [
            {
                AttributeName: 'userId',
                AttributeType: 'S'
            },
            {
                AttributeName: 'email',
                AttributeType: 'S'
            }
        ],
        GlobalSecondaryIndexes: [
            {
                IndexName: 'EmailIndex',
                KeySchema: [
                    {
                        AttributeName: 'email',
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
        Tags: [
            {
                Key: 'Environment',
                Value: 'Development'
            },
            {
                Key: 'Project',
                Value: 'iOS-Auth'
            }
        ]
    };

    try {
        const result = await dynamodb.createTable(params).promise();
        console.log('Users table created successfully:', result);
    } catch (error) {
        console.error('Error creating table:', error);
    }
};

// Create table
createUsersTable();
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

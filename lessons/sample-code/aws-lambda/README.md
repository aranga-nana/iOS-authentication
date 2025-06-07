# AWS Lambda Functions for iOS Authentication

This directory contains the AWS Lambda functions that power the backend authentication system for the iOS app, built with AWS SAM (Serverless Application Model).

## Features

- **User Registration**: Register new users with Firebase authentication
- **User Login**: Authenticate existing users and update login timestamps
- **Profile Management**: Get, update, and delete user profiles
- **Security**: JWT token validation, rate limiting, input validation
- **Error Handling**: Comprehensive error handling with structured responses
- **Logging**: Structured logging with Winston and CloudWatch
- **Testing**: Complete test suite with Jest
- **Infrastructure as Code**: AWS SAM template for easy deployment
- **Local Development**: SAM CLI support for local testing

## Architecture

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│   iOS App   │───▶│   API Gateway    │───▶│   Lambda    │
└─────────────┘    └──────────────────┘    └─────────────┘
                                                   │
                                          ┌────────▼────────┐
                                          │    DynamoDB     │
                                          └─────────────────┘
                                                   │
                                          ┌────────▼────────┐
                                          │ Firebase Admin  │
                                          └─────────────────┘
```

## SAM Template Overview

The `template.yaml` file defines the complete serverless infrastructure:

- **5 Lambda Functions**: User registration, login, profile management
- **API Gateway**: RESTful API with CORS support and request tracing
- **DynamoDB Table**: User data storage with GSI for email lookups
- **CloudWatch Logs**: Centralized logging with retention policies
- **Application Insights**: Monitoring and observability

## Functions

### 1. Register User (`POST /auth/register`)
- Validates Firebase ID token
- Creates new user record in DynamoDB
- Returns custom JWT token for API access
- Handles duplicate registrations gracefully

### 2. Login User (`POST /auth/login`)
- Validates Firebase ID token
- Updates last login timestamp
- Returns user profile and JWT token
- Checks account status

### 3. Get User Profile (`GET /users/{userId}`)
- Requires JWT authentication
- Returns user profile data
- Access control (users can only access own profile)

### 4. Update User Profile (`PUT /users/{userId}`)
- Requires JWT authentication
- Updates display name, profile picture, preferences
- Input validation and sanitization

### 5. Delete User Account (`DELETE /users/{userId}`)
- Requires JWT authentication
- Soft delete (marks account as inactive)
- Preserves data for audit purposes

## Setup

### Prerequisites
- Node.js 18+
- AWS CLI configured with appropriate permissions
- AWS SAM CLI installed
- Firebase project with Admin SDK

### Installation

1. Install AWS SAM CLI:
```bash
# macOS
brew install aws-sam-cli

# Windows
choco install aws-sam-cli

# Linux
pip install aws-sam-cli
```

2. Install dependencies:
```bash
npm install
```

3. Configure environment variables for local development:
```bash
cp env.json.example env.json
# Edit env.json with your actual values
```

4. Configure Firebase Admin SDK:
   - Download service account key from Firebase Console
   - Add credentials to environment variables

### Local Development

Run functions locally with SAM CLI:
```bash
# Start local API Gateway
npm run local

# Or use SAM directly
sam local start-api --env-vars env.json
```

The API will be available at `http://localhost:3000`

For local DynamoDB, you can use DynamoDB Local:
```bash
# Install DynamoDB Local
docker run -p 8000:8000 amazon/dynamodb-local

# Create local table
aws dynamodb create-table \
  --table-name ios-auth-backend-users-local \
  --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=email,AttributeType=S \
  --key-schema AttributeName=userId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes IndexName=EmailIndex,KeySchema=[{AttributeName=email,KeyType=HASH}],Projection={ProjectionType=ALL} \
  --endpoint-url http://localhost:8000
```

### Testing

Run the test suite:
```bash
npm test
```

Run tests with coverage:
```bash
npm test -- --coverage
```

### Deployment

Deploy to AWS using SAM:
```bash
# Build the application
npm run build-sam

# Deploy to development
sam deploy --config-env dev

# Deploy to staging
sam deploy --config-env staging

# Deploy to production
sam deploy --config-env prod
```

Alternatively, use npm scripts:
```bash
# Build and validate
npm run build
npm run validate

# Deploy
npm run deploy
```

### Managing Parameters

For sensitive parameters like JWT secrets and Firebase keys, use AWS Systems Manager Parameter Store or AWS Secrets Manager:

```bash
# Store JWT secret
aws ssm put-parameter \
  --name "/ios-auth-backend/dev/jwt-secret" \
  --value "your-super-secret-key" \
  --type "SecureString"

# Store Firebase private key
aws ssm put-parameter \
  --name "/ios-auth-backend/dev/firebase-private-key" \
  --value "$(cat firebase-service-account-key.json | jq -r .private_key)" \
  --type "SecureString"
```

## API Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/auth/register` | Register new user | Firebase Token |
| POST | `/auth/login` | Login user | Firebase Token |
| GET | `/users/{userId}` | Get user profile | JWT Token |
| PUT | `/users/{userId}` | Update user profile | JWT Token |
| DELETE | `/users/{userId}` | Delete user account | JWT Token |

## Request/Response Format

### Registration Request
```json
{
  "idToken": "firebase-id-token",
  "userData": {
    "displayName": "John Doe",
    "profilePicture": "https://example.com/avatar.jpg",
    "preferences": {
      "notifications": true,
      "theme": "dark"
    }
  }
}
```

### Success Response
```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "userId": "user-123",
    "email": "user@example.com",
    "displayName": "John Doe",
    "profilePicture": "https://example.com/avatar.jpg",
    "createdAt": "2023-12-01T00:00:00.000Z"
  },
  "accessToken": "jwt-token-here"
}
```

### Error Response
```json
{
  "error": true,
  "message": "Invalid Firebase token",
  "errorCode": "INVALID_TOKEN",
  "timestamp": "2023-12-01T00:00:00.000Z"
}
```

## Security Features

### Rate Limiting
- Registration: 5 requests per 5 minutes per IP
- Login: 20 requests per 5 minutes per IP
- Other endpoints: Default AWS API Gateway limits

### Input Validation
- Email format validation
- URL validation for profile pictures
- Display name length limits
- JSON schema validation

### Authentication
- Firebase ID token validation
- Custom JWT tokens for API access
- Access control enforcement

### Error Handling
- Structured error responses
- No sensitive information leaked
- Comprehensive logging

## Performance Optimizations

### AWS Lambda
- Connection pooling for DynamoDB
- Reserved concurrency limits
- Memory optimization (512MB)
- 30-second timeout

### DynamoDB
- Pay-per-request billing
- Point-in-time recovery enabled
- Encryption at rest
- Global secondary index for email lookups

## Monitoring and Observability

### Application Insights
AWS Application Insights is automatically configured to provide:
- Application topology visualization
- Performance monitoring dashboards
- Automated anomaly detection
- Custom CloudWatch dashboards

### CloudWatch Metrics
SAM automatically creates CloudWatch metrics for:
- Function duration and invocations
- API Gateway request/response metrics
- Error rates and cold starts
- DynamoDB read/write metrics

### X-Ray Tracing
Distributed tracing is enabled by default:
- End-to-end request tracing
- Service map visualization
- Performance bottleneck identification
- Error root cause analysis

### Logging
- Structured JSON logs with correlation IDs
- Request/response correlation
- Performance timing
- Centralized log aggregation with CloudWatch Logs

### Alarms and Notifications
Configure CloudWatch alarms for:
```bash
# Create high error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ios-auth-high-error-rate" \
  --alarm-description "High error rate in authentication API" \
  --metric-name "4XXError" \
  --namespace "AWS/ApiGateway" \
  --statistic "Sum" \
  --period 300 \
  --threshold 10 \
  --comparison-operator "GreaterThanThreshold"
```

## SAM CLI Commands

### Development Workflow
```bash
# Validate template
sam validate

# Build application
sam build --cached --parallel

# Test locally
sam local start-api --env-vars env.json --port 3000

# Invoke specific function locally
sam local invoke RegisterUserFunction --event events/register-event.json

# Generate sample events
sam local generate-event apigateway aws-proxy --path /auth/register --method POST

# Test with hot reloading
sam sync --stack-name ios-auth-backend-dev --watch
```

### Deployment Commands
```bash
# Guided deployment (first time)
sam deploy --guided

# Deploy with specific configuration
sam deploy --config-env dev --parameter-overrides "JWTSecret=your-secret"

# Deploy with capabilities
sam deploy --capabilities CAPABILITY_IAM

# Deploy and skip confirmation
sam deploy --no-confirm-changeset
```

### Troubleshooting
```bash
# View logs
sam logs --stack-name ios-auth-backend-dev --tail

# View specific function logs
sam logs --name RegisterUserFunction --stack-name ios-auth-backend-dev --tail

# Debug locally
sam local start-api --debug-port 5858 --env-vars env.json
```

## Performance Optimizations

### AWS Lambda Best Practices
- **Connection Reuse**: DynamoDB DocumentClient initialized outside handler
- **Reserved Concurrency**: Function-specific limits to prevent resource exhaustion
- **Memory Optimization**: 512MB provides optimal price/performance
- **Cold Start Mitigation**: Keep functions warm with CloudWatch Events

### DynamoDB Optimizations
- **On-Demand Billing**: Automatic scaling without capacity planning
- **Point-in-Time Recovery**: Data protection without performance impact
- **Encryption at Rest**: Security without additional latency
- **GSI Design**: Email index for efficient user lookups

### API Gateway Features
- **Request Validation**: Schema validation at gateway level
- **Caching**: Response caching for frequently accessed data
- **Throttling**: Built-in rate limiting protection
- **CORS**: Automated CORS header management

## Security Best Practices

### Infrastructure Security
- **IAM Principle of Least Privilege**: Function-specific permissions
- **VPC Configuration**: Optional VPC deployment for enhanced isolation
- **Resource-Based Policies**: Fine-grained access control
- **Encryption**: Data encrypted in transit and at rest

### Application Security
- **Input Validation**: Multi-layer validation (API Gateway + Lambda)
- **Token Verification**: Firebase and JWT token validation
- **Rate Limiting**: IP-based and user-based limits
- **CORS Configuration**: Strict origin policies

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `JWT_SECRET` | Secret key for JWT signing | Yes |
| `JWT_EXPIRES_IN` | JWT token expiration time | No (default: 24h) |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Yes |
| `FIREBASE_CLIENT_EMAIL` | Firebase service account email | Yes |
| `FIREBASE_PRIVATE_KEY` | Firebase service account private key | Yes |
| `LOG_LEVEL` | Winston log level | No (default: info) |
| `USERS_TABLE` | DynamoDB table name | Auto-generated |

## Troubleshooting

### Common Issues

1. **Firebase Token Validation Fails**
   - Check Firebase project configuration
   - Verify service account credentials
   - Ensure token hasn't expired

2. **DynamoDB Access Denied**
   - Check IAM role permissions
   - Verify table name configuration
   - Check AWS region settings

3. **CORS Errors**
   - Verify CORS configuration in template.yaml
   - Check request headers
   - Test with Postman/curl first

### Debug Commands

```bash
# View CloudWatch logs
sam logs -n RegisterUser --stack-name ios-auth-backend-dev -t

# Test function locally
sam local invoke RegisterUser -e test-event.json

# Check DynamoDB table
aws dynamodb scan --table-name ios-auth-users-dev

# Validate deployment
sam list endpoints --stack-name ios-auth-backend-dev
```

## Development Guidelines

### Code Style
- Use ESLint for code linting
- Prettier for code formatting
- Follow AWS Lambda best practices

### Testing
- Unit tests for all functions
- Mock AWS services in tests
- Test error scenarios
- Maintain >80% code coverage

### Documentation
- Update API documentation
- Document environment variables
- Include error codes reference
- Update README for changes

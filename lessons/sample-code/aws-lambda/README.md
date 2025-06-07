# AWS Lambda Functions for iOS Authentication

This directory contains the AWS Lambda functions that power the backend authentication system for the iOS app.

## Features

- **User Registration**: Register new users with Firebase authentication
- **User Login**: Authenticate existing users and update login timestamps
- **Profile Management**: Get, update, and delete user profiles
- **Security**: JWT token validation, rate limiting, input validation
- **Error Handling**: Comprehensive error handling with structured responses
- **Logging**: Structured logging with Winston
- **Testing**: Complete test suite with Jest

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
- AWS CLI configured
- Serverless Framework
- Firebase project with Admin SDK

### Installation

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your actual values
```

3. Configure Firebase Admin SDK:
   - Download service account key from Firebase Console
   - Add credentials to environment variables

### Local Development

Run functions locally with Serverless Offline:
```bash
npm run local
```

The API will be available at `http://localhost:3001`

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

Deploy to AWS:
```bash
# Deploy to development
serverless deploy

# Deploy to production
serverless deploy --stage prod
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

## Monitoring

### CloudWatch Metrics
- Function duration
- Error rates
- Invocation counts
- DynamoDB metrics

### Logging
- Structured JSON logs
- Request/response correlation
- Performance timing
- Error stack traces

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
   - Verify CORS configuration in serverless.yml
   - Check request headers
   - Test with Postman/curl first

### Debug Commands

```bash
# View CloudWatch logs
serverless logs -f registerUser -t

# Test function locally
serverless invoke local -f registerUser -p test-event.json

# Check DynamoDB table
aws dynamodb scan --table-name ios-auth-users-dev

# Validate deployment
serverless info
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

const { registerUser, loginUser, getUserProfile, updateUserProfile, deleteUserAccount } = require('../userFunctions');
const AWSMock = require('aws-sdk-mock');
const jwt = require('jsonwebtoken');

// Mock Firebase Admin
jest.mock('firebase-admin', () => ({
  apps: [],
  initializeApp: jest.fn(),
  credential: {
    cert: jest.fn()
  },
  auth: () => ({
    verifyIdToken: jest.fn()
  })
}));

const admin = require('firebase-admin');

// Test data
const mockUser = {
  userId: 'test-user-123',
  email: 'test@example.com',
  displayName: 'Test User',
  profilePicture: 'https://example.com/avatar.jpg',
  createdAt: '2023-01-01T00:00:00.000Z',
  updatedAt: '2023-01-01T00:00:00.000Z',
  lastLoginAt: '2023-01-01T00:00:00.000Z',
  isActive: true,
  version: 1
};

const mockFirebaseToken = {
  uid: 'test-user-123',
  email: 'test@example.com',
  name: 'Test User',
  picture: 'https://example.com/avatar.jpg'
};

const createMockEvent = (method = 'POST', body = {}, pathParameters = {}, headers = {}) => ({
  httpMethod: method,
  body: JSON.stringify(body),
  pathParameters,
  headers,
  requestContext: {
    identity: {
      sourceIp: '127.0.0.1'
    }
  }
});

describe('User Registration', () => {
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    AWSMock.restore('DynamoDB.DocumentClient');
    
    // Set up environment variables
    process.env.USERS_TABLE = 'test-users-table';
    process.env.JWT_SECRET = 'test-secret';
    process.env.JWT_EXPIRES_IN = '24h';
  });

  test('should register new user successfully', async () => {
    // Mock Firebase token verification
    admin.auth().verifyIdToken.mockResolvedValue(mockFirebaseToken);
    
    // Mock DynamoDB operations
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, {}); // User doesn't exist
    });
    
    AWSMock.mock('DynamoDB.DocumentClient', 'put', (params, callback) => {
      callback(null, {});
    });
    
    const event = createMockEvent('POST', {
      idToken: 'valid-firebase-token',
      userData: {
        displayName: 'Test User'
      }
    });
    
    const result = await registerUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(201);
    expect(response.success).toBe(true);
    expect(response.user.userId).toBe(mockFirebaseToken.uid);
    expect(response.user.email).toBe(mockFirebaseToken.email);
    expect(response.accessToken).toBeDefined();
  });

  test('should return error for invalid Firebase token', async () => {
    // Mock Firebase token verification failure
    admin.auth().verifyIdToken.mockRejectedValue(new Error('Invalid token'));
    
    const event = createMockEvent('POST', {
      idToken: 'invalid-firebase-token'
    });
    
    const result = await registerUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(401);
    expect(response.error).toBe(true);
    expect(response.errorCode).toBe('INVALID_TOKEN');
  });

  test('should return error when user already exists', async () => {
    // Mock Firebase token verification
    admin.auth().verifyIdToken.mockResolvedValue(mockFirebaseToken);
    
    // Mock DynamoDB get to return existing user
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, { Item: mockUser });
    });
    
    const event = createMockEvent('POST', {
      idToken: 'valid-firebase-token'
    });
    
    const result = await registerUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(200);
    expect(response.success).toBe(true);
    expect(response.message).toBe('User already registered');
  });

  test('should handle missing token', async () => {
    const event = createMockEvent('POST', {});
    
    const result = await registerUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(400);
    expect(response.errorCode).toBe('MISSING_TOKEN');
  });

  test('should handle CORS preflight', async () => {
    const event = createMockEvent('OPTIONS');
    
    const result = await registerUser(event);
    
    expect(result.statusCode).toBe(200);
    expect(result.headers['Access-Control-Allow-Origin']).toBe('*');
  });
});

describe('User Login', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('should login user successfully', async () => {
    // Mock Firebase token verification
    admin.auth().verifyIdToken.mockResolvedValue(mockFirebaseToken);
    
    // Mock DynamoDB operations
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, { Item: mockUser });
    });
    
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      callback(null, {});
    });
    
    const event = createMockEvent('POST', {
      idToken: 'valid-firebase-token'
    });
    
    const result = await loginUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(200);
    expect(response.success).toBe(true);
    expect(response.user.userId).toBe(mockUser.userId);
    expect(response.accessToken).toBeDefined();
  });

  test('should return error for non-existent user', async () => {
    // Mock Firebase token verification
    admin.auth().verifyIdToken.mockResolvedValue(mockFirebaseToken);
    
    // Mock DynamoDB get to return no user
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, {});
    });
    
    const event = createMockEvent('POST', {
      idToken: 'valid-firebase-token'
    });
    
    const result = await loginUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(404);
    expect(response.errorCode).toBe('USER_NOT_FOUND');
  });

  test('should return error for inactive user', async () => {
    // Mock Firebase token verification
    admin.auth().verifyIdToken.mockResolvedValue(mockFirebaseToken);
    
    // Mock DynamoDB get to return inactive user
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, { Item: { ...mockUser, isActive: false } });
    });
    
    const event = createMockEvent('POST', {
      idToken: 'valid-firebase-token'
    });
    
    const result = await loginUser(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(403);
    expect(response.errorCode).toBe('ACCOUNT_DISABLED');
  });
});

describe('Get User Profile', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('should get user profile successfully', async () => {
    // Mock DynamoDB get
    AWSMock.mock('DynamoDB.DocumentClient', 'get', (params, callback) => {
      callback(null, { Item: mockUser });
    });
    
    // Create valid JWT token
    const token = jwt.sign(
      { userId: mockUser.userId, email: mockUser.email, type: 'user_access' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    const event = createMockEvent('GET', {}, 
      { userId: mockUser.userId }, 
      { Authorization: `Bearer ${token}` }
    );
    
    const result = await getUserProfile(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(200);
    expect(response.success).toBe(true);
    expect(response.user.userId).toBe(mockUser.userId);
    expect(response.user.version).toBeUndefined(); // Should be removed
  });

  test('should return error for missing authorization', async () => {
    const event = createMockEvent('GET', {}, { userId: mockUser.userId });
    
    const result = await getUserProfile(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(401);
    expect(response.errorCode).toBe('MISSING_AUTH_TOKEN');
  });

  test('should return error for accessing different user profile', async () => {
    // Create JWT token for different user
    const token = jwt.sign(
      { userId: 'different-user', email: 'different@example.com', type: 'user_access' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    const event = createMockEvent('GET', {}, 
      { userId: mockUser.userId }, 
      { Authorization: `Bearer ${token}` }
    );
    
    const result = await getUserProfile(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(403);
    expect(response.errorCode).toBe('ACCESS_DENIED');
  });
});

describe('Update User Profile', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('should update user profile successfully', async () => {
    // Mock DynamoDB update
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      callback(null, { 
        Attributes: { 
          ...mockUser, 
          displayName: 'Updated Name',
          updatedAt: '2023-12-01T00:00:00.000Z'
        } 
      });
    });
    
    // Create valid JWT token
    const token = jwt.sign(
      { userId: mockUser.userId, email: mockUser.email, type: 'user_access' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    const event = createMockEvent('PUT', 
      { displayName: 'Updated Name' },
      { userId: mockUser.userId }, 
      { Authorization: `Bearer ${token}` }
    );
    
    const result = await updateUserProfile(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(200);
    expect(response.success).toBe(true);
    expect(response.user.displayName).toBe('Updated Name');
  });

  test('should return error for invalid display name', async () => {
    // Create valid JWT token
    const token = jwt.sign(
      { userId: mockUser.userId, email: mockUser.email, type: 'user_access' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    const event = createMockEvent('PUT', 
      { displayName: 'a'.repeat(101) }, // Too long
      { userId: mockUser.userId }, 
      { Authorization: `Bearer ${token}` }
    );
    
    const result = await updateUserProfile(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(400);
    expect(response.errorCode).toBe('INVALID_DISPLAY_NAME');
  });
});

describe('Delete User Account', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    AWSMock.restore('DynamoDB.DocumentClient');
  });

  test('should delete user account successfully', async () => {
    // Mock DynamoDB update
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      callback(null, {});
    });
    
    // Create valid JWT token
    const token = jwt.sign(
      { userId: mockUser.userId, email: mockUser.email, type: 'user_access' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    const event = createMockEvent('DELETE', {},
      { userId: mockUser.userId }, 
      { Authorization: `Bearer ${token}` }
    );
    
    const result = await deleteUserAccount(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(200);
    expect(response.success).toBe(true);
    expect(response.message).toBe('Account deleted successfully');
  });

  test('should return error for non-existent user', async () => {
    // Mock DynamoDB update to throw conditional check failed
    AWSMock.mock('DynamoDB.DocumentClient', 'update', (params, callback) => {
      const error = new Error('Conditional check failed');
      error.code = 'ConditionalCheckFailedException';
      callback(error);
    });
    
    // Create valid JWT token
    const token = jwt.sign(
      { userId: mockUser.userId, email: mockUser.email, type: 'user_access' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    const event = createMockEvent('DELETE', {},
      { userId: mockUser.userId }, 
      { Authorization: `Bearer ${token}` }
    );
    
    const result = await deleteUserAccount(event);
    const response = JSON.parse(result.body);
    
    expect(result.statusCode).toBe(404);
    expect(response.errorCode).toBe('USER_NOT_FOUND');
  });
});

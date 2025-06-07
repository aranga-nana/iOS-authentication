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
const USERS_TABLE = process.env.USERS_TABLE || 'ios-auth-users';
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

const createErrorResponse = (statusCode, message, errorCode = null) => {
  logger.error(`Error ${statusCode}: ${message}`, { errorCode });
  return createResponse(statusCode, {
    error: true,
    message,
    errorCode,
    timestamp: new Date().toISOString()
  });
};

// Input validation
const validateEmail = (email) => {
  return validator.isEmail(email) && email.length <= 254;
};

const validateFirebaseToken = async (idToken) => {
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return { valid: true, decoded: decodedToken };
  } catch (error) {
    logger.error('Firebase token validation failed', { error: error.message });
    return { valid: false, error: error.message };
  }
};

// Rate limiting (simple in-memory store - use Redis in production)
const rateLimitStore = new Map();
const checkRateLimit = (key, limit = 10, window = 60000) => {
  const now = Date.now();
  const requests = rateLimitStore.get(key) || [];
  
  // Clean old requests
  const validRequests = requests.filter(time => now - time < window);
  
  if (validRequests.length >= limit) {
    return false;
  }
  
  validRequests.push(now);
  rateLimitStore.set(key, validRequests);
  return true;
};

/**
 * User Registration Handler
 * Creates a new user profile in DynamoDB after Firebase authentication
 */
exports.registerUser = async (event) => {
  const startTime = Date.now();
  const requestId = uuidv4();
  
  try {
    logger.info('User registration started', { requestId });
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createResponse(200, {});
    }
    
    // Parse request body
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (error) {
      return createErrorResponse(400, 'Invalid JSON in request body', 'INVALID_JSON');
    }
    
    const { idToken, userData = {} } = body;
    
    // Validate required fields
    if (!idToken) {
      return createErrorResponse(400, 'Firebase ID token is required', 'MISSING_TOKEN');
    }
    
    // Rate limiting
    const clientIP = event.requestContext?.identity?.sourceIp || 'unknown';
    if (!checkRateLimit(`register:${clientIP}`, 5, 300000)) { // 5 requests per 5 minutes
      return createErrorResponse(429, 'Too many registration attempts', 'RATE_LIMIT_EXCEEDED');
    }
    
    // Validate Firebase token
    const tokenValidation = await validateFirebaseToken(idToken);
    if (!tokenValidation.valid) {
      return createErrorResponse(401, 'Invalid Firebase token', 'INVALID_TOKEN');
    }
    
    const { uid, email, name, picture } = tokenValidation.decoded;
    
    // Validate email format
    if (email && !validateEmail(email)) {
      return createErrorResponse(400, 'Invalid email format', 'INVALID_EMAIL');
    }
    
    // Check if user already exists
    try {
      const existingUser = await dynamodb.get({
        TableName: USERS_TABLE,
        Key: { userId: uid }
      }).promise();
      
      if (existingUser.Item) {
        logger.info('User already exists', { userId: uid, requestId });
        return createResponse(200, {
          success: true,
          message: 'User already registered',
          user: {
            userId: existingUser.Item.userId,
            email: existingUser.Item.email,
            displayName: existingUser.Item.displayName,
            profilePicture: existingUser.Item.profilePicture,
            createdAt: existingUser.Item.createdAt
          }
        });
      }
    } catch (error) {
      logger.error('Error checking existing user', { error: error.message, requestId });
      return createErrorResponse(500, 'Database error', 'DATABASE_ERROR');
    }
    
    // Create new user record
    const timestamp = new Date().toISOString();
    const userRecord = {
      userId: uid,
      email: email || null,
      displayName: userData.displayName || name || 'Anonymous User',
      profilePicture: userData.profilePicture || picture || null,
      preferences: userData.preferences || {},
      createdAt: timestamp,
      updatedAt: timestamp,
      lastLoginAt: timestamp,
      isActive: true,
      version: 1
    };
    
    try {
      await dynamodb.put({
        TableName: USERS_TABLE,
        Item: userRecord,
        ConditionExpression: 'attribute_not_exists(userId)'
      }).promise();
      
      logger.info('User registered successfully', { userId: uid, requestId });
      
      // Generate custom JWT token for additional security
      const customToken = jwt.sign(
        {
          userId: uid,
          email: email,
          type: 'user_access'
        },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
      );
      
      return createResponse(201, {
        success: true,
        message: 'User registered successfully',
        user: {
          userId: userRecord.userId,
          email: userRecord.email,
          displayName: userRecord.displayName,
          profilePicture: userRecord.profilePicture,
          createdAt: userRecord.createdAt
        },
        accessToken: customToken
      });
      
    } catch (error) {
      if (error.code === 'ConditionalCheckFailedException') {
        return createErrorResponse(409, 'User already exists', 'USER_EXISTS');
      }
      
      logger.error('Error creating user', { error: error.message, requestId });
      return createErrorResponse(500, 'Failed to create user', 'CREATE_USER_ERROR');
    }
    
  } catch (error) {
    logger.error('Unexpected error in registerUser', { error: error.message, requestId });
    return createErrorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
  } finally {
    const duration = Date.now() - startTime;
    logger.info('Register user request completed', { requestId, duration });
  }
};

/**
 * User Login Handler
 * Validates Firebase token and updates user login timestamp
 */
exports.loginUser = async (event) => {
  const startTime = Date.now();
  const requestId = uuidv4();
  
  try {
    logger.info('User login started', { requestId });
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createResponse(200, {});
    }
    
    // Parse request body
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (error) {
      return createErrorResponse(400, 'Invalid JSON in request body', 'INVALID_JSON');
    }
    
    const { idToken } = body;
    
    // Validate required fields
    if (!idToken) {
      return createErrorResponse(400, 'Firebase ID token is required', 'MISSING_TOKEN');
    }
    
    // Rate limiting
    const clientIP = event.requestContext?.identity?.sourceIp || 'unknown';
    if (!checkRateLimit(`login:${clientIP}`, 20, 300000)) { // 20 requests per 5 minutes
      return createErrorResponse(429, 'Too many login attempts', 'RATE_LIMIT_EXCEEDED');
    }
    
    // Validate Firebase token
    const tokenValidation = await validateFirebaseToken(idToken);
    if (!tokenValidation.valid) {
      return createErrorResponse(401, 'Invalid Firebase token', 'INVALID_TOKEN');
    }
    
    const { uid, email } = tokenValidation.decoded;
    
    // Get user from database
    try {
      const result = await dynamodb.get({
        TableName: USERS_TABLE,
        Key: { userId: uid }
      }).promise();
      
      if (!result.Item) {
        logger.warn('User not found during login', { userId: uid, requestId });
        return createErrorResponse(404, 'User not found', 'USER_NOT_FOUND');
      }
      
      const user = result.Item;
      
      // Check if user is active
      if (!user.isActive) {
        return createErrorResponse(403, 'User account is disabled', 'ACCOUNT_DISABLED');
      }
      
      // Update last login timestamp
      const timestamp = new Date().toISOString();
      await dynamodb.update({
        TableName: USERS_TABLE,
        Key: { userId: uid },
        UpdateExpression: 'SET lastLoginAt = :timestamp, updatedAt = :timestamp',
        ExpressionAttributeValues: {
          ':timestamp': timestamp
        }
      }).promise();
      
      logger.info('User login successful', { userId: uid, requestId });
      
      // Generate custom JWT token
      const customToken = jwt.sign(
        {
          userId: uid,
          email: email,
          type: 'user_access'
        },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
      );
      
      return createResponse(200, {
        success: true,
        message: 'Login successful',
        user: {
          userId: user.userId,
          email: user.email,
          displayName: user.displayName,
          profilePicture: user.profilePicture,
          lastLoginAt: timestamp
        },
        accessToken: customToken
      });
      
    } catch (error) {
      logger.error('Error during login', { error: error.message, requestId });
      return createErrorResponse(500, 'Login failed', 'LOGIN_ERROR');
    }
    
  } catch (error) {
    logger.error('Unexpected error in loginUser', { error: error.message, requestId });
    return createErrorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
  } finally {
    const duration = Date.now() - startTime;
    logger.info('Login user request completed', { requestId, duration });
  }
};

/**
 * Get User Profile Handler
 * Retrieves user profile information
 */
exports.getUserProfile = async (event) => {
  const startTime = Date.now();
  const requestId = uuidv4();
  
  try {
    logger.info('Get user profile started', { requestId });
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createResponse(200, {});
    }
    
    // Extract user ID from path parameters
    const { userId } = event.pathParameters || {};
    
    if (!userId) {
      return createErrorResponse(400, 'User ID is required', 'MISSING_USER_ID');
    }
    
    // Validate JWT token from Authorization header
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return createErrorResponse(401, 'Authorization token required', 'MISSING_AUTH_TOKEN');
    }
    
    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Ensure user can only access their own profile (or implement admin access)
      if (decoded.userId !== userId) {
        return createErrorResponse(403, 'Access denied', 'ACCESS_DENIED');
      }
      
    } catch (error) {
      return createErrorResponse(401, 'Invalid authorization token', 'INVALID_AUTH_TOKEN');
    }
    
    // Get user profile from database
    try {
      const result = await dynamodb.get({
        TableName: USERS_TABLE,
        Key: { userId }
      }).promise();
      
      if (!result.Item) {
        return createErrorResponse(404, 'User not found', 'USER_NOT_FOUND');
      }
      
      const user = result.Item;
      
      // Remove sensitive information
      const { version, ...userProfile } = user;
      
      logger.info('User profile retrieved successfully', { userId, requestId });
      
      return createResponse(200, {
        success: true,
        user: userProfile
      });
      
    } catch (error) {
      logger.error('Error retrieving user profile', { error: error.message, requestId });
      return createErrorResponse(500, 'Failed to retrieve profile', 'PROFILE_ERROR');
    }
    
  } catch (error) {
    logger.error('Unexpected error in getUserProfile', { error: error.message, requestId });
    return createErrorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
  } finally {
    const duration = Date.now() - startTime;
    logger.info('Get user profile request completed', { requestId, duration });
  }
};

/**
 * Update User Profile Handler
 * Updates user profile information
 */
exports.updateUserProfile = async (event) => {
  const startTime = Date.now();
  const requestId = uuidv4();
  
  try {
    logger.info('Update user profile started', { requestId });
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createResponse(200, {});
    }
    
    // Extract user ID from path parameters
    const { userId } = event.pathParameters || {};
    
    if (!userId) {
      return createErrorResponse(400, 'User ID is required', 'MISSING_USER_ID');
    }
    
    // Validate JWT token from Authorization header
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return createErrorResponse(401, 'Authorization token required', 'MISSING_AUTH_TOKEN');
    }
    
    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Ensure user can only update their own profile
      if (decoded.userId !== userId) {
        return createErrorResponse(403, 'Access denied', 'ACCESS_DENIED');
      }
      
    } catch (error) {
      return createErrorResponse(401, 'Invalid authorization token', 'INVALID_AUTH_TOKEN');
    }
    
    // Parse request body
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (error) {
      return createErrorResponse(400, 'Invalid JSON in request body', 'INVALID_JSON');
    }
    
    const { displayName, profilePicture, preferences } = body;
    
    // Validate inputs
    if (displayName && (typeof displayName !== 'string' || displayName.length > 100)) {
      return createErrorResponse(400, 'Invalid display name', 'INVALID_DISPLAY_NAME');
    }
    
    if (profilePicture && (typeof profilePicture !== 'string' || !validator.isURL(profilePicture))) {
      return createErrorResponse(400, 'Invalid profile picture URL', 'INVALID_PROFILE_PICTURE');
    }
    
    if (preferences && typeof preferences !== 'object') {
      return createErrorResponse(400, 'Invalid preferences format', 'INVALID_PREFERENCES');
    }
    
    // Build update expression
    const updateExpressions = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};
    
    if (displayName !== undefined) {
      updateExpressions.push('#displayName = :displayName');
      expressionAttributeNames['#displayName'] = 'displayName';
      expressionAttributeValues[':displayName'] = displayName;
    }
    
    if (profilePicture !== undefined) {
      updateExpressions.push('profilePicture = :profilePicture');
      expressionAttributeValues[':profilePicture'] = profilePicture;
    }
    
    if (preferences !== undefined) {
      updateExpressions.push('preferences = :preferences');
      expressionAttributeValues[':preferences'] = preferences;
    }
    
    if (updateExpressions.length === 0) {
      return createErrorResponse(400, 'No valid fields to update', 'NO_UPDATE_FIELDS');
    }
    
    // Always update the updatedAt timestamp
    updateExpressions.push('updatedAt = :updatedAt');
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();
    
    try {
      const result = await dynamodb.update({
        TableName: USERS_TABLE,
        Key: { userId },
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeNames: Object.keys(expressionAttributeNames).length > 0 ? expressionAttributeNames : undefined,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW',
        ConditionExpression: 'attribute_exists(userId)'
      }).promise();
      
      const updatedUser = result.Attributes;
      
      // Remove sensitive information
      const { version, ...userProfile } = updatedUser;
      
      logger.info('User profile updated successfully', { userId, requestId });
      
      return createResponse(200, {
        success: true,
        message: 'Profile updated successfully',
        user: userProfile
      });
      
    } catch (error) {
      if (error.code === 'ConditionalCheckFailedException') {
        return createErrorResponse(404, 'User not found', 'USER_NOT_FOUND');
      }
      
      logger.error('Error updating user profile', { error: error.message, requestId });
      return createErrorResponse(500, 'Failed to update profile', 'UPDATE_ERROR');
    }
    
  } catch (error) {
    logger.error('Unexpected error in updateUserProfile', { error: error.message, requestId });
    return createErrorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
  } finally {
    const duration = Date.now() - startTime;
    logger.info('Update user profile request completed', { requestId, duration });
  }
};

/**
 * Delete User Account Handler
 * Soft deletes user account (marks as inactive)
 */
exports.deleteUserAccount = async (event) => {
  const startTime = Date.now();
  const requestId = uuidv4();
  
  try {
    logger.info('Delete user account started', { requestId });
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createResponse(200, {});
    }
    
    // Extract user ID from path parameters
    const { userId } = event.pathParameters || {};
    
    if (!userId) {
      return createErrorResponse(400, 'User ID is required', 'MISSING_USER_ID');
    }
    
    // Validate JWT token from Authorization header
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return createErrorResponse(401, 'Authorization token required', 'MISSING_AUTH_TOKEN');
    }
    
    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Ensure user can only delete their own account
      if (decoded.userId !== userId) {
        return createErrorResponse(403, 'Access denied', 'ACCESS_DENIED');
      }
      
    } catch (error) {
      return createErrorResponse(401, 'Invalid authorization token', 'INVALID_AUTH_TOKEN');
    }
    
    // Soft delete user account (mark as inactive)
    try {
      const timestamp = new Date().toISOString();
      
      await dynamodb.update({
        TableName: USERS_TABLE,
        Key: { userId },
        UpdateExpression: 'SET isActive = :isActive, deletedAt = :deletedAt, updatedAt = :updatedAt',
        ExpressionAttributeValues: {
          ':isActive': false,
          ':deletedAt': timestamp,
          ':updatedAt': timestamp
        },
        ConditionExpression: 'attribute_exists(userId) AND isActive = :currentActive',
        ExpressionAttributeValues: {
          ...expressionAttributeValues,
          ':currentActive': true
        }
      }).promise();
      
      logger.info('User account deleted successfully', { userId, requestId });
      
      return createResponse(200, {
        success: true,
        message: 'Account deleted successfully'
      });
      
    } catch (error) {
      if (error.code === 'ConditionalCheckFailedException') {
        return createErrorResponse(404, 'User not found or already deleted', 'USER_NOT_FOUND');
      }
      
      logger.error('Error deleting user account', { error: error.message, requestId });
      return createErrorResponse(500, 'Failed to delete account', 'DELETE_ERROR');
    }
    
  } catch (error) {
    logger.error('Unexpected error in deleteUserAccount', { error: error.message, requestId });
    return createErrorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
  } finally {
    const duration = Date.now() - startTime;
    logger.info('Delete user account request completed', { requestId, duration });
  }
};

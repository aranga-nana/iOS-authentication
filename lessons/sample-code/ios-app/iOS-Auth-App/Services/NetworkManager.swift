//
//  NetworkManager.swift
//  iOS-Auth-App
//
//  Network layer for API communication with AWS backend
//

import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL: String
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load base URL from configuration
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let url = config["APIBaseURL"] as? String {
            self.baseURL = url
        } else {
            // Fallback URL - replace with your actual API Gateway URL
            self.baseURL = "https://your-api-gateway-url.execute-api.region.amazonaws.com/prod"
        }
    }
    
    // MARK: - API Methods
    
    func createUser(userData: CreateUserRequest) async throws -> UserResponse {
        let endpoint = "\(baseURL)/users"
        return try await performRequest(
            url: endpoint,
            method: "POST",
            body: userData,
            responseType: UserResponse.self
        )
    }
    
    func getUser(userId: String, idToken: String) async throws -> UserResponse {
        let endpoint = "\(baseURL)/users/\(userId)"
        return try await performRequest(
            url: endpoint,
            method: "GET",
            headers: ["Authorization": "Bearer \(idToken)"],
            responseType: UserResponse.self
        )
    }
    
    func updateUser(userId: String, userData: UpdateUserRequest, idToken: String) async throws -> UserResponse {
        let endpoint = "\(baseURL)/users/\(userId)"
        return try await performRequest(
            url: endpoint,
            method: "PUT",
            headers: ["Authorization": "Bearer \(idToken)"],
            body: userData,
            responseType: UserResponse.self
        )
    }
    
    func deleteUser(userId: String, idToken: String) async throws {
        let endpoint = "\(baseURL)/users/\(userId)"
        let _: EmptyResponse = try await performRequest(
            url: endpoint,
            method: "DELETE",
            headers: ["Authorization": "Bearer \(idToken)"],
            responseType: EmptyResponse.self
        )
    }
    
    func verifyToken(idToken: String) async throws -> TokenVerificationResponse {
        let endpoint = "\(baseURL)/auth/verify"
        return try await performRequest(
            url: endpoint,
            method: "POST",
            headers: ["Authorization": "Bearer \(idToken)"],
            responseType: TokenVerificationResponse.self
        )
    }
    
    // MARK: - Generic Request Method
    
    private func performRequest<T: Codable, U: Codable>(
        url: String,
        method: String,
        headers: [String: String] = [:],
        body: T? = nil,
        responseType: U.Type
    ) async throws -> U {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if provided
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                if U.self == EmptyResponse.self {
                    return EmptyResponse() as! U
                }
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(responseType, from: data)
                } catch {
                    throw NetworkError.decodingError(error)
                }
                
            case 400:
                throw NetworkError.badRequest(String(data: data, encoding: .utf8) ?? "Bad Request")
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 429:
                throw NetworkError.rateLimited
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknownError(httpResponse.statusCode)
            }
        } catch {
            if error is NetworkError {
                throw error
            } else {
                throw NetworkError.networkError(error)
            }
        }
    }
    
    // MARK: - File Upload
    
    func uploadProfileImage(_ image: UIImage, userId: String, idToken: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.imageProcessingError
        }
        
        let endpoint = "\(baseURL)/users/\(userId)/avatar"
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                return uploadResponse.url
            } else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}

// MARK: - Network Error Types

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case badRequest(String)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case unknownError(Int)
    case imageProcessingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .unknownError(let code):
            return "Unknown error (code: \(code))"
        case .imageProcessingError:
            return "Failed to process image"
        }
    }
}

// MARK: - Request/Response Models

struct CreateUserRequest: Codable {
    let email: String
    let displayName: String?
    let photoURL: String?
    let firebaseUID: String
}

struct UpdateUserRequest: Codable {
    let displayName: String?
    let photoURL: String?
}

struct UserResponse: Codable {
    let id: String
    let email: String
    let displayName: String?
    let photoURL: String?
    let firebaseUID: String
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
}

struct TokenVerificationResponse: Codable {
    let valid: Bool
    let uid: String?
    let email: String?
    let expiresAt: Date?
}

struct UploadResponse: Codable {
    let url: String
    let message: String
}

struct EmptyResponse: Codable {
    init() {}
}

// MARK: - Network Monitoring

extension NetworkManager {
    func startNetworkMonitoring() {
        // Monitor network connectivity
        // This is a simplified version - in a real app, you'd use NWPathMonitor
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await self.performHealthCheck()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performHealthCheck() async {
        do {
            let endpoint = "\(baseURL)/health"
            let _: EmptyResponse = try await performRequest(
                url: endpoint,
                method: "GET",
                responseType: EmptyResponse.self
            )
            print("Health check passed")
        } catch {
            print("Health check failed: \(error)")
        }
    }
}

// MARK: - Request Interceptors

extension NetworkManager {
    private func addAuthenticationInterceptor(to request: inout URLRequest, with token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    private func addRequestLogging(for request: URLRequest) {
        #if DEBUG
        print("🌐 API Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            print("📋 Headers: \(headers)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📦 Body: \(bodyString)")
        }
        #endif
    }
    
    private func logResponse(data: Data, response: URLResponse) {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 API Response: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Response Data: \(responseString)")
        }
        #endif
    }
}

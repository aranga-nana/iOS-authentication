//
//  BiometricManager.swift
//  iOS-Auth-App
//
//  Biometric authentication manager for Face ID/Touch ID
//

import Foundation
import LocalAuthentication

class BiometricManager: ObservableObject {
    static let shared = BiometricManager()
    
    @Published var isBiometricEnabled = false
    @Published var biometricType: LABiometryType = .none
    
    private let context = LAContext()
    private let keychainService = "com.yourapp.biometric"
    
    private init() {
        checkBiometricAvailability()
        loadBiometricPreference()
    }
    
    // MARK: - Biometric Availability
    
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.biometryAny, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
            print("Biometric not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    var isBiometricAvailable: Bool {
        return biometricType != .none
    }
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometric() async throws -> Bool {
        guard isBiometricAvailable else {
            throw BiometricError.notAvailable
        }
        
        let reason = "Authenticate with \(biometricTypeString) to access your account"
        
        do {
            let success = try await context.evaluatePolicy(.biometryAny, localizedReason: reason)
            return success
        } catch {
            throw BiometricError.authenticationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Biometric Settings
    
    func enableBiometric() async throws {
        guard isBiometricAvailable else {
            throw BiometricError.notAvailable
        }
        
        // First authenticate to enable biometric
        let authenticated = try await authenticateWithBiometric()
        
        if authenticated {
            // Store biometric preference
            saveBiometricPreference(enabled: true)
            
            await MainActor.run {
                self.isBiometricEnabled = true
            }
        }
    }
    
    func disableBiometric() {
        saveBiometricPreference(enabled: false)
        isBiometricEnabled = false
    }
    
    // MARK: - Keychain Operations
    
    private func saveBiometricPreference(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "biometric_enabled")
    }
    
    private func loadBiometricPreference() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
    }
    
    // Store credentials securely for biometric access
    func storeCredentialsForBiometric(email: String, password: String) throws {
        let credentials = BiometricCredentials(email: email, password: password)
        let data = try JSONEncoder().encode(credentials)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "biometric_credentials",
            kSecValueData as String: data,
            kSecAttrAccessControl as String: createAccessControl()
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw BiometricError.keychainError("Failed to store credentials")
        }
    }
    
    func retrieveCredentialsWithBiometric() async throws -> BiometricCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "biometric_credentials",
            kSecReturnData as String: true,
            kSecUseOperationPrompt as String: "Access your saved credentials"
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            guard let data = result as? Data else {
                throw BiometricError.keychainError("Invalid data format")
            }
            
            do {
                let credentials = try JSONDecoder().decode(BiometricCredentials.self, from: data)
                return credentials
            } catch {
                throw BiometricError.keychainError("Failed to decode credentials")
            }
        } else {
            throw BiometricError.keychainError("Failed to retrieve credentials")
        }
    }
    
    func deleteStoredCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "biometric_credentials"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw BiometricError.keychainError("Failed to delete credentials")
        }
    }
    
    // MARK: - Access Control
    
    private func createAccessControl() -> SecAccessControl {
        var error: Unmanaged<CFError>?
        
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            print("Failed to create access control: \(error)")
        }
        
        return accessControl!
    }
}

// MARK: - Models

struct BiometricCredentials: Codable {
    let email: String
    let password: String
}

// MARK: - Errors

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed(String)
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}

// MARK: - Biometric Type Extensions

extension LABiometryType {
    var icon: String {
        switch self {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock"
        @unknown default:
            return "lock"
        }
    }
    
    var description: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct BiometricAuthButton: View {
    @StateObject private var biometricManager = BiometricManager.shared
    let action: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack {
                Image(systemName: biometricManager.biometricType.icon)
                Text("Sign in with \(biometricManager.biometricTypeString)")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!biometricManager.isBiometricAvailable)
    }
}

struct BiometricSettingsView: View {
    @StateObject private var biometricManager = BiometricManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Section("Biometric Authentication") {
            HStack {
                Image(systemName: biometricManager.biometricType.icon)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(biometricManager.biometricTypeString)
                        .font(.body)
                    Text("Use \(biometricManager.biometricTypeString) to sign in quickly")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { biometricManager.isBiometricEnabled },
                    set: { enabled in
                        if enabled {
                            Task {
                                do {
                                    try await biometricManager.enableBiometric()
                                } catch {
                                    alertMessage = error.localizedDescription
                                    showingAlert = true
                                }
                            }
                        } else {
                            biometricManager.disableBiometric()
                        }
                    }
                ))
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

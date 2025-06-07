//
//  ValidationHelpers.swift
//  iOS-Auth-App
//
//  Input validation utilities for forms and user data
//

import Foundation
import UIKit

struct ValidationHelpers {
    
    // MARK: - Email Validation
    
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func validateEmail(_ email: String) -> ValidationResult {
        guard !email.isEmpty else {
            return .invalid("Email is required")
        }
        
        guard isValidEmail(email) else {
            return .invalid("Please enter a valid email address")
        }
        
        return .valid
    }
    
    // MARK: - Password Validation
    
    static func validatePassword(_ password: String) -> ValidationResult {
        guard !password.isEmpty else {
            return .invalid("Password is required")
        }
        
        guard password.count >= 8 else {
            return .invalid("Password must be at least 8 characters long")
        }
        
        guard password.rangeOfCharacter(from: .uppercaseLetters) != nil else {
            return .invalid("Password must contain at least one uppercase letter")
        }
        
        guard password.rangeOfCharacter(from: .lowercaseLetters) != nil else {
            return .invalid("Password must contain at least one lowercase letter")
        }
        
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            return .invalid("Password must contain at least one number")
        }
        
        guard password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil else {
            return .invalid("Password must contain at least one special character")
        }
        
        return .valid
    }
    
    static func getPasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // Length check
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // Character type checks
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }
        
        // Common patterns check (reduce score)
        if isCommonPassword(password) { score -= 2 }
        if hasRepeatingCharacters(password) { score -= 1 }
        
        switch score {
        case 0...2:
            return .weak
        case 3...4:
            return .medium
        case 5...6:
            return .strong
        default:
            return .veryStrong
        }
    }
    
    private static func isCommonPassword(_ password: String) -> Bool {
        let commonPasswords = [
            "password", "123456", "password123", "admin", "qwerty",
            "12345678", "welcome", "login", "abc123", "password1"
        ]
        return commonPasswords.contains(password.lowercased())
    }
    
    private static func hasRepeatingCharacters(_ password: String) -> Bool {
        let chars = Array(password)
        for i in 0..<chars.count-2 {
            if chars[i] == chars[i+1] && chars[i+1] == chars[i+2] {
                return true
            }
        }
        return false
    }
    
    // MARK: - Name Validation
    
    static func validateName(_ name: String, fieldName: String = "Name") -> ValidationResult {
        guard !name.isEmpty else {
            return .invalid("\(fieldName) is required")
        }
        
        guard name.count >= 2 else {
            return .invalid("\(fieldName) must be at least 2 characters long")
        }
        
        guard name.count <= 50 else {
            return .invalid("\(fieldName) must be less than 50 characters")
        }
        
        let nameRegex = "^[a-zA-Z\\s\\-']+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        guard namePredicate.evaluate(with: name) else {
            return .invalid("\(fieldName) can only contain letters, spaces, hyphens, and apostrophes")
        }
        
        return .valid
    }
    
    // MARK: - Phone Number Validation
    
    static func validatePhoneNumber(_ phoneNumber: String) -> ValidationResult {
        guard !phoneNumber.isEmpty else {
            return .invalid("Phone number is required")
        }
        
        // Remove all non-digit characters for validation
        let digitsOnly = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        guard digitsOnly.count >= 10 else {
            return .invalid("Phone number must be at least 10 digits")
        }
        
        guard digitsOnly.count <= 15 else {
            return .invalid("Phone number cannot exceed 15 digits")
        }
        
        return .valid
    }
    
    static func formatPhoneNumber(_ phoneNumber: String) -> String {
        let digitsOnly = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if digitsOnly.count == 10 {
            // US format: (XXX) XXX-XXXX
            let areaCode = String(digitsOnly.prefix(3))
            let centralOffice = String(digitsOnly.dropFirst(3).prefix(3))
            let lastFour = String(digitsOnly.suffix(4))
            return "(\(areaCode)) \(centralOffice)-\(lastFour)"
        }
        
        return phoneNumber // Return original if not 10 digits
    }
    
    // MARK: - General Validation
    
    static func validateRequired(_ value: String, fieldName: String) -> ValidationResult {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("\(fieldName) is required")
        }
        return .valid
    }
    
    static func validateLength(_ value: String, fieldName: String, min: Int, max: Int) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count >= min else {
            return .invalid("\(fieldName) must be at least \(min) characters long")
        }
        
        guard trimmed.count <= max else {
            return .invalid("\(fieldName) must be less than \(max) characters")
        }
        
        return .valid
    }
    
    // MARK: - Form Validation
    
    static func validateLoginForm(email: String, password: String) -> [String: ValidationResult] {
        return [
            "email": validateEmail(email),
            "password": validateRequired(password, fieldName: "Password")
        ]
    }
    
    static func validateSignUpForm(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        confirmPassword: String
    ) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [
            "firstName": validateName(firstName, fieldName: "First name"),
            "lastName": validateName(lastName, fieldName: "Last name"),
            "email": validateEmail(email),
            "password": validatePassword(password)
        ]
        
        // Confirm password validation
        if password != confirmPassword {
            results["confirmPassword"] = .invalid("Passwords do not match")
        } else {
            results["confirmPassword"] = .valid
        }
        
        return results
    }
    
    static func validateProfileForm(
        firstName: String,
        lastName: String,
        phoneNumber: String?
    ) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [
            "firstName": validateName(firstName, fieldName: "First name"),
            "lastName": validateName(lastName, fieldName: "Last name")
        ]
        
        if let phone = phoneNumber, !phone.isEmpty {
            results["phoneNumber"] = validatePhoneNumber(phone)
        }
        
        return results
    }
}

// MARK: - Validation Result Types

enum ValidationResult {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
}

enum PasswordStrength: CaseIterable {
    case weak
    case medium
    case strong
    case veryStrong
    
    var description: String {
        switch self {
        case .weak:
            return "Weak"
        case .medium:
            return "Medium"
        case .strong:
            return "Strong"
        case .veryStrong:
            return "Very Strong"
        }
    }
    
    var color: UIColor {
        switch self {
        case .weak:
            return .systemRed
        case .medium:
            return .systemOrange
        case .strong:
            return .systemGreen
        case .veryStrong:
            return .systemBlue
        }
    }
    
    var progress: Float {
        switch self {
        case .weak:
            return 0.25
        case .medium:
            return 0.5
        case .strong:
            return 0.75
        case .veryStrong:
            return 1.0
        }
    }
}

// MARK: - SwiftUI Validation Extensions

extension ValidationResult {
    var swiftUIColor: Color {
        switch self {
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }
}

extension PasswordStrength {
    var swiftUIColor: Color {
        switch self {
        case .weak:
            return .red
        case .medium:
            return .orange
        case .strong:
            return .green
        case .veryStrong:
            return .blue
        }
    }
}

// MARK: - Real-time Validation Helpers

class ValidationObserver: ObservableObject {
    @Published var validationResults: [String: ValidationResult] = [:]
    
    func validate(field: String, value: String, validator: (String) -> ValidationResult) {
        validationResults[field] = validator(value)
    }
    
    func isFormValid() -> Bool {
        return validationResults.values.allSatisfy { $0.isValid }
    }
    
    func getErrorMessage(for field: String) -> String? {
        return validationResults[field]?.errorMessage
    }
    
    func clearValidation(for field: String) {
        validationResults.removeValue(forKey: field)
    }
    
    func clearAllValidation() {
        validationResults.removeAll()
    }
}

// MARK: - Custom Text Field with Validation

import SwiftUI

struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let validator: (String) -> ValidationResult
    @State private var validationResult: ValidationResult = .valid
    let isSecure: Bool
    
    init(
        title: String,
        text: Binding<String>,
        validator: @escaping (String) -> ValidationResult,
        isSecure: Bool = false
    ) {
        self.title = title
        self._text = text
        self.validator = validator
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isSecure {
                SecureField(title, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: text) { _ in
                        validationResult = validator(text)
                    }
            } else {
                TextField(title, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: text) { _ in
                        validationResult = validator(text)
                    }
            }
            
            if let errorMessage = validationResult.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

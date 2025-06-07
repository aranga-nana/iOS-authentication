# Lesson 3: Form Validation and Error Handling
**Phase 2, Week 2** | **Duration:** 6-8 hours | **Difficulty:** Intermediate

## 🎯 Learning Objectives
By the end of this lesson, you will:
- Implement comprehensive form validation for authentication
- Create reusable validation components
- Handle and display errors gracefully
- Build user-friendly validation feedback systems
- Understand real-time vs. submission validation patterns

## 📋 Prerequisites
- Completed Week 1 lessons (iOS UI Fundamentals)
- Understanding of SwiftUI state management
- Basic knowledge of Swift optionals and error handling

## 🔧 Validation Architecture

### 1. Validation Models
Create `Models/Validation.swift`:

```swift
import Foundation

// MARK: - Validation Result
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

// MARK: - Field Validator Protocol
protocol FieldValidator {
    func validate(_ value: String) -> ValidationResult
}

// MARK: - Validation Rules
struct ValidationRules {
    
    // Email Validator
    struct EmailValidator: FieldValidator {
        func validate(_ value: String) -> ValidationResult {
            guard !value.isEmpty else {
                return .invalid("Email is required")
            }
            
            let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            
            guard emailPredicate.evaluate(with: value) else {
                return .invalid("Please enter a valid email address")
            }
            
            return .valid
        }
    }
    
    // Password Validator
    struct PasswordValidator: FieldValidator {
        let minLength: Int
        let requireUppercase: Bool
        let requireLowercase: Bool
        let requireNumbers: Bool
        let requireSpecialChars: Bool
        
        init(
            minLength: Int = 8,
            requireUppercase: Bool = true,
            requireLowercase: Bool = true,
            requireNumbers: Bool = true,
            requireSpecialChars: Bool = false
        ) {
            self.minLength = minLength
            self.requireUppercase = requireUppercase
            self.requireLowercase = requireLowercase
            self.requireNumbers = requireNumbers
            self.requireSpecialChars = requireSpecialChars
        }
        
        func validate(_ value: String) -> ValidationResult {
            guard !value.isEmpty else {
                return .invalid("Password is required")
            }
            
            guard value.count >= minLength else {
                return .invalid("Password must be at least \(minLength) characters long")
            }
            
            if requireUppercase && !value.contains(where: { $0.isUppercase }) {
                return .invalid("Password must contain at least one uppercase letter")
            }
            
            if requireLowercase && !value.contains(where: { $0.isLowercase }) {
                return .invalid("Password must contain at least one lowercase letter")
            }
            
            if requireNumbers && !value.contains(where: { $0.isNumber }) {
                return .invalid("Password must contain at least one number")
            }
            
            if requireSpecialChars {
                let specialCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
                if value.rangeOfCharacter(from: specialCharacterSet) == nil {
                    return .invalid("Password must contain at least one special character")
                }
            }
            
            return .valid
        }
    }
    
    // Name Validator
    struct NameValidator: FieldValidator {
        let minLength: Int
        let maxLength: Int
        
        init(minLength: Int = 2, maxLength: Int = 50) {
            self.minLength = minLength
            self.maxLength = maxLength
        }
        
        func validate(_ value: String) -> ValidationResult {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedValue.isEmpty else {
                return .invalid("Name is required")
            }
            
            guard trimmedValue.count >= minLength else {
                return .invalid("Name must be at least \(minLength) characters long")
            }
            
            guard trimmedValue.count <= maxLength else {
                return .invalid("Name must be no more than \(maxLength) characters long")
            }
            
            // Check for valid characters (letters, spaces, hyphens, apostrophes)
            let nameRegex = #"^[a-zA-Z\s\-']+$"#
            let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
            
            guard namePredicate.evaluate(with: trimmedValue) else {
                return .invalid("Name can only contain letters, spaces, hyphens, and apostrophes")
            }
            
            return .valid
        }
    }
    
    // Confirm Password Validator
    struct ConfirmPasswordValidator: FieldValidator {
        let originalPassword: String
        
        init(originalPassword: String) {
            self.originalPassword = originalPassword
        }
        
        func validate(_ value: String) -> ValidationResult {
            guard !value.isEmpty else {
                return .invalid("Please confirm your password")
            }
            
            guard value == originalPassword else {
                return .invalid("Passwords do not match")
            }
            
            return .valid
        }
    }
}

// MARK: - Form Validator
class FormValidator: ObservableObject {
    @Published var isValid = false
    @Published var errors: [String: String] = [:]
    
    private var validators: [String: FieldValidator] = [:]
    private var values: [String: String] = [:]
    
    func addValidator(for field: String, validator: FieldValidator) {
        validators[field] = validator
        validateField(field)
    }
    
    func setValue(_ value: String, for field: String) {
        values[field] = value
        validateField(field)
    }
    
    func validateField(_ field: String) {
        guard let validator = validators[field],
              let value = values[field] else { return }
        
        let result = validator.validate(value)
        
        if result.isValid {
            errors.removeValue(forKey: field)
        } else {
            errors[field] = result.errorMessage
        }
        
        updateFormValidState()
    }
    
    func validateAllFields() -> Bool {
        for field in validators.keys {
            validateField(field)
        }
        return isValid
    }
    
    private func updateFormValidState() {
        isValid = errors.isEmpty && !validators.isEmpty
    }
    
    func getError(for field: String) -> String? {
        return errors[field]
    }
    
    func hasError(for field: String) -> Bool {
        return errors[field] != nil
    }
}
```

### 2. Validated Text Field Component
Create `Components/ValidatedTextField.swift`:

```swift
import SwiftUI

struct ValidatedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let validator: FieldValidator
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    
    @State private var validationResult: ValidationResult = .valid
    @State private var showValidation = false
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        validator: FieldValidator,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.validator = validator
        self.isSecure = isSecure
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Input Field
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(ValidatedTextFieldStyle(
                            hasError: !validationResult.isValid && showValidation
                        ))
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textFieldStyle(ValidatedTextFieldStyle(
                            hasError: !validationResult.isValid && showValidation
                        ))
                }
            }
            .onChange(of: text) { newValue in
                validateInput(newValue)
            }
            .onSubmit {
                showValidation = true
                validateInput(text)
            }
            
            // Error Message
            if !validationResult.isValid && showValidation {
                Text(validationResult.errorMessage ?? "")
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Password Strength Indicator (for password fields only)
            if isSecure && !text.isEmpty && showValidation {
                PasswordStrengthIndicator(password: text)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationResult.isValid)
        .animation(.easeInOut(duration: 0.2), value: showValidation)
    }
    
    private func validateInput(_ value: String) {
        validationResult = validator.validate(value)
        
        // Show validation after user starts typing
        if !value.isEmpty {
            showValidation = true
        }
    }
    
    // Public method to trigger validation
    func triggerValidation() {
        showValidation = true
        validateInput(text)
    }
    
    var isValid: Bool {
        return validationResult.isValid
    }
}

// Custom Text Field Style
struct ValidatedTextFieldStyle: TextFieldStyle {
    let hasError: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hasError ? Color.red : Color(.systemGray4),
                        lineWidth: hasError ? 2 : 1
                    )
            )
    }
}
```

### 3. Password Strength Indicator
Add to `Components/ValidatedTextField.swift`:

```swift
struct PasswordStrengthIndicator: View {
    let password: String
    
    private var strength: PasswordStrength {
        calculateStrength(password)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Strength Bars
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    Rectangle()
                        .frame(height: 4)
                        .foregroundColor(barColor(for: index))
                        .cornerRadius(2)
                }
            }
            
            // Strength Label
            Text(strength.label)
                .font(.caption)
                .foregroundColor(strength.color)
            
            // Requirements Checklist
            if strength != .strong {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(getPasswordRequirements(), id: \.requirement) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isMet ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isMet ? .green : .secondary)
                                .font(.caption)
                            
                            Text(item.requirement)
                                .font(.caption)
                                .foregroundColor(item.isMet ? .green : .secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        switch strength {
        case .weak:
            return index == 0 ? .red : .secondary.opacity(0.3)
        case .fair:
            return index <= 1 ? .orange : .secondary.opacity(0.3)
        case .good:
            return index <= 2 ? .yellow : .secondary.opacity(0.3)
        case .strong:
            return .green
        }
    }
    
    private func calculateStrength(_ password: String) -> PasswordStrength {
        let length = password.count
        let hasUppercase = password.contains(where: \.isUppercase)
        let hasLowercase = password.contains(where: \.isLowercase)
        let hasNumbers = password.contains(where: \.isNumber)
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil
        
        var score = 0
        
        if length >= 8 { score += 1 }
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasNumbers { score += 1 }
        if hasSpecialChars { score += 1 }
        if length >= 12 { score += 1 }
        
        switch score {
        case 0...2:
            return .weak
        case 3...4:
            return .fair
        case 5:
            return .good
        case 6:
            return .strong
        default:
            return .weak
        }
    }
    
    private func getPasswordRequirements() -> [PasswordRequirement] {
        [
            PasswordRequirement(
                requirement: "At least 8 characters",
                isMet: password.count >= 8
            ),
            PasswordRequirement(
                requirement: "Contains uppercase letter",
                isMet: password.contains(where: \.isUppercase)
            ),
            PasswordRequirement(
                requirement: "Contains lowercase letter",
                isMet: password.contains(where: \.isLowercase)
            ),
            PasswordRequirement(
                requirement: "Contains number",
                isMet: password.contains(where: \.isNumber)
            ),
            PasswordRequirement(
                requirement: "Contains special character",
                isMet: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil
            )
        ]
    }
}

enum PasswordStrength {
    case weak, fair, good, strong
    
    var label: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .strong: return .green
        }
    }
}

struct PasswordRequirement {
    let requirement: String
    let isMet: Bool
}
```

## 🔐 Enhanced Authentication Views

### 1. Validated Sign Up View
Update `Views/Authentication/SignUpView.swift`:

```swift
import SwiftUI

struct ValidatedSignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var formValidator = FormValidator()
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false
    
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Validators
    private let nameValidator = ValidationRules.NameValidator()
    private let emailValidator = ValidationRules.EmailValidator()
    private let passwordValidator = ValidationRules.PasswordValidator()
    
    var confirmPasswordValidator: ValidationRules.ConfirmPasswordValidator {
        ValidationRules.ConfirmPasswordValidator(originalPassword: password)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign up to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        ValidatedTextField(
                            title: "Full Name",
                            placeholder: "Enter your full name",
                            text: $fullName,
                            validator: nameValidator
                        )
                        
                        ValidatedTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            validator: emailValidator,
                            keyboardType: .emailAddress
                        )
                        
                        ValidatedTextField(
                            title: "Password",
                            placeholder: "Create a password",
                            text: $password,
                            validator: passwordValidator,
                            isSecure: true
                        )
                        
                        ValidatedTextField(
                            title: "Confirm Password",
                            placeholder: "Confirm your password",
                            text: $confirmPassword,
                            validator: confirmPasswordValidator,
                            isSecure: true
                        )
                    }
                    
                    // Terms Agreement
                    TermsAgreementView(agreeToTerms: $agreeToTerms)
                    
                    // Sign Up Button
                    CustomButton(
                        title: "Create Account",
                        isLoading: isLoading,
                        action: signUp
                    )
                    .disabled(!canSignUp)
                    .opacity(canSignUp ? 1.0 : 0.6)
                    
                    // Sign In Link
                    HStack {
                        Text("Already have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Sign In") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var canSignUp: Bool {
        return isFormValid && agreeToTerms && !isLoading
    }
    
    private var isFormValid: Bool {
        return nameValidator.validate(fullName).isValid &&
               emailValidator.validate(email).isValid &&
               passwordValidator.validate(password).isValid &&
               confirmPasswordValidator.validate(confirmPassword).isValid
    }
    
    private func signUp() {
        guard canSignUp else {
            alertMessage = "Please fill out all fields correctly and agree to the terms."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            // TODO: Implement actual sign up logic
            print("Sign up attempt with:")
            print("Name: \(fullName)")
            print("Email: \(email)")
            print("Password: \(password)")
        }
    }
}

// Terms Agreement Component
struct TermsAgreementView: View {
    @Binding var agreeToTerms: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { agreeToTerms.toggle() }) {
                Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                    .foregroundColor(agreeToTerms ? .blue : .secondary)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("I agree to the")
                    .font(.subheadline)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // TODO: Show terms
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    
                    Text("and")
                        .font(.subheadline)
                    
                    Button("Privacy Policy") {
                        // TODO: Show privacy policy
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
    }
}
```

### 2. Validated Login View
Update `Views/Authentication/LoginView.swift`:

```swift
import SwiftUI

struct ValidatedLoginView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var attemptedSubmission = false
    
    // Validators
    private let emailValidator = ValidationRules.EmailValidator()
    private let passwordValidator = ValidationRules.PasswordValidator(
        minLength: 1, // Less strict for login
        requireUppercase: false,
        requireLowercase: false,
        requireNumbers: false
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        ValidatedTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            validator: emailValidator,
                            keyboardType: .emailAddress
                        )
                        
                        ValidatedTextField(
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            validator: passwordValidator,
                            isSecure: true
                        )
                    }
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            showForgotPassword()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    // Sign In Button
                    CustomButton(
                        title: "Sign In",
                        isLoading: isLoading,
                        action: signIn
                    )
                    
                    // Divider
                    DividerWithText(text: "or")
                    
                    // Social Sign In
                    VStack(spacing: 12) {
                        CustomButton(
                            title: "Continue with Google",
                            style: .social(.google),
                            action: signInWithGoogle
                        )
                        
                        CustomButton(
                            title: "Continue with Apple",
                            style: .social(.apple),
                            action: signInWithApple
                        )
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        return emailValidator.validate(email).isValid &&
               passwordValidator.validate(password).isValid
    }
    
    private func signIn() {
        attemptedSubmission = true
        
        guard isFormValid else {
            alertMessage = "Please enter a valid email and password."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            // TODO: Implement actual sign in logic
            print("Sign in attempt with email: \(email)")
        }
    }
    
    private func signInWithGoogle() {
        // TODO: Implement Google sign in
        print("Sign in with Google")
    }
    
    private func signInWithApple() {
        // TODO: Implement Apple sign in
        print("Sign in with Apple")
    }
    
    private func showForgotPassword() {
        // TODO: Show forgot password flow
        print("Show forgot password")
    }
}

// Divider with Text Component
struct DividerWithText: View {
    let text: String
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.secondary.opacity(0.3))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.secondary.opacity(0.3))
        }
    }
}
```

## 🧪 Form Validation Testing

### 1. Unit Tests for Validators
Create `Tests/ValidationTests.swift`:

```swift
import XCTest
@testable import iOSAuthApp

class ValidationTests: XCTestCase {
    
    func testEmailValidator() {
        let validator = ValidationRules.EmailValidator()
        
        // Valid emails
        XCTAssertTrue(validator.validate("test@example.com").isValid)
        XCTAssertTrue(validator.validate("user.name+tag@domain.co.uk").isValid)
        
        // Invalid emails
        XCTAssertFalse(validator.validate("").isValid)
        XCTAssertFalse(validator.validate("invalid-email").isValid)
        XCTAssertFalse(validator.validate("@domain.com").isValid)
        XCTAssertFalse(validator.validate("user@").isValid)
    }
    
    func testPasswordValidator() {
        let validator = ValidationRules.PasswordValidator()
        
        // Valid password
        XCTAssertTrue(validator.validate("StrongPass123").isValid)
        
        // Invalid passwords
        XCTAssertFalse(validator.validate("").isValid)
        XCTAssertFalse(validator.validate("short").isValid)
        XCTAssertFalse(validator.validate("nouppercase123").isValid)
        XCTAssertFalse(validator.validate("NOLOWERCASE123").isValid)
        XCTAssertFalse(validator.validate("NoNumbers").isValid)
    }
    
    func testNameValidator() {
        let validator = ValidationRules.NameValidator()
        
        // Valid names
        XCTAssertTrue(validator.validate("John Doe").isValid)
        XCTAssertTrue(validator.validate("Mary-Jane O'Connor").isValid)
        
        // Invalid names
        XCTAssertFalse(validator.validate("").isValid)
        XCTAssertFalse(validator.validate("A").isValid)
        XCTAssertFalse(validator.validate("John123").isValid)
        XCTAssertFalse(validator.validate("   ").isValid)
    }
    
    func testConfirmPasswordValidator() {
        let originalPassword = "TestPassword123"
        let validator = ValidationRules.ConfirmPasswordValidator(originalPassword: originalPassword)
        
        // Valid confirmation
        XCTAssertTrue(validator.validate("TestPassword123").isValid)
        
        // Invalid confirmations
        XCTAssertFalse(validator.validate("").isValid)
        XCTAssertFalse(validator.validate("WrongPassword").isValid)
        XCTAssertFalse(validator.validate("testpassword123").isValid) // Case sensitive
    }
}
```

## 📱 Enhanced User Experience

### 1. Real-time Validation Feedback
- Validation triggers as user types (after first interaction)
- Visual indicators (colors, icons) for field states
- Progressive disclosure of validation rules
- Debounced validation to avoid excessive checking

### 2. Error Prevention
- Input formatters for specific field types
- Character limits and input restrictions
- Autocomplete suggestions for email domains
- Password visibility toggle

### 3. Accessibility Improvements
```swift
// Add to ValidatedTextField
.accessibilityLabel(title)
.accessibilityValue(text)
.accessibilityHint(validationResult.isValid ? "Valid input" : validationResult.errorMessage ?? "")
```

## 🎯 Best Practices

### 1. Validation Timing
- **On Focus Lost**: Validate when user leaves field
- **On Submission**: Always validate before submitting
- **Real-time**: For password strength and availability checks
- **Debounced**: For expensive validations (API calls)

### 2. Error Messaging
- Be specific and actionable
- Use positive language when possible
- Provide examples of correct formats
- Avoid technical jargon

### 3. Form State Management
- Track field interaction states
- Maintain validation state separately from input state
- Reset validation state appropriately
- Handle async validation results

## 📚 Key Concepts Learned

1. **Validation Architecture**: Separating validation logic from UI
2. **User Experience**: Providing helpful, timely feedback
3. **Accessibility**: Making forms usable for everyone
4. **Testing**: Ensuring validation logic works correctly
5. **State Management**: Handling complex form states

## 🎯 Next Steps

In the next lesson, we'll focus on:
- Advanced UI animations and transitions
- Loading states and skeleton screens
- Responsive design patterns
- Custom input components

---

**🎉 Excellent Work!** You've implemented a robust form validation system that provides excellent user experience while maintaining data integrity.

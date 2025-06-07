import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var acceptedTerms = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Join us today!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Sign Up Form
                    VStack(spacing: 16) {
                        // Name Fields
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("First name", text: $firstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(isLoading)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Last name", text: $lastName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(isLoading)
                            }
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLoading)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isLoading)
                            
                            // Password Requirements
                            VStack(alignment: .leading, spacing: 4) {
                                PasswordRequirement(text: "At least 8 characters", isMet: password.count >= 8)
                                PasswordRequirement(text: "Contains uppercase letter", isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil)
                                PasswordRequirement(text: "Contains lowercase letter", isMet: password.rangeOfCharacter(from: .lowercaseLetters) != nil)
                                PasswordRequirement(text: "Contains number", isMet: password.rangeOfCharacter(from: .decimalDigits) != nil)
                            }
                            .padding(.leading, 8)
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Confirm your password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isLoading)
                            
                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords do not match")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.leading, 8)
                            }
                        }
                        
                        // Terms and Conditions
                        HStack {
                            Button(action: { acceptedTerms.toggle() }) {
                                Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(acceptedTerms ? .blue : .gray)
                            }
                            
                            Text("I agree to the ")
                                .font(.caption)
                                .foregroundColor(.gray)
                            +
                            Text("Terms and Conditions")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                            +
                            Text(" and ")
                                .font(.caption)
                                .foregroundColor(.gray)
                            +
                            Text("Privacy Policy")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                            
                            Spacer()
                        }
                        .disabled(isLoading)
                        
                        // Sign Up Button
                        Button(action: signUp) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!isFormValid || isLoading)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            Text("OR")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        
                        // Social Sign Up
                        VStack(spacing: 12) {
                            Button(action: signUpWithGoogle) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Continue with Google")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isLoading)
                            
                            Button(action: signUpWithApple) {
                                HStack {
                                    Image(systemName: "applelogo")
                                    Text("Continue with Apple")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Already have account
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.gray)
                        Button("Sign In") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword &&
        acceptedTerms
    }
    
    private func signUp() {
        guard isFormValid else { return }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.createAccount(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func signUpWithGoogle() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signInWithGoogle()
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func signUpWithApple() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signInWithApple()
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
}

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .green : .gray)
            
            Spacer()
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}

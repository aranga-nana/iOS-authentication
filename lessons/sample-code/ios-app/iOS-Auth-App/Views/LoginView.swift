import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and Title
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Login Form
                VStack(spacing: 16) {
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
                    }
                    
                    // Login Button
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    
                    // Forgot Password
                    Button("Forgot Password?") {
                        resetPassword()
                    }
                    .foregroundColor(.blue)
                    .disabled(isLoading)
                    
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
                    .padding(.vertical)
                    
                    // Social Login Buttons
                    VStack(spacing: 12) {
                        // Google Sign In
                        Button(action: signInWithGoogle) {
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
                        
                        // Apple Sign In
                        Button(action: signInWithApple) {
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
                
                Spacer()
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.gray)
                    Button("Sign Up") {
                        showingSignUp = true
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
    }
    
    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func resetPassword() {
        guard !email.isEmpty else {
            alertMessage = "Please enter your email address first"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.resetPassword(email: email)
                await MainActor.run {
                    alertMessage = "Password reset email sent successfully"
                    showingAlert = true
                    isLoading = false
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
    
    private func signInWithGoogle() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func signInWithApple() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signInWithApple()
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

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

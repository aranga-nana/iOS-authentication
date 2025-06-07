import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var biometricManager = BiometricManager.shared
    @State private var showingSplash = true
    
    var body: some View {
        Group {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingSplash)
        .onAppear {
            authManager.checkAuthState()
            biometricManager.checkBiometricAvailability()
            
            // Show splash for 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingSplash = false
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if authManager.isAuthenticated {
            MainTabView()
                .transition(.slide)
        } else {
            AuthenticationFlowView()
                .transition(.slide)
        }
    }
}

struct AuthenticationFlowView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var biometricManager = BiometricManager.shared
    
    var body: some View {
        VStack {
            if biometricManager.isBiometricEnabled && biometricManager.isBiometricAvailable {
                BiometricLoginView()
            } else {
                LoginView()
            }
        }
    }
}

struct BiometricLoginView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var biometricManager = BiometricManager.shared
    @State private var showingPasswordLogin = false
    @State private var isAuthenticating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 10) {
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Use \(biometricManager.biometricTypeString) to sign in")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Biometric Authentication Button
            Button(action: authenticateWithBiometric) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: biometricManager.biometricType.icon)
                    }
                    Text("Sign in with \(biometricManager.biometricTypeString)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isAuthenticating)
            
            // Alternative login option
            Button("Use Password Instead") {
                showingPasswordLogin = true
            }
            .foregroundColor(.blue)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 32)
        .sheet(isPresented: $showingPasswordLogin) {
            LoginView()
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func authenticateWithBiometric() {
        isAuthenticating = true
        
        Task {
            do {
                let authenticated = try await biometricManager.authenticateWithBiometric()
                
                if authenticated {
                    // Retrieve stored credentials and sign in
                    let credentials = try await biometricManager.retrieveCredentialsWithBiometric()
                    try await authManager.signIn(email: credentials.email, password: credentials.password)
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isAuthenticating = false
                }
            }
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("iOS Auth App")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Secure Authentication Demo")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        TabView {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(.blue)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(AppStateManager())
    }
}

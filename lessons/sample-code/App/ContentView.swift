// ContentView.swift
// Main content view that routes between authentication and main app

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                SplashView()
            } else if authManager.isAuthenticated {
                MainAppView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            // Check authentication status on app launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoading = false
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

// MARK: - Splash Screen
struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        scale = 1.2
                        opacity = 1.0
                    }
                }
            
            Text("AuthApp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Secure Authentication")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Main App View (Post-Authentication)
struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    WelcomeHeaderView()
                    
                    // Quick Actions
                    QuickActionsView()
                    
                    // Recent Activity
                    RecentActivityView()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                // Refresh dashboard data
                await refreshDashboard()
            }
        }
    }
    
    private func refreshDashboard() async {
        // Simulate data refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - Welcome Header
struct WelcomeHeaderView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(authManager.currentUser?.displayName ?? "User")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            AsyncImage(url: URL(string: authManager.currentUser?.profile.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionCard(
                    title: "Update Profile",
                    icon: "person.fill",
                    color: .blue
                ) {
                    // Handle profile update
                }
                
                QuickActionCard(
                    title: "Security",
                    icon: "lock.fill",
                    color: .green
                ) {
                    // Handle security settings
                }
                
                QuickActionCard(
                    title: "Notifications",
                    icon: "bell.fill",
                    color: .orange
                ) {
                    // Handle notifications
                }
                
                QuickActionCard(
                    title: "Support",
                    icon: "questionmark.circle.fill",
                    color: .purple
                ) {
                    // Handle support
                }
            }
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Activity
struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ActivityRowView(
                    title: "Account Created",
                    subtitle: "Welcome to the app!",
                    time: "2 hours ago",
                    icon: "person.badge.plus",
                    color: .green
                )
                
                ActivityRowView(
                    title: "Profile Updated",
                    subtitle: "Display name changed",
                    time: "1 day ago",
                    icon: "pencil.circle",
                    color: .blue
                )
                
                ActivityRowView(
                    title: "Security Alert",
                    subtitle: "New device login",
                    time: "3 days ago",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
            }
        }
    }
}

struct ActivityRowView: View {
    let title: String
    let subtitle: String
    let time: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingEditProfile = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    ProfileHeaderView()
                }
                
                // Profile Actions
                Section("Account") {
                    ProfileRowView(
                        title: "Edit Profile",
                        icon: "pencil",
                        action: { showingEditProfile = true }
                    )
                    
                    ProfileRowView(
                        title: "Change Password",
                        icon: "key",
                        action: { /* Handle password change */ }
                    )
                    
                    ProfileRowView(
                        title: "Privacy Settings",
                        icon: "hand.raised",
                        action: { /* Handle privacy */ }
                    )
                }
                
                // App Settings
                Section("Preferences") {
                    ProfileRowView(
                        title: "Notifications",
                        icon: "bell",
                        action: { /* Handle notifications */ }
                    )
                    
                    ProfileRowView(
                        title: "Dark Mode",
                        icon: "moon",
                        action: { /* Handle dark mode */ }
                    )
                }
                
                // Sign Out
                Section {
                    Button("Sign Out") {
                        showingSignOutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct ProfileHeaderView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: authManager.currentUser?.profile.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(authManager.currentUser?.displayName ?? "User")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(authManager.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}

struct ProfileRowView: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings View
struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("General") {
                    SettingRowView(title: "About", icon: "info.circle")
                    SettingRowView(title: "Terms of Service", icon: "doc.text")
                    SettingRowView(title: "Privacy Policy", icon: "hand.raised")
                }
                
                Section("Support") {
                    SettingRowView(title: "Help Center", icon: "questionmark.circle")
                    SettingRowView(title: "Contact Us", icon: "envelope")
                    SettingRowView(title: "Report Bug", icon: "ant")
                }
                
                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingRowView: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var displayName = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Display Name", text: $displayName)
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save profile changes
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        if let user = authManager.currentUser {
            displayName = user.displayName
            firstName = user.profile.firstName
            lastName = user.profile.lastName
            phoneNumber = user.profile.phoneNumber
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}

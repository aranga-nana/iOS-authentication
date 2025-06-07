import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeader()
                    
                    // Quick Actions
                    QuickActionsSection()
                    
                    // Account Information
                    AccountInfoSection(
                        showingEditProfile: $showingEditProfile,
                        showingChangePassword: $showingChangePassword
                    )
                    
                    // Security Settings
                    SecuritySection()
                    
                    // App Settings
                    AppSettingsSection()
                    
                    // Danger Zone
                    DangerZoneSection(showingDeleteAccount: $showingDeleteAccount)
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .refreshable {
                await refreshUserData()
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    private func refreshUserData() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await authManager.refreshUserProfile()
        } catch {
            print("Failed to refresh user data: \(error)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await authManager.deleteAccount()
            } catch {
                print("Failed to delete account: \(error)")
            }
        }
    }
}

struct ProfileHeader: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: authManager.currentUser?.photoURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            // User Info
            VStack(spacing: 4) {
                Text(authManager.currentUser?.displayName ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(authManager.currentUser?.email ?? "No email")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let joinDate = authManager.currentUser?.metadata.creationDate {
                    Text("Member since \(joinDate, formatter: DateFormatter.memberSince)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickActionCard(
                    icon: "bell.fill",
                    title: "Notifications",
                    color: .orange
                ) {
                    // Handle notifications
                }
                
                QuickActionCard(
                    icon: "shield.fill",
                    title: "Security",
                    color: .green
                ) {
                    // Handle security
                }
                
                QuickActionCard(
                    icon: "heart.fill",
                    title: "Favorites",
                    color: .red
                ) {
                    // Handle favorites
                }
                
                QuickActionCard(
                    icon: "gear",
                    title: "Settings",
                    color: .blue
                ) {
                    // Handle settings
                }
            }
            .padding(.horizontal)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
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
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct AccountInfoSection: View {
    @Binding var showingEditProfile: Bool
    @Binding var showingChangePassword: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.fill",
                    title: "Edit Profile",
                    subtitle: "Update your personal information"
                ) {
                    showingEditProfile = true
                }
                
                Divider().padding(.leading, 50)
                
                SettingsRow(
                    icon: "key.fill",
                    title: "Change Password",
                    subtitle: "Update your account password"
                ) {
                    showingChangePassword = true
                }
                
                Divider().padding(.leading, 50)
                
                SettingsRow(
                    icon: "envelope.fill",
                    title: "Email Preferences",
                    subtitle: "Manage email notifications"
                ) {
                    // Handle email preferences
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct SecuritySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security & Privacy")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "faceid",
                    title: "Biometric Authentication",
                    subtitle: "Use Face ID or Touch ID"
                ) {
                    // Handle biometric auth
                }
                
                Divider().padding(.leading, 50)
                
                SettingsRow(
                    icon: "lock.fill",
                    title: "Two-Factor Authentication",
                    subtitle: "Add an extra layer of security"
                ) {
                    // Handle 2FA
                }
                
                Divider().padding(.leading, 50)
                
                SettingsRow(
                    icon: "eye.slash.fill",
                    title: "Privacy Settings",
                    subtitle: "Control your data and privacy"
                ) {
                    // Handle privacy settings
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct AppSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Settings")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage push notifications"
                ) {
                    // Handle notifications
                }
                
                Divider().padding(.leading, 50)
                
                SettingsRow(
                    icon: "moon.fill",
                    title: "Dark Mode",
                    subtitle: "Choose your preferred theme"
                ) {
                    // Handle dark mode
                }
                
                Divider().padding(.leading, 50)
                
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "Get help and contact support"
                ) {
                    // Handle help
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct DangerZoneSection: View {
    @Binding var showingDeleteAccount: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)
                .foregroundColor(.red)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "trash.fill",
                    title: "Delete Account",
                    subtitle: "Permanently delete your account",
                    titleColor: .red
                ) {
                    showingDeleteAccount = true
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let titleColor: Color
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        titleColor: Color = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(titleColor)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension DateFormatter {
    static let memberSince: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}

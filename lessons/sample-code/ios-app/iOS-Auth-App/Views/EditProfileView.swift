import SwiftUI

struct EditProfileView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Profile Photo
                    HStack {
                        Spacer()
                        
                        Button(action: { showingImagePicker = true }) {
                            ZStack {
                                if let selectedImage = selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    AsyncImage(url: authManager.currentUser?.photoURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 100))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                }
                                
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.white)
                                    .font(.title2)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                        .disabled(isLoading)
                    
                    TextField("Last Name", text: $lastName)
                        .disabled(isLoading)
                    
                    TextField("Display Name", text: $displayName)
                        .disabled(isLoading)
                }
                
                Section("Contact Information") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .disabled(isLoading)
                }
                
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authManager.currentUser?.email ?? "N/A")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Account Created")
                        Spacer()
                        Text(authManager.currentUser?.metadata.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveProfile()
                }
                .disabled(isLoading)
            )
            .onAppear {
                loadCurrentData()
            }
            .disabled(isLoading)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
    
    private func loadCurrentData() {
        if let user = authManager.currentUser {
            displayName = user.displayName ?? ""
            phoneNumber = user.phoneNumber ?? ""
            
            // Parse display name into first and last name if possible
            let components = displayName.components(separatedBy: " ")
            if components.count >= 2 {
                firstName = components.first ?? ""
                lastName = components.dropFirst().joined(separator: " ")
            } else {
                firstName = displayName
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        
        Task {
            do {
                // Combine first and last name for display name
                let newDisplayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                
                try await authManager.updateProfile(
                    displayName: newDisplayName.isEmpty ? nil : newDisplayName,
                    photoURL: nil // We'll handle photo upload separately
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
}

struct ChangePasswordView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Password") {
                    SecureField("Enter current password", text: $currentPassword)
                        .disabled(isLoading)
                }
                
                Section("New Password") {
                    SecureField("Enter new password", text: $newPassword)
                        .disabled(isLoading)
                    
                    SecureField("Confirm new password", text: $confirmPassword)
                        .disabled(isLoading)
                    
                    // Password Requirements
                    VStack(alignment: .leading, spacing: 4) {
                        PasswordRequirement(text: "At least 8 characters", isMet: newPassword.count >= 8)
                        PasswordRequirement(text: "Contains uppercase letter", isMet: newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil)
                        PasswordRequirement(text: "Contains lowercase letter", isMet: newPassword.rangeOfCharacter(from: .lowercaseLetters) != nil)
                        PasswordRequirement(text: "Contains number", isMet: newPassword.rangeOfCharacter(from: .decimalDigits) != nil)
                        PasswordRequirement(text: "Passwords match", isMet: !newPassword.isEmpty && newPassword == confirmPassword)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Update") {
                    changePassword()
                }
                .disabled(!isFormValid || isLoading)
            )
            .disabled(isLoading)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        currentPassword != newPassword
    }
    
    private func changePassword() {
        isLoading = true
        
        Task {
            do {
                try await authManager.updatePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
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
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
    }
}

# Lesson 1: iOS UI Fundamentals for Authentication
**Phase 2, Week 1** | **Duration:** 6-8 hours | **Difficulty:** Beginner to Intermediate

## 🎯 Learning Objectives
By the end of this lesson, you will:
- Understand SwiftUI vs UIKit for authentication interfaces
- Create basic authentication UI components
- Implement proper navigation patterns
- Design accessible and user-friendly login screens
- Set up the foundation for your authentication app UI

## 📋 Prerequisites
- Completed Phase 1 (iOS basics and development environment setup)
- Xcode installed and configured
- Basic understanding of Swift syntax

## 🏗️ Project Structure Setup

### 1. Create New iOS Project
```bash
# Navigate to your project directory
cd /path/to/your/projects
```

**In Xcode:**
1. Create new iOS App project
2. Name: `iOS-Auth-App`
3. Interface: SwiftUI
4. Language: Swift
5. Use Core Data: No (we'll use Firebase)

### 2. Project Organization
```
iOS-Auth-App/
├── App/
│   └── iOS_Auth_AppApp.swift
├── Views/
│   ├── Authentication/
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── WelcomeView.swift
│   └── Main/
│       ├── ContentView.swift
│       └── ProfileView.swift
├── Components/
│   ├── CustomButton.swift
│   ├── CustomTextField.swift
│   └── LoadingView.swift
├── Models/
│   └── User.swift
└── Services/
    └── AuthenticationManager.swift
```

## 🎨 SwiftUI UI Components

### 1. Custom Text Field Component
Create `Components/CustomTextField.swift`:

```swift
import SwiftUI

struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}

// Preview
struct CustomTextField_Previews: PreviewProvider {
    @State static var email = ""
    @State static var password = ""
    
    static var previews: some View {
        VStack(spacing: 20) {
            CustomTextField(
                title: "Email",
                placeholder: "Enter your email",
                text: $email,
                keyboardType: .emailAddress
            )
            
            CustomTextField(
                title: "Password",
                placeholder: "Enter your password",
                text: $password,
                isSecure: true
            )
        }
        .padding()
    }
}
```

### 2. Custom Button Component
Create `Components/CustomButton.swift`:

```swift
import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    let isLoading: Bool
    
    enum ButtonStyle {
        case primary
        case secondary
        case social(SocialProvider)
        
        enum SocialProvider {
            case google
            case apple
        }
    }
    
    init(
        title: String,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if case .social(let provider) = style {
                    socialIcon(for: provider)
                        .frame(width: 20, height: 20)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .disabled(isLoading)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.blue
        case .secondary:
            return Color.clear
        case .social(.google):
            return Color.white
        case .social(.apple):
            return Color.black
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .blue
        case .social(.google):
            return .black
        case .social(.apple):
            return .white
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return Color.blue
        case .social:
            return Color(.systemGray4)
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary:
            return 0
        case .secondary, .social:
            return 1
        }
    }
    
    @ViewBuilder
    private func socialIcon(for provider: ButtonStyle.SocialProvider) -> some View {
        switch provider {
        case .google:
            Image(systemName: "globe")
                .foregroundColor(.red)
        case .apple:
            Image(systemName: "applelogo")
                .foregroundColor(.white)
        }
    }
}

// Preview
struct CustomButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CustomButton(title: "Sign In", action: {})
            
            CustomButton(
                title: "Create Account",
                style: .secondary,
                action: {}
            )
            
            CustomButton(
                title: "Continue with Google",
                style: .social(.google),
                action: {}
            )
            
            CustomButton(
                title: "Continue with Apple",
                style: .social(.apple),
                action: {}
            )
            
            CustomButton(
                title: "Loading...",
                isLoading: true,
                action: {}
            )
        }
        .padding()
    }
}
```

### 3. Loading View Component
Create `Components/LoadingView.swift`:

```swift
import SwiftUI

struct LoadingView: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// Preview
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView(message: "Signing you in...")
    }
}
```

## 🔐 Authentication Views

### 1. Welcome View
Create `Views/Authentication/WelcomeView.swift`:

```swift
import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo/Icon
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("SecureAuth")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your secure authentication solution")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    CustomButton(
                        title: "Sign In",
                        action: { showLogin = true }
                    )
                    
                    CustomButton(
                        title: "Create Account",
                        style: .secondary,
                        action: { showSignUp = true }
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
}

// Preview
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
```

### 2. Login View Skeleton
Create `Views/Authentication/LoginView.swift`:

```swift
import SwiftUI

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                        CustomTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        CustomTextField(
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            isSecure: true
                        )
                    }
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            // TODO: Implement forgot password
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
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        Text("or")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    
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
    
    private func signIn() {
        // TODO: Implement email/password sign in
        print("Sign in with email: \(email)")
    }
    
    private func signInWithGoogle() {
        // TODO: Implement Google sign in
        print("Sign in with Google")
    }
    
    private func signInWithApple() {
        // TODO: Implement Apple sign in
        print("Sign in with Apple")
    }
}

// Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
```

### 3. Sign Up View Skeleton
Create `Views/Authentication/SignUpView.swift`:

```swift
import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var agreeToTerms = false
    
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
                        CustomTextField(
                            title: "Full Name",
                            placeholder: "Enter your full name",
                            text: $fullName
                        )
                        
                        CustomTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        CustomTextField(
                            title: "Password",
                            placeholder: "Create a password",
                            text: $password,
                            isSecure: true
                        )
                        
                        CustomTextField(
                            title: "Confirm Password",
                            placeholder: "Confirm your password",
                            text: $confirmPassword,
                            isSecure: true
                        )
                    }
                    
                    // Terms Agreement
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
                    
                    // Sign Up Button
                    CustomButton(
                        title: "Create Account",
                        isLoading: isLoading,
                        action: signUp
                    )
                    .disabled(!agreeToTerms)
                    .opacity(agreeToTerms ? 1.0 : 0.6)
                    
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
    
    private func signUp() {
        // TODO: Implement sign up logic
        print("Sign up with email: \(email)")
    }
}

// Preview
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
```

## 🔄 Navigation Setup

### Update ContentView
Update `Views/Main/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                ProfileView()
            } else {
                WelcomeView()
            }
        }
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

## 📱 Accessibility & Best Practices

### 1. Accessibility Support
- All interactive elements have proper accessibility labels
- Form fields support VoiceOver
- Color contrast meets WCAG guidelines
- Text scales properly with Dynamic Type

### 2. UI Best Practices
- Consistent spacing and typography
- Proper loading states
- Error handling with user-friendly messages
- Keyboard-friendly navigation
- Safe area considerations

## 🧪 Testing Your UI

### 1. Preview Testing
- Use Xcode previews for rapid iteration
- Test different device sizes
- Test light and dark mode
- Test with different text sizes

### 2. Manual Testing Checklist
- [ ] All buttons are tappable
- [ ] Text fields accept input correctly
- [ ] Navigation works properly
- [ ] Loading states display correctly
- [ ] Error messages are clear
- [ ] Accessibility features work

## 📚 Key Concepts Learned

1. **SwiftUI Component Architecture**: Building reusable UI components
2. **State Management**: Using `@State` and `@Binding` for UI state
3. **Navigation Patterns**: Modal presentations and navigation views
4. **Design System**: Consistent styling and theming
5. **Accessibility**: Making apps usable for everyone

## 🎯 Next Steps

In the next lesson, we'll focus on:
- Form validation and error handling
- Advanced UI animations
- Custom input validation
- User experience improvements

## 📖 Additional Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Accessibility in SwiftUI](https://developer.apple.com/documentation/swiftui/accessibility)

---

**🎉 Congratulations!** You've built the foundation UI components for your authentication system. These reusable components will serve as the building blocks for the complete authentication flow.

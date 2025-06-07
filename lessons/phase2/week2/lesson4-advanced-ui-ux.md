# Lesson 4: Advanced UI/UX and Design Patterns
**Phase 2, Week 2** | **Duration:** 6-8 hours | **Difficulty:** Intermediate to Advanced

## 🎯 Learning Objectives
By the end of this lesson, you will:
- Implement advanced UI animations and transitions
- Create loading states and skeleton screens
- Build responsive design patterns for different devices
- Design custom input components with enhanced UX
- Understand and apply iOS design principles
- Create accessible and inclusive interfaces

## 📋 Prerequisites
- Completed previous lessons in Phase 2
- Understanding of SwiftUI animations
- Basic knowledge of iOS Human Interface Guidelines

## 🎨 Advanced Animation Patterns

### 1. Micro-Interactions and Feedback
Create `Components/AnimatedComponents.swift`:

```swift
import SwiftUI

// MARK: - Animated Button
struct AnimatedButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    let isLoading: Bool
    
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    enum ButtonStyle {
        case primary, secondary, destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .clear
            case .destructive: return .red
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .blue
            case .destructive: return .white
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary: return .clear
            case .secondary: return .blue
            case .destructive: return .clear
            }
        }
    }
    
    var body: some View {
        Button(action: {
            performAction()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.8)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style.borderColor, lineWidth: 2)
            )
            .scaleEffect(scale)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .disabled(isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
                scale = pressing ? 0.98 : 1.0
            }
        }, perform: {})
    }
    
    private func performAction() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
        
        action()
    }
}

// MARK: - Animated Text Field
struct AnimatedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    
    @State private var isFocused = false
    @State private var showPassword = false
    @FocusState private var fieldIsFocused: Bool
    
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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? Color.blue : Color(.systemGray4),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        // Floating Label
                        Text(title)
                            .font(.caption)
                            .foregroundColor(isFocused ? .blue : .secondary)
                            .opacity(isFocused || !text.isEmpty ? 1 : 0)
                            .scaleEffect(isFocused || !text.isEmpty ? 1 : 0.8, anchor: .leading)
                            .offset(y: isFocused || !text.isEmpty ? 0 : 12)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
                        
                        // Input Field
                        Group {
                            if isSecure && !showPassword {
                                SecureField("", text: $text)
                            } else {
                                TextField("", text: $text)
                                    .keyboardType(keyboardType)
                            }
                        }
                        .focused($fieldIsFocused)
                        .font(.system(size: 16))
                        .onChange(of: fieldIsFocused) { focused in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFocused = focused
                            }
                        }
                    }
                    
                    // Password Toggle
                    if isSecure {
                        Button(action: {
                            showPassword.toggle()
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16)
                
                // Placeholder
                if text.isEmpty && !isFocused {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    @State private var isAnimating = false
    
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 4) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray4),
                        Color(.systemGray5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(70))
                    .offset(x: isAnimating ? 200 : -200)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}
```

### 2. Page Transitions and Navigation
Create `Views/Shared/PageTransitions.swift`:

```swift
import SwiftUI

// MARK: - Page Transition Styles
enum PageTransition {
    case slide
    case fade
    case scale
    case push
    
    var transition: AnyTransition {
        switch self {
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .fade:
            return .opacity
        case .scale:
            return .scale.combined(with: .opacity)
        case .push:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        }
    }
}

// MARK: - Animated Navigation Container
struct AnimatedNavigationContainer<Content: View>: View {
    @Binding var currentPage: Int
    let transition: PageTransition
    let content: Content
    
    init(
        currentPage: Binding<Int>,
        transition: PageTransition = .slide,
        @ViewBuilder content: () -> Content
    ) {
        self._currentPage = currentPage
        self.transition = transition
        self.content = content()
    }
    
    var body: some View {
        content
            .transition(transition.transition)
            .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
}

// MARK: - Progress Indicator
struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.blue : Color(.systemGray4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
    }
}
```

## 📱 Responsive Design Patterns

### 1. Adaptive Layout System
Create `Views/Shared/AdaptiveLayout.swift`:

```swift
import SwiftUI

// MARK: - Device Size Classes
enum DeviceSize {
    case compact, regular, large
    
    static func current(width: CGFloat) -> DeviceSize {
        switch width {
        case ..<400:
            return .compact
        case 400..<800:
            return .regular
        default:
            return .large
        }
    }
}

// MARK: - Adaptive Container
struct AdaptiveContainer<Content: View>: View {
    let content: (DeviceSize) -> Content
    
    init(@ViewBuilder content: @escaping (DeviceSize) -> Content) {
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let deviceSize = DeviceSize.current(width: geometry.size.width)
            content(deviceSize)
        }
    }
}

// MARK: - Responsive Grid
struct ResponsiveGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    private func columns(for size: DeviceSize) -> [GridItem] {
        switch size {
        case .compact:
            return [GridItem(.flexible())]
        case .regular:
            return Array(repeating: GridItem(.flexible()), count: 2)
        case .large:
            return Array(repeating: GridItem(.flexible()), count: 3)
        }
    }
    
    var body: some View {
        AdaptiveContainer { deviceSize in
            LazyVGrid(columns: columns(for: deviceSize), spacing: 16) {
                ForEach(items) { item in
                    content(item)
                }
            }
        }
    }
}

// MARK: - Adaptive Authentication Layout
struct AdaptiveAuthLayout<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        AdaptiveContainer { deviceSize in
            switch deviceSize {
            case .compact:
                // Mobile layout - full screen
                ScrollView {
                    VStack(spacing: 24) {
                        content
                    }
                    .padding(.horizontal, 24)
                }
                
            case .regular:
                // Tablet portrait - centered with padding
                ScrollView {
                    VStack(spacing: 32) {
                        content
                    }
                    .padding(.horizontal, 64)
                    .frame(maxWidth: 500)
                }
                .frame(maxWidth: .infinity)
                
            case .large:
                // Desktop/Tablet landscape - card layout
                HStack {
                    Spacer()
                    
                    VStack(spacing: 32) {
                        content
                    }
                    .padding(48)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .frame(maxWidth: 400)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            }
        }
    }
}
```

### 2. Responsive Authentication Views
Update authentication views to use adaptive layouts:

```swift
// Enhanced Responsive Login View
struct ResponsiveLoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            AdaptiveAuthLayout {
                VStack(spacing: 32) {
                    // Header
                    AuthHeaderView(
                        title: "Welcome Back",
                        subtitle: "Sign in to your account"
                    )
                    
                    // Form
                    VStack(spacing: 20) {
                        AnimatedTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        AnimatedTextField(
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            isSecure: true
                        )
                    }
                    
                    // Actions
                    VStack(spacing: 16) {
                        AnimatedButton(
                            title: "Sign In",
                            action: signIn,
                            style: .primary,
                            isLoading: isLoading
                        )
                        
                        Button("Forgot Password?") {
                            // Handle forgot password
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    // Social Login
                    SocialLoginSection()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func signIn() {
        isLoading = true
        // Implement sign in logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
        }
    }
}

// MARK: - Reusable Components
struct AuthHeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, value: true)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct SocialLoginSection: View {
    var body: some View {
        VStack(spacing: 16) {
            DividerWithText(text: "or continue with")
            
            HStack(spacing: 16) {
                SocialLoginButton(
                    provider: .google,
                    action: { print("Google login") }
                )
                
                SocialLoginButton(
                    provider: .apple,
                    action: { print("Apple login") }
                )
            }
        }
    }
}

struct SocialLoginButton: View {
    enum Provider {
        case google, apple
        
        var title: String {
            switch self {
            case .google: return "Google"
            case .apple: return "Apple"
            }
        }
        
        var icon: String {
            switch self {
            case .google: return "globe"
            case .apple: return "applelogo"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .google: return .white
            case .apple: return .black
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .google: return .black
            case .apple: return .white
            }
        }
    }
    
    let provider: Provider
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: provider.icon)
                    .font(.system(size: 16))
                
                Text(provider.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(provider.backgroundColor)
            .foregroundColor(provider.foregroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}
```

## 🎭 Loading States and Skeleton Screens

### 1. Comprehensive Loading System
Create `Views/Shared/LoadingStates.swift`:

```swift
import SwiftUI

// MARK: - Loading State Enum
enum LoadingState {
    case idle
    case loading
    case success
    case failure(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Loading View Modifier
struct LoadingViewModifier: ViewModifier {
    let isLoading: Bool
    let loadingText: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                LoadingOverlay(text: loadingText)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

extension View {
    func loading(_ isLoading: Bool, text: String = "Loading...") -> some View {
        modifier(LoadingViewModifier(isLoading: isLoading, loadingText: text))
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let text: String
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Skeleton Loading Components
struct AuthFormSkeleton: View {
    var body: some View {
        VStack(spacing: 24) {
            // Header Skeleton
            VStack(spacing: 12) {
                SkeletonView(height: 60, cornerRadius: 30)
                    .frame(width: 60)
                
                SkeletonView(height: 32, cornerRadius: 8)
                    .frame(width: 200)
                
                SkeletonView(height: 20, cornerRadius: 4)
                    .frame(width: 150)
            }
            
            // Form Fields Skeleton
            VStack(spacing: 20) {
                ForEach(0..<3) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(height: 16, cornerRadius: 4)
                            .frame(width: 80)
                        
                        SkeletonView(height: 56, cornerRadius: 12)
                    }
                }
            }
            
            // Button Skeleton
            SkeletonView(height: 50, cornerRadius: 12)
            
            // Social Login Skeleton
            HStack(spacing: 16) {
                SkeletonView(height: 44, cornerRadius: 8)
                SkeletonView(height: 44, cornerRadius: 8)
            }
        }
        .padding(.horizontal, 32)
    }
}
```

### 2. Enhanced Button States
Update the AnimatedButton to handle more states:

```swift
// Enhanced Animated Button with Multiple States
struct StatefulButton: View {
    let title: String
    let action: () -> Void
    let state: ButtonState
    let style: ButtonStyleType
    
    enum ButtonState {
        case idle
        case loading
        case success
        case failure
        
        var title: String {
            switch self {
            case .idle: return ""
            case .loading: return "Loading..."
            case .success: return "Success!"
            case .failure: return "Try Again"
            }
        }
    }
    
    enum ButtonStyleType {
        case primary, secondary, destructive
    }
    
    var body: some View {
        Button(action: performAction) {
            HStack {
                switch state {
                case .idle:
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.opacity.combined(with: .scale))
                    
                case .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.opacity.combined(with: .scale))
                    
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.scale.combined(with: .opacity))
                    
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.opacity.combined(with: .scale))
                    
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.scale.combined(with: .opacity))
                    
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold))
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColorForState)
            .foregroundColor(foregroundColorForState)
            .cornerRadius(12)
            .disabled(state == .loading)
        }
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var backgroundColorForState: Color {
        switch (style, state) {
        case (.primary, .success):
            return .green
        case (.primary, .failure):
            return .red
        case (.primary, _):
            return .blue
        case (.secondary, _):
            return .clear
        case (.destructive, _):
            return .red
        }
    }
    
    private var foregroundColorForState: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .blue
        }
    }
    
    private func performAction() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        action()
    }
}
```

## ♿ Accessibility and Inclusive Design

### 1. Accessibility Enhancements
Create `Extensions/AccessibilityExtensions.swift`:

```swift
import SwiftUI

// MARK: - Accessibility Helpers
extension View {
    func accessibleButton(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits([.isButton] + traits)
    }
    
    func accessibleTextField(
        label: String,
        value: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint ?? "")
    }
    
    func reduceMotionSensitive<T: View>(
        @ViewBuilder alternative: () -> T
    ) -> some View {
        Group {
            if UIAccessibility.isReduceMotionEnabled {
                alternative()
            } else {
                self
            }
        }
    }
}

// MARK: - High Contrast Support
struct HighContrastModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(
                UIAccessibility.isDarkerSystemColorsEnabled
                    ? (colorScheme == .dark ? .white : .black)
                    : nil
            )
    }
}

extension View {
    func highContrastSupport() -> some View {
        modifier(HighContrastModifier())
    }
}
```

### 2. Accessible Form Components
Update form components with accessibility:

```swift
// Accessible Animated TextField
struct AccessibleAnimatedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let validator: FieldValidator?
    
    @State private var isFocused = false
    @State private var showPassword = false
    @State private var validationResult: ValidationResult?
    @FocusState private var fieldIsFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AnimatedTextField(
                title: title,
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure && !showPassword,
                keyboardType: keyboardType
            )
            .accessibleTextField(
                label: title,
                value: text.isEmpty ? "Empty" : "Filled",
                hint: validationResult?.errorMessage ?? "Enter your \(title.lowercased())"
            )
            .onChange(of: text) { newValue in
                if let validator = validator {
                    validationResult = validator.validate(newValue)
                }
            }
            
            // Error message with accessibility
            if let error = validationResult?.errorMessage, !validationResult!.isValid {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityLabel("Error: \(error)")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}
```

## 🧪 Testing UI Components

### 1. SwiftUI Previews for Different States
```swift
// Comprehensive Preview Provider
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state
            ResponsiveLoginView()
                .previewDisplayName("Default")
            
            // Loading state
            ResponsiveLoginView()
                .loading(true, text: "Signing in...")
                .previewDisplayName("Loading")
            
            // Dark mode
            ResponsiveLoginView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Large text
            ResponsiveLoginView()
                .environment(\.sizeCategory, .accessibilityExtraLarge)
                .previewDisplayName("Large Text")
            
            // Different device sizes
            ResponsiveLoginView()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("Compact")
            
            ResponsiveLoginView()
                .previewDevice("iPad Air (5th generation)")
                .previewDisplayName("Regular")
            
            // Skeleton loading
            AuthFormSkeleton()
                .previewDisplayName("Skeleton Loading")
            
            // Error state
            ResponsiveLoginView()
                .previewDisplayName("Error State")
        }
    }
}
```

## 📚 Design System Documentation

### 1. Design Tokens
Create `DesignSystem/Tokens.swift`:

```swift
import SwiftUI

// MARK: - Design Tokens
struct DesignTokens {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.blue
        static let secondary = Color(.systemGray)
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        static let background = Color(.systemBackground)
        static let surface = Color(.systemGray6)
        static let onPrimary = Color.white
        static let onBackground = Color(.label)
    }
    
    // MARK: - Typography
    struct Typography {
        static let title1 = Font.largeTitle.weight(.bold)
        static let title2 = Font.title.weight(.semibold)
        static let title3 = Font.title2.weight(.medium)
        static let body = Font.body
        static let caption = Font.caption
        static let button = Font.system(size: 16, weight: .semibold)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(
            color: .black.opacity(0.1),
            radius: 4,
            offset: CGSize(width: 0, height: 2)
        )
        
        static let medium = Shadow(
            color: .black.opacity(0.15),
            radius: 8,
            offset: CGSize(width: 0, height: 4)
        )
        
        static let large = Shadow(
            color: .black.opacity(0.2),
            radius: 16,
            offset: CGSize(width: 0, height: 8)
        )
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let offset: CGSize
}

extension View {
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.offset.width,
            y: shadow.offset.height
        )
    }
}
```

## 🎯 Performance Optimization

### 1. View Optimization Techniques
```swift
// Optimized List Performance
struct OptimizedAuthHistoryView: View {
    let authEvents: [AuthEvent]
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(authEvents) { event in
                AuthEventRow(event: event)
                    .id(event.id) // Stable identity for better performance
            }
        }
    }
}

// Efficient Image Loading
struct OptimizedProfileImage: View {
    let url: URL?
    let size: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                SkeletonView(height: size, cornerRadius: size / 2)
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
```

## 📚 Key Concepts Learned

1. **Advanced Animations**: Micro-interactions and smooth transitions
2. **Responsive Design**: Adaptive layouts for different screen sizes
3. **Loading States**: Comprehensive loading and skeleton screens
4. **Accessibility**: Inclusive design practices
5. **Performance**: Optimization techniques for smooth UI
6. **Design Systems**: Consistent styling and theming

## 🎯 Next Steps

In the next phase, we'll integrate these UI components with:
- Firebase Authentication
- Real-time validation
- Error handling from backend services
- User session management

---

**🎉 Outstanding Work!** You've built a comprehensive, accessible, and beautiful authentication UI system that follows iOS design principles and provides excellent user experience across all devices.

import Foundation
import SwiftUI
import Firebase
import GoogleSignIn

@main
struct iOS_Auth_AppApp: App {
    @StateObject private var authenticationManager = AuthenticationManager.shared
    @StateObject private var appStateManager = AppStateManager()
    
    init() {
        configureFirebase()
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authenticationManager)
                .environmentObject(appStateManager)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    // Configure additional app setup
                    authenticationManager.configureAuthStateListener()
                }
        }
    }
    
    // MARK: - Configuration
    
    private func configureFirebase() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ Could not get CLIENT_ID from GoogleService-Info.plist")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    private func configureAppearance() {
        // Configure global app appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle URL schemes (deep links, Google Sign-In callback, etc.)
        print("📱 Handling incoming URL: \(url)")
        
        // Handle Google Sign-In URL
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        
        // Handle other URL schemes as needed
        // Custom deep link handling would go here
    }
}

// MARK: - App State Manager

class AppStateManager: ObservableObject {
    @Published var isActive = true
    @Published var backgroundTime: Date?
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isActive = false
            self.backgroundTime = Date()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isActive = true
            self.checkBackgroundTime()
        }
    }
    
    private func checkBackgroundTime() {
        guard let backgroundTime = backgroundTime else { return }
        
        let timeInBackground = Date().timeIntervalSince(backgroundTime)
        
        // If app was in background for more than 5 minutes, require re-authentication
        if timeInBackground > 300 {
            AuthenticationManager.shared.requireReAuthentication()
        }
        
        self.backgroundTime = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

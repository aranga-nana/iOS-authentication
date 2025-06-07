// iOSAuthAppApp.swift
// Main app entry point with Firebase and Google Sign-In configuration

import SwiftUI
import Firebase
import GoogleSignIn

@main
struct iOSAuthAppApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    init() {
        configureFirebase()
        configureGoogleSignIn()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    authManager.checkAuthenticationStatus()
                }
        }
    }
    
    private func configureFirebase() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let _ = NSDictionary(contentsOfFile: path) else {
            fatalError("GoogleService-Info.plist not found")
        }
        
        FirebaseApp.configure()
        
        #if DEBUG
        print("✅ Firebase configured successfully")
        #endif
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            fatalError("Failed to get CLIENT_ID from GoogleService-Info.plist")
        }
        
        guard let config = GIDConfiguration(clientID: clientId) else {
            fatalError("Failed to create Google Sign-In configuration")
        }
        
        GIDSignIn.sharedInstance.configuration = config
        
        #if DEBUG
        print("✅ Google Sign-In configured successfully")
        #endif
    }
}

// MARK: - App Delegate for additional configuration
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Additional app configuration if needed
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

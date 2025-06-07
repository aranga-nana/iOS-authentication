import ProjectDescription

let project = Project(
    name: "iOS-Auth-App",
    organizationName: "com.yourcompany.authapp",
    targets: [
        Target(
            name: "iOS-Auth-App",
            platform: .iOS,
            product: .app,
            bundleId: "com.yourcompany.authapp",
            deploymentTarget: .iOS(targetVersion: "15.0", devices: [.iphone, .ipad]),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchStoryboardName": "LaunchScreen",
                    "UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight"
                    ],
                    "NSFaceIDUsageDescription": "This app uses Face ID for secure authentication",
                    "NSCameraUsageDescription": "This app uses camera for profile picture uploads",
                    "NSPhotoLibraryUsageDescription": "This app accesses photo library for profile pictures",
                    "CFBundleURLTypes": [
                        [
                            "CFBundleURLName": "GoogleSignIn",
                            "CFBundleURLSchemes": ["$(REVERSED_CLIENT_ID)"]
                        ]
                    ]
                ]
            ),
            sources: ["App/**", "Models/**", "Services/**", "Views/**", "Utilities/**"],
            resources: [
                "Config.plist",
                "GoogleService-Info.plist",
                "Assets.xcassets"
            ],
            dependencies: [
                .external(name: "Firebase"),
                .external(name: "FirebaseAuth"),
                .external(name: "FirebaseAnalytics"),
                .external(name: "GoogleSignIn"),
                .external(name: "Alamofire")
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": "YOUR_TEAM_ID",
                    "CODE_SIGN_STYLE": "Automatic",
                    "SWIFT_VERSION": "5.0",
                    "IPHONEOS_DEPLOYMENT_TARGET": "15.0"
                ],
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release")
                ]
            )
        ),
        Target(
            name: "iOS-Auth-AppTests",
            platform: .iOS,
            product: .unitTests,
            bundleId: "com.yourcompany.authapp.tests",
            deploymentTarget: .iOS(targetVersion: "15.0", devices: [.iphone, .ipad]),
            infoPlist: .default,
            sources: ["Tests/**"],
            resources: [],
            dependencies: [
                .target(name: "iOS-Auth-App")
            ]
        )
    ],
    packages: [
        .remote(
            url: "https://github.com/firebase/firebase-ios-sdk",
            requirement: .upToNextMajor(from: "10.0.0")
        ),
        .remote(
            url: "https://github.com/google/GoogleSignIn-iOS",
            requirement: .upToNextMajor(from: "7.0.0")
        ),
        .remote(
            url: "https://github.com/Alamofire/Alamofire",
            requirement: .upToNextMajor(from: "5.6.0")
        )
    ]
)

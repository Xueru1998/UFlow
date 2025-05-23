import SwiftUI

@main
struct Medical_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isLoggedIn: Bool = false
    @State private var initialTab: CustomTabView.Tab? = nil
    
    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                // Pass the initialTab parameter to CustomTabView
                CustomTabView(initialTab: initialTab, isLoggedIn: $isLoggedIn)
                    .onAppear {
                        // Reset initialTab after it's been used
                        // This ensures it's only used on the first appearance
                        DispatchQueue.main.async {
                            initialTab = nil
                        }
                    }
            } else {
                // Pass both bindings to RegisterPageView
                LoginPageView(isLoggedIn: $isLoggedIn, appDelegate: appDelegate)
            }
        }
    }
    
    init() {
        // Check login state on app launch
        let isUserLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        let hasToken = UserDefaults.standard.string(forKey: "userToken") != nil
        
        // Only consider logged in if both flag is set AND token exists
        _isLoggedIn = State(initialValue: isUserLoggedIn && hasToken)
    }
}

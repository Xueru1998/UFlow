import SwiftUI

struct CustomTabView: View {
    // Make selectedTab a binding that can be set from outside
    @State private var selectedTab: Tab
    @Binding var isLoggedIn: Bool

    enum Tab {
        case dashboard
        case profile
    }
    
    // Initialize with optional initial tab
    init(initialTab: Tab? = nil, isLoggedIn: Binding<Bool>) {
        // Use the provided initial tab or default to dashboard
        _selectedTab = State(initialValue: initialTab ?? .dashboard)
        _isLoggedIn = isLoggedIn
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Health Dashboard Tab
            HealthDashboardView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Dashboard")
                }
                .tag(Tab.dashboard)

            // Profile Tab
            ProfileView(isLoggedIn: $isLoggedIn)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .accentColor(.purple) // Customize the selected tab color to match your UI
    }
}

// Preview
struct CustomTabView_Previews: PreviewProvider {
    @State static var isLoggedIn = true
    
    static var previews: some View {
        CustomTabView(isLoggedIn: $isLoggedIn)
    }
}

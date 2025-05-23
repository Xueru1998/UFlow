import SwiftUI
import HealthKit

struct ProfileView: View {
    @State private var avatarImage: UIImage? = nil
    @State private var userName: String = "Loading..."
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var firstname: String = ""
    @State private var lastname: String = ""
    @State private var phoneNumber: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = true
    @State private var healthKitAuthorized: Bool = false
    @State private var showLogoutConfirmation: Bool = false
    
    // Add binding to control app-wide login state
    @Binding var isLoggedIn: Bool
    
    // State to track if we need to retry loading
    @State private var shouldRetry: Bool = false
    @State private var retryCount: Int = 0
    
    // Health store instance
    let healthStore = HKHealthStore()
    
    var body: some View {
        ZStack {
            VStack {
                // Top bar with logout button
                HStack {
                    Spacer()
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.trailing)
                    .alert(isPresented: $showLogoutConfirmation) {
                        Alert(
                            title: Text("Log Out"),
                            message: Text("Are you sure you want to log out?"),
                            primaryButton: .destructive(Text("Log Out")) {
                                logoutUser()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                .padding(.top)
                
                Spacer(minLength: 20)
                
                // Avatar Image
                if isLoading {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                } else if let avatarImage = avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                }
                
                // User Name and Email
                Text(userName)
                    .font(.title)
                    .bold()
                    .foregroundColor(Color.blue)
                    .padding(.top, 10)
                
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Divider for spacing
                Divider()
                    .padding(.vertical, 20)
                
                // Show loading indicator instead of empty data
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading profile data...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    // Profile Details Section
                    VStack(alignment: .leading, spacing: 15) {
                        if !phoneNumber.isEmpty {
                            profileDetailRow(icon: "phone.fill", title: "Mobile Number", value: phoneNumber)
                        }
                        profileDetailRow(icon: "person.fill", title: "Username", value: username)
                        
                        // Health Data Integration Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Health Data Integration")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.top, 20)
                            
                            HStack {
                                Image(systemName: healthKitAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(healthKitAuthorized ? .green : .red)
                                    .font(.title2)
                                
                                Text(healthKitAuthorized ? "Health Data Access Enabled" : "Health Data Access Disabled")
                                    .font(.body)
                                    .foregroundColor(healthKitAuthorized ? .green : .red)
                            }
                            .padding(.vertical, 5)
                            
                            if !healthKitAuthorized {
                                Button(action: {
                                    requestHealthKitAuthorization()
                                }) {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                        Text("Enable Health Data Access")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 5)
                            } else {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Health data will be synchronized with your account")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 5)
                            }
                            
                            // Direct Open Health App button instead of settings sheet
                            Button(action: {
                                if let url = URL(string: "x-apple-health://") {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Manage Health Data Settings")
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Error message and retry button if needed
                if let errorMessage = errorMessage {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button(action: {
                            retryLoadProfile()
                        }) {
                            Text("Retry")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            .onAppear {
                // Check if token exists, if not wait briefly and retry
                if UserDefaults.standard.string(forKey: "userToken") == nil {
                    print("Token not found on first attempt, will retry shortly...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        fetchUserProfileAndAvatar()
                    }
                } else {
                    fetchUserProfileAndAvatar()
                }
                
                // Check current HealthKit authorization status
                checkHealthKitAuthorizationStatus()
            }
            .onChange(of: shouldRetry) { newValue in
                if newValue && retryCount < 3 {
                    fetchUserProfileAndAvatar()
                }
            }
        }
    }
    
    // Function to logout user
    func logoutUser() {
        // Clear token and user data
        UserDefaults.standard.removeObject(forKey: "userToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        
        // If you're using KeychainHelper, add this too
        if let keychainTokenKey = Bundle.main.bundleIdentifier {
            // Uncomment if you're using KeychainHelper
            // KeychainHelper.deleteToken(service: keychainTokenKey)
        }
        
        // Reset user state
        avatarImage = nil
        userName = "Loading..."
        email = ""
        username = ""
        phoneNumber = ""
        
        // Update app login state to trigger navigation to login screen
        isLoggedIn = false
    }
    
    // Function to retry loading profile
    func retryLoadProfile() {
        retryCount += 1
        isLoading = true
        errorMessage = nil
        shouldRetry = true
    }
    
    // Function to fetch user profile and avatar
    func fetchUserProfileAndAvatar() {
        isLoading = true
        shouldRetry = false
        
        // Debug: Check if token exists
        if let token = UserDefaults.standard.string(forKey: "userToken") {
            print("Token found: \(token.prefix(10))...")
        } else {
            print("No token found in UserDefaults!")
        }
        
        APIService.shared.getUserProfile { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let userProfile):
                    self.userName = "\(userProfile.firstname) \(userProfile.lastname)"
                    self.email = userProfile.email
                    self.username = userProfile.username
                    self.firstname = userProfile.firstname
                    self.lastname = userProfile.lastname
                    self.phoneNumber = userProfile.telephone ?? ""
                    self.errorMessage = nil
                    
                    // Decode the Base64 avatar
                    if let avatarBase64 = userProfile.avatar, let avatarData = Data(base64Encoded: avatarBase64) {
                        self.avatarImage = UIImage(data: avatarData)
                    } else {
                        self.avatarImage = nil // No avatar available
                    }
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    // If error is "no token found" and we haven't retried too many times
                    if error.localizedDescription.contains("No token found") && self.retryCount < 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.retryCount += 1
                            self.fetchUserProfileAndAvatar() // Retry after a delay
                        }
                    }
                }
            }
        }
    }
    
    // Check current HealthKit authorization status
    func checkHealthKitAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitAuthorized = false
            return
        }
        
        // Create a set of the health data types we want to check authorization for
        let healthDataTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        // Use empty set for toShare parameter instead of nil
        healthStore.getRequestStatusForAuthorization(toShare: Set<HKSampleType>(), read: healthDataTypes) { status, error in
            DispatchQueue.main.async {
                if status == .unnecessary {
                    // Already authorized
                    self.healthKitAuthorized = true
                } else {
                    // Not authorized or partially authorized
                    self.healthKitAuthorized = false
                }
            }
        }
    }
    
    // Request HealthKit authorization
    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Device doesn't support HealthKit
            return
        }
        
        // Types to read (read from HealthKit)
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            
            // Exercise, Workouts
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKQuantityType.workoutType(),
            
            // Heart Rate and related metrics
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            
            // Wrist Temperature (instead of body temperature)
            HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
            
            // Sleep Analysis (Detailed stages)
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]
        
        // Request authorization to read data only
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization successful")
                    self.healthKitAuthorized = true
                    
                    // Notify to sync the newly authorized health data
                    NotificationCenter.default.post(name: NSNotification.Name("HealthKitAuthorizationChanged"), object: nil)
                } else {
                    print("HealthKit authorization failed: \(String(describing: error?.localizedDescription))")
                    self.healthKitAuthorized = false
                }
            }
        }
    }
    
    // Reusable row for displaying profile details
    func profileDetailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.blue.opacity(0.8))
            Text("\(title):")
                .font(.body)
                .bold()
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
}

// Preview helper that doesn't require binding
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a constant binding for preview
        ProfileView(isLoggedIn: .constant(true))
    }
}

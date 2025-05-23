import SwiftUI
import HealthKit
import Security

struct LoginPageView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var showResetPassword = false
    @State private var isHealthKitAuthorized = false
    @State private var showHealthDashboard = false
    
    // This is the Binding that is passed from the parent to control the login state
    @Binding var isLoggedIn: Bool
    @Binding var initialTab: CustomTabView.Tab?
    var appDelegate: AppDelegate
    
    let healthStore = HKHealthStore()
    
    // For compatibility with code that doesn't yet pass initialTab
    init(isLoggedIn: Binding<Bool>, appDelegate: AppDelegate) {
        self._isLoggedIn = isLoggedIn
        self._initialTab = .constant(nil)
        self.appDelegate = appDelegate
    }
    
    // New initializer that accepts initialTab
    init(isLoggedIn: Binding<Bool>, initialTab: Binding<CustomTabView.Tab?>, appDelegate: AppDelegate) {
        self._isLoggedIn = isLoggedIn
        self._initialTab = initialTab
        self.appDelegate = appDelegate
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.6)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                            TextField("Enter email", text: $email)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white)
                            SecureField("Password", text: $password)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Sign In Button
                    Button(action: loginUser) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    // Forgot password link
                    Button(action: {
                        showResetPassword.toggle()
                    }) {
                        Text("Forgot Password?")
                            .foregroundColor(.white)
                    }
                    .sheet(isPresented: $showResetPassword) {
                        ResetPasswordView()
                    }
                    
                    // Fixed NavigationLink with correct parameter order
                    NavigationLink(destination: RegisterPageView(
                        isLoggedIn: $isLoggedIn,
                        initialTab: $initialTab,
                        appDelegate: appDelegate
                    )) {
                        Text("Don't have an account? Sign up")
                            .foregroundColor(.white)
                            .underline()
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showHealthDashboard, content: {
                HealthDashboardView()
            })
        }
        .onAppear(perform: checkLoginState)  // Check login state when the view appears
    }
    
    func loginUser() {
        APIService.shared.login(email: email, password: password) { result in
            switch result {
            case .success(let loginResponse):  // Assuming 'loginResponse' is of type 'LoginResponse'
                print("Login successful")
                errorMessage = nil
                // Extract the token from the loginResponse object
                let token = loginResponse.token  // Ensure 'LoginResponse' has a 'token' property
                
                // Save login state and token
                isLoggedIn = true
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                KeychainHelper.saveToken(token: token)  // Pass the token string to KeychainHelper
                
                // Request HealthKit access after login
                requestHealthKitAuthorization()
                
            case .failure(let error):
                print("Login failed: \(error.localizedDescription)")
                errorMessage = "Login failed. Please check your credentials."
            }
        }
    }

    func checkLoginState() {
        // Check if the user is already logged in
        if let token = KeychainHelper.getToken(), UserDefaults.standard.bool(forKey: "isLoggedIn") {
            // If the token exists and the user is logged in, skip to the dashboard
            print("User already logged in")
            isLoggedIn = true
            initialTab = .dashboard
        }
    }
    
    func requestHealthKitAuthorization() {
        if HKHealthStore.isHealthDataAvailable() {
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
                        self.isHealthKitAuthorized = true
                        
                        // Set initial tab to dashboard
                        self.initialTab = .dashboard
                        
                        // Trigger data sync
                        self.appDelegate.fetchLatestHealthData { success in
                            if success {
                                print("Health data synced immediately after login")
                            } else {
                                print("Failed to sync health data after login")
                            }
                        }
                    } else {
                        print("HealthKit authorization failed: \(String(describing: error?.localizedDescription))")
                        self.isHealthKitAuthorized = false
                    }
                }
            }
        }
    }
}

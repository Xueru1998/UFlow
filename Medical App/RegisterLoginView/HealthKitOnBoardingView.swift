import SwiftUI
import HealthKit

enum OnboardingCompletion {
    case showDashboard    // Show the HealthDashboardView
    case showMainContent  // Show the CustomTabView or other main content
}

struct HealthKitOnboardingView: View {
    // Instead of a simple binding, we'll use a completion handler
    var onComplete: (OnboardingCompletion) -> Void
    
    @State private var isHealthKitAuthorized = false
    @State private var showSkipAlert = false
    @State private var isLoading = false
    @State private var showSuccess = false
    
    let healthStore = HKHealthStore()
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: showSuccess ? "checkmark.circle.fill" : "heart.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundColor(showSuccess ? .green : .red)
                    .padding()
                    .animation(.spring(), value: showSuccess)
                
                Text(showSuccess ? "Successfully Connected!" : "Connect Health Data")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                    .animation(.spring(), value: showSuccess)
                
                if !showSuccess {
                    Text("Track your health and wellness journey by connecting to your device's health data")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        benefitRow(icon: "heart.fill", text: "Monitor your heart rate trends")
                        benefitRow(icon: "figure.walk", text: "Track your daily activity and steps")
                        benefitRow(icon: "bed.double.fill", text: "Analyze your sleep patterns")
                        benefitRow(icon: "waveform.path.ecg", text: "Get personalized health insights")
                    }
                    .padding(.vertical, 20)
                } else {
                    Text("Your device's health data is now connected and will be synchronized.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                
                if !showSuccess {
                    Button(action: {
                        isLoading = true
                        requestHealthKitAuthorization()
                    }) {
                        ZStack {
                            Text("Connect Health Data")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .opacity(isLoading ? 0 : 1)
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                    
                    Button(action: {
                        showSkipAlert = true
                    }) {
                        Text("Skip for now")
                            .foregroundColor(.gray)
                            .underline()
                    }
                    .padding(.top, 10)
                    .disabled(isLoading)
                    .alert(isPresented: $showSkipAlert) {
                        Alert(
                            title: Text("Skip Health Integration?"),
                            message: Text("You can enable health data integration later in your profile settings."),
                            primaryButton: .default(Text("Go Back")),
                            secondaryButton: .destructive(Text("Skip")) {
                                // Navigate to dashboard
                                onComplete(.showDashboard)
                            }
                        )
                    }
                } else {
                    Button(action: {
                        // Navigate to dashboard
                        onComplete(.showDashboard)
                    }) {
                        Text("Continue to Dashboard")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .opacity(isLoading && !showSuccess ? 0.7 : 1)
        }
    }
    
    func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
    
    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Device doesn't support HealthKit
            DispatchQueue.main.async {
                isLoading = false
                onComplete(.showDashboard)
            }
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
                isLoading = false
                
                if success {
                    print("HealthKit authorization successful")
                    self.isHealthKitAuthorized = true
                    
                    // Show success state before proceeding
                    withAnimation {
                        self.showSuccess = true
                    }
                    
                    // Post notification to sync health data
                    NotificationCenter.default.post(name: NSNotification.Name("HealthKitAuthorizationChanged"), object: nil)
                } else {
                    print("HealthKit authorization failed: \(String(describing: error?.localizedDescription))")
                    
                    // Even if authorization fails, we'll navigate to dashboard
                    onComplete(.showDashboard)
                }
            }
        }
    }
}

import SwiftUI

struct RegisterPageView: View {
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var firstname: String = ""
    @State private var lastname: String = ""
    @State private var verificationCodeSent = false
    @State private var verificationCode = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var showHealthOnboarding = false
    
    // Bindings
    @Binding var isLoggedIn: Bool
    @Binding var initialTab: CustomTabView.Tab?
    
    var appDelegate: AppDelegate?

    // Updated initializer with consistent parameter order
    init(isLoggedIn: Binding<Bool>, initialTab: Binding<CustomTabView.Tab?>, appDelegate: AppDelegate?) {
        self._isLoggedIn = isLoggedIn
        self._initialTab = initialTab
        self.appDelegate = appDelegate
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.6)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "person.crop.circle.fill.badge.plus")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                        TextField("Enter username", text: $username)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)

                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.white)
                        TextField("Enter email", text: $email)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                        TextField("Enter firstname", text: $firstname)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                        TextField("Enter lastname", text: $lastname)
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

                    if verificationCodeSent {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            TextField("Enter verification code", text: $verificationCode)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)

                Button(action: {
                    if verificationCodeSent {
                        verifyAndRegisterUser()
                    } else {
                        sendVerificationCode()
                    }
                }) {
                    // Display a loading indicator when appropriate
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    } else {
                        Text(verificationCodeSent ? "Verify & Register" : "Send Verification Code")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading)

                if let appDelegate = appDelegate {
                    NavigationLink(destination: LoginPageView(isLoggedIn: $isLoggedIn, initialTab: $initialTab, appDelegate: appDelegate)) {
                        Text("Already have an account? Log in here")
                            .foregroundColor(.white)
                            .underline()
                    }
                } else {
                    Text("App delegate is not available.")
                }

                Spacer()
            }
            .fullScreenCover(isPresented: $showHealthOnboarding) {
                // When the health onboarding cover is dismissed, we'll already be logged in
                // so we don't need to do anything here
            } content: {
                // Use the completion handler version for better control
                HealthKitOnboardingView { result in
                    // Dismiss the health onboarding screen
                    showHealthOnboarding = false
                    
                    switch result {
                    case .showDashboard:
                        // Set the initial tab to dashboard and log in
                        initialTab = .dashboard
                        isLoggedIn = true
                    case .showMainContent:
                        // Just set the logged in state to true
                        isLoggedIn = true
                    }
                }
            }
        }
    }

    func sendVerificationCode() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        APIService.shared.sendVerificationCode(email: email, username: username, password: password, firstname: firstname, lastname: lastname) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    verificationCodeSent = true
                    errorMessage = nil
                case .failure(let error):
                    print("Failed to send verification code: \(error)")
                    errorMessage = "Failed to send verification code: \(error.localizedDescription)"
                }
            }
        }
    }

    func verifyAndRegisterUser() {
        guard !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Use the updated method that properly handles token
        APIService.shared.verifyEmailAndRegister(
            email: email,
            verificationCode: verificationCode,
            username: username,
            password: password,
            firstname: firstname,
            lastname: lastname
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    print("Verification and registration successful")
                    print("Token: \(response.token)")
                    print("UserID: \(response.userId)")
                    
                    // Double-check token is saved
                    if UserDefaults.standard.string(forKey: "userToken") == nil {
                        print("WARNING: Token wasn't saved properly! Forcing save...")
                        UserDefaults.standard.setValue(response.token, forKey: "userToken")
                        UserDefaults.standard.setValue(response.userId, forKey: "userId")
                        UserDefaults.standard.synchronize()
                    }
                    
                    errorMessage = nil
                    
                    // Show health onboarding
                    showHealthOnboarding = true
                    
                case .failure(let error):
                    print("Failed to verify and register: \(error.localizedDescription)")
                    errorMessage = "Verification failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct RegisterPageView_Previews: PreviewProvider {
    @State static var isLoggedIn = false
    @State static var initialTab: CustomTabView.Tab? = nil

    static var previews: some View {
        RegisterPageView(
            isLoggedIn: $isLoggedIn,
            initialTab: $initialTab,
            appDelegate: nil
        )
    }
}

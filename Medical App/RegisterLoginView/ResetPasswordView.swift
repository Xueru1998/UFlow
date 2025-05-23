import SwiftUI

struct ResetPasswordView: View {
    @State private var email: String = ""
    @State private var resetMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Reset Password")
                .font(.title)
                .padding()

            TextField("Enter your email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                sendPasswordResetEmail()
            }) {
                Text("Send Reset Email")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }

            if let resetMessage = resetMessage {
                Text(resetMessage)
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer()
        }
        .padding()
    }

    func sendPasswordResetEmail() {
        APIService.shared.sendPasswordResetEmail(email: email) { result in
            switch result {
            case .success:
                resetMessage = "Reset email sent! Please check your inbox."
            case .failure(let error):
                resetMessage = "Failed to send reset email."
                print("Error: \(error)")
            }
        }
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
    }
}

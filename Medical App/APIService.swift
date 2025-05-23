import Foundation
import UIKit

struct RegistrationResponse: Codable {
    let message: String
    let token: String
    let userId: String
}



class APIService {
    static let shared = APIService() // Singleton instance for global access

    // Login
    func login(email: String, password: String, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        guard let url = URL(string: "\(API.baseURL)/auth/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userData = ["login": email, "password": password]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: userData, options: [])
        } catch {
            print("Failed to encode JSON")
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("No data returned")
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
                return
            }

            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                // Save the token and userId in UserDefaults
                UserDefaults.standard.setValue(loginResponse.token, forKey: "userToken")
                UserDefaults.standard.setValue(loginResponse.userId, forKey: "userId")
                completion(.success(loginResponse))
            } catch {
                print("Failed to decode response")
                completion(.failure(error))
            }
        }.resume()
    }

    
    
    // Register (Sending Verification Code)
    func sendVerificationCode(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(API.baseURL)/auth/send-verification-code") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userData = ["email": email]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: userData, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }.resume()
    }

    // Register (Sending Verification Code)
    func sendVerificationCode(email: String, username: String, password: String, firstname: String, lastname: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(API.baseURL)/auth/send-verification-code") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userData: [String: Any] = [
            "email": email,
            "username": username,
            "password": password,
            "firstname": firstname,
            "lastname": lastname
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: userData, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }.resume()
    }
    


        // Verify Email and Register
    func verifyEmailAndRegister(email: String, verificationCode: String, username: String, password: String, firstname: String, lastname: String, completion: @escaping (Result<RegistrationResponse, Error>) -> Void) {
            guard let url = URL(string: "\(API.baseURL)/auth/verify-email-and-register") else {
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Include all required parameters
            let verificationData: [String: Any] = [
                "email": email,
                "verificationCode": verificationCode,
                "username": username,
                "password": password,
                "firstname": firstname,
                "lastname": lastname
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: verificationData, options: [])
            } catch {
                completion(.failure(error))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                    
                    // Log the raw response for debugging
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response data: \(responseString)")
                    }
                    
                    if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                        // Parse error message if available
                        if let data = data, let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = errorObj["message"] as? String {
                            let error = NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                            completion(.failure(error))
                            return
                        } else {
                            let error = NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Registration failed"])
                            completion(.failure(error))
                            return
                        }
                    }
                }
                
                // Parse the response
                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    // Try to decode the response as a structured object
                    let response = try JSONDecoder().decode(RegistrationResponse.self, from: data)
                    
                    // Save the token and userId immediately to UserDefaults
                    UserDefaults.standard.setValue(response.token, forKey: "userToken")
                    UserDefaults.standard.setValue(response.userId, forKey: "userId")
                    UserDefaults.standard.synchronize() // Force synchronization
                    
                    completion(.success(response))
                } catch {
                    print("Failed to decode registration response: \(error)")
                    
                    // Fallback: Try to manually extract the token and userId from the JSON
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let token = json["token"] as? String,
                           let userId = json["userId"] as? String {
                            
                            // Save to UserDefaults
                            UserDefaults.standard.setValue(token, forKey: "userToken")
                            UserDefaults.standard.setValue(userId, forKey: "userId")
                            UserDefaults.standard.synchronize()
                            
                            let manualResponse = RegistrationResponse(
                                message: json["message"] as? String ?? "Registration successful",
                                token: token,
                                userId: userId
                            )
                            
                            completion(.success(manualResponse))
                        } else {
                            completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            }.resume()
        }

    // Send Password Reset Email
    func sendPasswordResetEmail(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(API.baseURL)/auth/send-password-reset-email") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userData = ["email": email]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: userData, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }.resume()
    }
    
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: "userToken")
    }

    func getUserProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        guard let token = getToken() else {
            print("⚠️ No token found in UserDefaults")
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "No token found. User must be logged in."])))
            return
        }
        
        // Print partial token for debugging (never log the full token)
        if token.count > 10 {
            let tokenPrefix = String(token.prefix(10))
            print("🔑 Using token: \(tokenPrefix)...")
        }
        
        guard let url = URL(string: "\(API.baseURL)/users/me") else {
            completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("📡 Making request to: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept") // Explicitly request JSON
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status Code: \(httpResponse.statusCode)")
                
                // Check for authentication errors
                if httpResponse.statusCode == 401 {
                    print("🔒 Authentication error: Invalid or expired token")
                    completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please login again."])))
                    return
                }
                
                // Check for other error status codes
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    print("❌ HTTP error: \(httpResponse.statusCode)")
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error code \(httpResponse.statusCode)"])))
                    return
                }
            }
            
            // Ensure data exists
            guard let data = data else {
                print("⚠️ No data returned from server")
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "No data returned from server"])))
                return
            }
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw JSON Response: \(jsonString)")
            }
            
            // Try different parsing strategies
            do {
                // Strategy 1: Try parsing as UserProfile directly
                let decoder = JSONDecoder()
                let userProfile = try decoder.decode(UserProfile.self, from: data)
                print("✅ Successfully decoded user profile for: \(userProfile.username)")
                completion(.success(userProfile))
                return
            } catch {
                print("⚠️ Initial UserProfile decoding failed: \(error)")
                
                // Strategy 2: Try to see if the profile is nested under a 'user' or other key
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        // Check for common response wrappers
                        let possibleWrappers = ["user", "data", "profile", "result", "response"]
                        
                        for wrapper in possibleWrappers {
                            if let nestedUser = json[wrapper] as? [String: Any] {
                                print("📦 Found user data nested under '\(wrapper)' key")
                                
                                if let nestedData = try? JSONSerialization.data(withJSONObject: nestedUser, options: []) {
                                    do {
                                        let userProfile = try JSONDecoder().decode(UserProfile.self, from: nestedData)
                                        print("✅ Successfully decoded nested user profile")
                                        completion(.success(userProfile))
                                        return
                                    } catch {
                                        print("⚠️ Failed to decode nested user data: \(error)")
                                    }
                                }
                            }
                        }
                        
                        // Strategy 3: Try to manually construct UserProfile from JSON
                        let id = json["_id"] as? String ?? json["id"] as? String ?? "unknown"
                        let email = json["email"] as? String ?? ""
                        let username = json["username"] as? String ?? ""
                        let firstname = json["firstname"] as? String ?? json["firstName"] as? String ?? ""
                        let lastname = json["lastname"] as? String ?? json["lastName"] as? String ?? ""
                        
                        let profile = UserProfile(
                            id: id,
                            email: email,
                            username: username,
                            firstname: firstname,
                            lastname: lastname,
                            isAdmin: json["isAdmin"] as? Bool,
                            avatar: json["avatar"] as? String,
                            avatarContentType: json["avatarContentType"] as? String,
                            place: json["place"] as? String,
                            street: json["street"] as? String,
                            telephone: json["telephone"] as? String ?? json["phone"] as? String,
                            isVerified: json["isVerified"] as? Bool,
                            createdAt: json["createdAt"] as? String,
                            notes: nil,  // Simplified for fallback
                            notificationAssignedAt: nil
                        )
                        
                        print("✅ Manually constructed user profile")
                        completion(.success(profile))
                        return
                    }
                } catch {
                    print("❌ JSON parsing error: \(error)")
                }
                
                completion(.failure(NSError(domain: "", code: 422, userInfo: [NSLocalizedDescriptionKey: "Could not parse user profile data. Please try again later."])))
            }
        }.resume()
    }
    
    func fetchAvatar(userId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let token = getToken() else {
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "No token found. User must be logged in."])))
            return
        }

        guard let url = URL(string: "\(API.baseURL)\(userId)/avatar") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Fetch avatar as binary data
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])))
                return
            }

            completion(.success(image))
        }.resume()
    }
    
    func syncHealthData(_ healthData: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔄 Syncing health data to backend...")

        // ✅ Ensure a valid token is present
        guard let token = getToken() else {
            let errorMessage = "No token found. User must be logged in."
            print("❌ \(errorMessage)")
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }

        // ✅ Retrieve userId from UserDefaults
        guard let userId = UserDefaults.standard.string(forKey: "userId") else {
            let errorMessage = "No userId found in UserDefaults"
            print("❌ \(errorMessage)")
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }

        // ✅ Ensure the API base URL is properly formatted
        let endpoint = "healthdata/save"  // Ensure no leading "/"
        let fullURL = "\(API.baseURL)/\(endpoint)".trimmingCharacters(in: .whitespacesAndNewlines)

        // ✅ Ensure URL is valid
        guard let url = URL(string: fullURL) else {
            completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }


        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // ✅ Attach userId to health data
        var healthDataWithUserId = healthData
        healthDataWithUserId["userId"] = userId

        // ✅ Debug: Print JSON payload before sending
        do {
            let requestData = try JSONSerialization.data(withJSONObject: healthDataWithUserId, options: .prettyPrinted)
            if let jsonString = String(data: requestData, encoding: .utf8) {
               
            }
            request.httpBody = requestData
        } catch {
            print("❌ Failed to serialize health data: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        // ✅ Make the network request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // ✅ Check for network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // ✅ Debug: Print raw server response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response Status Code: \(httpResponse.statusCode)")
            }

            // ✅ Ensure response is valid
            guard let httpResponse = response as? HTTPURLResponse, let responseData = data else {
                print("❌ Invalid response from server")
                completion(.failure(NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }

            // ✅ Handle non-200 status codes properly
            if httpResponse.statusCode != 200 {
                let responseString = String(data: responseData, encoding: .utf8) ?? "No response body"
                print("❌ Server error: \(httpResponse.statusCode) - \(responseString)")
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: responseString])))
                return
            }

            // ✅ Debug: Print successful response
            let responseString = String(data: responseData, encoding: .utf8) ?? "No response body"
            print("✅ Health data synced successfully: \(responseString)")
            completion(.success(()))
        }
        
        task.resume()
    }



      

}

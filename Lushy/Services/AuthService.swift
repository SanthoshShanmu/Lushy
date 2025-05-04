import Foundation

class AuthService {
    static let shared = AuthService()
    
    private let tokenKey = "authToken"
    private let userIdKey = "userId"
    
    var token: String? {
        get {
            let token = UserDefaults.standard.string(forKey: tokenKey)
            print("Getting token: \(token ?? "nil")")
            return token
        }
        set {
            print("Setting token: \(newValue ?? "nil")")
            UserDefaults.standard.set(newValue, forKey: tokenKey)
        }
    }
    
    var userId: String? {
        get { UserDefaults.standard.string(forKey: userIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: userIdKey) }
    }
    
    var isLoggedIn: Bool {
        return token != nil
    }
    
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // Create the login request
        guard let url = URL(string: "http://localhost:5001/api/auth/login") else {
            completion(false, "Invalid URL")
            return
        }
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create credentials JSON
        let credentials = ["email": email, "password": password]
        guard let jsonData = try? JSONEncoder().encode(credentials) else {
            completion(false, "Failed to encode credentials")
            return
        }
        request.httpBody = jsonData
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Handle response
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            guard let data = data else {
                completion(false, "No data received")
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String,
                   let userId = json["userId"] as? String {
                    
                    // Store token and user ID
                    self?.token = token
                    self?.userId = userId
                    
                    print("Login successful, token received")
                    completion(true, nil)
                } else {
                    // Failed to get token
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        completion(false, message)
                    } else {
                        completion(false, "Invalid response format")
                    }
                }
            } catch {
                completion(false, "Failed to parse response: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func register(name: String, email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // Create the registration request
        guard let url = URL(string: "http://localhost:5001/api/auth/signup") else {
            completion(false, "Invalid URL")
            return
        }
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create user data JSON
        let userData = ["name": name, "email": email, "password": password]
        guard let jsonData = try? JSONEncoder().encode(userData) else {
            completion(false, "Failed to encode user data")
            return
        }
        request.httpBody = jsonData
        
        // Make request
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            guard let data = data else {
                completion(false, "No data received")
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    completion(true, nil)
                } else {
                    // Registration failed
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        completion(false, message)
                    } else {
                        completion(false, "Registration failed")
                    }
                }
            } catch {
                completion(false, "Failed to parse response: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func logout() {
        token = nil
        userId = nil
    }
}

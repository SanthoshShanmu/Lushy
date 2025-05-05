import Foundation
import Combine
import KeychainSwift

class AuthService {
    static let shared = AuthService()
    
    private let keychain = KeychainSwift()
    private let tokenKey = "lushy_auth_token"
    private let userIdKey = "lushy_user_id"
    
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    
    var cancellables = Set<AnyCancellable>()
    
    var token: String? {
        get { keychain.get(tokenKey) }
        set {
            if let newValue = newValue {
                keychain.set(newValue, forKey: tokenKey)
                isAuthenticated = true
            } else {
                keychain.delete(tokenKey)
                isAuthenticated = false
            }
        }
    }
    
    var userId: String? {
        get { keychain.get(userIdKey) }
        set {
            if let newValue = newValue {
                keychain.set(newValue, forKey: userIdKey)
                currentUserId = newValue
            } else {
                keychain.delete(userIdKey)
                currentUserId = nil
            }
        }
    }
    
    private init() {
        // Check if user is already authenticated
        if let _ = keychain.get(tokenKey), 
           let userId = keychain.get(userIdKey) {
            self.isAuthenticated = true
            self.currentUserId = userId
        }
    }
    
    func register(name: String, email: String, password: String) -> AnyPublisher<Bool, Error> {
        let url = URL(string: "http://localhost:5001/api/auth/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": name, "email": email, "password": password, "passwordConfirm": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .map { response in
                self.token = response.token
                self.userId = response.userId
                return true
            }
            .eraseToAnyPublisher()
    }
    
    func login(email: String, password: String) -> AnyPublisher<Bool, Error> {
        let url = URL(string: "http://localhost:5001/api/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .map { response in
                self.token = response.token
                self.userId = response.userId
                return true
            }
            .eraseToAnyPublisher()
    }
    
    func logout() {
        token = nil
        userId = nil
    }
}

// Response model for auth endpoints
struct AuthResponse: Codable {
    let status: String
    let token: String
    let userId: String
    let data: AuthUserData
    
    struct AuthUserData: Codable {
        let user: User
    }
    
    struct User: Codable {
        // The backend sends _id, not id
        let _id: String
        let name: String
        let email: String
        
        // Use CodingKeys to map _id to id if you prefer to use "id" in your Swift code
        enum CodingKeys: String, CodingKey {
            case _id = "_id"  // This maps the JSON field "_id" to the Swift property "_id"
            case name
            case email
        }
    }
}

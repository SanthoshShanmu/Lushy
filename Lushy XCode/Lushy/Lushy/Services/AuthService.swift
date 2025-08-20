import Foundation
import Combine

class AuthService {
    static let shared = AuthService()
    
    // Replaced Keychain with UserDefaults storage
    private let defaults = UserDefaults.standard
    private let tokenKey = "lushy_auth_token"
    private let userIdKey = "lushy_user_id"
    
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    
    var cancellables = Set<AnyCancellable>()
    
    var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: tokenKey)
                isAuthenticated = true
            } else {
                defaults.removeObject(forKey: tokenKey)
                isAuthenticated = false
            }
        }
    }
    
    var userId: String? {
        get { defaults.string(forKey: userIdKey) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: userIdKey)
                currentUserId = value
            } else {
                defaults.removeObject(forKey: userIdKey)
                currentUserId = nil
            }
        }
    }
    
    private init() {
        if let storedToken = defaults.string(forKey: tokenKey),
           let storedUserId = defaults.string(forKey: userIdKey) {
            token = storedToken
            userId = storedUserId
            isAuthenticated = true
            currentUserId = storedUserId
        }
    }
    
    func register(name: String, username: String, email: String, password: String) -> AnyPublisher<Bool, Error> {
        let url = URL(string: "http://localhost:5001/api/auth/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "name": name,
            "username": username,
            "email": email,
            "password": password,
            "passwordConfirm": password
        ]
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
    
    func login(identifier: String, password: String) -> AnyPublisher<Bool, Error> {
        let url = URL(string: "http://localhost:5001/api/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["identifier": identifier, "password": password]
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
    
    func checkUsernameAvailability(username: String) -> AnyPublisher<Bool, Error> {
        let url = URL(string: "http://localhost:5001/api/users/username/\(username)/availability")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: UsernameAvailabilityResponse.self, decoder: JSONDecoder())
            .map { response in
                response.available
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

struct UsernameAvailabilityResponse: Codable {
    let available: Bool
}

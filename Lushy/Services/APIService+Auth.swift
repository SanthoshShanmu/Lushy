import Foundation
import Combine

extension APIService {
    // Fetch user profile
    func fetchUserProfile() -> AnyPublisher<UserProfile, Error> {
        guard AuthService.shared.isAuthenticated else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/auth/me"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse, 
                       httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: ProfileResponse.self, decoder: JSONDecoder())
            .map { response in
                UserProfile(name: response.data.user.name, 
                           email: response.data.user.email,
                           id: response.data.user.id)
            }
            .mapError { error -> Error in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError
                }
                return APIError.networkError
            }
            .eraseToAnyPublisher()
    }
    
    // Update user password
    func updatePassword(currentPassword: String, newPassword: String, passwordConfirm: String) -> AnyPublisher<Bool, Error> {
        let urlString = "\(baseURL)/auth/update-password"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "currentPassword": currentPassword,
            "newPassword": newPassword,
            "passwordConfirm": passwordConfirm
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 401 {
                            throw APIError.authenticationRequired
                        } else if httpResponse.statusCode == 400 {
                            throw APIError.invalidPassword
                        }
                    }
                    throw APIError.invalidResponse
                }
                return true
            }
            .mapError { error -> Error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.networkError
            }
            .eraseToAnyPublisher()
    }
}

// Response model for profile endpoints
struct ProfileResponse: Codable {
    let status: String
    let data: ProfileData
    
    struct ProfileData: Codable {
        let user: User
    }
    
    struct User: Codable {
        let id: String
        let name: String
        let email: String
    }
}

extension APIError {
    static let invalidPassword = APIError.customError("Incorrect current password")
}
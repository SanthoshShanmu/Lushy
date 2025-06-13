import Foundation
import Combine

extension APIService {
    // Fetch wishlist items from backend
    func fetchWishlist() -> AnyPublisher<[AppWishlistItem], APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/users/\(userId)/wishlist"
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
            .decode(type: WishlistResponse.self, decoder: JSONDecoder())
            .map { response in
                // Convert BackendWishlistItems to AppWishlistItems
                return response.data.wishlistItems.map { item in
                    AppWishlistItem(
                        id: UUID(uuidString: item.id) ?? UUID(),
                        productName: item.productName,
                        productURL: item.productURL,
                        notes: item.notes ?? "",
                        imageURL: item.imageURL
                    )
                }
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError
                }
                return APIError.networkError
            }
            .eraseToAnyPublisher()
    }
    
    // Add a wishlist item to backend
    func addWishlistItem(_ item: NewWishlistItem) -> AnyPublisher<Void, APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/users/\(userId)/wishlist"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(item)
        } catch {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Void in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                return ()
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.networkError
            }
            .eraseToAnyPublisher()
    }
    
    // Delete a wishlist item from backend
    func deleteWishlistItem(id: String) -> AnyPublisher<Void, APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/users/\(userId)/wishlist/\(id)"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Void in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                return ()
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.networkError
            }
            .eraseToAnyPublisher()
    }
}

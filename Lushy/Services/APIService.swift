import Foundation
import Combine

enum APIError: Error, Equatable {
    case invalidURL
    case networkError
    case decodingError
    case authenticationRequired
    case noData
    case unexpectedResponse
    case invalidResponse
    case customError(String)
    case encodingError // Add this missing case
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .authenticationRequired:
            return "Authentication required. Please log in."
        case .noData:
            return "No data received"
        case .unexpectedResponse:
            return "Unexpected server response"
        case .invalidResponse:
            return "Invalid response format"
        case .customError(let message):
            return message
        case .encodingError:
            return "Failed to encode request"
        }
    }
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.networkError, .networkError),
             (.decodingError, .decodingError),
             (.noData, .noData),
             (.unexpectedResponse, .unexpectedResponse),
             (.invalidResponse, .invalidResponse),
             (.authenticationRequired, .authenticationRequired),
             (.encodingError, .encodingError):
            return true
        case (.customError(let lhsMessage), .customError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

class APIService {
    static let shared = APIService()
    
    // Change from private to internal
    let baseURL = "http://localhost:5001/api"
    
    private init() {}
    
    // MARK: - Open Beauty Facts API
    
    func fetchProduct(barcode: String) -> AnyPublisher<Product, APIError> {
        let urlString = "https://world.openbeautyfacts.org/api/v2/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else {
            return Fail<Product, APIError>(error: .invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    throw APIError.invalidResponse
                }
                
                guard let product = Product.fromOpenBeautyFactsResponse(json) else {
                    throw APIError.invalidResponse
                }
                
                return product
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.customError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Cruelty-Free Makeup API
    
    func fetchEthicsInfo(brand: String) -> AnyPublisher<EthicsInfo, APIError> {
        // This would use our backend as a proxy to hide API keys
        let urlString = "http://localhost:5001/api/ethics/\(brand.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            return Fail<EthicsInfo, APIError>(error: .invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: EthicsInfo.self, decoder: JSONDecoder())
            .mapError { error in
                if error is URLError {
                    return APIError.networkError
                } else if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.customError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Backup/Restore with Backend
    
    func syncUserProducts(userProducts: [UserProduct]) -> AnyPublisher<Bool, APIError> {
        // Implementation would depend on authentication system
        // This is a placeholder for the actual sync logic
        
        let urlString = "http://localhost:5001/api/users/current/products"
        guard let url = URL(string: urlString) else {
            return Fail<Bool, APIError>(error: .invalidURL).eraseToAnyPublisher()
        }
        
        // Convert products to JSON
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // This would need proper serialization of UserProduct objects
        // For now, just return success as a placeholder
        
        return Just(true)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // Method to fetch wishlist items from backend
    func fetchWishlistItems() -> AnyPublisher<[WishlistItem], APIError> {
        let urlString = "http://localhost:5001/api/users/current/wishlist"
        
        guard let url = URL(string: urlString) else {
            return Fail<[WishlistItem], APIError>(error: .invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: [WishlistItem].self, decoder: JSONDecoder())
            .mapError { error in
                if error is URLError {
                    return APIError.networkError
                } else if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.customError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchData<T: Decodable>(endpoint: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication token if available
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Handle HTTP errors
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])))
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Add authentication header to requests
    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // Update the fetchWishlist method to reflect your model:
    func fetchWishlist(completion: @escaping (Result<[WishlistItem], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/current/wishlist") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Use authorized request with timeout
        var request = URLRequest(url: url, timeoutInterval: 15) // Increased timeout
        if let token = AuthService.shared.token {
            print("Adding token to wishlist request: \(token)")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("No token available for wishlist request!")
        }
        
        // Print request for debugging
        print("Request URL: \(request.url?.absoluteString ?? "nil")")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // First check for network error
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Log response
            if let httpResponse = response as? HTTPURLResponse {
                print("Wishlist API response status: \(httpResponse.statusCode)")
                
                // Print response body for debugging
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response body preview: \(responseString.prefix(100))")
                }
                
                // Status code handling
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - continue to data processing
                    break
                case 401:
                    completion(.failure(APIError.authenticationRequired))
                    return
                case 404:
                    completion(.failure(APIError.customError("Wishlist endpoint not found: \(url.absoluteString)")))
                    return
                default:
                    completion(.failure(APIError.customError("Server error: \(httpResponse.statusCode)")))
                    return
                }
            } else {
                print("Missing HTTP response")
                completion(.failure(APIError.customError("Invalid response format")))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                // First decode the wrapper structure
                let decoder = JSONDecoder()
                
                // Create a struct to match the API response format
                struct WishlistResponse: Codable {
                    let status: String
                    let results: Int
                    let data: WishlistData
                    
                    struct WishlistData: Codable {
                        let wishlistItems: [APIWishlistItem]
                    }
                }
                
                // Decode the response
                let response = try decoder.decode(WishlistResponse.self, from: data)
                
                // Map API items to app model
                let appItems = response.data.wishlistItems.map { apiItem in
                    WishlistItem(
                        id: UUID(uuidString: apiItem.id) ?? UUID(),
                        productName: apiItem.productName,
                        productURL: apiItem.productURL,
                        notes: apiItem.notes,
                        imageURL: apiItem.imageURL
                    )
                }
                
                // Return the converted items
                completion(.success(appItems))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(APIError.decodingError))
            }
        }.resume()  // Don't forget this!
    }

    func addWishlistItem(_ item: NewWishlistItem, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/wishlist") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode item
        do {
            request.httpBody = try JSONEncoder().encode(item)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Make request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    completion(.failure(APIError.authenticationRequired))
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    completion(.success(()))
                    return
                }
            }
            
            completion(.failure(APIError.unexpectedResponse))
        }.resume()
    }

    func deleteWishlistItem(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/wishlist/\(id)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // Add auth token
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Make request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    completion(.failure(APIError.authenticationRequired))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                    return
                }
            }
            
            completion(.failure(APIError.unexpectedResponse))
        }.resume()
    }

    // Add these methods to use the backend API

    func syncProductWithBackend(product: UserProduct) -> AnyPublisher<Bool, APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/users/\(userId)/products"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        // Convert CoreData product to backend format
        let openDateValue = product.openDate?.timeIntervalSince1970
        
        var productData: [String: Any] = [
            "barcode": product.barcode ?? "",
            "productName": product.productName ?? "Unknown Product",
            "brand": product.brand ?? "",
            "imageUrl": product.imageUrl ?? "",
            "purchaseDate": product.purchaseDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "vegan": product.vegan,
            "crueltyFree": product.crueltyFree,
            "favorite": product.favorite
        ]
        
        // Only add optional fields if they exist
        if let openDateValue = openDateValue {
            productData["openDate"] = openDateValue
        }
        
        if let periodsAfterOpening = product.periodsAfterOpening {
            productData["periodsAfterOpening"] = periodsAfterOpening
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: productData)
        } catch {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse, 
                       httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                return true
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.networkError
            }
            .eraseToAnyPublisher()
    }

    func fetchUserProductsFromBackend() -> AnyPublisher<[BackendUserProduct], APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/users/\(userId)/products"
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
            .decode(type: ProductsResponse.self, decoder: JSONDecoder())
            .map { $0.data.products }
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

    // Token validation endpoint
    func validateToken() -> AnyPublisher<Bool, APIError> {
        guard let token = AuthService.shared.token else {
            return Just(false)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        let urlString = "\(baseURL)/auth/validate-token"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw APIError.authenticationRequired
                }
                
                return (200...299).contains(httpResponse.statusCode)
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

// API version of wishlist item (matches what your backend returns)
struct APIWishlistItem: Codable {
    let id: String
    let productName: String
    let productURL: String
    let notes: String
    let imageURL: String?
}

// Create a Models namespace to avoid ambiguity
enum Models {
    // Empty for namespace purposes
}


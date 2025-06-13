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
    case productNotFound  // Add this case
    
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
        case .productNotFound:
            return "Product not found"
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
             (.encodingError, .encodingError),
             (.productNotFound, .productNotFound):
            return true
        case (.customError(let lhsMessage), .customError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

struct UserSearchResponse: Codable {
    let users: [UserSummary]
}

struct FeedResponse: Codable {
    let feed: [Activity]
}

struct UserProfileWrapper: Codable {
    let user: UserProfile
}

class APIService {
    static let shared = APIService()
    
    // Change from private to internal
    let baseURL = URL(string: "http://localhost:5001/api")!
    
    private init() {}

    func perform<T: Decodable>(request: URLRequest, completion: @escaping (Result<T, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Social Features

    func fetchUserFeed(userId: String, completion: @escaping (Result<[Activity], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("users/\(userId)/feed")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData // Always fetch fresh data
        
        // Add authentication if available
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("APIService: Fetching feed from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("APIService: Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("APIService: Invalid response type")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            print("APIService: Feed response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("APIService: HTTP error: \(httpResponse.statusCode)")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard let data = data else {
                print("APIService: No data received")
                completion(.failure(APIError.noData))
                return
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("APIService: Feed response: \(responseString)")
            }
            
            do {
                let feedResponse = try JSONDecoder().decode(FeedResponse.self, from: data)
                print("APIService: Successfully decoded \(feedResponse.feed.count) activities")
                completion(.success(feedResponse.feed))
            } catch {
                print("APIService: Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func followUser(targetUserId: String, currentUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("users/\(targetUserId)/follow")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["currentUserId": currentUserId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(APIError.unexpectedResponse))
            }
        }.resume()
    }
    
    func unfollowUser(targetUserId: String, currentUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("users/\(targetUserId)/unfollow")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["currentUserId": currentUserId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(APIError.unexpectedResponse))
            }
        }.resume()
    }
    
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfileWrapper, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("users/\(userId)/profile")
        var request = URLRequest(url: url)
        
        // Add authentication headers
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("APIService: Fetching user profile from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("APIService: Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("APIService: Invalid response type")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            print("APIService: Profile response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("APIService: Profile response: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(APIError.authenticationRequired))
                } else if httpResponse.statusCode == 404 {
                    completion(.failure(APIError.customError("User not found")))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                print("APIService: No data received")
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                let userProfileWrapper = try JSONDecoder().decode(UserProfileWrapper.self, from: data)
                print("APIService: Successfully decoded user profile for \(userProfileWrapper.user.name)")
                completion(.success(userProfileWrapper))
            } catch {
                print("APIService: Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    func searchUsers(query: String, completion: @escaping (Result<[UserSummary], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("users/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        let request = URLRequest(url: components.url!)
        perform(request: request) { (result: Result<UserSearchResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.users))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Open Beauty Facts API
    
    // Update the fetchProduct method to include new fields

    func fetchProduct(barcode: String) -> AnyPublisher<Product, APIError> {
        let urlString = "https://world.openbeautyfacts.org/api/v2/product/\(barcode)?fields=code,product_name,brands,image_url,image_small_url,periods_after_opening,periods_after_opening_tags,ingredients_text_with_allergens,batch_code,manufacturing_date"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> [String: Any] in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.invalidResponse
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError
                }
                
                return json
            }
            .tryMap { json -> Product in
                guard let product = Product.fromOpenBeautyFactsResponse(json) else {
                    throw APIError.decodingError
                }
                return product
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError
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

    // Fetch user products from backend
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
                } else {
                    return APIError.networkError
                }
            }
            .eraseToAnyPublisher()
    }

    // Sync product with backend
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
            print("🚀 Syncing product to backend: \(productData["productName"] ?? "Unknown")")
        } catch {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                print("📡 Backend sync response status: \(httpResponse.statusCode)")
                
                // Log the response body for debugging 400 errors
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Backend response body: \(responseString)")
                }
                
                if httpResponse.statusCode == 401 {
                    throw APIError.authenticationRequired
                } else if httpResponse.statusCode == 400 {
                    // Parse the error message from the response
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorData["message"] as? String {
                        print("❌ Backend 400 error: \(message)")
                        throw APIError.customError("Backend error: \(message)")
                    } else {
                        throw APIError.customError("Bad request - invalid data format")
                    }
                } else if (200...299).contains(httpResponse.statusCode) {
                    // Parse response to get the backend ID
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataDict = json["data"] as? [String: Any],
                       let productDict = dataDict["product"] as? [String: Any],
                       let backendId = productDict["_id"] as? String {
                        
                        // Store the backend ID in the local product
                        DispatchQueue.main.async {
                            product.backendId = backendId
                            try? CoreDataManager.shared.viewContext.save()
                            print("✅ Product synced successfully! Backend ID: \(backendId)")
                        }
                    }
                    
                    return true
                } else {
                    throw APIError.invalidResponse
                }
            }
            .mapError { error -> APIError in
                print("❌ Product sync failed: \(error)")
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

// Also add these model definitions
struct PAOTaxonomyResponse: Codable {
    let tags: [PAOTaxonomyItem]
}

struct PAOTaxonomyItem: Codable, Identifiable {
    let id: String
    let known: Int
    let products: Int
    
    var displayName: String {
        // Convert "en:12-months" to "12 Months"
        let parts = id.split(separator: ":")
        if parts.count > 1 {
            return parts[1].replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
        return id
    }
}

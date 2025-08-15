import Foundation
import Combine
import UIKit

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
// Provide legacy alias expected by callers
typealias UserSummaryResponse = [UserSummary]

struct FeedResponse: Codable {
    let feed: [Activity]
}

struct UserProfileWrapper: Codable {
    let user: UserProfile
}

// New settings/OBF response models
struct UserSettingsResponse: Codable {
    struct Settings: Codable {
        let region: String
        let autoContributeToOBF: Bool
    }
    struct OBF: Codable {
        let contributionCount: Int
        let contributedProducts: [String]
    }
    let settings: Settings
    let obf: OBF?
}

class APIService {
    static let shared = APIService()

    // Base URL for our backend server
    let baseURL = URL(string: "http://localhost:5001/api")!
    
    // Helper to convert Date to milliseconds since epoch (backend expects ms)
    private func msSinceEpoch(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

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

    // MARK: - User Settings & OBF
    func fetchUserSettings(userId: String, completion: @escaping (Result<UserSettingsResponse, APIError>) -> Void) {
        let url = baseURL.appendingPathComponent("users").appendingPathComponent(userId).appendingPathComponent("settings")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let _ = error { completion(.failure(.networkError)); return }
            guard let http = response as? HTTPURLResponse, let data = data else { completion(.failure(.invalidResponse)); return }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(http.statusCode == 401 ? .authenticationRequired : .invalidResponse)); return
            }
            do {
                let resp = try JSONDecoder().decode(UserSettingsResponse.self, from: data)
                completion(.success(resp))
            } catch { completion(.failure(.decodingError)) }
        }.resume()
    }

    func updateUserSettings(userId: String, region: String? = nil, autoContributeToOBF: Bool? = nil, completion: ((Result<UserSettingsResponse.Settings, APIError>) -> Void)? = nil) {
        let url = baseURL.appendingPathComponent("users").appendingPathComponent(userId).appendingPathComponent("settings")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = [:]
        if let region = region { body["region"] = region }
        if let auto = autoContributeToOBF { body["autoContributeToOBF"] = auto }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let completion = completion else { return }
            if let _ = error { completion(.failure(.networkError)); return }
            guard let http = response as? HTTPURLResponse, let data = data else { completion(.failure(.invalidResponse)); return }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(http.statusCode == 401 ? .authenticationRequired : .invalidResponse)); return
            }
            do {
                struct UpdateResp: Codable { let settings: UserSettingsResponse.Settings }
                let resp = try JSONDecoder().decode(UpdateResp.self, from: data)
                completion(.success(resp.settings))
            } catch { completion(.failure(.decodingError)) }
        }.resume()
    }

    func addOBFContribution(userId: String, productId: String?, completion: ((Result<UserSettingsResponse.OBF, APIError>) -> Void)? = nil) {
        let url = baseURL.appendingPathComponent("users").appendingPathComponent(userId).appendingPathComponent("obf").appendingPathComponent("contributions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = [:]
        if let pid = productId { body["productId"] = pid }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let completion = completion else { return }
            if let _ = error { completion(.failure(.networkError)); return }
            guard let http = response as? HTTPURLResponse, let data = data else { completion(.failure(.invalidResponse)); return }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(http.statusCode == 401 ? .authenticationRequired : .invalidResponse)); return
            }
            do {
                struct OBFResp: Codable { let obf: UserSettingsResponse.OBF }
                let resp = try JSONDecoder().decode(OBFResp.self, from: data)
                completion(.success(resp.obf))
            } catch { completion(.failure(.decodingError)) }
        }.resume()
    }

    // MARK: - OBF Contribution via Backend
    
    /// Contribute to Open Beauty Facts via backend proxy (secure)
    func contributeToOBFViaBackend(
        barcode: String?,
        name: String,
        brand: String,
        category: String,
        periodsAfterOpening: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent("products").appendingPathComponent("contribute-obf")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Prepare request body
        var body: [String: Any] = [
            "productName": name,
            "brand": brand,
            "category": category,
            "periodsAfterOpening": periodsAfterOpening
        ]
        
        if let barcode = barcode, !barcode.isEmpty {
            body["barcode"] = barcode
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("🔄 Contributing to OBF via backend: \(name) by \(brand)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Backend OBF contribution network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📄 Backend OBF response: \(json)")
                    
                    if httpResponse.statusCode == 200,
                       let status = json["status"] as? String,
                       status == "success" {
                        let productId = json["productId"] as? String ?? "unknown"
                        print("✅ Successfully contributed to OBF via backend: \(productId)")
                        completion(.success(productId))
                    } else {
                        let errorMessage = json["message"] as? String ?? "Unknown error"
                        completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
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
    
    // MARK: - Activity Interactions (Likes & Comments)
    func likeActivity(activityId: String, completion: @escaping (Result<(likes: Int, liked: Bool), Error>) -> Void) {
        let url = baseURL
            .appendingPathComponent("activities")
            .appendingPathComponent(activityId)
            .appendingPathComponent("like")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(APIError.invalidResponse)); return }
            struct LikeResp: Decodable { let likes: Int; let liked: Bool }
            do {
                let resp = try JSONDecoder().decode(LikeResp.self, from: data)
                completion(.success((likes: resp.likes, liked: resp.liked)))
            } catch { completion(.failure(error)) }
        }.resume()
    }
    
    func commentOnActivity(activityId: String, text: String, completion: @escaping (Result<[CommentSummary], Error>) -> Void) {
        let url = baseURL
            .appendingPathComponent("activities")
            .appendingPathComponent(activityId)
            .appendingPathComponent("comment")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let body = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(APIError.invalidResponse)); return }
            struct CommentResp: Decodable { let comments: [CommentSummary] }
            do {
                let resp = try JSONDecoder().decode(CommentResp.self, from: data)
                completion(.success(resp.comments))
            } catch { completion(.failure(error)) }
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

    func searchUsers(query: String, completion: @escaping (Result<UserSummaryResponse, Error>) -> Void) {
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
    // MARK: - Product Search (backend + OBF fallback handled server-side)
    func searchProducts(query: String, completion: @escaping (Result<[ProductSearchSummary], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("products").appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { completion(.failure(APIError.invalidURL)); return }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = AuthService.shared.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, let data = data else { completion(.failure(APIError.invalidResponse)); return }
            guard (200...299).contains(http.statusCode) else { completion(.failure(APIError.invalidResponse)); return }
            // Decode wrapper { status, results, data: { products: [] } }
            struct Wrapper: Decodable {
                let status: String
                let results: Int?
                let data: Inner?
                struct Inner: Decodable { let products: [ProductSearchSummary]? }
            }
            do {
                let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
                let products = wrapper.data?.products ?? []
                completion(.success(products))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Combine-compatible version of searchProducts
    func searchProductsPublisher(query: String) -> AnyPublisher<[ProductSearchSummary], APIError> {
        return Future<[ProductSearchSummary], APIError> { promise in
            self.searchProducts(query: query) { result in
                switch result {
                case .success(let products):
                    promise(.success(products))
                case .failure(let error):
                    if let apiError = error as? APIError {
                        promise(.failure(apiError))
                    } else {
                        promise(.failure(.networkError))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
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
                guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                // Treat 404 specifically as product not found (better UX)
                if httpResponse.statusCode == 404 { throw APIError.productNotFound }
                guard (200...299).contains(httpResponse.statusCode) else { throw APIError.invalidResponse }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.decodingError }
                // OBF sometimes returns { status: 0 } for not found while still 200
                if let status = json["status"] as? Int, status == 0 { throw APIError.productNotFound }
                return json
            }
            .tryMap { json -> Product in
                guard let product = Product.fromOpenBeautyFactsResponse(json) else { throw APIError.decodingError }
                return product
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                return .networkError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Hybrid Product Lookup (Backend + OBF)
    
    /// Enhanced product lookup that searches backend first, then falls back to OBF
    func fetchProductHybrid(barcode: String) -> AnyPublisher<Product, APIError> {
        // First, search in your backend database
        return searchProductsPublisher(query: barcode)
            .map { searchResults -> Product? in
                // Look for exact barcode match in your database
                if let match = searchResults.first(where: { $0.barcode == barcode }) {
                    // Convert ProductSearchSummary to Product
                    return Product(
                        id: match.barcode,
                        code: match.barcode,
                        productName: match.productName,
                        brands: match.brand,
                        imageUrl: match.imageUrl,
                        ingredients: nil,
                        periodsAfterOpening: nil,
                        imageSmallUrl: match.imageUrl,
                        periodsAfterOpeningTags: nil,
                        batchCode: nil,
                        manufactureDate: nil,
                        complianceAdvisory: nil,
                        regionSpecificGuidelines: nil
                    )
                }
                return nil
            }
            .flatMap { backendProduct -> AnyPublisher<Product, APIError> in
                if let product = backendProduct {
                    // Found in backend, return it
                    print("🎯 Product found in backend database: \(product.productName ?? "Unknown")")
                    return Just(product)
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                } else {
                    // Not found in backend, try Open Beauty Facts
                    print("🔍 Product not in backend, searching Open Beauty Facts...")
                    return self.fetchProduct(barcode: barcode)
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
        
        print("APIService: Fetching user products from: \(urlString)")
        
        let decoder = JSONDecoder()
        // Decode ISO8601 strings with fractional seconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try fractional seconds parser
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: dateString) {
                return date
            }
            // Fallback to default ISO8601 parser
            let basicFormatter = ISO8601DateFormatter()
            if let date = basicFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(dateString)"))
        }

        // Start request
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("APIService: fetchUserProductsFromBackend - Invalid HTTP response")
                    throw APIError.invalidResponse
                }
                
                print("APIService: fetchUserProductsFromBackend response status: \(httpResponse.statusCode)")
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("APIService: fetchUserProductsFromBackend response: \(responseString)")
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        print("APIService: fetchUserProductsFromBackend - Authentication required")
                        throw APIError.authenticationRequired
                    }
                    print("APIService: fetchUserProductsFromBackend - HTTP error: \(httpResponse.statusCode)")
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: ProductsResponse.self, decoder: decoder)
            .map { response in
                print("APIService: Successfully decoded ProductsResponse with \(response.data.products.count) products")
                return response.data.products
            }
            .mapError { error -> APIError in
                print("APIService: fetchUserProductsFromBackend error: \(error)")
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    print("APIService: fetchUserProductsFromBackend decoding error details: \(error)")
                    return APIError.decodingError
                } else {
                    return APIError.networkError
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Create a new beauty bag for a user
    func createBag(userId: String, name: String) -> AnyPublisher<BeautyBagSummary, APIError> {
        let url = baseURL.appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("bags")
         var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.addValue("application/json", forHTTPHeaderField: "Content-Type")
         if let token = AuthService.shared.token {
             request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
         }
         let body = ["name": name]
         request.httpBody = try? JSONSerialization.data(withJSONObject: body)
         return URLSession.shared.dataTaskPublisher(for: request)
             .tryMap { data, response -> BeautyBagSummary in
                 guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                     throw APIError.invalidResponse
                 }
                 let wrapper = try JSONDecoder().decode(BagResponse.self, from: data)
                 let bag = wrapper.bag
                 return BeautyBagSummary(id: bag._id, name: bag.name)
             }
             .mapError { error in
                 (error as? APIError) ?? .networkError
             }
             .eraseToAnyPublisher()
    }

    // Response wrapper for createBag
    private struct BagResponse: Codable {
        let bag: BagData
        struct BagData: Codable {
            let _id: String
            let name: String
        }
    }
    
    // Delete a beauty bag for a user
    func deleteBag(userId: String, bagId: String) -> AnyPublisher<Void, APIError> {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("bags")
            .appendingPathComponent(bagId)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { _, response in
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw APIError.invalidResponse
                }
                return ()
            }
            .mapError { error in (error as? APIError) ?? .networkError }
            .eraseToAnyPublisher()
    }
    
    // Fetch user tags from backend
    func fetchUserTags(userId: String, completion: @escaping (Result<[TagSummary], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("users").appendingPathComponent(userId).appendingPathComponent("tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(APIError.invalidResponse)); return
            }
            do {
                // Use global TagSummary with CodingKeys for _id
                struct TagListResponse: Codable { let tags: [TagSummary] }
                let wrapper = try JSONDecoder().decode(TagListResponse.self, from: data)
                completion(.success(wrapper.tags))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Create a new product tag for a user
    func createTag(userId: String, name: String, color: String) -> AnyPublisher<TagSummary, APIError> {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("tags")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: String] = ["name": name, "color": color]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // Wrapper for createTag response
        struct CreateTagWrapper: Codable {
            let tag: TagSummary
        }
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw APIError.invalidResponse
                }
                if let jsonStr = String(data: data, encoding: .utf8) {
                    print("APIService: createTag response HTTP \(http.statusCode): \(jsonStr)")
                }
                return data
            }
            .decode(type: CreateTagWrapper.self, decoder: JSONDecoder())
            .map { $0.tag }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return .decodingError
                } else {
                    return .networkError
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Add tag to product on backend
    func updateProductTags(userId: String, productId: String, addTagId: String) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(productId)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = ["addTagId": addTagId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }

    // Remove tag from product on backend
    func removeProductTags(userId: String, productId: String, removeTagId: String) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(productId)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = ["removeTagId": removeTagId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // Fetch user bags from backend
    func fetchUserBags(userId: String, completion: @escaping (Result<[BeautyBagSummary], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("users").appendingPathComponent(userId).appendingPathComponent("bags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            do {
                struct BagListResponse: Codable { let bags: [BeautyBagSummary] }
                let wrapper = try JSONDecoder().decode(BagListResponse.self, from: data)
                completion(.success(wrapper.bags))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Fetch a single user product (with tags and bags) from backend
    func fetchUserProduct(userId: String, productId: String, completion: @escaping (Result<BackendUserProduct, APIError>) -> Void) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(productId)
        var request = URLRequest(url: url)
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil { // was: if let error = error { completion(.failure(.networkError)); return }
                completion(.failure(.networkError)); return
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data = data else {
                completion(.failure(.invalidResponse)); return
            }

            // Debug: print raw JSON for fetchUserProduct
            if let raw = String(data: data, encoding: .utf8) {
                print("APIService.fetchUserProduct JSON: \(raw)")
            }
            struct SingleResponse: Codable {
                struct Payload: Codable { let product: BackendUserProduct }
                let status: String
                let data: Payload
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateStr = try container.decode(String.self)
                    let frac = ISO8601DateFormatter()
                    frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = frac.date(from: dateStr) { return d }
                    let basic = ISO8601DateFormatter()
                    if let d = basic.date(from: dateStr) { return d }
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(dateStr)"))
                }
                let wrapper = try decoder.decode(SingleResponse.self, from: data)
                completion(.success(wrapper.data.product))
            } catch {
                print("APIService.fetchUserProduct decode error: \(error)")
                completion(.failure(.decodingError)); return
            }
        }.resume()
    }
    
    // Replace manual JSON parsing implementation of syncProductWithBackend with Codable decoding

    func syncProductWithBackend(product: UserProduct, image: UIImage? = nil) -> AnyPublisher<String, APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: .authenticationRequired).eraseToAnyPublisher()
        }
        // Decide create vs update
        let isUpdate = (product.backendId != nil && !(product.backendId ?? "").isEmpty)
        let url = isUpdate ? baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(product.backendId!) : baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
        var request = URLRequest(url: url)
        request.httpMethod = isUpdate ? "PUT" : "POST"
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        // Helper to convert to ms epoch
        func ms(_ date: Date?) -> Int64? { guard let d = date else { return nil }; return Int64(d.timeIntervalSince1970 * 1000) }

        // Build common fields
        var fields: [String: Any] = [
            "barcode": product.barcode ?? "",
            "productName": product.productName ?? "",
            "brand": product.brand ?? "",
            "vegan": product.vegan,
            "crueltyFree": product.crueltyFree,
            "favorite": product.favorite,
            "quantity": Int(product.quantity)
        ]
        if let purchase = ms(product.purchaseDate) { fields["purchaseDate"] = purchase }
        if let open = ms(product.openDate) { fields["openDate"] = open }
        if let pao = product.periodsAfterOpening { fields["periodsAfterOpening"] = pao }
        if let shade = product.shade, !shade.isEmpty { fields["shade"] = shade }
        if product.sizeInMl > 0 { fields["sizeInMl"] = product.sizeInMl }
        if product.spf > 0 { fields["spf"] = Int(product.spf) }
        if let tagsSet = product.tags as? Set<ProductTag>, !tagsSet.isEmpty {
            let backendTagIds = tagsSet.compactMap { $0.backendId }
            if !backendTagIds.isEmpty { fields["tags"] = backendTagIds }
        }
        if let bagsSet = product.bags as? Set<BeautyBag>, !bagsSet.isEmpty {
            let backendBagIds = bagsSet.compactMap { $0.backendId }
            if !backendBagIds.isEmpty { fields["bags"] = backendBagIds }
        }

        // If no image OR image already has remote URL, send JSON
        if image == nil {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: fields)
        } else {
            // Multipart form-data
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            // Text fields
            for (key, value) in fields {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)\r\n")
            }
            if let imgData = image?.jpegData(compressionQuality: 0.85) {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n")
                body.appendString("Content-Type: image/jpeg\r\n\r\n")
                body.append(imgData)
                body.appendString("\r\n")
            }
            body.appendString("--\(boundary)--\r\n")
            request.httpBody = body
        }

        // Define response structure that matches backend MongoDB response
        struct CreateOrUpdateResponse: Decodable {
            let status: String
            let data: DataContainer
            
            struct DataContainer: Decodable {
                let product: MongoProduct
            }
            struct MongoProduct: Decodable {
                let _id: String  // MongoDB returns _id field directly
                
                enum CodingKeys: String, CodingKey {
                    case _id
                }
            }
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    if let http = response as? HTTPURLResponse, http.statusCode == 401 { throw APIError.authenticationRequired }
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: CreateOrUpdateResponse.self, decoder: {
                let decoder = JSONDecoder()
                // Add custom date decoding strategy to handle ISO8601 dates with fractional seconds
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    // Try fractional seconds parser first
                    let fractionalFormatter = ISO8601DateFormatter()
                    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = fractionalFormatter.date(from: dateString) {
                        return date
                    }
                    // Fallback to default ISO8601 parser
                    let basicFormatter = ISO8601DateFormatter()
                    if let date = basicFormatter.date(from: dateString) {
                        return date
                    }
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(dateString)"))
                }
                return decoder
            }())
            .map { response -> String in
                let backendId = response.data.product._id
                
                print("✅ Product synced successfully with backend ID: \(backendId)")
                
                return backendId
            }
            .mapError { error in
                if let apiErr = error as? APIError { return apiErr }
                if error is DecodingError { 
                    print("APIService: syncProductWithBackend decoding error: \(error)")
                    return .decodingError 
                }
                return .networkError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - PAO Taxonomy
    func fetchPAOTaxonomy() -> AnyPublisher<[String:String], APIError> {
        let urlString = "https://world.openbeautyfacts.org/periods-after-opening.json"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        struct Root: Decodable { struct Tag: Decodable { let id: String?; let name: String? }
            let tags: [Tag]? }
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { _ in APIError.networkError }
            .map { $0.data }
            .decode(type: Root.self, decoder: JSONDecoder())
            .map { root -> [String:String] in
                var dict: [String:String] = [:]
                guard let tags = root.tags else { return dict }
                for t in tags {
                    guard let id = t.id, let name = t.name else { continue }
                    // Extract digits from id to form month key
                    let num = id.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !num.isEmpty {
                        let key = num + "M"
                        if dict[key] == nil { dict[key] = name }
                    }
                }
                return dict
            }
            .mapError { err in
                if err is DecodingError { return .decodingError }
                return (err as? APIError) ?? .networkError
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Data append helper for multipart
private extension Data {
    mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}

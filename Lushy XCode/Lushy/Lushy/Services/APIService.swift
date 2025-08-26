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
    case encodingError
    case productNotFound
    
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
    let status: String
    let results: Int
    let data: FeedData
    
    struct FeedData: Codable {
        let activities: [Activity]
    }
}

struct UserProfileWrapper: Codable {
    let user: UserProfile
}

// Simplified settings response model (removed OBF)
struct UserSettingsResponse: Codable {
    struct Settings: Codable {
        let region: String
    }
    let settings: Settings
}

class APIService {
    static let shared = APIService()

    // Base URL for our backend server
    let baseURL = URL(string: "http://localhost:5001/api")!
    
    // Base URL for static files (without /api prefix)
    var staticBaseURL: String {
        return "http://localhost:5001"
    }
    
    // Helper to convert Date to milliseconds since epoch (backend expects ms)
    private func msSinceEpoch(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

    // Centralized JSONDecoder configuration for consistent date handling
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try standard date formatter as fallback
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            
            // If all else fails, return current date
            print("⚠️ Failed to decode date string: \(dateString), using current date")
            return Date()
        }
        return decoder
    }

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
                let decodedResponse = try self.jsonDecoder.decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - User Settings
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
                let resp = try self.jsonDecoder.decode(UserSettingsResponse.self, from: data)
                completion(.success(resp))
            } catch { completion(.failure(.decodingError)) }
        }.resume()
    }

    func updateUserSettings(userId: String, region: String? = nil, completion: ((Result<UserSettingsResponse.Settings, APIError>) -> Void)? = nil) {
        let url = baseURL.appendingPathComponent("users").appendingPathComponent(userId).appendingPathComponent("settings")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = [:]
        if let region = region { body["region"] = region }
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
                let resp = try self.jsonDecoder.decode(UpdateResp.self, from: data)
                completion(.success(resp.settings))
            } catch { completion(.failure(.decodingError)) }
        }.resume()
    }

    // MARK: - Social Features
    func fetchUserFeed(userId: String, completion: @escaping (Result<[Activity], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("activities").appendingPathComponent("feed")
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
                if httpResponse.statusCode == 401 {
                    completion(.failure(APIError.authenticationRequired))
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
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("APIService: Feed response: \(responseString)")
            }
            
            do {
                let feedResponse = try self.jsonDecoder.decode(FeedResponse.self, from: data)
                print("APIService: Successfully decoded \(feedResponse.data.activities.count) activities")
                completion(.success(feedResponse.data.activities))
            } catch {
                print("APIService: Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context)")
                        print("Available keys: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type \(type): \(context)")
                        print("Coding path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type \(type): \(context)")
                        print("Coding path: \(context.codingPath)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                
                // Try to decode just the status to see if the basic structure is there
                if let basicResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Basic JSON structure: \(basicResponse.keys)")
                    if let dataSection = basicResponse["data"] as? [String: Any] {
                        print("Data section keys: \(dataSection.keys)")
                        if let activities = dataSection["activities"] as? [[String: Any]] {
                            print("Found \(activities.count) activities in raw JSON")
                            if let firstActivity = activities.first {
                                print("First activity keys: \(firstActivity.keys)")
                            }
                        }
                    }
                }
                
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
                let resp = try self.jsonDecoder.decode(LikeResp.self, from: data)
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
                let resp = try self.jsonDecoder.decode(CommentResp.self, from: data)
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
                let userProfileWrapper = try self.jsonDecoder.decode(UserProfileWrapper.self, from: data)
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
    
    // MARK: - Product Search (MongoDB backend only)
    func searchProducts(query: String, completion: @escaping (Result<[ProductSearchSummary], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("products").appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        
        let request = URLRequest(url: components.url!)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                struct SearchResponse: Decodable {
                    let status: String
                    let results: Int
                    let data: SearchData
                    
                    struct SearchData: Decodable {
                        let products: [ProductSearchSummary]
                    }
                }
                
                let response = try JSONDecoder().decode(SearchResponse.self, from: data)
                completion(.success(response.data.products))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Get users who own a specific product
    func getUsersWhoOwnProduct(barcode: String, currentUserId: String? = nil, completion: @escaping (Result<UsersWhoOwnProductResponse, Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("products").appendingPathComponent("barcode").appendingPathComponent(barcode).appendingPathComponent("users"), resolvingAgainstBaseURL: false)!
        
        if let currentUserId = currentUserId {
            components.queryItems = [URLQueryItem(name: "currentUserId", value: currentUserId)]
        }
        
        let request = URLRequest(url: components.url!)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(UsersWhoOwnProductResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Fetch all reviews for a product from all users
    func getAllReviewsForProduct(barcode: String) -> AnyPublisher<[BackendReview], APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent("reviews")
            .appendingPathComponent("barcode")
            .appendingPathComponent(barcode)
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: AllReviewsResponse.self, decoder: jsonDecoder)
            .map { response in
                return response.data.reviews
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return .networkError
            }
            .eraseToAnyPublisher()
    }
    
    // Add product to user's collection from search results
    func addProductToCollection(barcode: String, productName: String, brand: String?, imageUrl: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = AuthService.shared.userId else {
            completion(.failure(APIError.authenticationRequired))
            return
        }
        
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "barcode": barcode,
            "productName": productName,
            "brand": brand ?? "",
            "imageUrl": imageUrl ?? "",
            "purchaseDate": Date().timeIntervalSince1970 * 1000, // Convert to milliseconds
            "vegan": false,
            "crueltyFree": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(APIError.authenticationRequired))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            do {
                struct ProductResponse: Codable {
                    let status: String
                    let data: ProductData
                    
                    struct ProductData: Codable {
                        let product: ProductInfo
                        
                        struct ProductInfo: Codable {
                            let _id: String
                        }
                    }
                }
                
                let response = try JSONDecoder().decode(ProductResponse.self, from: data)
                completion(.success(response.data.product._id))
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
    
    // MARK: - Product Lookup (MongoDB backend only)
    
    /// Product lookup using MongoDB backend only
    func fetchProduct(barcode: String) -> AnyPublisher<Product, APIError> {
        let url = baseURL
            .appendingPathComponent("products")
            .appendingPathComponent("barcode")
            .appendingPathComponent(barcode)
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Product in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 404 {
                        throw APIError.productNotFound
                    } else if httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                
                struct ProductResponse: Codable {
                    let status: String
                    let data: ProductData
                    
                    struct ProductData: Codable {
                        let product: ProductInfo
                        
                        struct ProductInfo: Codable {
                            let _id: String
                            let productName: String
                            let brand: String?
                            let barcode: String
                            let vegan: Bool
                            let crueltyFree: Bool
                            let periodsAfterOpening: String?
                            let ingredients: [String]?
                            let imageUrl: String?
                        }
                    }
                }
                
                let response = try self.jsonDecoder.decode(ProductResponse.self, from: data)
                let productInfo = response.data.product
                
                return Product(
                    id: productInfo.barcode,
                    code: productInfo.barcode,
                    productName: productInfo.productName,
                    brands: productInfo.brand,
                    imageUrl: productInfo.imageUrl,
                    imageData: nil,
                    imageMimeType: nil,
                    ingredients: productInfo.ingredients,
                    periodsAfterOpening: productInfo.periodsAfterOpening,
                    imageSmallUrl: productInfo.imageUrl,
                    periodsAfterOpeningTags: nil,
                    batchCode: nil,
                    manufactureDate: nil,
                    complianceAdvisory: nil,
                    regionSpecificGuidelines: nil,
                    vegan: productInfo.vegan,
                    crueltyFree: productInfo.crueltyFree
                )
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return .networkError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - PAO Taxonomy (Local data)
    
    func fetchPAOTaxonomy() -> AnyPublisher<[String:String], APIError> {
        // Return local PAO taxonomy data instead of fetching from OBF
        let localPAO: [String: String] = [
            "3M": "3 months",
            "6M": "6 months",
            "9M": "9 months", 
            "12M": "12 months",
            "18M": "18 months",
            "24M": "24 months",
            "36M": "36 months"
        ]
        
        return Just(localPAO)
            .setFailureType(to: APIError.self)
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
    
    // MARK: - Product Sync Operations
    
    func syncProductWithBackend(product: UserProduct) -> AnyPublisher<String, APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Convert UserProduct to JSON, handling base64 images
        var productData: [String: Any] = [
            "productName": product.productName ?? "",
            "brand": product.brand ?? "",
            "barcode": product.barcode ?? "",
            "purchaseDate": Int64(product.purchaseDate?.timeIntervalSince1970 ?? 0) * 1000,
            "vegan": product.vegan,
            "crueltyFree": product.crueltyFree,
            "favorite": product.favorite,
            "shade": product.shade ?? "",
            "sizeInMl": product.sizeInMl,
            "spf": Int(product.spf),
            "currentAmount": product.currentAmount,
            "quantity": Int(product.quantity)
        ]
        
        // Handle dates
        if let openDate = product.openDate {
            productData["openDate"] = Int64(openDate.timeIntervalSince1970) * 1000
        }
        
        if let expireDate = product.expireDate {
            productData["expireDate"] = Int64(expireDate.timeIntervalSince1970) * 1000
        }
        
        if let finishDate = product.finishDate {
            productData["finishDate"] = Int64(finishDate.timeIntervalSince1970) * 1000
        }
        
        // Handle periods after opening
        if let pao = product.periodsAfterOpening {
            productData["periodsAfterOpening"] = pao
        }
        
        // Handle image - convert to base64 if it's a local file or data URL
        if let imageUrl = product.imageUrl {
            if imageUrl.hasPrefix("data:") {
                // Already a data URL, extract base64 data and MIME type
                let components = imageUrl.components(separatedBy: ",")
                if components.count == 2 {
                    let header = components[0] // "data:image/jpeg;base64"
                    let base64Data = components[1]
                    
                    // Extract MIME type
                    if let mimeRange = header.range(of: "data:"),
                       let semicolonRange = header.range(of: ";") {
                        let mimeType = String(header[header.index(mimeRange.upperBound, offsetBy: 0)..<semicolonRange.lowerBound])
                        productData["imageMimeType"] = mimeType
                        productData["imageData"] = base64Data
                        productData["imageUrl"] = imageUrl // Keep for backward compatibility
                    }
                }
            } else if imageUrl.hasPrefix("/") {
                // Local file path, convert to base64
                if let imageData = FileManager.default.contents(atPath: imageUrl),
                   let image = UIImage(data: imageData),
                   let jpegData = image.jpegData(compressionQuality: 0.8) {
                    let base64String = jpegData.base64EncodedString()
                    productData["imageData"] = base64String
                    productData["imageMimeType"] = "image/jpeg"
                    productData["imageUrl"] = "data:image/jpeg;base64,\(base64String)"
                }
            } else {
                // Regular URL, keep as is
                productData["imageUrl"] = imageUrl
            }
        }
        
        // Handle tag associations
        if let tags = product.tags as? Set<ProductTag> {
            let tagIds = tags.compactMap { $0.backendId }
            if !tagIds.isEmpty {
                productData["tags"] = tagIds
            }
        }
        
        // Handle bag associations  
        if let bags = product.bags as? Set<BeautyBag> {
            let bagIds = bags.compactMap { $0.backendId }
            if !bagIds.isEmpty {
                productData["bags"] = bagIds
            }
        }
        
        return Future<String, APIError> { promise in
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: productData)
                
                URLSession.shared.dataTask(with: request) { data, response, _ in
                    if data == nil {
                        promise(.failure(.networkError))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        promise(.failure(.invalidResponse))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 401 {
                            promise(.failure(.authenticationRequired))
                        } else {
                            promise(.failure(.invalidResponse))
                        }
                        return
                    }
                    
                    guard let data = data else {
                        promise(.failure(.noData))
                        return
                    }
                    
                    do {
                        // Parse response to get the backend ID
                        struct ProductResponse: Codable {
                            let status: String
                            let data: ProductData
                            
                            struct ProductData: Codable {
                                let product: ProductInfo
                                
                                struct ProductInfo: Codable {
                                    let _id: String
                                }
                            }
                        }
                        
                        let response = try self.jsonDecoder.decode(ProductResponse.self, from: data)
                        promise(.success(response.data.product._id))
                    } catch {
                        promise(.failure(.decodingError))
                    }
                } .resume()
            } catch {
                promise(.failure(.encodingError))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - User Product Operations
    
    func fetchUserProductsFromBackend() -> AnyPublisher<[BackendUserProduct], APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: APIError.authenticationRequired).eraseToAnyPublisher()
        }
        
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> [BackendUserProduct] in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                
                struct Response: Codable {
                    let status: String
                    let data: DataWrapper
                    
                    struct DataWrapper: Codable {
                        let products: [BackendUserProduct]
                    }
                }
                
                let response = try self.jsonDecoder.decode(Response.self, from: data)
                return response.data.products
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return .networkError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - User Product Single Fetch
    
    func fetchUserProduct(userId: String, productId: String, completion: @escaping (Result<BackendUserProduct, APIError>) -> Void) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(productId)
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if data == nil {
                completion(.failure(.networkError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.authenticationRequired))
                } else if httpResponse.statusCode == 404 {
                    completion(.failure(.customError("Product not found")))
                } else {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                struct Response: Codable {
                    let status: String
                    let data: DataWrapper
                    
                    struct DataWrapper: Codable {
                        let product: BackendUserProduct
                    }
                }
                
                // Configure JSONDecoder to properly parse ISO 8601 date strings
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let response = try decoder.decode(Response.self, from: data)
                completion(.success(response.data.product))
            } catch {
                print("JSONDecoder error: \(error)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // MARK: - User Tags API
    
    func fetchUserTags(userId: String, completion: @escaping (Result<[TagSummary], APIError>) -> Void) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("tags")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if data == nil {
                completion(.failure(.networkError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.authenticationRequired))
                } else {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                struct Response: Codable {
                    let status: String
                    let data: DataWrapper
                    
                    struct DataWrapper: Codable {
                        let tags: [TagSummary]
                    }
                }
                
                let response = try self.jsonDecoder.decode(Response.self, from: data)
                completion(.success(response.data.tags))
            } catch {
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // MARK: - User Tags Management API
    
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
        
        let body = [
            "name": name,
            "color": color
        ]
        
        return Future<TagSummary, APIError> { promise in
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                URLSession.shared.dataTask(with: request) { data, response, _ in
                    if data == nil {
                        promise(.failure(.networkError))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        promise(.failure(.invalidResponse))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 401 {
                            promise(.failure(.authenticationRequired))
                        } else {
                            promise(.failure(.invalidResponse))
                        }
                        return
                    }
                    
                    guard let data = data else {
                        promise(.failure(.noData))
                        return
                    }
                    
                    do {
                        struct Response: Codable {
                            let tag: TagSummary
                        }
                        
                        let response = try self.jsonDecoder.decode(Response.self, from: data)
                        promise(.success(response.tag))
                    } catch {
                        promise(.failure(.decodingError))
                    }
                }.resume()
            } catch {
                promise(.failure(.encodingError))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateProductTags(userId: String, productId: String, addTagId: String) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(productId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["addTagId": addTagId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func removeProductTags(userId: String, productId: String, removeTagId: String) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
            .appendingPathComponent(productId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["removeTagId": removeTagId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // MARK: - User Bags API
    
    func fetchUserBags(userId: String, completion: @escaping (Result<[BeautyBagSummary], APIError>) -> Void) {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("bags")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if data == nil {
                completion(.failure(.networkError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.authenticationRequired))
                } else {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                struct Response: Codable {
                    let status: String
                    let data: DataWrapper
                    
                    struct DataWrapper: Codable {
                        let bags: [BeautyBagSummary]
                    }
                }
                
                let response = try self.jsonDecoder.decode(Response.self, from: data)
                completion(.success(response.data.bags))
            } catch {
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // MARK: - Beauty Bag Management API
    
    func createBag(userId: String, name: String, color: String = "lushyPink", icon: String = "bag.fill") -> AnyPublisher<BeautyBagSummary, APIError> {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("bags")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "name": name,
            "color": color,
            "icon": icon
        ]
        
        return Future<BeautyBagSummary, APIError> { promise in
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                URLSession.shared.dataTask(with: request) { data, response, _ in
                    if data == nil {
                        promise(.failure(.networkError))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        promise(.failure(.invalidResponse))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 401 {
                            promise(.failure(.authenticationRequired))
                        } else {
                            promise(.failure(.invalidResponse))
                        }
                        return
                    }
                    
                    guard let data = data else {
                        promise(.failure(.noData))
                        return
                    }
                    
                    do {
                        struct Response: Codable {
                            let bag: BeautyBagSummary
                        }
                        
                        let response = try self.jsonDecoder.decode(Response.self, from: data)
                        promise(.success(response.bag))
                    } catch {
                        promise(.failure(.decodingError))
                    }
                }.resume()
            } catch {
                promise(.failure(.encodingError))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateBag(userId: String, bagId: String, name: String, color: String, icon: String) -> AnyPublisher<Void, APIError> {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("bags")
            .appendingPathComponent(bagId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "name": name,
            "color": color,
            "icon": icon
        ]
        
        return Future<Void, APIError> { promise in
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                URLSession.shared.dataTask(with: request) { data, response, _ in
                    if data == nil {
                        promise(.failure(.networkError))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        promise(.failure(.invalidResponse))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 401 {
                            promise(.failure(.authenticationRequired))
                        } else {
                            promise(.failure(.invalidResponse))
                        }
                        return
                    }
                    
                    promise(.success(()))
                }.resume()
            } catch {
                promise(.failure(.encodingError))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteBag(userId: String, bagId: String) -> AnyPublisher<Void, APIError> {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("bags")
            .appendingPathComponent(bagId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return Future<Void, APIError> { promise in
            URLSession.shared.dataTask(with: request) { data, response, _ in
                if data == nil {
                    promise(.failure(.networkError))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    promise(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        promise(.failure(.authenticationRequired))
                    } else if httpResponse.statusCode == 404 {
                        promise(.failure(.customError("Bag not found")))
                    } else {
                        promise(.failure(.invalidResponse))
                    }
                    return
                }
                
                promise(.success(()))
            }.resume()
        }
        .eraseToAnyPublisher()
    }
}

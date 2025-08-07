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

    // Base URL for our backend server
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
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 401 {
                        throw APIError.authenticationRequired
                    }
                    throw APIError.invalidResponse
                }
                // Debug: print server JSON for products
                if let jsonStr = String(data: data, encoding: .utf8) {
                    print("APIService: Products JSON: \(jsonStr)")
                }
                return data
            }
            .decode(type: ProductsResponse.self, decoder: decoder)
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
            if let error = error {
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

    func syncProductWithBackend(product: UserProduct) -> AnyPublisher<String, APIError> {
        guard let userId = AuthService.shared.userId else {
            return Fail(error: .authenticationRequired).eraseToAnyPublisher()
        }
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("products")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Build payload including tags & bags
        var payload: [String: Any] = [
            "barcode": product.barcode ?? "",
            "productName": product.productName ?? "",
            "brand": product.brand ?? "",
            "imageUrl": product.imageUrl ?? "",
            "purchaseDate": product.purchaseDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "vegan": product.vegan,
            "crueltyFree": product.crueltyFree,
            "favorite": product.favorite
        ]
        if let tagsSet = product.tags as? Set<ProductTag>, !tagsSet.isEmpty {
            payload["tags"] = tagsSet.compactMap { $0.backendId }
        }
        if let bagsSet = product.bags as? Set<BeautyBag>, !bagsSet.isEmpty {
            payload["bags"] = bagsSet.compactMap { $0.backendId }
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        struct ResponseWrapper: Decodable {
            let status: String
            let data: DataContainer
            struct DataContainer: Decodable {
                let product: BackendUserProduct
            }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: ResponseWrapper.self, decoder: decoder)
            .map { $0.data.product.id }
            .mapError { error in
                if let apiErr = error as? APIError { return apiErr }
                if error is DecodingError { return .decodingError }
                return .networkError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - PAO Taxonomy
    /// Fetch periods-after-opening taxonomy from OpenBeautyFacts
    func fetchPAOTaxonomy() -> AnyPublisher<[String: String], APIError> {
        let urlString = "https://world.openbeautyfacts.org/periods-after-opening.json"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .tryMap { data -> [String: String] in
                // JSON is a dictionary of code: label
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    throw APIError.decodingError
                }
                return dict
            }
            .mapError { error in
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
    
    /// Like an activity
    func likeActivity(activityId: String, completion: @escaping (Result<(likes: Int, liked: Bool), Error>) -> Void) {
        let url = baseURL.appendingPathComponent("activities/")
            .appendingPathComponent(activityId)
            .appendingPathComponent("like")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(APIError.noData)); return
            }
            do {
                struct LikeResponse: Codable { let likes: Int; let liked: Bool }
                let resp = try JSONDecoder().decode(LikeResponse.self, from: data)
                completion(.success((likes: resp.likes, liked: resp.liked)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Comment on an activity
    func commentOnActivity(activityId: String, text: String, completion: @escaping (Result<[CommentSummary], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("activities/")
            .appendingPathComponent(activityId)
            .appendingPathComponent("comment")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = ["text": text]
        request.httpBody = try? JSONEncoder().encode(body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(APIError.noData)); return
            }
            do {
                let wrapper = try JSONDecoder().decode([String: [CommentSummary]].self, from: data)
                let comments = wrapper["comments"] ?? []
                completion(.success(comments))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Product Search
    /// Search products across all users by name
    func searchProducts(query: String, completion: @escaping (Result<[ProductSearchSummary], Error>) -> Void) {
        fallbackOBSearch(query: query, completion: completion)
    }
    
    /// Fetch general product detail by product ID
    func fetchProductDetail(productId: String, completion: @escaping (Result<BackendUserProduct, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("products").appendingPathComponent(productId)
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(APIError.noData)); return
            }

            // Debug: print raw JSON for inspection
            if let raw = String(data: data, encoding: .utf8) {
                print("APIService.fetchProductDetail JSON: \(raw)")
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateStr = try container.decode(String.self)
                    // Try fractional seconds parser
                    let frac = ISO8601DateFormatter()
                    frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = frac.date(from: dateStr) { return d }
                    // Fallback to standard ISO8601
                    let basic = ISO8601DateFormatter()
                    if let d = basic.date(from: dateStr) { return d }
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(dateStr)"))
                }
                let root = try decoder.decode(ProductDetailResponse.self, from: data)
                completion(.success(root.data.product))
            } catch {
                print("APIService.fetchProductDetail decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // Wrapper for decoding product detail
    private struct ProductDetailResponse: Codable {
        struct DataContainer: Codable { let product: BackendUserProduct }
        let status: String
        let data: DataContainer
    }
    
    // Client-side fallback search using OpenBeautyFacts when backend returns no results
    private func fallbackOBSearch(query: String, completion: @escaping (Result<[ProductSearchSummary], Error>) -> Void) {
        var components = URLComponents(string: "https://world.openbeautyfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,image_url,image_small_url"),
            URLQueryItem(name: "page_size", value: "20")
        ]
        guard let url = components.url else {
            completion(.failure(APIError.invalidURL)); return
        }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(APIError.noData)); return
            }
            do {
                struct OBResponse: Decodable { let products: [ProductSearchSummary] }
                let resp = try JSONDecoder().decode(OBResponse.self, from: data)
                completion(.success(resp.products))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

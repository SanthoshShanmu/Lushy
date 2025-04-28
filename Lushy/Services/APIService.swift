import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case unknown(Error)
}

class APIService {
    static let shared = APIService()
    
    private init() {}
    
    // MARK: - Open Beauty Facts API
    
    func fetchProduct(barcode: String) -> AnyPublisher<Product, APIError> {
        let urlString = "https://world.openbeautyfacts.org/api/v2/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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
                    return APIError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Cruelty-Free Makeup API
    
    func fetchEthicsInfo(brand: String) -> AnyPublisher<EthicsInfo, APIError> {
        // This would use our backend as a proxy to hide API keys
        let urlString = "https://lushy-backend.herokuapp.com/api/ethics/\(brand.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: EthicsInfo.self, decoder: JSONDecoder())
            .mapError { error in
                if let urlError = error as? URLError {
                    return APIError.unknown(urlError)
                } else if let decodingError = error as? DecodingError {
                    return APIError.decodingError(decodingError)
                } else {
                    return APIError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Backup/Restore with Backend
    
    func syncUserProducts(userProducts: [UserProduct]) -> AnyPublisher<Bool, APIError> {
        // Implementation would depend on authentication system
        // This is a placeholder for the actual sync logic
        
        let urlString = "https://lushy-backend.herokuapp.com/api/users/current/products"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
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
        let urlString = "https://lushy-backend.herokuapp.com/api/users/current/wishlist"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [WishlistItem].self, decoder: JSONDecoder())
            .mapError { error in
                if let urlError = error as? URLError {
                    return APIError.unknown(urlError)
                } else if let decodingError = error as? DecodingError {
                    return APIError.decodingError(decodingError)
                } else {
                    return APIError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
}
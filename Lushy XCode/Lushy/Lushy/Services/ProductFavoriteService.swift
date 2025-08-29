import Foundation
import Combine

class ProductFavoriteService: ObservableObject {
    static let shared = ProductFavoriteService()
    
    private let baseURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.baseURL = APIService.shared.baseURL
    }
    
    // Toggle favorite status for a product by barcode
    func toggleFavorite(barcode: String, userId: String) -> AnyPublisher<ProductFavoriteResponse, Error> {
        guard let url = URL(string: "\(baseURL)/products/barcode/\(barcode)/favorite") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["userId": userId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ProductFavoriteResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // Get favorite status for a product by barcode
    func getFavoriteStatus(barcode: String, userId: String) -> AnyPublisher<ProductFavoriteStatusResponse, Error> {
        guard let url = URL(string: "\(baseURL)/products/barcode/\(barcode)/favorite?userId=\(userId)") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ProductFavoriteStatusResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // Get all favorite products for a user
    func getUserFavorites(userId: String) -> AnyPublisher<UserFavoritesResponse, Error> {
        guard let url = URL(string: "\(baseURL)/products/users/\(userId)/favorites") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: UserFavoritesResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Response Models

struct ProductFavoriteResponse: Codable {
    let status: String
    let data: ProductFavoriteData
    
    struct ProductFavoriteData: Codable {
        let product: FavoriteProduct
    }
    
    struct FavoriteProduct: Codable {
        let barcode: String
        let productName: String
        let brand: String?
        let isFavorited: Bool
        let favoriteCount: Int
    }
}

struct ProductFavoriteStatusResponse: Codable {
    let status: String
    let data: FavoriteStatusData
    
    struct FavoriteStatusData: Codable {
        let barcode: String
        let isFavorited: Bool
        let favoriteCount: Int
    }
}

struct UserFavoritesResponse: Codable {
    let status: String
    let results: Int
    let data: FavoritesData
    
    struct FavoritesData: Codable {
        let favorites: [FavoriteProductSummary]
    }
    
    struct FavoriteProductSummary: Codable, Identifiable {
        let id: String
        let product: ProductInfo
        let purchaseDate: String
        let openDate: String?
        let isFinished: Bool
        let tags: [TagInfo]
        let bags: [BagInfo]
        let totalInstances: Int
        
        struct ProductInfo: Codable {
            let id: String
            let barcode: String
            let productName: String
            let brand: String?
            let imageUrl: String
            let vegan: Bool
            let crueltyFree: Bool
            let favoriteCount: Int
            
            enum CodingKeys: String, CodingKey {
                case id = "_id"
                case barcode, productName, brand, imageUrl, vegan, crueltyFree, favoriteCount
            }
        }
        
        struct TagInfo: Codable {
            let id: String
            let name: String
            let color: String
            
            enum CodingKeys: String, CodingKey {
                case id = "_id"
                case name, color
            }
        }
        
        struct BagInfo: Codable {
            let id: String
            let name: String
            
            enum CodingKeys: String, CodingKey {
                case id = "_id"
                case name
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case product, purchaseDate, openDate, isFinished, tags, bags, totalInstances
        }
    }
}
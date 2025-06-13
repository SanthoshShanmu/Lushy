import Foundation

// Response model for products endpoints
struct ProductsResponse: Codable {
    let status: String
    let results: Int
    let data: ProductsData
    
    struct ProductsData: Codable {
        let products: [BackendUserProduct]
    }
}

// Backend user product model
struct BackendUserProduct: Codable, Identifiable {
    let id: String
    let barcode: String
    let productName: String
    let brand: String?
    let imageUrl: String?
    let purchaseDate: TimeInterval
    let openDate: TimeInterval?
    let periodsAfterOpening: String?
    let vegan: Bool
    let crueltyFree: Bool
    let favorite: Bool
    let comments: [Comment]?
    let reviews: [Review]?
    
    struct Comment: Codable {
        let text: String
        let date: TimeInterval
    }
    
    struct Review: Codable {
        let rating: Int
        let title: String
        let text: String
        let date: TimeInterval
    }
}

// Wishlist response model
struct WishlistResponse: Codable {
    let status: String
    let results: Int
    let data: WishlistData
    
    struct WishlistData: Codable {
        let wishlistItems: [BackendWishlistItem]
    }
}

// Backend wishlist item
struct BackendWishlistItem: Codable, Identifiable {
    let id: String
    let productName: String
    let productURL: String
    let notes: String?
    let imageURL: String?
    let createdAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productName
        case productURL
        case notes
        case imageURL
        case createdAt
    }
}

struct UserSummary: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
    }
}

struct UserProfile: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let followers: [UserSummary]?
    let following: [UserSummary]?
    let bags: [BeautyBagSummary]?
    let products: [UserProductSummary]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case followers
        case following
        case bags
        case products
    }
}

struct BeautyBagSummary: Identifiable, Codable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
    }
}

struct UserProductSummary: Identifiable, Codable {
    let id: String
    let name: String
    let brand: String?
    let isFavorite: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case brand
        case isFavorite
    }
}

struct Activity: Codable, Identifiable {
    let id: String
    let user: UserSummary
    let type: String
    let targetId: String?
    let targetType: String?
    let description: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user, type, targetId, targetType, description, createdAt
    }
}

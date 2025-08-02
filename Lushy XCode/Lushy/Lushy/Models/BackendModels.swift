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

// Tag model for backend responses
struct TagSummary: Codable, Identifiable {
    let id: String
    let name: String
    let color: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case color
    }
}

// Backend user product model
struct BackendUserProduct: Codable, Identifiable {
    let id: String
    let barcode: String
    let productName: String
    let brand: String?
    let imageUrl: String?
    let purchaseDate: Date
    let openDate: Date?
    let periodsAfterOpening: String?
    let vegan: Bool
    let crueltyFree: Bool
    let favorite: Bool
    let tags: [TagSummary]?  // Tag associations
    let bags: [BeautyBagSummary]?  // Bag associations
    // New metadata fields
    let shade: String?
    let sizeInMl: Double?
    let spf: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case barcode
        case productName
        case brand
        case imageUrl
        case purchaseDate
        case openDate
        case periodsAfterOpening
        case vegan
        case crueltyFree
        case favorite
        case tags
        case bags
        case shade
        case sizeInMl
        case spf
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
    let user: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productName
        case productURL
        case notes
        case imageURL
        case user
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
    let tags: [TagSummary]?  // added to decode tag associations
    let bags: [BeautyBagSummary]?  // added to decode bag associations

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name = "productName"  // Map productName from backend to name in iOS
        case brand
        case isFavorite = "favorite"  // Map favorite from backend to isFavorite in iOS
        case tags
        case bags
    }
}

struct Activity: Codable, Identifiable {
    let id: String
    let user: UserSummary
    let type: String
    let targetId: String?
    let targetType: String?
    let description: String?
    let rating: Int?  // star rating for review activities
    let likes: Int?   // number of likes
    let comments: [CommentSummary]?  // comments on this activity
    let liked: Bool?  // whether the current user has liked this activity
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user, type, targetId, targetType, description, rating, likes, comments, liked, createdAt
    }
}

// A minimal summary model for comments under an activity
struct CommentSummary: Codable, Identifiable {
    let id: String
    let user: UserSummary
    let text: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user, text, createdAt
    }
}

// Model for creating new wishlist items
struct NewWishlistItem: Codable {
    let productName: String
    let productURL: String
    let notes: String
    let imageURL: String?
}

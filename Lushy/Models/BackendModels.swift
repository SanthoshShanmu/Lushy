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
}
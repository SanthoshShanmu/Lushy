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
    let barcode: String // safe default "" when missing
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
    // NEW: Product instance support
    let quantity: Int

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
        case quantity
    }

    init(id: String, barcode: String, productName: String, brand: String?, imageUrl: String?, purchaseDate: Date, openDate: Date?, periodsAfterOpening: String?, vegan: Bool, crueltyFree: Bool, favorite: Bool, tags: [TagSummary]?, bags: [BeautyBagSummary]?, shade: String?, sizeInMl: Double?, spf: Int?, quantity: Int = 1) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageUrl = imageUrl
        self.purchaseDate = purchaseDate
        self.openDate = openDate
        self.periodsAfterOpening = periodsAfterOpening
        self.vegan = vegan
        self.crueltyFree = crueltyFree
        self.favorite = favorite
        self.tags = tags
        self.bags = bags
        self.shade = shade
        self.sizeInMl = sizeInMl
        self.spf = spf
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        barcode = (try? c.decode(String.self, forKey: .barcode)) ?? "" // default
        productName = try c.decode(String.self, forKey: .productName)
        brand = try? c.decode(String.self, forKey: .brand)
        imageUrl = try? c.decode(String.self, forKey: .imageUrl)
        purchaseDate = try c.decode(Date.self, forKey: .purchaseDate)
        openDate = try? c.decode(Date.self, forKey: .openDate)
        periodsAfterOpening = try? c.decode(String.self, forKey: .periodsAfterOpening)
        vegan = (try? c.decode(Bool.self, forKey: .vegan)) ?? false
        crueltyFree = (try? c.decode(Bool.self, forKey: .crueltyFree)) ?? false
        favorite = (try? c.decode(Bool.self, forKey: .favorite)) ?? false
        tags = try? c.decode([TagSummary].self, forKey: .tags)
        bags = try? c.decode([BeautyBagSummary].self, forKey: .bags)
        shade = try? c.decode(String.self, forKey: .shade)
        sizeInMl = try? c.decode(Double.self, forKey: .sizeInMl)
        spf = try? c.decode(Int.self, forKey: .spf)
        quantity = (try? c.decode(Int.self, forKey: .quantity)) ?? 1 // default to 1
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
    let isFinished: Bool?  // Add finished status property
    let tags: [TagSummary]?  // added to decode tag associations
    let bags: [BeautyBagSummary]?  // added to decode bag associations

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name = "productName"  // Map productName from backend to name in iOS
        case brand
        case isFavorite = "favorite"  // Map favorite from backend to isFavorite in iOS
        case isFinished = "isFinished"  // Map isFinished from backend
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
    let bundledActivities: [BundledActivityItem]?  // for bundled product additions
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user, type, targetId, targetType, description, rating, likes, comments, liked, createdAt, bundledActivities
    }
}

// Model for individual activities within a bundle
struct BundledActivityItem: Codable, Identifiable {
    let id: String
    let description: String?
    let targetId: String?
    let targetType: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case description, targetId, targetType, createdAt
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

// New model for product search results
struct ProductSearchSummary: Identifiable, Decodable, Hashable {
    let id: String
    let barcode: String
    let productName: String
    let brand: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case code // fallback from OpenBeautyFacts
        case barcode
        case productName
        case brand
        case imageUrl
        case product_name
        case brands
        case image_small_url
        case image_url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else {
            id = try container.decode(String.self, forKey: .code)
        }
        // barcode may be missing (OB fallback), fallback to code
        if let bc = try? container.decode(String.self, forKey: .barcode) {
            barcode = bc
        } else {
            barcode = try container.decode(String.self, forKey: .code)
        }
        // productName may come as 'productName' or 'product_name'
        if let name = try? container.decode(String.self, forKey: .productName) {
            productName = name
        } else if let name2 = try? container.decode(String.self, forKey: .product_name) {
            productName = name2
        } else {
            productName = ""
        }
        // brand may come as 'brand' or 'brands'
        if let br = try? container.decode(String.self, forKey: .brand) {
            brand = br
        } else {
            brand = try? container.decode(String.self, forKey: .brands)
        }
        // imageUrl may come as 'imageUrl', 'image_small_url', or 'image_url'
        if let img = try? container.decode(String.self, forKey: .imageUrl) {
            imageUrl = img
        } else if let img2 = try? container.decode(String.self, forKey: .image_small_url) {
            imageUrl = img2
        } else {
            imageUrl = try? container.decode(String.self, forKey: .image_url)
        }
    }
}

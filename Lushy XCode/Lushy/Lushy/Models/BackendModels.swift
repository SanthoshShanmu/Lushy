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

// Product catalog model for the referential architecture
struct BackendProductCatalog: Codable {
    let id: String
    let barcode: String
    let productName: String
    let brand: String?
    let imageUrl: String?
    let imageData: String?
    let imageMimeType: String?
    let periodsAfterOpening: String?
    let vegan: Bool
    let crueltyFree: Bool
    let category: String?
    // Product-specific attributes (different values = different barcodes/products)
    let shade: String?
    let sizeInMl: Double?
    let spf: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case barcode
        case productName
        case brand
        case imageUrl
        case imageData
        case imageMimeType
        case periodsAfterOpening
        case vegan
        case crueltyFree
        case category
        case shade
        case sizeInMl
        case spf
    }
    
    // Memberwise initializer
    init(id: String, barcode: String, productName: String, brand: String?, imageUrl: String?, imageData: String?, imageMimeType: String?, periodsAfterOpening: String?, vegan: Bool, crueltyFree: Bool, category: String?, shade: String?, sizeInMl: Double?, spf: Int?) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.imageMimeType = imageMimeType
        self.periodsAfterOpening = periodsAfterOpening
        self.vegan = vegan
        self.crueltyFree = crueltyFree
        self.category = category
        self.shade = shade
        self.sizeInMl = sizeInMl
        self.spf = spf
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        barcode = try container.decode(String.self, forKey: .barcode)
        productName = try container.decode(String.self, forKey: .productName)
        brand = try? container.decode(String.self, forKey: .brand)
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        imageData = try? container.decode(String.self, forKey: .imageData)
        imageMimeType = try? container.decode(String.self, forKey: .imageMimeType)
        periodsAfterOpening = try? container.decode(String.self, forKey: .periodsAfterOpening)
        vegan = (try? container.decode(Bool.self, forKey: .vegan)) ?? false
        crueltyFree = (try? container.decode(Bool.self, forKey: .crueltyFree)) ?? false
        category = try? container.decode(String.self, forKey: .category)
        shade = try? container.decode(String.self, forKey: .shade)
        sizeInMl = try? container.decode(Double.self, forKey: .sizeInMl)
        spf = try? container.decode(Int.self, forKey: .spf)
    }
}

// Backend user product model - updated for referential architecture
struct BackendUserProduct: Codable, Identifiable {
    let id: String
    let product: BackendProductCatalog // Reference to product catalog
    let purchaseDate: Date
    let openDate: Date?
    let expireDate: Date?
    let favorite: Bool
    let isFinished: Bool
    let finishDate: Date?
    let currentAmount: Double
    let timesUsed: Int32
    let tags: [TagSummary]?  // Tag associations
    let bags: [BeautyBagSummary]?  // Bag associations
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case product
        case purchaseDate
        case openDate
        case expireDate
        case favorite
        case isFinished
        case finishDate
        case currentAmount
        case timesUsed
        case tags
        case bags
        case quantity
    }

    // Convenience accessors for product catalog fields
    var barcode: String { product.barcode }
    var productName: String { product.productName }
    var brand: String? { product.brand }
    var imageUrl: String? { product.imageUrl }
    var periodsAfterOpening: String? { product.periodsAfterOpening }
    var vegan: Bool { product.vegan }
    var crueltyFree: Bool { product.crueltyFree }
    var shade: String? { product.shade }
    var sizeInMl: Double? { product.sizeInMl }
    var spf: Int? { product.spf }

    // Custom initializer for backward compatibility
    init(id: String, barcode: String, productName: String, brand: String?, imageUrl: String?, purchaseDate: Date, openDate: Date?, periodsAfterOpening: String?, vegan: Bool, crueltyFree: Bool, favorite: Bool, tags: [TagSummary]?, bags: [BeautyBagSummary]?, shade: String?, sizeInMl: Double?, spf: Int?, quantity: Int = 1) {
        self.id = id
        self.product = BackendProductCatalog(
            id: "",
            barcode: barcode,
            productName: productName,
            brand: brand,
            imageUrl: imageUrl,
            imageData: nil,
            imageMimeType: nil,
            periodsAfterOpening: periodsAfterOpening,
            vegan: vegan,
            crueltyFree: crueltyFree,
            category: nil,
            shade: shade,
            sizeInMl: sizeInMl,
            spf: spf
        )
        self.purchaseDate = purchaseDate
        self.openDate = openDate
        self.expireDate = nil
        self.favorite = favorite
        self.isFinished = false
        self.finishDate = nil
        self.currentAmount = 100.0
        self.timesUsed = 0
        self.tags = tags
        self.bags = bags
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        product = try c.decode(BackendProductCatalog.self, forKey: .product)
        
        // Handle date decoding with better error handling
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let purchaseDateString = try? c.decode(String.self, forKey: .purchaseDate) {
            purchaseDate = dateFormatter.date(from: purchaseDateString) ?? Date()
        } else {
            purchaseDate = Date()
        }
        
        if let openDateString = try? c.decode(String.self, forKey: .openDate) {
            openDate = dateFormatter.date(from: openDateString)
        } else {
            openDate = nil
        }
        
        if let expireDateString = try? c.decode(String.self, forKey: .expireDate) {
            expireDate = dateFormatter.date(from: expireDateString)
        } else {
            expireDate = nil
        }
        
        if let finishDateString = try? c.decode(String.self, forKey: .finishDate) {
            finishDate = dateFormatter.date(from: finishDateString)
        } else {
            finishDate = nil
        }
        
        favorite = (try? c.decode(Bool.self, forKey: .favorite)) ?? false
        isFinished = (try? c.decode(Bool.self, forKey: .isFinished)) ?? false
        currentAmount = (try? c.decode(Double.self, forKey: .currentAmount)) ?? 100.0
        timesUsed = (try? c.decode(Int32.self, forKey: .timesUsed)) ?? 0
        tags = try? c.decode([TagSummary].self, forKey: .tags)
        bags = try? c.decode([BeautyBagSummary].self, forKey: .bags)
        quantity = (try? c.decode(Int.self, forKey: .quantity)) ?? 1
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
    let username: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case username
        case profileImage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID - required field with fallback
        id = (try? container.decode(String.self, forKey: .id)) ?? ""
        
        // Handle name - required field with fallback
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown User"
        
        // Handle username - required field with fallback  
        username = (try? container.decode(String.self, forKey: .username)) ?? "unknown"
        
        // Handle optional profileImage
        profileImage = try? container.decode(String.self, forKey: .profileImage)
        
        // Debug logging
        print("🐛 UserSummary decoded: id=\(id), name=\(name), username=\(username)")
    }
}

struct UserProfile: Identifiable, Codable {
    let id: String
    let name: String
    let username: String
    let bio: String?
    let profileImage: String?
    let followers: [UserSummary]?
    let following: [UserSummary]?
    let bags: [BeautyBagSummary]?
    let products: [UserProductSummary]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case username
        case bio
        case profileImage
        case followers
        case following
        case bags
        case products
    }
}

struct BeautyBagSummary: Identifiable, Codable {
    let id: String
    let name: String
    let color: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case color
        case icon
    }
    
    init(id: String, name: String, color: String? = "lushyPink", icon: String? = "bag.fill") {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
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
    let createdAt: Date  // Changed from String to Date
    let bundledActivities: [BundledActivityItem]?  // for bundled product additions
    let imageUrl: String?  // product image URL for display in feed
    let reviewData: ReviewData?  // detailed review data for review_added activities
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user, type, targetId, targetType, description, rating, likes, comments, liked, createdAt, bundledActivities, imageUrl, reviewData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID - required field
        id = try container.decode(String.self, forKey: .id)
        
        // Handle user - required field with better error handling
        user = try container.decode(UserSummary.self, forKey: .user)
        
        // Handle type - required field with fallback
        type = (try? container.decode(String.self, forKey: .type)) ?? "unknown"
        
        // Handle optional fields
        targetId = try? container.decode(String.self, forKey: .targetId)
        targetType = try? container.decode(String.self, forKey: .targetType)
        description = try? container.decode(String.self, forKey: .description)
        rating = try? container.decode(Int.self, forKey: .rating)
        likes = try? container.decode(Int.self, forKey: .likes)
        comments = try? container.decode([CommentSummary].self, forKey: .comments)
        liked = try? container.decode(Bool.self, forKey: .liked)
        bundledActivities = try? container.decode([BundledActivityItem].self, forKey: .bundledActivities)
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        reviewData = try? container.decode(ReviewData.self, forKey: .reviewData)
        
        // Handle date decoding with multiple fallback strategies
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            if let parsedDate = dateFormatter.date(from: createdAtString) {
                createdAt = parsedDate
            } else {
                // Try without fractional seconds
                dateFormatter.formatOptions = [.withInternetDateTime]
                createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            }
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            // Handle timestamp format
            createdAt = Date(timeIntervalSince1970: createdAtDouble / 1000)
        } else {
            // Last resort fallback
            createdAt = Date()
        }
    }
}

// Review data structure for activities
struct ReviewData: Codable {
    let title: String
    let text: String
    let rating: Int
    let productName: String
    let brand: String?
}

// Model for individual activities within a bundle
struct BundledActivityItem: Codable, Identifiable {
    let id: String
    let description: String?
    let targetId: String?
    let targetType: String?
    let createdAt: Date  // Changed from String to Date
    let imageUrl: String?  // product image URL for bundled items
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case description, targetId, targetType, createdAt, imageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID with fallback
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        
        // Handle optional fields
        description = try? container.decode(String.self, forKey: .description)
        targetId = try? container.decode(String.self, forKey: .targetId)
        targetType = try? container.decode(String.self, forKey: .targetType)
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        
        // Handle date decoding with multiple fallback strategies
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            if let parsedDate = dateFormatter.date(from: createdAtString) {
                createdAt = parsedDate
            } else {
                // Try without fractional seconds
                dateFormatter.formatOptions = [.withInternetDateTime]
                createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            }
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            // Handle timestamp format
            createdAt = Date(timeIntervalSince1970: createdAtDouble / 1000)
        } else {
            // Last resort fallback
            createdAt = Date()
        }
    }
}

// A minimal summary model for comments under an activity
struct CommentSummary: Codable, Identifiable {
    let id: String
    let user: UserSummary
    let text: String
    let createdAt: Date  // Changed from String to Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case user, text, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        user = try container.decode(UserSummary.self, forKey: .user)
        text = try container.decode(String.self, forKey: .text)
        
        // Handle date decoding
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }
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
    let vegan: Bool
    let crueltyFree: Bool
    let periodsAfterOpening: String?
    let category: String?
    let shade: String?
    let sizeInMl: Double?
    let spf: Int?
    let ingredients: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case barcode
        case productName
        case brand
        case imageUrl
        case vegan
        case crueltyFree
        case periodsAfterOpening
        case category
        case shade
        case sizeInMl
        case spf
        case ingredients
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        barcode = try container.decode(String.self, forKey: .barcode)
        productName = try container.decode(String.self, forKey: .productName)
        brand = try? container.decode(String.self, forKey: .brand)
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        vegan = (try? container.decode(Bool.self, forKey: .vegan)) ?? false
        crueltyFree = (try? container.decode(Bool.self, forKey: .crueltyFree)) ?? false
        periodsAfterOpening = try? container.decode(String.self, forKey: .periodsAfterOpening)
        category = try? container.decode(String.self, forKey: .category)
        shade = try? container.decode(String.self, forKey: .shade)
        sizeInMl = try? container.decode(Double.self, forKey: .sizeInMl)
        spf = try? container.decode(Int.self, forKey: .spf)
        ingredients = try? container.decode([String].self, forKey: .ingredients)
    }
}

// Model for users who own a product response
struct UsersWhoOwnProductResponse: Codable {
    let status: String
    let data: UsersWhoOwnProductData
    
    struct UsersWhoOwnProductData: Codable {
        let product: ProductInfo
        let users: [UserSummary]
        
        struct ProductInfo: Codable {
            let barcode: String
            let productName: String
            let brand: String?
            let imageUrl: String?
        }
    }
}

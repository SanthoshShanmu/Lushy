import Foundation

// Standard model without namespace
struct WishlistItem: Identifiable, Codable {
    let id: UUID
    let productName: String
    let productURL: String
    let notes: String
    let imageURL: String?
    
    init(id: UUID = UUID(), productName: String, productURL: String, notes: String, imageURL: String? = nil) {
        self.id = id
        self.productName = productName
        self.productURL = productURL
        self.notes = notes
        self.imageURL = imageURL
    }
}

// App-specific model (renamed to avoid conflicts)
struct AppWishlistItem: Identifiable, Codable {
    let id: String  // Changed from UUID to String to preserve MongoDB ObjectId
    let productName: String
    let productURL: String
    let notes: String
    let imageURL: String?
    
    init(id: String = UUID().uuidString, productName: String, productURL: String, notes: String, imageURL: String? = nil) {
        self.id = id
        self.productName = productName
        self.productURL = productURL
        self.notes = notes
        self.imageURL = imageURL
    }
}

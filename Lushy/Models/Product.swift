import Foundation

// Model based on OpenBeautyFacts API response
struct Product: Codable, Identifiable {
    let id: String  // Using barcode as id
    let code: String  // Barcode
    let productName: String?
    let brands: String?
    let imageUrl: String?
    let ingredients: [String]?
    let periodsAfterOpening: String?  // "12 months", etc
    let imageSmallUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, code
        case productName = "product_name"
        case brands
        case imageUrl = "image_url"
        case ingredients = "ingredients_text_with_allergens"
        case periodsAfterOpening = "periods_after_opening"
        case imageSmallUrl = "image_small_url"
    }
    
    // Parse from OpenBeautyFacts API response
    static func fromOpenBeautyFactsResponse(_ json: [String: Any]) -> Product? {
        guard let code = json["code"] as? String else { return nil }
        
        let product = json["product"] as? [String: Any] ?? [:]
        let productName = product["product_name"] as? String
        let brands = product["brands"] as? String
        let imageUrl = product["image_url"] as? String
        let imageSmallUrl = product["image_small_url"] as? String
        let ingredients = product["ingredients_text_with_allergens"] as? String
        let periodsAfterOpening = product["periods_after_opening"] as? String
        
        return Product(
            id: code,
            code: code,
            productName: productName,
            brands: brands,
            imageUrl: imageUrl,
            ingredients: ingredients?.components(separatedBy: ", "),
            periodsAfterOpening: periodsAfterOpening,
            imageSmallUrl: imageSmallUrl
        )
    }
}

// Ethics info from Cruelty-free API
struct EthicsInfo: Codable {
    let vegan: Bool
    let crueltyFree: Bool
    
    enum CodingKeys: String, CodingKey {
        case vegan
        case crueltyFree = "cruelty_free"
    }
}

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
    // Enhanced fields for shelf life data
    let periodsAfterOpeningTags: [String]?
    let batchCode: String?
    let manufactureDate: Date?
    let complianceAdvisory: String?
    let regionSpecificGuidelines: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id, code
        case productName = "product_name"
        case brands
        case imageUrl = "image_url"
        case ingredients = "ingredients_text_with_allergens"
        case periodsAfterOpening = "periods_after_opening"
        case imageSmallUrl = "image_small_url"
        case periodsAfterOpeningTags = "periods_after_opening_tags"
        case batchCode = "batch_code"
        case manufactureDate = "manufacturing_date"
        case complianceAdvisory = "compliance_advisory"
        case regionSpecificGuidelines = "region_specific_guidelines"
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
        let periodsAfterOpeningTags = product["periods_after_opening_tags"] as? [String]
        let batchCode = product["batch_code"] as? String
        
        // Parse manufacturing date if available
        var manufactureDate: Date? = nil
        if let dateString = product["manufacturing_date"] as? String {
            let formatter = ISO8601DateFormatter()
            manufactureDate = formatter.date(from: dateString)
        }
        
        // Get compliance advisory if available
        let complianceAdvisory = product["compliance_advisory"] as? String
        
        // Parse region-specific guidelines if available
        let regionSpecificGuidelines = product["region_specific_guidelines"] as? [String: String]
        
        return Product(
            id: code,
            code: code,
            productName: productName,
            brands: brands,
            imageUrl: imageUrl,
            ingredients: ingredients?.components(separatedBy: ", "),
            periodsAfterOpening: periodsAfterOpening,
            imageSmallUrl: imageSmallUrl,
            periodsAfterOpeningTags: periodsAfterOpeningTags,
            batchCode: batchCode,
            manufactureDate: manufactureDate,
            complianceAdvisory: complianceAdvisory,
            regionSpecificGuidelines: regionSpecificGuidelines
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

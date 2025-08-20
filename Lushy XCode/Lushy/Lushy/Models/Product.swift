import Foundation

// Model for beauty products stored in MongoDB database
struct Product: Codable, Identifiable {
    let id: String  // Using barcode as id
    let code: String  // Barcode
    let productName: String?
    let brands: String?
    let imageUrl: String?
    let imageData: String? // Base64 image data from MongoDB
    let imageMimeType: String? // MIME type for base64 images
    let ingredients: [String]?
    let periodsAfterOpening: String?  // "12 months", etc
    let imageSmallUrl: String?
    // Enhanced fields for shelf life data
    let periodsAfterOpeningTags: [String]?
    let batchCode: String?
    let manufactureDate: Date?
    let complianceAdvisory: String?
    let regionSpecificGuidelines: [String: String]?
    // Ethics info from database
    let vegan: Bool?
    let crueltyFree: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, code
        case productName = "product_name"
        case brands
        case imageUrl = "image_url"
        case imageData
        case imageMimeType
        case ingredients = "ingredients_text_with_allergens"
        case periodsAfterOpening = "periods_after_opening"
        case imageSmallUrl = "image_small_url"
        case periodsAfterOpeningTags = "periods_after_opening_tags"
        case batchCode = "batch_code"
        case manufactureDate = "manufacturing_date"
        case complianceAdvisory = "compliance_advisory"
        case regionSpecificGuidelines = "region_specific_guidelines"
        case vegan
        case crueltyFree = "cruelty_free"
    }
    
    // Initialize from database response
    init(id: String, code: String, productName: String?, brands: String?, imageUrl: String?, imageData: String?, imageMimeType: String?, ingredients: [String]?, periodsAfterOpening: String?, imageSmallUrl: String?, periodsAfterOpeningTags: [String]?, batchCode: String?, manufactureDate: Date?, complianceAdvisory: String?, regionSpecificGuidelines: [String: String]?, vegan: Bool?, crueltyFree: Bool?) {
        self.id = id
        self.code = code
        self.productName = productName
        self.brands = brands
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.imageMimeType = imageMimeType
        self.ingredients = ingredients
        self.periodsAfterOpening = periodsAfterOpening
        self.imageSmallUrl = imageSmallUrl
        self.periodsAfterOpeningTags = periodsAfterOpeningTags
        self.batchCode = batchCode
        self.manufactureDate = manufactureDate
        self.complianceAdvisory = complianceAdvisory
        self.regionSpecificGuidelines = regionSpecificGuidelines
        self.vegan = vegan
        self.crueltyFree = crueltyFree
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

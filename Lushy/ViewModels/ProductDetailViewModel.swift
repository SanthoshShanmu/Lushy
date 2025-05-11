import Foundation
import CoreData
import Combine

class ProductDetailViewModel: ObservableObject {
    @Published var product: UserProduct
    @Published var newComment = ""
    @Published var showReviewForm = false
    @Published var reviewRating = 3
    @Published var reviewTitle = ""
    @Published var reviewText = ""
    @Published var allBags: [BeautyBag] = []
    @Published var allTags: [ProductTag] = []

    private var cancellables = Set<AnyCancellable>()
    
    // Get compliance advisory for current region
    var complianceAdvisory: String {
        // Get user's region from UserDefaults
        let region = UserDefaults.standard.string(forKey: "userRegion") ?? "GLOBAL"
        
        // Rules for different regions
        let rules = [
            "EU": "PAO symbol mandatory for cosmetics after opening.",
            "US": "Manufacture date required, expiry guidelines recommended.",
            "JP": "Both expiry date and PAO are required by regulation.",
            "GLOBAL": "Use within 36 months of manufacture if no PAO specified."
        ]
        
        // Return region-specific rule or global rule
        return rules[region] ?? rules["GLOBAL"]!
    }
    
    // Check if a product has a PAO symbol
    var hasPAOSymbol: Bool {
        return product.periodsAfterOpening != nil
    }
    
    // Add batch code info if available
    var batchCodeInfo: String? {
        return product.value(forKey: "batchCode") as? String
    }
    
    // Fix the incomplete notification handler in init()
    init(product: UserProduct) {
        self.product = product
        
        // Complete the notification subscription that was left incomplete
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshProduct()
            }
            .store(in: &cancellables)
    }
    
    // Add a comment to the product
    func addComment() {
        guard !newComment.isEmpty else { return }
        
        CoreDataManager.shared.addComment(to: product.objectID, text: newComment)
        newComment = "" // Reset comment field
    }
    
    // Submit a review for the product
    func submitReview() {
        guard !reviewTitle.isEmpty && !reviewText.isEmpty else { return }
        
        CoreDataManager.shared.addReview(
            to: product.objectID,
            rating: reviewRating,
            title: reviewTitle,
            text: reviewText
        )
        
        // Reset form
        reviewRating = 3
        reviewTitle = ""
        reviewText = ""
        showReviewForm = false
        
        // Refresh product
        refreshProduct()
    }
    
    // Mark product as opened
    func markAsOpened() {
        CoreDataManager.shared.markProductAsOpened(id: product.objectID, openDate: Date())
        
        // Schedule expiry notification
        NotificationService.shared.scheduleExpiryNotification(for: product)
        
        // Refresh the product with updated data
        refreshProduct()
    }
    
    // Replace the markAsEmpty() function with this:
    func markAsEmpty() {
        // Check if product already has a review
        let hasReview = (product.reviews?.count ?? 0) > 0
        
        if hasReview {
            // If already reviewed, directly mark as finished
            CoreDataManager.shared.markProductAsFinished(id: product.objectID)
            // This will trigger UI refresh via the notification subscription
        } else {
            // If no review yet, offer to write one via the review form
            showReviewForm = true
        }
    }
    
    // Toggle favorite status
    func toggleFavorite() {
        CoreDataManager.shared.toggleFavorite(id: product.objectID)
        
        // Refresh the product with updated data
        refreshProduct()
    }
    
    // Make sure refreshProduct() handles errors properly:
    private func refreshProduct() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if the object still exists in the context
                if self.product.managedObjectContext == nil {
                    // Object has been deleted from the context
                    NotificationCenter.default.post(name: NSNotification.Name("ProductDeleted"), object: self.product.objectID)
                    return
                }
                
                // Safely try to get the updated object
                let updatedProduct = try CoreDataManager.shared.viewContext.existingObject(with: self.product.objectID)
                
                if let userProduct = updatedProduct as? UserProduct {
                    self.product = userProduct
                } else {
                    print("Object is not a UserProduct")
                    NotificationCenter.default.post(name: NSNotification.Name("ProductDeleted"), object: self.product.objectID)
                }
            } catch {
                print("Error refreshing product: \(error)")
                // Object was deleted or otherwise unavailable - notify to dismiss the view
                NotificationCenter.default.post(name: NSNotification.Name("ProductDeleted"), object: self.product.objectID)
            }
        }
    }
    
    // Calculate days until expiry
    var daysUntilExpiry: Int? {
        guard let expireDate = product.expireDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let expiry = Calendar.current.startOfDay(for: expireDate)
        
        let components = Calendar.current.dateComponents([.day], from: today, to: expiry)
        return components.day
    }
    
    // Formatted expire date string
    var expiryDateString: String {
        guard let expireDate = product.expireDate else { return "No expiry date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "Expires on \(formatter.string(from: expireDate))"
    }
    
    // Also modify the submitReview function to handle cancellations properly:
    func cancelReview() {
        // Reset form
        reviewRating = 3
        reviewTitle = ""
        reviewText = ""
        showReviewForm = false
    }
    
    // Add this method to ProductDetailViewModel:

    // Delete current product
    func deleteProduct() {
        // Cancel any pending notifications
        NotificationService.shared.cancelNotification(for: product)
        
        // Delete from Core Data
        CoreDataManager.shared.deleteProduct(id: product.objectID)
        
        // Post notification so lists can update
        NotificationCenter.default.post(
            name: NSNotification.Name("ProductDeleted"), 
            object: product.objectID
        )
    }

    // MARK: - Beauty Bags & Tags
    func fetchBagsAndTags() {
        allBags = CoreDataManager.shared.fetchBeautyBags()
        allTags = CoreDataManager.shared.fetchProductTags()
    }

    func bagsForProduct() -> [BeautyBag] {
        (product.bags as? Set<BeautyBag>)?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
    }

    func tagsForProduct() -> [ProductTag] {
        (product.tags as? Set<ProductTag>)?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
    }

    func addProductToBag(_ bag: BeautyBag) {
        CoreDataManager.shared.addProduct(product, toBag: bag)
        refreshProduct()
    }

    func removeProductFromBag(_ bag: BeautyBag) {
        CoreDataManager.shared.removeProduct(product, fromBag: bag)
        refreshProduct()
    }

    func addTagToProduct(_ tag: ProductTag) {
        CoreDataManager.shared.addTag(tag, toProduct: product)
        refreshProduct()
    }

    func removeTagFromProduct(_ tag: ProductTag) {
        CoreDataManager.shared.removeTag(tag, fromProduct: product)
        refreshProduct()
    }
}

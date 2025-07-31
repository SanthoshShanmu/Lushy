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
        
        // Subscribe to Core Data saves to refresh product
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshProduct() }
            .store(in: &cancellables)
        // Subscribe to profile refresh to reload available bags
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fetchBagsAndTags() }
            .store(in: &cancellables)
        // Subscribe to tags sync to reload tags
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTags"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fetchBagsAndTags() }
            .store(in: &cancellables)
        // Initial load of bags, tags, and refresh product relationships
        fetchBagsAndTags()
        // Fetch backend detail to sync tags and bags associations
        refreshRemoteDetail()
        // Load latest product including relationships (tags, bags)
        refreshProduct()
    }
    
    /// Fetch a single product from backend and update local Core Data relationships
    private func refreshRemoteDetail() {
        guard let userId = AuthService.shared.userId,
              let prodBackendId = product.backendId else { return }
        APIService.shared.fetchUserProduct(userId: userId, productId: prodBackendId) { [weak self] result in
            switch result {
            case .success(let backendProd):
                DispatchQueue.main.async {
                    let ctx = CoreDataManager.shared.viewContext
                    ctx.performAndWait {
                        // Update tag relationships only if backend returned any
                        if let fetchedTags = backendProd.tags, !fetchedTags.isEmpty {
                            // Clear existing and attach new
                            (self?.product.tags as? Set<ProductTag> ?? []).forEach { self?.product.removeFromTags($0) }
                            for summary in fetchedTags {
                                if let tag = CoreDataManager.shared.fetchProductTags().first(where: { $0.backendId == summary.id }) {
                                    self?.product.addToTags(tag)
                                }
                            }
                        }
                        // Update bag relationships only if backend returned any
                        if let fetchedBags = backendProd.bags, !fetchedBags.isEmpty {
                            (self?.product.bags as? Set<BeautyBag> ?? []).forEach { self?.product.removeFromBags($0) }
                            for summary in fetchedBags {
                                if let bag = CoreDataManager.shared.fetchBeautyBags().first(where: { $0.backendId == summary.id }) {
                                    self?.product.addToBags(bag)
                                }
                            }
                        }
                        try? ctx.save()
                    }
                    self?.refreshProduct()
                }
            case .failure:
                break
            }
        }
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
        
        // Save review locally - CoreDataManager handles backend sync and activity creation
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
        // Remove backend sync - CoreDataManager already handles this
        NotificationService.shared.scheduleExpiryNotification(for: product)
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
        // Remove backend sync - CoreDataManager handles this
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
        return Calendar.current.dateComponents([.day], from: today, to: expiry).day
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
        // Load current local tags first
        allTags = CoreDataManager.shared.fetchProductTags()
        if let userId = AuthService.shared.userId {
            APIService.shared.fetchUserTags(userId: userId) { [weak self] result in
                switch result {
                case .success(let summaries):
                    // Merge remote tag definitions: update existing or add new
                    let localTags = CoreDataManager.shared.fetchProductTags()
                    for summary in summaries {
                        if let tag = localTags.first(where: { $0.backendId == summary.id }) {
                            // update name/color if changed
                            tag.name = summary.name
                            tag.color = summary.color
                        } else {
                            _ = CoreDataManager.shared.createProductTag(name: summary.name, color: summary.color, backendId: summary.id)
                        }
                    }
                case .failure:
                    break
                }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // Deduplicate bags as before
                    let rawBags = CoreDataManager.shared.fetchBeautyBags()
                    var uniqueBags: [BeautyBag] = []
                    var seenKeys = Set<String>()
                    for bag in rawBags {
                        let key = bag.backendId ?? bag.objectID.uriRepresentation().absoluteString
                        if !seenKeys.contains(key) {
                            seenKeys.insert(key)
                            uniqueBags.append(bag)
                        }
                    }
                    self.allBags = uniqueBags
                    self.allTags = CoreDataManager.shared.fetchProductTags()
                }
            }
        } else {
            // Local-only mode
            let rawBags = CoreDataManager.shared.fetchBeautyBags()
            var uniqueBags: [BeautyBag] = []
            var seenKeys = Set<String>()
            for bag in rawBags {
                let key = bag.backendId ?? bag.objectID.uriRepresentation().absoluteString
                if !seenKeys.contains(key) {
                    seenKeys.insert(key)
                    uniqueBags.append(bag)
                }
            }
            allBags = uniqueBags
            allTags = CoreDataManager.shared.fetchProductTags()
        }
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
    
    // Calculate average rating from reviews
    var rating: Double {
        let reviews = (product.reviews as? Set<Review>) ?? []
        guard !reviews.isEmpty else { return 0.0 }
        let total = reviews.reduce(0.0) { $0 + Double($1.rating) }
        return total / Double(reviews.count)
    }

    // Increment usage count, marking as opened if first use
    func incrementUsage() {
        if product.openDate == nil {
            // First use also marks as opened
            markAsOpened()
        }
        // Increment usage count
        CoreDataManager.shared.incrementUsage(id: product.objectID)
        refreshProduct()
    }
}

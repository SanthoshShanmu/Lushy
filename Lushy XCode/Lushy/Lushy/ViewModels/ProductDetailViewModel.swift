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
    @Published var isLoading = false
    @Published var error: String?
    // Flag to stop further network / observer work after deletion
    @Published private(set) var isDeleted: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let productId: String

    // Computed property to check if editing should be disabled (for finished products)
    var isEditingDisabled: Bool {
        return product.isFinished
    }

    // Get compliance advisory for current region
    var complianceAdvisory: String {
        // Get user's region from UserDefaults
        let region = UserDefaults.standard.string(forKey: "userRegion") ?? "GLOBAL"
        
        switch region {
        case "EU":
            return "🇪🇺 This product complies with EU cosmetics regulations. Check expiry dates and discontinue use if irritation occurs."
        case "US":
            return "🇺🇸 This product follows FDA cosmetics guidelines. Always patch test new products and check ingredient lists for allergens."
        case "JP":
            return "🇯🇵 This product meets Japanese cosmetics standards. Follow PAO guidelines and store in appropriate conditions."
        default:
            return "🌍 Follow local cosmetics regulations in your region. Always check expiry dates and discontinue use if irritation occurs."
        }
    }
    
    // Check if user has already reviewed this product
    var hasUserReviewed: Bool {
        guard let reviews = product.reviews as? Set<Review> else { return false }
        return !reviews.isEmpty
    }
    
    // Number of reviews for this product
    var reviewCount: Int {
        guard let reviews = product.reviews as? Set<Review> else { return 0 }
        return reviews.count
    }

    // Compute days until expiry for UI badges
    var daysUntilExpiry: Int? {
        guard let expire = product.expireDate else { return nil }
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: expire)
        return comps.day
    }

    init(product: UserProduct) {
        self.product = product
        self.productId = product.backendId ?? ""
        
        // Subscribe to Core Data saves to refresh product with debouncing
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main) // Add debouncing
            .sink { [weak self] _ in self?.refreshProduct() }
            .store(in: &cancellables)
        // Subscribe to profile refresh to reload available bags
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Add debouncing
            .sink { [weak self] _ in self?.fetchBagsAndTags() }
            .store(in: &cancellables)
        // Subscribe to tags sync to reload tags
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTags"))
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Add debouncing
            .sink { [weak self] _ in self?.fetchBagsAndTags() }
            .store(in: &cancellables)
        
        // Subscribe to ProductFinished notifications to automatically show review form
        NotificationCenter.default.publisher(for: NSNotification.Name("ProductFinished"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // Check if the finished product is this specific product
                if let finishedProductID = notification.object as? NSManagedObjectID,
                   finishedProductID == self.product.objectID {
                    // Automatically show the review form when this product is finished
                    self.showReviewForm = true
                }
            }
            .store(in: &cancellables)
        
        // Initial load of bags, tags, and refresh product relationships
        fetchBagsAndTags()
        // Sync remote metadata, tags, bags for this product
        refreshRemoteDetail()
        // Load latest product including relationships (tags, bags)
        refreshProduct()
    }
    
    /// Fetch a single product from backend and update local Core Data relationships
    func refreshRemoteDetail() {
        // Prevent further remote lookups if product deleted
        if isDeleted { return }
        guard let userId = AuthService.shared.userId,
              let prodBackendId = product.backendId else { 
            print("❌ refreshRemoteDetail failed: Missing userId or product backendId")
            print("   userId: \(AuthService.shared.userId ?? "nil")")
            print("   backendId: \(product.backendId ?? "nil")")
            return 
        }
        
        print("🔄 refreshRemoteDetail starting for product: \(prodBackendId)")
        
        APIService.shared.fetchUserProduct(userId: userId, productId: prodBackendId) { [weak self] result in
            guard let self = self, !self.isDeleted else { return }
            switch result {
            case .success(let backendProd):
                print("✅ refreshRemoteDetail succeeded for product: \(prodBackendId)")
                DispatchQueue.main.async {
                    // Clear any previous error state since the call succeeded
                    self.error = nil
                    
                    let ctx = CoreDataManager.shared.viewContext
                    ctx.performAndWait {
                        // Ensure tag definitions exist locally for any fetched tags
                        if let fetchedTags = backendProd.tags {
                            let localTags = CoreDataManager.shared.fetchProductTags()
                            for summary in fetchedTags {
                                if !localTags.contains(where: { $0.backendId == summary.id }) {
                                    if let newTagId = CoreDataManager.shared.createProductTag(name: summary.name, color: summary.color, backendId: summary.id) {
                                        CoreDataManager.shared.updateProductTagBackendId(id: newTagId, backendId: summary.id)
                                    }
                                }
                            }
                        }
                        // Ensure bag definitions exist locally for any fetched bags
                        if let fetchedBags = backendProd.bags {
                            let localBags = CoreDataManager.shared.fetchBeautyBags()
                            for summary in fetchedBags {
                                if !localBags.contains(where: { $0.backendId == summary.id }) {
                                    if let newBagId = CoreDataManager.shared.createBeautyBag(name: summary.name, color: "lushyPink", icon: "bag.fill") {
                                        CoreDataManager.shared.updateBeautyBagBackendId(id: newBagId, backendId: summary.id)
                                    }
                                }
                            }
                        }
                        
                        // Refresh local collections after creating new entities
                        let refreshedTags = CoreDataManager.shared.fetchProductTags()
                        let refreshedBags = CoreDataManager.shared.fetchBeautyBags()
                        
                        // Update tag relationships only if backend returned any
                        if let fetchedTags = backendProd.tags, !fetchedTags.isEmpty {
                            (self.product.tags as? Set<ProductTag> ?? []).forEach { self.product.removeFromTags($0) }
                            for summary in fetchedTags {
                                if let tag = refreshedTags.first(where: { $0.backendId == summary.id }) {
                                    self.product.addToTags(tag)
                                }
                            }
                        }
                        
                        // Update bag relationships only if backend returned any
                        if let fetchedBags = backendProd.bags, !fetchedBags.isEmpty {
                            (self.product.bags as? Set<BeautyBag> ?? []).forEach { self.product.removeFromBags($0) }
                            for summary in fetchedBags {
                                if let bag = refreshedBags.first(where: { $0.backendId == summary.id }) {
                                    self.product.addToBags(bag)
                                }
                            }
                        }
                        
                        // Sync core metadata fields from backend - handle new nested structure
                        self.product.productName = backendProd.productName
                        self.product.brand = backendProd.brand
                        self.product.purchaseDate = backendProd.purchaseDate
                        self.product.openDate = backendProd.openDate
                        self.product.expireDate = backendProd.expireDate
                        self.product.favorite = backendProd.favorite
                        self.product.isFinished = backendProd.isFinished
                        self.product.finishDate = backendProd.finishDate
                        self.product.currentAmount = backendProd.currentAmount
                        self.product.timesUsed = backendProd.timesUsed
                        
                        // Update product catalog fields from nested product
                        self.product.barcode = backendProd.product.barcode
                        self.product.periodsAfterOpening = backendProd.product.periodsAfterOpening
                        self.product.vegan = backendProd.product.vegan
                        self.product.crueltyFree = backendProd.product.crueltyFree
                        
                        // Handle image from product catalog
                        if let imageData = backendProd.product.imageData,
                           let mimeType = backendProd.product.imageMimeType {
                            self.product.imageUrl = "data:\(mimeType);base64,\(imageData)"
                        } else {
                            self.product.imageUrl = backendProd.product.imageUrl
                        }
                        
                        // Update user-specific metadata
                        if let shade = backendProd.shade { self.product.shade = shade }
                        if let sizeValue = backendProd.sizeInMl { self.product.sizeInMl = sizeValue }
                        if let spfValue = backendProd.spf { self.product.spf = Int16(spfValue) }
                        
                        try? ctx.save()
                    }
                    self.refreshProduct()
                }
            case .failure(let error):
                print("❌ refreshRemoteDetail failed for product: \(prodBackendId)")
                print("   Error type: \(type(of: error))")
                print("   Error description: \(error.localizedDescription)")
                print("   APIError details: \(error)")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isDeleted else { return }
                    // Show more detailed error message for debugging
                    self.error = "Failed to refresh from server: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Add a comment to the product - now creates Usage Journey event
    func addComment() {
        guard !newComment.isEmpty else { return }
        
        // Create Usage Journey event instead of regular comment
        CoreDataManager.shared.addUsageJourneyEventNew(
            to: product.objectID,
            type: UsageJourneyEvent.EventType.thought,
            text: newComment,
            title: nil,
            rating: 0
        )
        
        newComment = "" // Reset comment field
    }
    
    // Submit a review for the product
    func submitReview() {
        guard !reviewTitle.isEmpty && !reviewText.isEmpty else { return }
        
        // Check if user has already reviewed this product
        if hasUserReviewed {
            return // Prevent multiple reviews
        }
        
        // Save review locally - CoreDataManager handles backend sync and activity creation
        CoreDataManager.shared.addReview(
            to: product.objectID,
            rating: reviewRating,
            title: reviewTitle,
            text: reviewText
        )
        
        // Automatically mark product as finished after writing a review
        if !product.isFinished {
            CoreDataManager.shared.markProductAsFinished(id: product.objectID)
        }
        
        // Reset form
        reviewRating = 3
        reviewTitle = ""
        reviewText = ""
        showReviewForm = false
        
        // Refresh product to update UI
        refreshProduct()
    }
    
    // Mark product as opened
    func markAsOpened() {
        CoreDataManager.shared.markProductAsOpened(id: product.objectID, openDate: Date())
        // Remove backend sync - CoreDataManager already handles this
        NotificationService.shared.scheduleExpiryNotification(for: product)
        refreshProduct()
    }
    
    func markAsEmpty() {
        // Always finish the product first
        CoreDataManager.shared.markProductAsFinished(id: product.objectID)
        
        // Force review writing for finished products
        // Don't check if user has already reviewed - just show the form
        showReviewForm = true
    }
    
    // Toggle favorite status
    func toggleFavorite() {
        CoreDataManager.shared.toggleFavorite(id: product.objectID)
        // Remove the refreshProduct() call to prevent infinite loop
        // The Core Data observer will handle the refresh automatically
    }
    
    // Make sure refreshProduct() handles errors properly:
    private func refreshProduct() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isDeleted { return }
            do {
                // Check if the object still exists in the context
                if self.product.managedObjectContext == nil {
                    // Mark deleted & broadcast once
                    self.markAsDeletedAndCleanup()
                    return
                }
                let context = self.product.managedObjectContext ?? CoreDataManager.shared.viewContext
                let refreshed = try context.existingObject(with: self.product.objectID)
                if let up = refreshed as? UserProduct {
                    self.product = up
                }
            } catch {
                self.error = "Failed to refresh product locally."
            }
        }
    }
    
    func fetchBagsAndTags() {
        if isDeleted { return }
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
                    // Removed automatic refreshRemoteDetail() call here to prevent loops
                    // Only refresh product locally after bags/tags are loaded
                    self.refreshProduct()
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
    
    // Create usage tracking view model
    private var _usageTrackingViewModel: UsageTrackingViewModel?
    var usageTrackingViewModel: UsageTrackingViewModel {
        if _usageTrackingViewModel == nil {
            _usageTrackingViewModel = UsageTrackingViewModel(product: product)
        }
        return _usageTrackingViewModel!
    }

    // Legacy increment usage count (kept for compatibility)
    func incrementUsage() {
        if product.openDate == nil {
            // First use also marks as opened
            markAsOpened()
        }
        // Increment usage count
        CoreDataManager.shared.incrementUsage(id: product.objectID)
        refreshProduct()
    }
    
    /// Update editable product details and sync
    func updateDetails(
        productName: String,
        brand: String?,
        shade: String?,
        sizeInMl: Double?,
        spf: Int?,
        purchaseDate: Date,
        isOpened: Bool,
        openDate: Date?,
        periodsAfterOpening: String?
    ) {
        CoreDataManager.shared.updateProductDetails(
            id: product.objectID,
            productName: productName,
            brand: brand,
            shade: shade,
            sizeInMl: sizeInMl,
            spf: spf,
            purchaseDate: purchaseDate,
            isOpened: isOpened,
            openDate: openDate,
            periodsAfterOpening: periodsAfterOpening
        )
        refreshProduct()
        // Removed automatic refreshRemoteDetail() call to prevent infinite loops
        // Remote details will be refreshed when explicitly needed (onAppear, manual refresh, etc.)
    }
    
    // New: bulk update helpers so UI can edit tags/bags in one sheet
    func updateBags(to selectedBags: Set<BeautyBag>) {
        let current = Set(bagsForProduct())
        let toAdd = selectedBags.subtracting(current)
        let toRemove = current.subtracting(selectedBags)
        toAdd.forEach { addProductToBag($0) }
        toRemove.forEach { removeProductFromBag($0) }
    }

    func updateTags(to selectedTags: Set<ProductTag>) {
        let current = Set(tagsForProduct())
        let toAdd = selectedTags.subtracting(current)
        let toRemove = current.subtracting(selectedTags)
        toAdd.forEach { addTagToProduct($0) }
        toRemove.forEach { removeTagFromProduct($0) }
    }
    
    // Delete product and notify UI to dismiss detail view
    func deleteProduct() {
        if isDeleted { return }
        
        // Mark as deleted immediately to prevent any further operations
        markAsDeletedAndCleanup()
        
        // Cancel any pending local notification for this product
        NotificationService.shared.cancelNotification(for: product)
        
        let id = product.objectID
        let backendId = product.backendId
        let userId = AuthService.shared.userId
        
        // Perform local deletion WITHOUT triggering notifications to avoid loops
        let context = CoreDataManager.shared.viewContext
        context.perform {
            guard let productToDelete = try? context.existingObject(with: id) as? UserProduct else { return }
            context.delete(productToDelete)
            try? context.save()
            
            // Only fire backend deletion if we have the needed IDs
            if let backendId = backendId, let userId = userId {
                let url = APIService.shared.baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent(userId)
                    .appendingPathComponent("products")
                    .appendingPathComponent(backendId)
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                if let token = AuthService.shared.token { 
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") 
                }
                URLSession.shared.dataTask(with: request).resume()
            }
            
            // Post single refresh notification on main thread after deletion completes
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
            }
        }
    }

    private func markAsDeletedAndCleanup() {
        if isDeleted { return }
        isDeleted = true
        // Stop any future sinks
        cancellables.removeAll()
        // Post single notification for UI dismissal
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(name: NSNotification.Name("ProductDeleted"), object: self.product.objectID)
        }
    }
}

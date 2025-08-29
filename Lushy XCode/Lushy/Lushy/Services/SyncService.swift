import Foundation
import Combine
import CoreData

class SyncService {
    static let shared = SyncService()
    
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false
    private var didInitialSync = false
    
    // Add sync queue and semaphore to prevent concurrent operations
    private let syncQueue = DispatchQueue(label: "com.lushy.syncservice", qos: .utility)
    private let syncSemaphore = DispatchSemaphore(value: 1)
    private var lastSyncTime: Date?
    private let minimumSyncInterval: TimeInterval = 2.0 // Minimum 2 seconds between syncs
    
    private init() {
        // Subscribe to user changes
        AuthService.shared.$currentUserId
            .compactMap { $0 } // Only when userId is non-nil
            .sink { [weak self] userId in
                self?.performInitialSync()
            }
            .store(in: &cancellables)
    }
    
    func performInitialSync() {
        // Only perform once per app launch
        guard !didInitialSync else { return }
        didInitialSync = true

        // Fetch tags, then bags, then products sequentially
        fetchRemoteTags {
            self.fetchRemoteBags {
                self.fetchRemoteProducts()
            }
        }
    }
    
    // Public: Force refresh of all entities from backend in order
    func refreshAllFromBackend() {
        // Throttle frequent refresh calls
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we need to throttle
            let now = Date()
            if let lastSync = self.lastSyncTime, 
               now.timeIntervalSince(lastSync) < self.minimumSyncInterval {
                print("SyncService: Throttling refresh request")
                return
            }
            
            self.lastSyncTime = now
            
            // Use semaphore to prevent concurrent syncs
            self.syncSemaphore.wait()
            defer { self.syncSemaphore.signal() }
            
            DispatchQueue.main.async {
                self.fetchRemoteTags { [weak self] in
                    self?.fetchRemoteBags { [weak self] in
                        self?.fetchRemoteProducts()
                    }
                }
            }
        }
    }
    
    // Force a server-authoritative refresh when app returns to foreground
    func performAuthoritativeRefresh() {
        // Always refetch all entities (tags, bags, products) regardless of didInitialSync
        fetchRemoteTags { [weak self] in
            self?.fetchRemoteBags { [weak self] in
                self?.fetchRemoteProducts()
            }
        }
    }
    
    // Fetch remote product tags and import
    private func fetchRemoteTags(completion: @escaping () -> Void) {
        guard let userId = AuthService.shared.userId else { completion(); return }
        APIService.shared.fetchUserTags(userId: userId) { result in
            switch result {
            case .success(let summaries):
                let context = CoreDataManager.shared.viewContext
                context.performAndWait {
                    // Build remote id set
                    let remoteIds = Set(summaries.map { $0.id })
                    // Import/update existing
                    let localTags = CoreDataManager.shared.fetchProductTags()
                    let existingByBackend: [String: ProductTag] = Dictionary(uniqueKeysWithValues: localTags.compactMap { tag -> (String, ProductTag)? in
                        guard let bid = tag.backendId else { return nil }
                        return (bid, tag)
                    })
                    for summary in summaries {
                        if let tag = existingByBackend[summary.id] {
                            tag.name = summary.name
                            tag.color = summary.color
                        } else {
                            _ = CoreDataManager.shared.createProductTag(name: summary.name, color: summary.color, backendId: summary.id)
                        }
                    }
                    // Prune local tags not present on server
                    for tag in localTags {
                        if let bid = tag.backendId {
                            if !remoteIds.contains(bid) {
                                CoreDataManager.shared.deleteProductTag(tag)
                            }
                        } else {
                            // Remove any local-only tags (no backend)
                            CoreDataManager.shared.deleteProductTag(tag)
                        }
                    }
                    try? context.save()
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshTags"), object: nil)
                    completion()
                }
            case .failure:
                completion()
            }
        }
        
        // After merge, prune any local tags not present remotely (backend is source of truth)
        let context = CoreDataManager.shared.viewContext
        context.performAndWait {
            // Fetch current local tags
            let request: NSFetchRequest<ProductTag> = ProductTag.fetchRequest()
            if let localTags = try? context.fetch(request) {
                // Build remote ID set from CoreData after network merge
                let remoteIds = Set(CoreDataManager.shared.fetchProductTags().compactMap { $0.backendId })
                for tag in localTags {
                    // Remove any tag with a backendId not in remote set, or tags without backendId
                    if let bid = tag.backendId {
                        if !remoteIds.contains(bid) {
                            context.delete(tag)
                        }
                    } else {
                        // No local-only tags allowed
                        context.delete(tag)
                    }
                }
                try? context.save()
            }
        }
    }
    
    // Fetch products from backend and merge with local
    func fetchRemoteProducts() {
        APIService.shared.fetchUserProductsFromBackend()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error syncing with backend: \(error)")
                }
            }, receiveValue: { backendProducts in
                self.mergeBackendProducts(backendProducts)
                
                // Prune any local products not present remotely and remove unsynced ones (no backendId)
                let context = CoreDataManager.shared.viewContext
                let remoteIds = Set(backendProducts.map { $0.id })
                context.performAndWait {
                    let fetchRequest: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
                    if let localProducts = try? context.fetch(fetchRequest) {
                        for product in localProducts {
                            if let bid = product.backendId {
                                if !remoteIds.contains(bid) {
                                    // Stale local product – delete
                                    context.delete(product)
                                }
                            } else {
                                // Local-only product not permitted – delete
                                context.delete(product)
                            }
                        }
                        do { try context.save() } catch {
                            print("Error pruning local products: \(error)")
                        }
                    }
                }
                
                // Notify listeners products changed
                NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
            })
            .store(in: &cancellables)
    }
    
    // Fetch remote user profile to sync beauty bags
    private func fetchRemoteBags(completion: @escaping () -> Void) {
        guard let userId = AuthService.shared.userId else { completion(); return }
        APIService.shared.fetchUserBags(userId: userId) { result in
            switch result {
            case .success(let summaries):
                let context = CoreDataManager.shared.viewContext
                context.performAndWait {
                    let localBags = CoreDataManager.shared.fetchBeautyBags()
                    
                    // Create dictionary safely, handling duplicates by keeping the first occurrence
                    var existingByBackend = [String: BeautyBag]()
                    for bag in localBags {
                        if let bid = bag.backendId, existingByBackend[bid] == nil {
                            existingByBackend[bid] = bag
                        }
                    }
                    
                    let remoteIds = Set(summaries.map { $0.id })
                    for summary in summaries {
                        if let bag = existingByBackend[summary.id] {
                            // update properties if needed
                            bag.name = summary.name
                            bag.color = summary.color ?? "lushyPink"
                            bag.icon = summary.icon ?? "bag.fill"
                        } else {
                            if let newID = CoreDataManager.shared.createBeautyBag(name: summary.name, color: summary.color ?? "lushyPink", icon: summary.icon ?? "bag.fill") {
                                CoreDataManager.shared.updateBeautyBagBackendId(id: newID, backendId: summary.id)
                            }
                        }
                    }
                    // Delete local bags not present remotely AND any without backendId
                    for bag in localBags {
                        if let bid = bag.backendId {
                            if !remoteIds.contains(bid) {
                                CoreDataManager.shared.deleteBeautyBag(bag)
                            }
                        } else {
                            CoreDataManager.shared.deleteBeautyBag(bag)
                        }
                    }
                    try? context.save()
                }
                DispatchQueue.main.async {
                    // Notify UI of bag updates
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
                    completion()
                }
            case .failure:
                completion()
            }
        }
    }
    
    // Merge backend products with CoreData
    private func mergeBackendProducts(_ backendProducts: [BackendUserProduct]) {
        let context = CoreDataManager.shared.viewContext
        
        context.performAndWait {
            for backendProduct in backendProducts {
                print("Debug: backendProduct.id=\(backendProduct.id), barcode=\(backendProduct.barcode), purchaseDate=\(backendProduct.purchaseDate)")
                // Check if product already exists locally by backendId first (to match stubs), else by barcode
                if let local = CoreDataManager.shared.fetchUserProduct(backendId: backendProduct.id) {
                    self.updateLocalProduct(local, with: backendProduct)
                } else {
                    let productToSync = self.createLocalProduct(from: backendProduct, in: context)
                    // Sync tag relationships
                    if let tagSummaries = backendProduct.tags {
                        (productToSync.tags as? Set<ProductTag> ?? []).forEach { productToSync.removeFromTags($0) }
                        for summary in tagSummaries {
                            if let tag = CoreDataManager.shared.fetchProductTags().first(where: { $0.backendId == summary.id }) {
                                productToSync.addToTags(tag)
                            }
                        }
                    }
                    // Sync bag relationships
                    if let bagSummaries = backendProduct.bags {
                        // clear existing
                        (productToSync.bags as? Set<BeautyBag> ?? []).forEach { productToSync.removeFromBags($0) }
                        for summary in bagSummaries {
                            if let bag = CoreDataManager.shared.fetchBeautyBags().first(where: { $0.backendId == summary.id }) {
                                productToSync.addToBags(bag)
                            }
                        }
                    }
                }
            } // for
            do {
                try context.save()
            } catch {
                print("Error merging backend products: \(error)")
            }
        }
    }
    
    // Update local product with backend data - handle new referential structure
    private func updateLocalProduct(_ localProduct: UserProduct, with backendProduct: BackendUserProduct) {
        // Update user-specific fields
        localProduct.purchaseDate = backendProduct.purchaseDate
        localProduct.openDate = backendProduct.openDate
        localProduct.expireDate = backendProduct.expireDate
        localProduct.isFinished = backendProduct.isFinished
        localProduct.finishDate = backendProduct.finishDate
        localProduct.currentAmount = backendProduct.currentAmount
        localProduct.timesUsed = backendProduct.timesUsed
        localProduct.quantity = Int32(backendProduct.quantity)
        
        // Update product catalog fields from nested product object
        localProduct.barcode = backendProduct.product.barcode
        localProduct.productName = backendProduct.product.productName
        localProduct.brand = backendProduct.product.brand
        localProduct.periodsAfterOpening = backendProduct.product.periodsAfterOpening
        localProduct.vegan = backendProduct.product.vegan
        localProduct.crueltyFree = backendProduct.product.crueltyFree
        localProduct.shade = backendProduct.product.shade
        localProduct.sizeInMl = backendProduct.product.sizeInMl ?? 0
        localProduct.spf = Int16(backendProduct.product.spf ?? 0)
        
        // Handle image URL from product catalog
        if let imageData = backendProduct.product.imageData,
           let mimeType = backendProduct.product.imageMimeType {
            localProduct.imageUrl = "data:\(mimeType);base64,\(imageData)"
        } else {
            localProduct.imageUrl = backendProduct.product.imageUrl
        }
        
        // Ensure required Core Data fields are populated
        localProduct.userId = AuthService.shared.userId ?? localProduct.userId
        localProduct.backendId = backendProduct.id // <-- set backendId
    }
    
    // Create new local product from backend data - handle new referential structure
    // Returns the created UserProduct so we can set up relationships
    private func createLocalProduct(from backendProduct: BackendUserProduct, in context: NSManagedObjectContext) -> UserProduct {
        let product = UserProduct(context: context)
        
        // Set product catalog fields from nested product object
        product.barcode = backendProduct.product.barcode
        product.productName = backendProduct.product.productName
        product.brand = backendProduct.product.brand
        product.periodsAfterOpening = backendProduct.product.periodsAfterOpening
        product.vegan = backendProduct.product.vegan
        product.crueltyFree = backendProduct.product.crueltyFree
        
        // Set product-specific attributes from product catalog
        product.shade = backendProduct.product.shade
        product.sizeInMl = backendProduct.product.sizeInMl ?? 0
        product.spf = Int16(backendProduct.product.spf ?? 0)
        
        // Handle image URL from product catalog
        if let imageData = backendProduct.product.imageData,
           let mimeType = backendProduct.product.imageMimeType {
            product.imageUrl = "data:\(mimeType);base64,\(imageData)"
        } else {
            product.imageUrl = backendProduct.product.imageUrl
        }
        
        // Set user-specific fields
        product.purchaseDate = backendProduct.purchaseDate
        product.openDate = backendProduct.openDate
        product.expireDate = backendProduct.expireDate
        product.isFinished = backendProduct.isFinished
        product.finishDate = backendProduct.finishDate
        product.currentAmount = backendProduct.currentAmount
        product.timesUsed = backendProduct.timesUsed
        product.quantity = Int32(backendProduct.quantity)
        
        // Set metadata
        product.userId = AuthService.shared.userId ?? ""
        product.backendId = backendProduct.id
        
        return product
    }
    
    // Sync local product to backend
    func syncProductToBackend(_ product: UserProduct) {
        print("SyncService: Starting sync for product: \(product.productName ?? "Unknown")")
        
        // Skip if already synced (has backend ID)
        if product.backendId != nil {
            print("Product already has backendId, skipping sync")
            return
        }
        
        APIService.shared.syncProductWithBackend(product: product)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error syncing product to backend: \(error.localizedDescription)")
                    // Remove local-only product to maintain server authority
                    if let ctx = product.managedObjectContext {
                        ctx.performAndWait { ctx.delete(product); try? ctx.save() }
                    }
                }
            }, receiveValue: { backendId in
                print("✅ Product synced successfully with backend ID: \(backendId)")
                
                // New product created - assign backend ID and save
                product.backendId = backendId
                try? CoreDataManager.shared.viewContext.save()
                
                // Refresh the feed to show the new activity
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                }
                
                // Persist any existing local tag relationships
                if let tagSet = product.tags as? Set<ProductTag> {
                    for tag in tagSet {
                        if let tagBackendId = tag.backendId, let userId = AuthService.shared.userId {
                            APIService.shared.updateProductTags(userId: userId, productId: backendId, addTagId: tagBackendId)
                        }
                    }
                }
                // Persist any existing local bag relationships
                if let bagSet = product.bags as? Set<BeautyBag> {
                    for bag in bagSet where bag.backendId != nil {
                        CoreDataManager.shared.addProduct(product, toBag: bag)
                    }
                }
            })
            .store(in: &cancellables)
    }
}

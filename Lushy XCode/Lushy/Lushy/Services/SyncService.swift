import Foundation
import Combine
import CoreData

class SyncService {
    static let shared = SyncService()
    
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false
    private var didInitialSync = false
    
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
    
    // Fetch remote product tags and import
    private func fetchRemoteTags(completion: @escaping () -> Void) {
        guard let userId = AuthService.shared.userId else { completion(); return }
        APIService.shared.fetchUserTags(userId: userId) { result in
            switch result {
            case .success(let tags):
                let context = CoreDataManager.shared.viewContext
                context.performAndWait {
                    // Merge remote tag definitions: update existing or add new
                    let fetchRequest: NSFetchRequest<ProductTag> = ProductTag.fetchRequest()
                    let existingTags = (try? context.fetch(fetchRequest)) ?? []
                    let existingByBackend = Dictionary<String, ProductTag>(uniqueKeysWithValues: existingTags.compactMap { tag in
                        guard let bid = tag.backendId else { return nil }
                        return (bid, tag)
                    })
                    for summary in tags {
                        let bid = summary.id
                        if let localTag = existingByBackend[bid] {
                            // update properties
                            localTag.name = summary.name
                            localTag.color = summary.color
                        } else {
                            // create new tag
                            let newTag = ProductTag(context: context)
                            newTag.name = summary.name
                            newTag.color = summary.color
                            newTag.backendId = summary.id
                            newTag.userId = userId
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
            })
            .store(in: &cancellables)
    }
    
    // Fetch remote user profile to sync beauty bags
    private func fetchRemoteBags(completion: @escaping () -> Void) {
        guard let userId = AuthService.shared.userId else { completion(); return }
        APIService.shared.fetchUserBags(userId: userId) { result in
            switch result {
            case .success(let summaries):
                // Avoid duplicates: only create new for missing backend IDs
                let existingIds = Set(CoreDataManager.shared.fetchBeautyBags().compactMap { $0.backendId })
                for summary in summaries where !existingIds.contains(summary.id) {
                    if let newID = CoreDataManager.shared.createBeautyBag(name: summary.name, color: "lushyPink", icon: "bag.fill") {
                        CoreDataManager.shared.updateBeautyBagBackendId(id: newID, backendId: summary.id)
                    }
                }
                // Notify listeners to refresh
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
    
    /// Push all local Core Data products to backend to create missing userproducts and activities
    func syncAllLocalProducts() {
        let context = CoreDataManager.shared.viewContext
        let fetchRequest: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        // Only sync products that don't have a backend ID yet
        fetchRequest.predicate = NSPredicate(format: "backendId == nil")
        
        do {
            let products = try context.fetch(fetchRequest)
            print("Found \(products.count) local products to sync (unsynced only)")
            products.forEach { syncProductToBackend($0) }
        } catch {
            print("Failed to fetch products for sync: \(error)")
        }
    }
    
    // Merge backend products with CoreData
    private func mergeBackendProducts(_ backendProducts: [BackendUserProduct]) {
        let context = CoreDataManager.shared.viewContext
        
        context.performAndWait {
            for backendProduct in backendProducts {
                print("Debug: backendProduct.id=\(backendProduct.id), barcode=\(backendProduct.barcode), purchaseDate=\(backendProduct.purchaseDate)")
                // Check if product already exists locally by backendId first (to match stubs), else by barcode
                let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
                let predicateByBackend = NSPredicate(format: "backendId == %@", backendProduct.id)
                let predicateByBarcode = NSPredicate(format: "barcode == %@", backendProduct.barcode)
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicateByBackend, predicateByBarcode])
                let existingProducts = (try? context.fetch(request)) ?? []
                let productToSync: UserProduct
                if let existingProduct = existingProducts.first {
                    updateLocalProduct(existingProduct, from: backendProduct)
                    productToSync = existingProduct
                } else {
                    let newProduct = createLocalProduct(from: backendProduct, in: context)
                    productToSync = newProduct
                }
                // Sync tag relationships
                if let tagSummaries = backendProduct.tags {
                    // clear existing
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
            } // for
            do {
                try context.save()
            } catch {
                print("Error merging backend products: \(error)")
            }
        }
    }
    
    // Update local product with backend data
    private func updateLocalProduct(_ localProduct: UserProduct, from backendProduct: BackendUserProduct) {
        localProduct.productName = backendProduct.productName
        localProduct.brand = backendProduct.brand
        localProduct.imageUrl = backendProduct.imageUrl
        // Core Data model stores purchaseDate as Date
        localProduct.purchaseDate = backendProduct.purchaseDate
        if let openDate = backendProduct.openDate {
            localProduct.openDate = openDate
        }
        localProduct.periodsAfterOpening = backendProduct.periodsAfterOpening
        localProduct.vegan = backendProduct.vegan
        localProduct.crueltyFree = backendProduct.crueltyFree
        localProduct.favorite = backendProduct.favorite
        // Sync new metadata fields
        localProduct.shade = backendProduct.shade
        localProduct.sizeInMl = backendProduct.sizeInMl ?? 0.0
        localProduct.spf = Int16(backendProduct.spf ?? 0)
        // Ensure required Core Data fields are populated
        localProduct.barcode = backendProduct.barcode
        localProduct.userId = AuthService.shared.userId ?? localProduct.userId
        localProduct.backendId = backendProduct.id // <-- set backendId
    }
    
    // Create new local product from backend data
    // Returns the created UserProduct so we can set up relationships
    private func createLocalProduct(from backendProduct: BackendUserProduct, in context: NSManagedObjectContext) -> UserProduct {
        let product = UserProduct(context: context)
        product.barcode = backendProduct.barcode
        product.productName = backendProduct.productName
        product.brand = backendProduct.brand
        product.imageUrl = backendProduct.imageUrl
        // Core Data model stores purchaseDate as Date
        product.purchaseDate = backendProduct.purchaseDate
        if let openDate = backendProduct.openDate {
            product.openDate = openDate
        }
        product.periodsAfterOpening = backendProduct.periodsAfterOpening
        product.vegan = backendProduct.vegan
        product.crueltyFree = backendProduct.crueltyFree
        product.favorite = backendProduct.favorite
        // New metadata fields
        product.shade = backendProduct.shade
        product.sizeInMl = backendProduct.sizeInMl ?? 0.0
        product.spf = Int16(backendProduct.spf ?? 0)
        product.userId = AuthService.shared.userId ?? "guest"
        product.backendId = backendProduct.id // <-- set backendId
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
                }
            }, receiveValue: { backendId in
                // Assign returned backendId and save
                product.backendId = backendId
                try? CoreDataManager.shared.viewContext.save()
                print("Product synced successfully with backend ID: \(backendId)")
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
    
    // Add this method to manually sync a specific product
    func syncProductImmediately(_ product: UserProduct) {
        print("SyncService: Immediate sync requested for product: \(product.productName ?? "Unknown")")
        syncProductToBackend(product)
    }
    
    // Start comprehensive sync
    func startSync() {
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }
        
        guard AuthService.shared.isAuthenticated else {
            print("User not authenticated, skipping sync")
            return
        }
        
        isSyncing = true
        print("Starting comprehensive sync...")
        
        let products = CoreDataManager.shared.fetchUserProducts()
        let unSyncedProducts = products.filter { $0.backendId == nil }
        
        print("Found \(unSyncedProducts.count) products to sync")
        
        for product in unSyncedProducts {
            syncProductToBackend(product)
        }
        
        // Mark sync as complete after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSyncing = false
        }
    }
}

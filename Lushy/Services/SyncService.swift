import Foundation
import Combine
import CoreData

class SyncService {
    static let shared = SyncService()
    
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false
    
    private init() {
        // Subscribe to authentication changes
        AuthService.shared.$isAuthenticated
            .filter { $0 } // Only when authenticated
            .sink { [weak self] _ in
                self?.performInitialSync()
            }
            .store(in: &cancellables)
    }
    
    func performInitialSync() {
        syncAllLocalProducts()
        fetchRemoteProducts()
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
        
        for backendProduct in backendProducts {
            // Check if product already exists locally by barcode
            let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
            request.predicate = NSPredicate(format: "barcode == %@", backendProduct.barcode)
            
            do {
                let existingProducts = try context.fetch(request)
                
                if let existingProduct = existingProducts.first {
                    // Update existing product
                    updateLocalProduct(existingProduct, from: backendProduct)
                    existingProduct.backendId = backendProduct.id // <-- set backendId
                } else {
                    // Create new product
                    createLocalProduct(from: backendProduct, in: context)
                }
                
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
        localProduct.purchaseDate = Date(timeIntervalSince1970: backendProduct.purchaseDate)
        if let openDate = backendProduct.openDate {
            localProduct.openDate = Date(timeIntervalSince1970: openDate)
        }
        localProduct.periodsAfterOpening = backendProduct.periodsAfterOpening
        localProduct.vegan = backendProduct.vegan
        localProduct.crueltyFree = backendProduct.crueltyFree
        localProduct.favorite = backendProduct.favorite
        localProduct.backendId = backendProduct.id // <-- set backendId
    }
    
    // Create new local product from backend data
    private func createLocalProduct(from backendProduct: BackendUserProduct, in context: NSManagedObjectContext) {
        let product = UserProduct(context: context)
        product.barcode = backendProduct.barcode
        product.productName = backendProduct.productName
        product.brand = backendProduct.brand
        product.imageUrl = backendProduct.imageUrl
        product.purchaseDate = Date(timeIntervalSince1970: backendProduct.purchaseDate)
        if let openDate = backendProduct.openDate {
            product.openDate = Date(timeIntervalSince1970: openDate)
        }
        product.periodsAfterOpening = backendProduct.periodsAfterOpening
        product.vegan = backendProduct.vegan
        product.crueltyFree = backendProduct.crueltyFree
        product.favorite = backendProduct.favorite
        product.backendId = backendProduct.id // <-- set backendId
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
                switch completion {
                case .failure(let error):
                    print("Error syncing product to backend: \(error.localizedDescription)")
                case .finished:
                    print("Product sync completed successfully")
                }
            }, receiveValue: { success in
                if success {
                    print("Product synced successfully and backend ID stored")
                    
                    // Refresh the feed to show the new activity
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
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

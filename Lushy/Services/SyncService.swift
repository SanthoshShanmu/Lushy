import Foundation
import Combine
import CoreData

class SyncService {
    static let shared = SyncService()
    
    private var cancellables = Set<AnyCancellable>()
    
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
    }
    
    // Sync local product to backend
    func syncProductToBackend(_ product: UserProduct) {
        APIService.shared.syncProductWithBackend(product: product)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error syncing product to backend: \(error)")
                }
            }, receiveValue: { success in
                print("Product synced successfully: \(success)")
            })
            .store(in: &cancellables)
    }
}
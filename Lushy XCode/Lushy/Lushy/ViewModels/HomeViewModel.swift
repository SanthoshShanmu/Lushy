import Foundation
import CoreData
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var openProducts: [UserProduct] = []
    @Published var expiringProducts: [UserProduct] = []
    @Published var storedProducts: [UserProduct] = []
    @Published var selectedProduct: UserProduct?
    @Published var showProductDetail = false
    @Published var selectedBag: BeautyBag? = nil
    @Published var selectedTag: ProductTag? = nil
    @Published var allBags: [BeautyBag] = []
    @Published var allTags: [ProductTag] = []

    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    // Add throttling for fetch operations
    private var lastFetchTime: Date?
    private let minimumFetchInterval: TimeInterval = 1.0 // Increased to 1 second between fetches
    private var pendingFetchWorkItem: DispatchWorkItem?
    
    init() {
        print("HomeViewModel: initializing")
        
        fetchProducts()
        
        print("HomeViewModel: setting up notification listener")
        
        // Subscribe to context changes with throttling to prevent excessive updates
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Debounce rapid saves
            .sink { [weak self] _ in
                print("HomeViewModel: received context did save notification (debounced)")
                self?.fetchProductsThrottled()
            }
            .store(in: &cancellables)
        
        print("HomeViewModel: initialization complete")
    }
    
    // Enhanced throttled version of fetchProducts to prevent excessive calls
    private func fetchProductsThrottled() {
        // Cancel any pending fetch
        pendingFetchWorkItem?.cancel()
        
        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let now = Date()
            self.lastFetchTime = now
            self.fetchProducts()
        }
        
        pendingFetchWorkItem = workItem
        
        // Execute after delay to batch multiple rapid calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    // Fetch products and sort into sections
    func fetchProducts() {
        allBags = CoreDataManager.shared.fetchBeautyBags()
        allTags = CoreDataManager.shared.fetchProductTags()
        let allProducts = CoreDataManager.shared.fetchUserProducts()
        
        // Ensure we're on the main thread when fetching and updating UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Filter by bag if selected
            var filteredProducts = allProducts
            if let bag = self.selectedBag {
                filteredProducts = filteredProducts.filter { ($0.bags as? Set<BeautyBag>)?.contains(bag) == true }
            }
            
            // Filter by tag if selected
            if let tag = self.selectedTag {
                filteredProducts = filteredProducts.filter { ($0.tags as? Set<ProductTag>)?.contains(tag) == true }
            }
            
            // Sort products into categories
            let today = Date()
            
            // Products that have been opened
            self.openProducts = filteredProducts.filter { product in
                // Skip products that are marked as finished
                guard product.value(forKey: "isFinished") as? Bool != true else {
                    return false
                }
                
                guard let openDate = product.openDate else { return false }
                guard let expireDate = product.expireDate else { return true }
                return openDate <= today && expireDate > today
            }
            
            // Products that are expiring soon (within 30 days)
            self.expiringProducts = filteredProducts.filter { product in
                // Skip products that are marked as finished
                guard product.value(forKey: "isFinished") as? Bool != true else {
                    return false
                }
                
                guard let expireDate = product.expireDate else { return false }
                let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: today)!
                return expireDate <= thirtyDaysFromNow && expireDate > today
            }
            
            // Products in storage (purchased but not opened)
            self.storedProducts = filteredProducts.filter { product in
                // Skip products that are marked as finished
                guard product.value(forKey: "isFinished") as? Bool != true else {
                    return false
                }
                
                return product.openDate == nil
            }
        }
    }
    
    // Method for navigating to a specific product (e.g., from notifications)
    func navigateToProduct(with barcode: String) {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "barcode == %@", barcode),
            NSPredicate(format: "userId == %@", AuthService.shared.userId ?? "guest")
        ])
        do {
            let matchingProducts = try managedObjectContext.fetch(request)
            if let product = matchingProducts.first {
                selectedProduct = product
                showProductDetail = true
            }
        } catch {
            print("Error fetching product with barcode \(barcode): \(error)")
        }
    }
    
    // Mark a product as opened
    func markProductAsOpened(product: UserProduct) {
        CoreDataManager.shared.markProductAsOpened(id: product.objectID, openDate: Date())
        // Remove backend sync - CoreDataManager already handles this
        NotificationService.shared.scheduleExpiryNotification(for: product)
    }

    // Toggle favorite status
    func toggleFavorite(product: UserProduct) {
        let productID = product.objectID
        CoreDataManager.shared.toggleFavorite(id: productID)
        // Remove backend sync - CoreDataManager handles this
        DispatchQueue.main.async {
            if let updatedProduct = try? self.managedObjectContext.existingObject(with: productID) as? UserProduct {
                self.updateProductInArrays(updatedProduct)
            }
        }
    }
    
    // Add this helper method to update a product in all arrays
    private func updateProductInArrays(_ updatedProduct: UserProduct) {
        // Update in openProducts
        if let index = openProducts.firstIndex(where: { $0.objectID == updatedProduct.objectID }) {
            openProducts[index] = updatedProduct
        }
        
        // Update in expiringProducts
        if let index = expiringProducts.firstIndex(where: { $0.objectID == updatedProduct.objectID }) {
            expiringProducts[index] = updatedProduct
        }
        
        // Update in storedProducts
        if let index = storedProducts.firstIndex(where: { $0.objectID == updatedProduct.objectID }) {
            storedProducts[index] = updatedProduct
        }
        
        // If this is the selected product, update it too
        if let selected = selectedProduct, selected.objectID == updatedProduct.objectID {
            selectedProduct = updatedProduct
        }
    }
    
    // Delete product
    func deleteProduct(product: UserProduct) {
        // First remove the product from arrays to prevent UI from referencing deleted objects
        openProducts.removeAll { $0.objectID == product.objectID }
        expiringProducts.removeAll { $0.objectID == product.objectID }
        storedProducts.removeAll { $0.objectID == product.objectID }
        
        // If this was the selected product, clear the selection
        if selectedProduct?.objectID == product.objectID {
            selectedProduct = nil
            showProductDetail = false
        }
        
        // Cancel any pending notifications
        NotificationService.shared.cancelNotification(for: product)
        
        // Then delete from Core Data
        CoreDataManager.shared.deleteProduct(id: product.objectID)
    }
    
    func setBagFilter(_ bag: BeautyBag?) {
        selectedBag = bag
        fetchProducts()
    }
    
    func setTagFilter(_ tag: ProductTag?) {
        selectedTag = tag
        fetchProducts()
    }
}

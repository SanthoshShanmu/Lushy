import Foundation
import CoreData
import Combine

class UserProductViewModel: ObservableObject {
    @Published var userProducts: [UserProduct] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchUserProducts()
        
        // Subscribe to Core Data changes to keep the UI updated
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchUserProducts()
            }
            .store(in: &cancellables)
    }
    
    // Fetch all user products from Core Data
    func fetchUserProducts() {
        isLoading = true
        error = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.userProducts = CoreDataManager.shared.fetchUserProducts()
            self.isLoading = false
        }
    }
    
    // Get products filtered by a specific bag
    func products(in bag: BeautyBag) -> [UserProduct] {
        return userProducts.filter { product in
            guard let bags = product.bags as? Set<BeautyBag> else { return false }
            return bags.contains(bag)
        }
    }
    
    // Get products not in a specific bag
    func productsNotIn(bag: BeautyBag) -> [UserProduct] {
        return userProducts.filter { product in
            guard let bags = product.bags as? Set<BeautyBag> else { return true }
            return !bags.contains(bag)
        }
    }
    
    // Get products filtered by search text
    func filteredProducts(searchText: String) -> [UserProduct] {
        guard !searchText.isEmpty else { return userProducts }
        
        return userProducts.filter { product in
            (product.productName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (product.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // Add product to bag
    func addProduct(_ product: UserProduct, to bag: BeautyBag) {
        CoreDataManager.shared.addProduct(product, toBag: bag)
        fetchUserProducts() // Refresh to show updated associations
    }
    
    // Remove product from bag
    func removeProduct(_ product: UserProduct, from bag: BeautyBag) {
        CoreDataManager.shared.removeProduct(product, fromBag: bag)
        fetchUserProducts() // Refresh to show updated associations
    }
}
import Foundation
import CoreData
import Combine

class FavoritesViewModel: ObservableObject {
    @Published var favoriteProducts: [UserProduct] = []
    @Published var selectedBag: BeautyBag? = nil
    @Published var selectedTag: ProductTag? = nil
    @Published var allBags: [BeautyBag] = []
    @Published var allTags: [ProductTag] = []

    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchFavorites()
        
        // Subscribe to context changes to keep the UI updated
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchFavorites()
            }
            .store(in: &cancellables)
    }
    
    // Fetch favorite products from Core Data
    func fetchFavorites() {
        fetchAllBagsAndTags()
        let allProducts = CoreDataManager.shared.fetchUserProducts()
        let favorites = allProducts.filter { $0.favorite }
        
        // Don't filter out finished products - favorites should show all beloved products
        var products = favorites
        
        if let bag = selectedBag {
            products = products.filter { ($0.bags as? Set<BeautyBag>)?.contains(bag) == true }
        }
        if let tag = selectedTag {
            products = products.filter { ($0.tags as? Set<ProductTag>)?.contains(tag) == true }
        }
        favoriteProducts = products
    }

    func fetchAllBagsAndTags() {
        allBags = CoreDataManager.shared.fetchBeautyBags()
        allTags = CoreDataManager.shared.fetchProductTags()
    }

    func setBagFilter(_ bag: BeautyBag?) {
        selectedBag = bag
        fetchFavorites()
    }

    func setTagFilter(_ tag: ProductTag?) {
        selectedTag = tag
        fetchFavorites()
    }
    
    // Toggle favorite status
    func toggleFavorite(product: UserProduct) {
        // Store the ID
        let productID = product.objectID
        
        // Toggle in CoreData
        CoreDataManager.shared.toggleFavorite(id: productID)
        
        // Immediately update UI without waiting for notification
        DispatchQueue.main.async {
            // If we're removing from favorites, remove from our array
            if !product.favorite {
                self.favoriteProducts.removeAll { $0.objectID == productID }
            } else {
                // Re-fetch all favorites to ensure proper sorting/filtering
                self.fetchFavorites()
            }
        }
    }
}

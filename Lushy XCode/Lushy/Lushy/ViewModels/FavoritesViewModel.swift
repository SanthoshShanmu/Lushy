import Foundation
import CoreData
import Combine

class FavoritesViewModel: ObservableObject {
    @Published var favoriteProducts: [UserFavoritesResponse.FavoriteProductSummary] = []
    @Published var selectedBag: BeautyBag? = nil
    @Published var selectedTag: ProductTag? = nil
    @Published var allBags: [BeautyBag] = []
    @Published var allTags: [ProductTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let productFavoriteService = ProductFavoriteService.shared
    
    init() {
        fetchFavorites()
    }
    
    // Fetch favorite products from backend
    func fetchFavorites() {
        guard let userId = AuthService.shared.userId else {
            print("❌ No user ID available for fetching favorites")
            return
        }
        
        print("📋 FavoritesViewModel: Fetching favorites from backend...")
        isLoading = true
        errorMessage = nil
        
        fetchAllBagsAndTags()
        
        productFavoriteService.getUserFavorites(userId: userId)
            .sink { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to fetch favorites: \(error)")
                        self?.errorMessage = "Failed to load favorites"
                    }
                }
            } receiveValue: { [weak self] response in
                DispatchQueue.main.async {
                    print("✅ Received \(response.results) favorite products from backend")
                    var products = response.data.favorites
                    
                    // Apply bag and tag filters
                    if let bag = self?.selectedBag {
                        products = products.filter { product in
                            product.bags.contains { $0.id == bag.backendId }
                        }
                        print("   After bag filter: \(products.count) products")
                    }
                    
                    if let tag = self?.selectedTag {
                        products = products.filter { product in
                            product.tags.contains { $0.id == tag.backendId }
                        }
                        print("   After tag filter: \(products.count) products")
                    }
                    
                    self?.favoriteProducts = products
                    print("   Final favorites count: \(products.count)")
                }
            }
            .store(in: &cancellables)
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

    // Toggle favorite status using the new backend service
    func toggleFavorite(product: UserFavoritesResponse.FavoriteProductSummary) {
        guard let userId = AuthService.shared.userId else {
            print("❌ No user ID available for toggling favorite")
            return
        }
        
        print("🔄 FavoritesViewModel: Toggling favorite for '\(product.product.productName)'")
        
        productFavoriteService.toggleFavorite(barcode: product.product.barcode, userId: userId)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to toggle favorite: \(error)")
                }
            } receiveValue: { [weak self] response in
                print("✅ Favorite toggled successfully")
                // Refresh the favorites list to reflect the change
                self?.fetchFavorites()
            }
            .store(in: &cancellables)
    }
}

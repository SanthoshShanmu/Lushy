import Foundation
import Combine

class SearchProductDetailViewModel: ObservableObject {
    @Published var usersWhoOwnProduct: [UserSummary] = []
    @Published var isLoading = false
    @Published var isLoadingUsers = false
    @Published var error: String?
    @Published var wishlistItems: [AppWishlistItem] = []
    @Published var isLoadingWishlist = false
    
    private let product: ProductSearchSummary
    private let currentUserId: String
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property to check if product is already in wishlist
    var isProductInWishlist: Bool {
        return wishlistItems.contains { item in
            item.productName.lowercased() == product.productName.lowercased() ||
            item.productURL.lowercased().contains(product.barcode.lowercased())
        }
    }
    
    init(product: ProductSearchSummary, currentUserId: String) {
        self.product = product
        self.currentUserId = currentUserId
        loadWishlist()
    }
    
    func loadUsersWhoOwnProduct() {
        isLoadingUsers = true
        
        APIService.shared.getUsersWhoOwnProduct(barcode: product.barcode, currentUserId: currentUserId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingUsers = false
                
                switch result {
                case .success(let response):
                    self?.usersWhoOwnProduct = response.data.users
                case .failure(let error):
                    print("Failed to load users who own product: \(error.localizedDescription)")
                    self?.usersWhoOwnProduct = []
                }
            }
        }
    }
    
    func loadWishlist() {
        isLoadingWishlist = true
        
        APIService.shared.fetchWishlist()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingWishlist = false
                if case .failure(let error) = completion {
                    print("Failed to load wishlist: \(error)")
                }
            } receiveValue: { [weak self] items in
                self?.wishlistItems = items
            }
            .store(in: &cancellables)
    }

    func addToCollection(completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        
        APIService.shared.addProductToCollection(
            barcode: product.barcode,
            productName: product.productName,
            brand: product.brand,
            imageUrl: product.imageUrl
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(_):
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func addToWishlist(completion: @escaping (Result<Void, Error>) -> Void) {
        // Check for duplicates before adding
        if isProductInWishlist {
            completion(.failure(NSError(domain: "DuplicateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "This product is already in your wishlist!"])))
            return
        }
        
        let wishlistItem = NewWishlistItem(
            productName: product.productName,
            productURL: "https://lushy.app/product/\(product.barcode)",
            notes: "Added from product search",
            imageURL: product.imageUrl
        )
        
        APIService.shared.addWishlistItem(wishlistItem)
            .receive(on: DispatchQueue.main)
            .sink { completionResult in
                switch completionResult {
                case .finished:
                    break
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { [weak self] _ in
                // Refresh wishlist after successful addition
                self?.loadWishlist()
                completion(.success(()))
            }
            .store(in: &cancellables)
    }
    
    func removeFromWishlist(completion: @escaping (Result<Void, Error>) -> Void) {
        // Find the wishlist item that matches this product
        guard let wishlistItem = wishlistItems.first(where: { item in
            item.productName.lowercased() == product.productName.lowercased() ||
            item.productURL.lowercased().contains(product.barcode.lowercased())
        }) else {
            completion(.failure(NSError(domain: "NotFoundError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Product not found in wishlist"])))
            return
        }
        
        APIService.shared.deleteWishlistItem(id: wishlistItem.id)
            .receive(on: DispatchQueue.main)
            .sink { completionResult in
                switch completionResult {
                case .finished:
                    break
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { [weak self] _ in
                // Refresh wishlist after successful removal
                self?.loadWishlist()
                completion(.success(()))
            }
            .store(in: &cancellables)
    }
}
import Foundation
import Combine

class SearchProductDetailViewModel: ObservableObject {
    @Published var usersWhoOwnProduct: [UserSummary] = []
    @Published var isLoading = false
    @Published var isLoadingUsers = false
    @Published var error: String?
    
    private let product: ProductSearchSummary
    private let currentUserId: String
    private var cancellables = Set<AnyCancellable>()
    
    init(product: ProductSearchSummary, currentUserId: String) {
        self.product = product
        self.currentUserId = currentUserId
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
            } receiveValue: { _ in
                completion(.success(()))
            }
            .store(in: &cancellables)
    }
}
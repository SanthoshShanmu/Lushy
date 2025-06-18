import Foundation
import Combine

class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var bags: [BeautyBagSummary] = []
    @Published var products: [UserProductSummary] = []
    @Published var favorites: [UserProductSummary] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isFollowing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    let currentUserId: String
    let targetUserId: String
    
    var isViewingOwnProfile: Bool {
        return currentUserId == targetUserId
    }
    
    init(currentUserId: String, targetUserId: String) {
        self.currentUserId = currentUserId
        self.targetUserId = targetUserId
        // Refresh profile on bag changes
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchProfile()
            }
            .store(in: &cancellables)
    }
    
    func fetchProfile() {
        isLoading = true
        error = nil
        APIService.shared.fetchUserProfile(userId: targetUserId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let wrapper):
                    self?.profile = wrapper.user
                    // Always use backend bags for any profile
                    self?.bags = wrapper.user.bags ?? []
                    self?.products = wrapper.user.products ?? []
                    self?.favorites = wrapper.user.products?.filter { $0.isFavorite == true } ?? []
                    self?.isFollowing = wrapper.user.followers?.contains(where: { $0.id == self?.currentUserId }) ?? false
                case .failure(let error):
                    self?.error = error.localizedDescription
                }
            }
        }
    }
    
    func follow() {
        APIService.shared.followUser(targetUserId: targetUserId, currentUserId: currentUserId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isFollowing = true
                    self?.fetchProfile()
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                case .failure(let err):
                    self?.error = err.localizedDescription
                }
            }
        }
    }
    
    func unfollow() {
        APIService.shared.unfollowUser(targetUserId: targetUserId, currentUserId: currentUserId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isFollowing = false
                    self?.fetchProfile()
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                case .failure(let err):
                    self?.error = err.localizedDescription
                }
            }
        }
    }
    
    func addProductToWishlist(productId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // First get the product details from the current user profile
        guard let product = products.first(where: { $0.id == productId }) else {
            completion(.failure(APIError.productNotFound))
            return
        }
        
        // Create a new wishlist item from the product information
        let wishlistItem = NewWishlistItem(
            productName: product.name,
            productURL: "https://world.openbeautyfacts.org/product/\(productId)", // Use product barcode as URL
            notes: "Added from \(profile?.name ?? "another user")'s collection",
            imageURL: nil // You could add product.imageURL if available
        )
        
        // Use the correct API extension method
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

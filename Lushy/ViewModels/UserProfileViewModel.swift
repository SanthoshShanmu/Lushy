import Foundation
import Combine

class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var bags: [BeautyBagSummary] = []
    @Published var products: [UserProductSummary] = []
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
                    self?.bags = wrapper.user.bags ?? []
                    self?.products = wrapper.user.products ?? []
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
        APIService.shared.addProductToWishlist(productId: productId, completion: completion)
    }
}

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
    @Published var addedWishlistIds: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    let currentUserId: String
    let targetUserId: String
    
    private var lastFetchTime: Date?
    private let throttleInterval: TimeInterval = 60  // throttle interval in seconds
    
    var isViewingOwnProfile: Bool {
        return currentUserId == targetUserId
    }
    
    // Computed properties for product counts
    var activeProductsCount: Int {
        return products.filter { !($0.isFinished == true) }.count
    }
    
    var finishedProductsCount: Int {
        return products.filter { $0.isFinished == true }.count
    }
    
    init(currentUserId: String, targetUserId: String) {
        self.currentUserId = currentUserId
        self.targetUserId = targetUserId
        
        // Refresh profile whenever requested, using remote data
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchProfile(force: true)  // always force refresh on explicit notification
            }
            .store(in: &cancellables)

        // Initial load
        fetchProfile(force: true)
    }

    // MARK: - Profile Fetching
    func fetchProfile(force: Bool = false) {
        // Throttle frequent calls unless forced
        let now = Date()
        if !force, let last = lastFetchTime, now.timeIntervalSince(last) < throttleInterval {
            return
        }
        lastFetchTime = now
        
        // Reset previous profile to avoid showing stale data
        DispatchQueue.main.async { [weak self] in self?.profile = nil }
        // Always fetch fresh profile when this method is called
        isLoading = true
        error = nil
        APIService.shared.fetchUserProfile(userId: targetUserId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let wrapper):
                    self?.profile = wrapper.user
                    // Use remote bag summaries for UI (own or other profile)
                    let remoteBags = wrapper.user.bags ?? []
                    let uniqueRemoteBags = remoteBags.reduce(into: [BeautyBagSummary]()) { acc, bag in
                        if !acc.contains(where: { $0.id == bag.id }) { acc.append(bag) }
                    }
                    self?.bags = uniqueRemoteBags
                    // Sync local Core Data store for bags
                    DispatchQueue.global(qos: .background).async {
                        let existingIds = Set(CoreDataManager.shared.fetchBeautyBags().compactMap { $0.backendId })
                        for summary in uniqueRemoteBags {
                            if !existingIds.contains(summary.id) {
                                if let newId = CoreDataManager.shared.createBeautyBag(name: summary.name, color: "lushyPink", icon: "bag.fill") {
                                    CoreDataManager.shared.updateBeautyBagBackendId(id: newId, backendId: summary.id)
                                }
                            }
                        }
                    }
                    // Sync backend products to local Core Data for navigation
                    SyncService.shared.fetchRemoteProducts()
                    self?.products = wrapper.user.products ?? []
                    self?.favorites = wrapper.user.products?.filter { $0.isFavorite == true } ?? []
                    self?.isFollowing = wrapper.user.followers?.contains { $0.id == self?.currentUserId } ?? false
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
                    self?.fetchProfile(force: true)
                    // Remove RefreshFeed notification to prevent loops
                    // Following/unfollowing shouldn't trigger feed refreshes
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
                    self?.fetchProfile(force: true)
                    // Remove RefreshFeed notification to prevent loops
                    // Following/unfollowing shouldn't trigger feed refreshes
                case .failure(let err):
                    self?.error = err.localizedDescription
                }
            }
        }
    }
    
    func addProductToWishlist(productId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let product = products.first(where: { $0.id == productId }) else {
            completion(.failure(APIError.productNotFound))
            return
        }
        let wishlistItem = NewWishlistItem(
            productName: product.name,
            productURL: "https://world.openbeautyfacts.org/product/\(productId)",
            notes: "Added from \(profile?.name ?? "another user")'s collection",
            imageURL: nil
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
                self.addedWishlistIds.insert(productId)
                completion(.success(()))
            }
            .store(in: &cancellables)
    }
    
    // Delete a beauty bag
    func deleteBag(summary: BeautyBagSummary) {
        let userId = currentUserId
        // Delete remotely
        APIService.shared.deleteBag(userId: userId, bagId: summary.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                // Handle errors if needed
            }, receiveValue: {
                // Remove locally
                if let cdBag = CoreDataManager.shared.fetchBeautyBags().first(where: { $0.backendId == summary.id }) {
                    CoreDataManager.shared.deleteBeautyBag(cdBag)
                }
                // Update UI summary list
                self.bags.removeAll { $0.id == summary.id }
                NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
            })
            .store(in: &cancellables)
    }
}

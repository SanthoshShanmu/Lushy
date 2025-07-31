import Foundation
import Combine
import SwiftUI

class BeautyBagViewModel: ObservableObject {
    @Published var bags: [BeautyBag] = []
    @Published var selectedBag: BeautyBag?
    @Published var newBagName: String = ""
    @Published var newBagIcon: String = "bag.fill"
    @Published var newBagColor: String = "lushyPink"
    
    var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to RefreshBags notifications to re-fetch when backend sync completes
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBags"))
            .sink { [weak self] _ in self?.fetchBags() }
            .store(in: &cancellables)
        fetchBags()
    }

    func fetchBags() {
        guard let userId = AuthService.shared.userId else {
            bags = CoreDataManager.shared.fetchBeautyBags()
            return
        }
        // Fetch remote bags and merge into Core Data
        APIService.shared.fetchUserBags(userId: userId) { result in
            switch result {
            case .success(let summaries):
                let context = CoreDataManager.shared.viewContext
                context.performAndWait {
                    let localBags = CoreDataManager.shared.fetchBeautyBags()
                    let existingByBackend = Dictionary<String, BeautyBag>(uniqueKeysWithValues: localBags.compactMap { bag in
                        guard let bid = bag.backendId else { return nil }
                        return (bid, bag)
                    })
                    let remoteIds = Set(summaries.map { $0.id })
                    for summary in summaries {
                        if let bag = existingByBackend[summary.id] {
                            // update properties if needed
                        } else {
                            if let newID = CoreDataManager.shared.createBeautyBag(name: summary.name, color: "lushyPink", icon: "bag.fill") {
                                CoreDataManager.shared.updateBeautyBagBackendId(id: newID, backendId: summary.id)
                            }
                        }
                    }
                    // Delete local bags no longer present remotely
                    for bag in localBags where bag.backendId != nil && !remoteIds.contains(bag.backendId!) {
                        context.delete(bag)
                    }
                    try? context.save()
                }
            case .failure:
                break
            }
            DispatchQueue.main.async {
                self.bags = CoreDataManager.shared.fetchBeautyBags()
            }
        }
    }

    func createBag() {
        guard !newBagName.isEmpty else { return }
        // Create locally and update local list immediately
        guard let bagID = CoreDataManager.shared.createBeautyBag(name: newBagName, color: newBagColor, icon: newBagIcon) else { return }
        self.bags = CoreDataManager.shared.fetchBeautyBags()

        // Create remotely and store backendId, then refresh list
        if let userId = AuthService.shared.userId {
            APIService.shared.createBag(userId: userId, name: newBagName)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to create bag remotely: \(error)")
                    }
                }, receiveValue: { summary in
                    // Link local bag to remote and refresh final list
                    CoreDataManager.shared.updateBeautyBagBackendId(id: bagID, backendId: summary.id)
                    self.bags = CoreDataManager.shared.fetchBeautyBags()
                })
                .store(in: &cancellables)
        }

        // Reset form
        newBagName = ""
        newBagIcon = "bag.fill"
        newBagColor = "lushyPink"
    }

    func deleteBag(_ bag: BeautyBag) {
        guard let userId = AuthService.shared.userId else {
            return
        }
        // Attempt remote deletion first
        if let backendId = bag.backendId {
            APIService.shared.deleteBag(userId: userId, bagId: backendId)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to delete bag remotely: \(error)")
                    }
                }, receiveValue: {
                    // Remove locally upon success
                    CoreDataManager.shared.deleteBeautyBag(bag)
                    self.fetchBags()
                    // Notify profile and other listeners to refresh bags
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
                })
                .store(in: &cancellables)
        } else {
            // Fallback to local only
            CoreDataManager.shared.deleteBeautyBag(bag)
            fetchBags()
            // Notify profile and other listeners to refresh bags
            NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
        }
    }

    func addProduct(_ product: UserProduct, to bag: BeautyBag) {
        CoreDataManager.shared.addProduct(product, toBag: bag)
        fetchBags()
    }

    func removeProduct(_ product: UserProduct, from bag: BeautyBag) {
        CoreDataManager.shared.removeProduct(product, fromBag: bag)
        fetchBags()
    }

    // Returns the products contained in the specified beauty bag
    func products(in bag: BeautyBag) -> [UserProduct] {
        (bag.products as? Set<UserProduct>)?
            .sorted { ($0.productName ?? "") < ($1.productName ?? "") } ?? []
    }
}

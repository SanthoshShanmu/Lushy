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
        fetchBags()
    }

    func fetchBags() {
        bags = CoreDataManager.shared.fetchBeautyBags()
    }

    func createBag() {
        guard !newBagName.isEmpty else { return }
        // Save locally
        CoreDataManager.shared.createBeautyBag(name: newBagName, color: newBagColor, icon: newBagIcon)
        fetchBags()
        // Sync to backend
        if let userId = AuthService.shared.userId {
            APIService.shared.createBag(userId: userId, name: newBagName)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
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
        // Use remote id if available, otherwise fallback to local objectID
        let bagId: String
        if let remoteId = (bag.value(forKey: "backendId") as? String) ?? (bag.value(forKey: "id") as? String) {
            bagId = remoteId
        } else {
            bagId = bag.objectID.uriRepresentation().absoluteString
        }
        // Delete locally
        CoreDataManager.shared.deleteBeautyBag(bag)
        fetchBags()
        // Delete remotely
        APIService.shared.deleteBag(userId: userId, bagId: bagId)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                // Refresh profile view after removal
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
            })
            .store(in: &cancellables)
    }

    func addProduct(_ product: UserProduct, to bag: BeautyBag) {
        CoreDataManager.shared.addProduct(product, toBag: bag)
        fetchBags()
    }

    func removeProduct(_ product: UserProduct, from bag: BeautyBag) {
        CoreDataManager.shared.removeProduct(product, fromBag: bag)
        fetchBags()
    }

    func products(in bag: BeautyBag) -> [UserProduct] {
        CoreDataManager.shared.products(inBag: bag)
    }
}

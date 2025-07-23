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
        // Create locally and get its objectID
        guard let bagID = CoreDataManager.shared.createBeautyBag(name: newBagName, color: newBagColor, icon: newBagIcon) else { return }
        fetchBags()
        // Create remotely and store backendId
        if let userId = AuthService.shared.userId {
            APIService.shared.createBag(userId: userId, name: newBagName)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to create bag remotely: \(error)")
                    }
                }, receiveValue: { summary in
                    // Link local bag to remote
                    CoreDataManager.shared.updateBeautyBagBackendId(id: bagID, backendId: summary.id)
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
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                })
                .store(in: &cancellables)
        } else {
            // Fallback to local only
            CoreDataManager.shared.deleteBeautyBag(bag)
            fetchBags()
            NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
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

    func products(in bag: BeautyBag) -> [UserProduct] {
        CoreDataManager.shared.products(inBag: bag)
    }
}

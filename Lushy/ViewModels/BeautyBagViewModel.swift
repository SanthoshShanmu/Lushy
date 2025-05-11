import Foundation
import Combine
import SwiftUI

class BeautyBagViewModel: ObservableObject {
    @Published var bags: [BeautyBag] = []
    @Published var selectedBag: BeautyBag?
    @Published var newBagName: String = ""
    @Published var newBagIcon: String = "bag.fill"
    @Published var newBagColor: String = "lushyPink"

    init() {
        fetchBags()
    }

    func fetchBags() {
        bags = CoreDataManager.shared.fetchBeautyBags()
    }

    func createBag() {
        guard !newBagName.isEmpty else { return }
        CoreDataManager.shared.createBeautyBag(name: newBagName, color: newBagColor, icon: newBagIcon)
        fetchBags()
        newBagName = ""
        newBagIcon = "bag.fill"
        newBagColor = "lushyPink"
    }

    func deleteBag(_ bag: BeautyBag) {
        CoreDataManager.shared.deleteBeautyBag(bag)
        fetchBags()
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

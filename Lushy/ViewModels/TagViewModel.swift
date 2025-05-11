import Foundation
import Combine
import SwiftUI

class TagViewModel: ObservableObject {
    @Published var tags: [ProductTag] = []
    @Published var newTagName: String = ""
    @Published var newTagColor: String = "blue"

    init() {
        fetchTags()
    }

    func fetchTags() {
        tags = CoreDataManager.shared.fetchProductTags()
    }

    func createTag() {
        guard !newTagName.isEmpty else { return }
        CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
        fetchTags()
        newTagName = ""
        newTagColor = "blue"
    }

    func deleteTag(_ tag: ProductTag) {
        CoreDataManager.shared.deleteProductTag(tag)
        fetchTags()
    }

    func addTag(_ tag: ProductTag, to product: UserProduct) {
        CoreDataManager.shared.addTag(tag, toProduct: product)
        fetchTags()
    }

    func removeTag(_ tag: ProductTag, from product: UserProduct) {
        CoreDataManager.shared.removeTag(tag, fromProduct: product)
        fetchTags()
    }

    func products(with tag: ProductTag) -> [UserProduct] {
        CoreDataManager.shared.products(withTag: tag)
    }
}

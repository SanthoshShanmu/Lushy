import Foundation
import Combine
import SwiftUI

class TagViewModel: ObservableObject {
    @Published var tags: [ProductTag] = []
    @Published var newTagName: String = ""
    @Published var newTagColor: String = "lushyPink"
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to RefreshTags notifications to always sync deletions
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTags"))
            .sink { [weak self] _ in self?.fetchTags() }
            .store(in: &cancellables)
        // Refresh tags on user login
        AuthService.shared.$currentUserId
            .compactMap { $0 }
            .sink { [weak self] _ in
                self?.fetchTags()
            }
            .store(in: &cancellables)
        // Initial load
        fetchTags()
    }

    func fetchTags() {
        guard let userId = AuthService.shared.userId else {
            tags = CoreDataManager.shared.fetchProductTags()
            return
        }
        // Get remote tags and merge into Core Data
        APIService.shared.fetchUserTags(userId: userId) { result in
            switch result {
            case .success(let summaries):
                let context = CoreDataManager.shared.viewContext
                context.performAndWait {
                    let localTags = CoreDataManager.shared.fetchProductTags()
                    // Build map of existing tags by backendId, ignoring duplicates
                    var existingByBackend = [String: ProductTag]()
                    for tag in localTags {
                        if let bid = tag.backendId, existingByBackend[bid] == nil {
                            existingByBackend[bid] = tag
                        }
                    }
                    let remoteIds = Set(summaries.map { $0.id })
                    // Merge remote tags: update existing or create new
                    for summary in summaries {
                        if let tag = existingByBackend[summary.id] {
                            tag.name = summary.name
                            tag.color = summary.color
                        } else {
                            _ = CoreDataManager.shared.createProductTag(name: summary.name, color: summary.color, backendId: summary.id)
                        }
                    }
                    // Delete local tags that are no longer present remotely
                    for tag in localTags where tag.backendId != nil && !remoteIds.contains(tag.backendId!) {
                        context.delete(tag)
                    }
                    try? context.save()
                }
            case .failure:
                break
            }
            DispatchQueue.main.async {
                self.tags = CoreDataManager.shared.fetchProductTags()
            }
        }
    }

    func createTag() {
        guard let userId = AuthService.shared.userId, !newTagName.isEmpty else { return }
        APIService.shared.createTag(userId: userId, name: newTagName, color: newTagColor)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { summary in
                _ = CoreDataManager.shared.createProductTag(name: summary.name, color: summary.color, backendId: summary.id)
                self.fetchTags()
                self.newTagName = ""
                self.newTagColor = "lushyPink"
            })
            .store(in: &cancellables)
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

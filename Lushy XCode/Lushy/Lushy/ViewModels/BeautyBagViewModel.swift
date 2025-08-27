import Foundation
import Combine
import SwiftUI
import CoreData

class BeautyBagViewModel: ObservableObject {
    @Published var bags: [BeautyBag] = []
    @Published var selectedBag: BeautyBag?
    @Published var newBagName: String = ""
    @Published var newBagDescription: String = ""
    @Published var newBagIcon: String = "bag.fill"
    @Published var newBagColor: String = "lushyPink"
    @Published var newBagImage: String? = nil
    @Published var newBagIsPrivate: Bool = false
    
    // Edit properties for editing existing bags
    @Published var editBagName: String = ""
    @Published var editBagDescription: String = ""
    @Published var editBagIcon: String = "bag.fill"
    @Published var editBagColor: String = "lushyPink"
    @Published var editBagIsPrivate: Bool = false
    
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
                    
                    // Create dictionary safely, handling duplicates by keeping the first occurrence
                    var existingByBackend = [String: BeautyBag]()
                    for bag in localBags {
                        if let bid = bag.backendId, existingByBackend[bid] == nil {
                            existingByBackend[bid] = bag
                        }
                    }
                    
                    let remoteIds = Set(summaries.map { $0.id })
                    for summary in summaries {
                        if let _ = existingByBackend[summary.id] {
                            // Update properties if needed - now including all new fields
                            if let existingBag = existingByBackend[summary.id] {
                                existingBag.name = summary.name
                                existingBag.bagDescription = summary.description
                                existingBag.color = summary.color ?? "lushyPink"
                                existingBag.icon = summary.icon ?? "bag.fill"
                                existingBag.image = summary.image
                                existingBag.isPrivate = summary.isPrivate ?? false
                            }
                        } else {
                            if let newID = CoreDataManager.shared.createBeautyBag(
                                name: summary.name,
                                description: summary.description ?? "",
                                color: summary.color ?? "lushyPink",
                                icon: summary.icon ?? "bag.fill",
                                image: summary.image,
                                isPrivate: summary.isPrivate ?? false
                            ) {
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

    func createBag(with image: UIImage? = nil) {
        guard !newBagName.isEmpty else { return }
        guard let userId = AuthService.shared.userId else { return }
        
        // Convert UIImage to Data if provided
        var imageData: Data? = nil
        if let image = image {
            imageData = image.jpegData(compressionQuality: 0.8)
        }
        
        // Remote-first: create on backend, then persist locally using returned id
        APIService.shared.createBag(
            userId: userId,
            name: newBagName,
            description: newBagDescription,
            color: newBagColor,
            icon: newBagIcon,
            image: newBagImage,
            isPrivate: newBagIsPrivate
        )
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to create bag remotely: \(error)")
                }
            }, receiveValue: { summary in
                // Persist the bag locally with all the new fields including image data
                if let newID = CoreDataManager.shared.createBeautyBag(
                    name: summary.name,
                    description: summary.description ?? "",
                    color: summary.color ?? self.newBagColor,
                    icon: summary.icon ?? self.newBagIcon,
                    image: summary.image,
                    isPrivate: summary.isPrivate ?? self.newBagIsPrivate,
                    imageData: imageData
                ) {
                    CoreDataManager.shared.updateBeautyBagBackendId(id: newID, backendId: summary.id)
                }
                self.bags = CoreDataManager.shared.fetchBeautyBags()
                // Trigger a refresh to ensure relationships and purges
                NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
            })
            .store(in: &cancellables)

        // Reset form
        newBagName = ""
        newBagDescription = ""
        newBagIcon = "bag.fill"
        newBagColor = "lushyPink"
        newBagImage = nil
        newBagIsPrivate = false
    }

    func updateBag(_ bag: BeautyBag, name: String, description: String = "", color: String, icon: String, imageUrl: String? = nil, isPrivate: Bool = false, customImage: UIImage? = nil) {
        guard let userId = AuthService.shared.userId else { return }
        
        // Convert UIImage to Data if provided
        var imageData: Data? = nil
        if let customImage = customImage {
            imageData = customImage.jpegData(compressionQuality: 0.8)
        }
        
        // Update locally first for instant UI feedback
        bag.name = name
        bag.bagDescription = description
        bag.color = color
        bag.icon = icon
        bag.image = imageUrl
        bag.isPrivate = isPrivate
        
        // Update image data if provided
        if let imageData = imageData {
            bag.imageData = imageData
        }
        
        do {
            try CoreDataManager.shared.viewContext.save()
            // Refresh the bags array to reflect changes in UI
            DispatchQueue.main.async {
                self.bags = CoreDataManager.shared.fetchBeautyBags()
            }
        } catch {
            print("Failed to save bag locally: \(error)")
            return
        }
        
        // If bag has backendId, update on backend
        if let backendId = bag.backendId {
            APIService.shared.updateBag(
                userId: userId,
                bagId: backendId,
                name: name,
                description: description,
                color: color,
                icon: icon,
                image: imageUrl,
                isPrivate: isPrivate
            )
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to update bag remotely: \(error)")
                        // Could revert changes here if needed
                    }
                }, receiveValue: { _ in
                    // Refresh bags to ensure consistency
                    self.fetchBags()
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
                })
                .store(in: &cancellables)
        } else {
            // For local-only bags, create them on the backend
            print("Creating local bag on backend...")
            APIService.shared.createBag(
                userId: userId,
                name: name,
                description: description,
                color: color,
                icon: icon,
                image: imageUrl,
                isPrivate: isPrivate
            )
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to create bag on backend: \(error)")
                    }
                }, receiveValue: { summary in
                    // Update the local bag with the backend ID
                    bag.backendId = summary.id
                    try? CoreDataManager.shared.viewContext.save()
                    self.fetchBags()
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBags"), object: nil)
                })
                .store(in: &cancellables)
        }
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
            // If no backendId, do nothing to avoid local-only state
            print("Cannot delete local-only bag; ignoring to enforce server-authoritative state")
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
        let allProducts = (bag.products as? Set<UserProduct>) ?? []
        
        // Filter out finished products
        let activeProducts = allProducts.filter { product in
            guard product.value(forKey: "isFinished") as? Bool != true else {
                return false
            }
            return true
        }
        
        return activeProducts.sorted { ($0.productName ?? "") < ($1.productName ?? "") }
    }
    
    // Update an existing bag
    func updateBag(
        id: NSManagedObjectID,
        name: String,
        description: String,
        color: String,
        icon: String,
        image: String? = nil,
        isPrivate: Bool,
        imageData: Data? = nil
    ) {
        CoreDataManager.shared.updateBeautyBag(
            id: id,
            name: name,
            description: description,
            color: color,
            icon: icon,
            image: image,
            isPrivate: isPrivate,
            imageData: imageData
        )
    }
    
    // Prepare edit properties when editing an existing bag
    func prepareForEditing(bag: BeautyBag) {
        editBagName = bag.name ?? ""
        editBagDescription = bag.bagDescription ?? ""
        editBagIcon = bag.icon ?? "bag.fill"
        editBagColor = bag.color ?? "lushyPink"
        editBagIsPrivate = bag.isPrivate
    }
    
    // Update bag with image - method signature expected by BeautyBagsView
    func updateBag(_ bag: BeautyBag, with image: UIImage? = nil) {
        updateBag(
            bag,
            name: editBagName,
            description: editBagDescription,
            color: editBagColor,
            icon: editBagIcon,
            imageUrl: nil,
            isPrivate: editBagIsPrivate,
            customImage: image
        )
    }
}

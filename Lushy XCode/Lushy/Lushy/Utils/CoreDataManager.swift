import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Lushy")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Saving support
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // Add a new usage entry
    func addUsageEntry(to productID: NSManagedObjectID, type: String, amount: Double, notes: String? = nil) {
        let context = persistentContainer.newBackgroundContext()
        
        context.performAndWait {
            guard let product = try? context.existingObject(with: productID) as? UserProduct else { return }
            
            // FIXED: Check if this is the first use to create appropriate journey events
            let isFirstUse = product.openDate == nil
            
            // ALWAYS create a usage entry for tracking purposes
            let usageEntry = UsageEntry(context: context)
            usageEntry.usageType = type
            usageEntry.usageAmount = amount
            usageEntry.notes = notes
            usageEntry.createdAt = Date()
            usageEntry.userId = currentUserId()
            usageEntry.userProduct = product
            
            // For first use, mark product as opened
            if isFirstUse && type == "check_in" {
                product.openDate = Date()
                
                // Calculate expiry if we have PAO
                if let pao = product.periodsAfterOpening, let months = extractMonths(from: pao) {
                    product.expireDate = Calendar.current.date(byAdding: .month, value: months, to: Date())
                    NotificationService.shared.scheduleExpiryNotification(for: product)
                }
                
                // Create "Open" journey event for first use
                let openEvent = UsageJourneyEvent(
                    context: context,
                    type: .open,
                    text: nil,
                    title: "First use",
                    rating: 0,
                    date: Date()
                )
                openEvent.userProduct = product
                print("✅ First use - created both usage entry and open journey event")
            } else {
                // For regular usage, create a usage journey event
                let usageEvent = UsageJourneyEvent(
                    context: context,
                    type: .usage,
                    text: notes,
                    title: "Used",
                    rating: 0,
                    date: Date()
                )
                usageEvent.userProduct = product
                print("✅ Regular use - created both usage entry and usage journey event")
            }
            
            // Update product's current amount
            let newAmount = max(0, product.currentAmount - amount)
            product.currentAmount = newAmount
            
            // Mark as finished if empty
            if newAmount <= 0 && !product.isFinished {
                product.setValue(true, forKey: "isFinished")
                product.setValue(Date(), forKey: "finishDate")
                NotificationService.shared.cancelNotification(for: product)
            }
            
            do {
                try context.save()
                print("✅ Usage entry and journey events created and saved: \(type)")
                
                // Sync usage entry to backend
                if let userId = AuthService.shared.userId, let backendId = product.backendId {
                    DispatchQueue.main.async {
                        self.syncUsageEntryToBackend(
                            userId: userId,
                            productId: backendId,
                            usageType: type,
                            usageAmount: amount,
                            notes: notes,
                            createdAt: Date()
                        )
                    }
                }
                
                // Sync journey event to backend
                if isFirstUse && type == "check_in" {
                    if let userId = AuthService.shared.userId, let backendId = product.backendId {
                        DispatchQueue.main.async {
                            self.syncJourneyEventToBackend(
                                userId: userId,
                                productId: backendId,
                                eventType: "open",
                                text: nil,
                                title: "First use",
                                rating: 0,
                                createdAt: Date()
                            )
                        }
                    }
                } else {
                    if let userId = AuthService.shared.userId, let backendId = product.backendId {
                        DispatchQueue.main.async {
                            self.syncJourneyEventToBackend(
                                userId: userId,
                                productId: backendId,
                                eventType: "usage",
                                text: notes,
                                title: "Used",
                                rating: 0,
                                createdAt: Date()
                            )
                        }
                    }
                }
            } catch {
                print("❌ Error adding usage entry: \(error)")
            }
        }
    }
    
    // MARK: - Helper methods
    private func currentUserId() -> String {
        return AuthService.shared.userId ?? "local_user"
    }
    
    private func extractMonths(from pao: String) -> Int? {
        let numbers = pao.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers)
    }
    
    // MARK: - Fetch methods
    func fetchProductTags() -> [ProductTag] {
        let request: NSFetchRequest<ProductTag> = ProductTag.fetchRequest()
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching product tags: \(error)")
            return []
        }
    }
    
    func fetchBeautyBags() -> [BeautyBag] {
        let request: NSFetchRequest<BeautyBag> = BeautyBag.fetchRequest()
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching beauty bags: \(error)")
            return []
        }
    }
    
    func fetchUserProduct(backendId: String) -> UserProduct? {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "backendId == %@", backendId)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching user product: \(error)")
            return nil
        }
    }
    
    func fetchUserProducts() -> [UserProduct] {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching user products: \(error)")
            return []
        }
    }
    
    func fetchUsageEntries(for productID: NSManagedObjectID) -> [UsageEntry] {
        guard let product = try? viewContext.existingObject(with: productID) as? UserProduct else {
            return []
        }
        
        let request: NSFetchRequest<UsageEntry> = UsageEntry.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UsageEntry.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching usage entries: \(error)")
            return []
        }
    }
    
    func fetchUsageJourneyEvents(for productID: NSManagedObjectID) -> [UsageJourneyEvent] {
        guard let product = try? viewContext.existingObject(with: productID) as? UserProduct else {
            return []
        }
        
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UsageJourneyEvent.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching usage journey events: \(error)")
            return []
        }
    }
    
    func products(withTag tag: ProductTag) -> [UserProduct] {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "ANY tags == %@", tag)
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching products with tag: \(error)")
            return []
        }
    }
    
    func countSimilarActiveProducts(productName: String?, brand: String?, size: String?) -> Int {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Add product name predicate if provided
        if let productName = productName {
            predicates.append(NSPredicate(format: "productName == %@", productName))
        }
        
        // Add brand predicate if provided
        if let brand = brand {
            predicates.append(NSPredicate(format: "brand == %@", brand))
        }
        
        // Add size predicate if provided
        if let size = size {
            predicates.append(NSPredicate(format: "size == %@", size))
        }
        
        // Only count non-finished products
        predicates.append(NSPredicate(format: "isFinished == NO"))
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            return try viewContext.fetch(request).count
        } catch {
            print("Error counting similar active products: \(error)")
            return 0
        }
    }
    
    func addTag(_ tag: ProductTag, toProduct product: UserProduct) {
        product.addToTags(tag)
        saveContext()
    }
    
    func removeTag(_ tag: ProductTag, fromProduct product: UserProduct) {
        product.removeFromTags(tag)
        saveContext()
    }
    
    func incrementUsage(id: NSManagedObjectID) {
        guard let product = try? viewContext.existingObject(with: id) as? UserProduct else {
            return
        }
        
        product.timesUsed += 1
        saveContext()
    }
    
    func updateProductDetails(
        id: NSManagedObjectID,
        productName: String,
        brand: String?,
        shade: String?,
        size: String?,
        spf: String?,
        price: Double?,
        currency: String?,
        purchaseDate: Date?,
        isOpened: Bool,
        openDate: Date?,
        periodsAfterOpening: String?,
        vegan: Bool,
        crueltyFree: Bool,
        imageUrl: String?
    ) {
        guard let product = try? viewContext.existingObject(with: id) as? UserProduct else {
            return
        }
        
        product.productName = productName
        product.brand = brand
        product.shade = shade
        product.size = size
        product.spf = spf
        if let price = price {
            product.price = price
        }
        product.currency = currency
        product.purchaseDate = purchaseDate
        product.openDate = openDate
        product.periodsAfterOpening = periodsAfterOpening
        product.vegan = vegan
        product.crueltyFree = crueltyFree
        product.imageUrl = imageUrl
        
        saveContext()
    }
    
    // MARK: - Create methods
    func createProductTag(name: String, color: String, backendId: String? = nil) -> String? {
        let tag = ProductTag(context: viewContext)
        tag.name = name
        tag.color = color
        tag.userId = currentUserId()
        tag.backendId = backendId
        
        saveContext()
        return tag.objectID.uriRepresentation().absoluteString
    }
    
    func createBeautyBag(name: String, description: String? = nil, color: String, icon: String, image: String? = nil, isPrivate: Bool = false, imageData: Data? = nil, backendId: String? = nil) -> String? {
        let bag = BeautyBag(context: viewContext)
        bag.name = name
        bag.bagDescription = description
        bag.color = color
        bag.icon = icon
        bag.image = image
        bag.isPrivate = isPrivate
        bag.imageData = imageData
        bag.userId = currentUserId()
        bag.createdAt = Date()
        bag.backendId = backendId
        
        saveContext()
        return bag.objectID.uriRepresentation().absoluteString
    }
    
    func addProduct(_ product: UserProduct, toBag bag: BeautyBag) {
        product.addToBags(bag)
        saveContext()
    }
    
    func updateBeautyBagBackendId(id: String, backendId: String) {
        guard let url = URL(string: id),
              let objectID = persistentContainer.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url),
              let bag = try? viewContext.existingObject(with: objectID) as? BeautyBag else {
            return
        }
        
        bag.backendId = backendId
        saveContext()
    }
    
    func updateProductTagBackendId(id: String, backendId: String) {
        guard let url = URL(string: id),
              let objectID = persistentContainer.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url),
              let tag = try? viewContext.existingObject(with: objectID) as? ProductTag else {
            return
        }
        
        tag.backendId = backendId
        saveContext()
    }
    
    func removeProduct(_ product: UserProduct, fromBag bag: BeautyBag) {
        bag.removeFromProducts(product)
        saveContext()
    }
    
    func updateBeautyBag(id: NSManagedObjectID, name: String, description: String, color: String, icon: String, image: String? = nil, isPrivate: Bool, imageData: Data? = nil) {
        guard let bag = try? viewContext.existingObject(with: id) as? BeautyBag else {
            return
        }
        
        bag.name = name
        bag.bagDescription = description
        bag.color = color
        bag.icon = icon
        bag.image = image
        bag.isPrivate = isPrivate
        bag.imageData = imageData
        
        saveContext()
    }
    
    // MARK: - Delete methods
    func deleteBeautyBag(_ bag: BeautyBag) {
        viewContext.delete(bag)
        saveContext()
    }
    
    func deleteProductTag(_ tag: ProductTag) {
        viewContext.delete(tag)
        saveContext()
    }
    
    func deleteProduct(id: NSManagedObjectID) {
        guard let product = try? viewContext.existingObject(with: id) as? UserProduct else {
            return
        }
        
        viewContext.delete(product)
        saveContext()
    }
    
    // MARK: - Product management
    func addProduct(barcode: String, productName: String, brand: String?, imageUrl: String?) -> UserProduct {
        let product = UserProduct(context: viewContext)
        product.barcode = barcode
        product.productName = productName
        product.brand = brand
        product.imageUrl = imageUrl
        product.userId = currentUserId()
        product.currentAmount = 100.0 // Default amount
        product.isFinished = false
        product.inWishlist = false
        product.vegan = false
        product.crueltyFree = false
        product.price = 0.0
        
        saveContext()
        return product
    }
    
    func saveUserProduct(
        barcode: String,
        productName: String,
        brand: String?,
        imageUrl: String?,
        purchaseDate: Date?,
        openDate: Date?,
        periodsAfterOpening: String?,
        vegan: Bool,
        crueltyFree: Bool,
        expiryOverride: Date?,
        shade: String? = nil,
        size: String? = nil,
        spf: String? = nil,
        price: Double? = nil,
        currency: String? = nil
    ) -> NSManagedObjectID {
        let product = UserProduct(context: viewContext)
        product.barcode = barcode
        product.productName = productName
        product.brand = brand
        product.imageUrl = imageUrl
        product.purchaseDate = purchaseDate
        product.openDate = openDate
        product.periodsAfterOpening = periodsAfterOpening
        product.vegan = vegan
        product.crueltyFree = crueltyFree
        product.shade = shade
        product.size = size
        product.spf = spf
        product.price = price ?? 0.0
        product.currency = currency
        product.userId = currentUserId()
        product.currentAmount = 100.0
        product.isFinished = false
        product.inWishlist = false
        product.timesUsed = 0
        
        // Handle expiry override or calculate from PAO
        if let expiryOverride = expiryOverride {
            product.expireDate = expiryOverride
        } else if let openDate = openDate, let pao = periodsAfterOpening, let months = extractMonths(from: pao) {
            product.expireDate = Calendar.current.date(byAdding: .month, value: months, to: openDate)
        }
        
        saveContext()
        return product.objectID
    }
    
    // MARK: - Journey events
    func addUsageJourneyEventNew(to productID: NSManagedObjectID, type: UsageJourneyEvent.EventType, text: String?, title: String?, rating: Int, date: Date = Date()) {
        guard let product = try? viewContext.existingObject(with: productID) as? UserProduct else {
            return
        }
        
        let event = UsageJourneyEvent(context: viewContext)
        event.eventType = type.rawValue
        event.text = text
        event.title = title
        event.rating = Int16(rating)
        event.createdAt = date
        event.userProduct = product
        
        saveContext()
    }
    
    func addUsageJourneyEventNew(to product: UserProduct, type: UsageJourneyEvent.EventType, text: String?, title: String?, rating: Int) {
        let event = UsageJourneyEvent(context: viewContext)
        event.eventType = type.rawValue
        event.text = text
        event.title = title
        event.rating = Int16(rating)
        event.createdAt = Date()
        event.userProduct = product
        
        saveContext()
    }
    
    func addReview(to productID: NSManagedObjectID, rating: Int, title: String?, text: String?) {
        guard let product = try? viewContext.existingObject(with: productID) as? UserProduct else {
            return
        }
        
        // Create a review journey event
        let event = UsageJourneyEvent(context: viewContext)
        event.eventType = UsageJourneyEvent.EventType.review.rawValue
        event.text = text
        event.title = title
        event.rating = Int16(rating)
        event.createdAt = Date()
        event.userProduct = product
        
        saveContext()
    }
    
    func markProductAsOpened(id: NSManagedObjectID, openDate: Date) {
        guard let product = try? viewContext.existingObject(with: id) as? UserProduct else {
            return
        }
        
        product.openDate = openDate
        
        // Calculate expiry if we have PAO
        if let pao = product.periodsAfterOpening, let months = extractMonths(from: pao) {
            product.expireDate = Calendar.current.date(byAdding: .month, value: months, to: openDate)
        }
        
        saveContext()
    }
    
    func markProductAsFinished(id: NSManagedObjectID) {
        guard let product = try? viewContext.existingObject(with: id) as? UserProduct else {
            return
        }
        
        product.isFinished = true
        product.finishDate = Date()
        product.currentAmount = 0.0
        
        saveContext()
    }
    
    // MARK: - Backend sync methods
    func syncUsageEntryToBackend(userId: String, productId: String, usageType: String, usageAmount: Double, notes: String?, createdAt: Date) {
        // Implementation for syncing usage entry to backend
        print("Syncing usage entry to backend: \(usageType) for product \(productId)")
        // Add actual API call here when needed
    }
    
    func syncJourneyEventToBackend(userId: String, productId: String, eventType: String, text: String?, title: String?, rating: Int, createdAt: Date) {
        // Implementation for syncing journey event to backend
        print("Syncing journey event to backend: \(eventType) for product \(productId)")
        // Add actual API call here when needed
    }
}

import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Lushy")
        
        // Configure store description with proper options
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        
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
    
    // MARK: - Store Management
    func resetCoreDataStore() {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return
        }
        
        do {
            try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            try persistentContainer.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        } catch {
            print("Failed to reset Core Data store: \(error)")
        }
    }

    // Add a new usage entry
    func addUsageEntry(to productID: NSManagedObjectID, type: String, amount: Double, notes: String? = nil) {
        print("🔄 Starting addUsageEntry - Type: \(type), Amount: \(amount)")
        
        // FIXED: Use main context to avoid deadlock issues with sync calls
        let context = viewContext
        
        context.perform {
            do {
                guard let product = try context.existingObject(with: productID) as? UserProduct else {
                    print("❌ CRITICAL: Product not found for ID: \(productID)")
                    return
                }
                
                print("🔍 Adding usage entry to product: \(product.productName ?? "Unknown")")
                print("🔍 Product openDate: \(String(describing: product.openDate))")
                
                // ALWAYS create a usage entry for tracking purposes
                let usageEntry = UsageEntry(context: context)
                usageEntry.usageType = type
                usageEntry.usageAmount = amount
                usageEntry.notes = notes
                usageEntry.createdAt = Date()
                usageEntry.userId = self.currentUserId()
                usageEntry.userProduct = product
                print("✅ Created UsageEntry with type: \(type)")
                
                // SIMPLE LOGIC: For check_in type, only handle first use setup
                // NO JOURNEY EVENT CREATION HERE - that's handled elsewhere
                if type == "check_in" {
                    // If this is the first use, set openDate
                    if product.openDate == nil {
                        product.openDate = Date()
                        
                        // Calculate expiry if we have PAO
                        if let pao = product.periodsAfterOpening, let months = self.extractMonths(from: pao) {
                            product.expireDate = Calendar.current.date(byAdding: .month, value: months, to: Date())
                            NotificationService.shared.scheduleExpiryNotification(for: product)
                        }
                        print("✅ First use - set openDate only")
                    }
                    
                    print("✅ Usage entry created for check_in - NO duplicate journey event")
                }
                
                // Update product's current amount
                let newAmount = max(0, product.currentAmount - amount)
                product.currentAmount = newAmount
                print("📊 Updated product amount from \(product.currentAmount + amount) to \(newAmount)")
                
                // Mark as finished if empty
                if newAmount <= 0 && !product.isFinished {
                    product.setValue(true, forKey: "isFinished")
                    product.setValue(Date(), forKey: "finishDate")
                    NotificationService.shared.cancelNotification(for: product)
                    print("🏁 Product marked as finished")
                }
                
                // CRITICAL: Save main context directly (no background context issues)
                try context.save()
                print("✅ Main context saved successfully - data WILL persist")
                
                // Post notification that usage data changed
                NotificationCenter.default.post(
                    name: NSNotification.Name("UsageDataChanged"), 
                    object: productID
                )
                print("📢 Posted UsageDataChanged notification")
                
                // Sync usage entry to backend (non-blocking)
                if let userId = AuthService.shared.userId, let backendId = product.backendId {
                    print("🔄 Starting backend sync for usage entry")
                    DispatchQueue.global(qos: .background).async {
                        self.syncUsageEntryToBackend(
                            userId: userId,
                            productId: backendId,
                            usageType: type,
                            usageAmount: amount,
                            notes: notes,
                            createdAt: Date()
                        )
                    }
                } else {
                    print("⚠️ Skipping backend sync - missing userId or backendId")
                }
                
            } catch {
                print("❌ CRITICAL ERROR in addUsageEntry: \(error)")
                print("❌ Stack trace: \(Thread.callStackSymbols)")
            }
        }
        
        print("🏁 addUsageEntry completed for type: \(type)")
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
        request.predicate = NSPredicate(format: "%K == %@", "backendId", backendId)
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
        request.predicate = NSPredicate(format: "%K == %@", "userProduct", product)
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
        request.predicate = NSPredicate(format: "%K == %@", "userProduct", product)
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
        request.predicate = NSPredicate(format: "ANY %K == %@", "tags", tag)
        
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
            predicates.append(NSPredicate(format: "%K == %@", "productName", productName))
        }
        
        // Add brand predicate if provided
        if let brand = brand {
            predicates.append(NSPredicate(format: "%K == %@", "brand", brand))
        }
        
        // Add size predicate if provided
        if let size = size {
            predicates.append(NSPredicate(format: "%K == %@", "size", size))
        }
        
        // Only count non-finished products
        predicates.append(NSPredicate(format: "%K == NO", "isFinished"))
        
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
        guard let url = URL(string: "\(APIService.shared.baseURL)/users/\(userId)/products/\(productId)/usage-entries") else {
            print("❌ Invalid URL for usage entry sync")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody: [String: Any] = [
            "usageType": usageType,
            "usageAmount": usageAmount,
            "notes": notes as Any,
            "createdAt": ISO8601DateFormatter().string(from: createdAt)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error encoding usage entry data: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error syncing usage entry: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    print("✅ Usage entry synced to backend successfully")
                } else {
                    print("❌ Failed to sync usage entry: HTTP \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    func syncJourneyEventToBackend(userId: String, productId: String, eventType: String, text: String?, title: String?, rating: Int, createdAt: Date) {
        guard let url = URL(string: "\(APIService.shared.baseURL)/users/\(userId)/products/\(productId)/journey-events") else {
            print("❌ Invalid URL for journey event sync")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody: [String: Any] = [
            "eventType": eventType,
            "text": text as Any,
            "title": title as Any,
            "rating": rating,
            "createdAt": ISO8601DateFormatter().string(from: createdAt)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error encoding journey event data: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error syncing journey event: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    print("✅ Journey event synced to backend successfully")
                } else {
                    print("❌ Failed to sync journey event: HTTP \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

import Foundation
import CoreData
import Combine

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        // Set the main queue concurrency type explicitly
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    private init() {
        container = NSPersistentContainer(name: "Lushy")
        
        // Add better error handling
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Persistent store loading error: \(error), \(error.userInfo)")
                
                // Handle corrupted store by recreating it
                if error.code == NSPersistentStoreIncompatibleVersionHashError ||
                   error.code == 256 || // The file couldn't be opened
                   error.domain == NSSQLiteErrorDomain {
                    
                    self.recreateCorruptedStore()
                }
            }
        }
        
        // Set global configurations for the container
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Add this method to handle corrupted database
    private func recreateCorruptedStore() {
        // Get URL to the SQLite store
        guard let storeURL = container.persistentStoreCoordinator.persistentStores.first?.url else {
            print("Could not find store URL")
            return
        }
        
        print("Attempting to recreate corrupted store at \(storeURL)")
        
        do {
            // Remove corrupted store
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType)
            
            // Create a new store
            try container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            
            print("Successfully recreated store")
        } catch {
            print("Failed to recreate store: \(error)")
        }
    }
    
    // Helper to get current userId
    private func currentUserId() -> String {
        return AuthService.shared.userId ?? "guest"
    }

    // MARK: - UserProduct Operations
    
    // Update the saveUserProduct function to accept explicit expiry date

    func saveUserProduct(
        barcode: String,
        productName: String,
        brand: String?,
        imageUrl: String?,
        purchaseDate: Date,
        openDate: Date?,
        periodsAfterOpening: String?,
        vegan: Bool,
        crueltyFree: Bool,
        expiryOverride: Date? = nil
    ) -> NSManagedObjectID? {
        // Create a new context for this operation
        let context = container.newBackgroundContext()
        var objectID: NSManagedObjectID?
        
        context.performAndWait {
            let product = UserProduct(context: context)
            
            // Set properties
            product.barcode = barcode
            product.productName = productName
            product.brand = brand
            product.imageUrl = imageUrl
            product.purchaseDate = purchaseDate
            product.openDate = openDate
            product.periodsAfterOpening = periodsAfterOpening
            product.vegan = vegan
            product.crueltyFree = crueltyFree
            product.userId = currentUserId()
            
            // Set expiry date - either from override or calculate from PAO
            if let expiryOverride = expiryOverride {
                product.expireDate = expiryOverride
            } else if let openDate = openDate, let periodsAfterOpening = periodsAfterOpening {
                if let months = extractMonths(from: periodsAfterOpening),
                   let expireDate = Calendar.current.date(byAdding: .month, value: months, to: openDate) {
                    product.expireDate = expireDate
                }
            }
            
            do {
                try context.save()
                objectID = product.objectID
                
                print("Product saved locally: \(productName)")
                
                // Sync to backend immediately after saving locally
                DispatchQueue.main.async {
                    print("Triggering immediate sync for new product")
                    // Convert to main context object for sync
                    if let mainContextProduct = try? self.viewContext.existingObject(with: product.objectID) as? UserProduct {
                        SyncService.shared.syncProductImmediately(mainContextProduct)
                    }
                }
                
            } catch {
                print("Failed to save user product: \(error)")
                // Error handling logic...
            }
        }
        
        return objectID
    }
    
    // Update product status (mark as opened)
    func markProductAsOpened(id: NSManagedObjectID, openDate: Date) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            if let userProduct = context.object(with: id) as? UserProduct {
                userProduct.openDate = openDate
                
                // Calculate expiry date if has periodsAfterOpening
                if let periodsAfterOpening = userProduct.periodsAfterOpening {
                    if let months = extractMonths(from: periodsAfterOpening) {
                        userProduct.expireDate = Calendar.current.date(byAdding: .month, value: months, to: openDate)
                    }
                }
                
                do {
                    try context.save()
                    
                    // Sync open date to backend to create opened_product activity
                    if let userId = AuthService.shared.userId, let backendId = userProduct.backendId {
                        DispatchQueue.main.async {
                            let url = APIService.shared.baseURL.appendingPathComponent("users/")
                                .appendingPathComponent(userId)
                                .appendingPathComponent("products/")
                                .appendingPathComponent(backendId)
                            var request = URLRequest(url: url)
                            request.httpMethod = "PUT"
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            if let token = AuthService.shared.token {
                                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            }
                            let body: [String: Any] = ["openDate": openDate.timeIntervalSince1970]
                            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                            URLSession.shared.dataTask(with: request) { _, _, _ in
                                // Refresh feed after opening product
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                                }
                            }.resume()
                        }
                    }
                } catch {
                    print("Error updating UserProduct: \(error)")
                }
            }
        }
    }
    
    // Add comment to a product
    func addComment(to productID: NSManagedObjectID, text: String) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            if let userProduct = try? context.existingObject(with: productID) as? UserProduct {
                let comment = Comment(context: context)
                comment.text = text
                comment.createdAt = Date()
                comment.userProduct = userProduct
                
                do {
                    try context.save()
                } catch {
                    print("Failed to save comment: \(error)")
                }
            }
        }
    }
    
    // Add review to a product
    func addReview(to productID: NSManagedObjectID, rating: Int, title: String, text: String) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            if let userProduct = try? context.existingObject(with: productID) as? UserProduct {
                let review = Review(context: context)
                review.rating = Int16(rating)
                review.title = title
                review.text = text
                review.createdAt = Date()
                review.userProduct = userProduct
                
                do {
                    try context.save()
                    
                    // Sync review to backend to create review_added activity
                    if let userId = AuthService.shared.userId, let backendId = userProduct.backendId {
                        DispatchQueue.main.async {
                            let url = APIService.shared.baseURL.appendingPathComponent("users/")
                                .appendingPathComponent(userId)
                                .appendingPathComponent("products/")
                                .appendingPathComponent(backendId)
                            var request = URLRequest(url: url)
                            request.httpMethod = "PUT"
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            if let token = AuthService.shared.token {
                                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            }
                            let body: [String: Any] = [
                                "newReview": [
                                    "rating": rating,
                                    "title": title,
                                    "text": text
                                ]
                            ]
                            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                            URLSession.shared.dataTask(with: request) { _, _, _ in
                                // Refresh feed after adding review
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                                }
                            }.resume()
                        }
                    }
                } catch {
                    print("Failed to save review: \(error)")
                }
            }
        }
    }
    
    // Toggle favorite status
    func toggleFavorite(id: NSManagedObjectID) {
        let context = viewContext
        
        context.performAndWait {
            guard let product = try? context.existingObject(with: id) as? UserProduct else {
                return
            }
            
            // Toggle the favorite status
            let newFavoriteStatus = !product.favorite
            product.favorite = newFavoriteStatus
            
            // Save the context immediately
            try? context.save()
            
            // Sync favorite status to backend to create activity
            if let userId = AuthService.shared.userId, let backendId = product.backendId {
                let url = APIService.shared.baseURL.appendingPathComponent("users/")
                    .appendingPathComponent(userId)
                    .appendingPathComponent("products/")
                    .appendingPathComponent(backendId)
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let body: [String: Any] = ["favorite": newFavoriteStatus]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                URLSession.shared.dataTask(with: request) { _, _, _ in
                    // Refresh feed after favorite toggle
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                    }
                }.resume()
            }
        }
    }
    
    // Delete a product
    func deleteProduct(id: NSManagedObjectID) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            let userProduct = context.object(with: id)
            context.delete(userProduct)
            
            do {
                try context.save()
            } catch {
                print("Error deleting product: \(error)")
            }
        }
    }
    
    // Helper function to extract months from period string like "12 months"
    private func extractMonths(from periodString: String) -> Int? {
        // Common formats: "12M", "12 months", "12 Month(s)", etc.
        let pattern = "([0-9]+)[\\s]*[Mm]?"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: periodString, range: NSRange(periodString.startIndex..., in: periodString)),
           let range = Range(match.range(at: 1), in: periodString) {
            return Int(periodString[range])
        }
        
        return nil
    }
    
    // Update product expiry date
    func updateProductExpiry(id: NSManagedObjectID, newExpiry: Date) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            if let product = try? context.existingObject(with: id) as? UserProduct {
                // Cancel existing notification
                NotificationService.shared.cancelNotification(for: product)
                
                // Update expiry
                product.expireDate = newExpiry
                
                try? context.save()
                
                // Reschedule notification
                NotificationService.shared.scheduleExpiryNotification(for: product)
            }
        }
    }
    
    // Add this function
    func calculateAverageProductLifespan(brand: String? = nil, productType: String? = nil) -> TimeInterval? {
        let context = viewContext
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        // Only include products that have been opened
        var predicates: [NSPredicate] = [
            NSPredicate(format: "openDate != nil"),
        ]
        
        if let brand = brand {
            predicates.append(NSPredicate(format: "brand == %@", brand))
        }
        
        if let productType = productType {
            predicates.append(NSPredicate(format: "productType == %@", productType))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let products = try context.fetch(request)
            if products.isEmpty { return nil }
            
            // Get finished products from UserDefaults
            let defaults = UserDefaults.standard
            let finishedProducts = defaults.dictionary(forKey: "FinishedProducts") as? [String: Date] ?? [:]
            
            // Calculate average time from open to finish using explicit closure instead of + operator
            let intervals = products.compactMap { product -> TimeInterval? in
                guard let barcode = product.barcode,
                      let openDate = product.openDate,
                      let finishDate = finishedProducts[barcode] else {
                    return nil
                }
                return finishDate.timeIntervalSince(openDate)
            }
            
            if intervals.isEmpty { return nil }
            
            // Sum intervals explicitly to avoid ambiguity
            let totalSeconds = intervals.reduce(0.0) { (result, interval) in
                return result + interval
            }
            
            return totalSeconds / Double(intervals.count)
        } catch {
            print("Error calculating average lifespan: \(error)")
            return nil
        }
    }
    
    // Improve the markProductAsFinished method:

    func markProductAsFinished(id: NSManagedObjectID) {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        context.performAndWait {
            guard let product = try? context.existingObject(with: id) as? UserProduct else {
                return
            }
            
            // Cancel any pending notifications
            NotificationService.shared.cancelNotification(for: product)
            
            // Instead of deleting, add a "finished" flag
            product.setValue(true, forKey: "isFinished")
            product.setValue(Date(), forKey: "finishDate")
            
            do {
                try context.save()
                
                // Sync to backend to create finished_product activity
                if let userId = AuthService.shared.userId, let backendId = product.backendId {
                    let url = APIService.shared.baseURL.appendingPathComponent("users/")
                        .appendingPathComponent(userId)
                        .appendingPathComponent("products/")
                        .appendingPathComponent(backendId)
                    var request = URLRequest(url: url)
                    request.httpMethod = "PUT"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if let token = AuthService.shared.token {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    let body: [String: Any] = [
                        "isFinished": true,
                        "finishDate": Date().timeIntervalSince1970
                    ]
                    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    URLSession.shared.dataTask(with: request).resume()
                }
                
                // Notify on the main thread after successful save
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .NSManagedObjectContextDidSave,
                        object: context
                    )
                    // Refresh feed to show the finished product activity
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                }
            } catch {
                print("Error updating product: \(error)")
            }
        }
    }

    // MARK: - BeautyBag Operations
    
    // Create a new beauty bag locally, returns its objectID
    func createBeautyBag(name: String, color: String, icon: String) -> NSManagedObjectID? {
        let context = viewContext
        let bag = BeautyBag(context: context)
        bag.name = name
        bag.color = color
        bag.icon = icon
        bag.createdAt = Date()
        bag.userId = currentUserId()
        // backendId remains nil until remote creation
        do {
            try context.save()
            return bag.objectID
        } catch {
            print("Failed to create beauty bag: \(error)")
            return nil
        }
    }

    // Update the backendId for a beauty bag
    func updateBeautyBagBackendId(id: NSManagedObjectID, backendId: String) {
        let context = container.newBackgroundContext()
        context.performAndWait {
            if let bag = try? context.existingObject(with: id) as? BeautyBag {
                bag.backendId = backendId
                try? context.save()
            }
        }
    }

    func fetchBeautyBags() -> [BeautyBag] {
        let request: NSFetchRequest<BeautyBag> = BeautyBag.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId())
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }
    
    func deleteBeautyBag(_ bag: BeautyBag) {
        let context = viewContext
        context.delete(bag)
        try? context.save()
    }
    
    func addProduct(_ product: UserProduct, toBag bag: BeautyBag) {
        bag.addToProducts(product)
        try? viewContext.save()
        
        // Sync to backend with bag activity
        if let userId = AuthService.shared.userId, let backendId = product.backendId {
            let url = APIService.shared.baseURL.appendingPathComponent("users/")
                .appendingPathComponent(userId)
                .appendingPathComponent("products/")
                .appendingPathComponent(backendId)
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = AuthService.shared.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            // Include the bag ID so backend can create add_to_bag activity
            let body: [String: Any] = ["addToBagId": bag.objectID.uriRepresentation().absoluteString]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: request).resume()
        }
    }
    
    func removeProduct(_ product: UserProduct, fromBag bag: BeautyBag) {
        bag.removeFromProducts(product)
        try? viewContext.save()
    }
    
    func products(inBag bag: BeautyBag) -> [UserProduct] {
        (bag.products as? Set<UserProduct>)?.sorted { ($0.productName ?? "") < ($1.productName ?? "") } ?? []
    }

    // MARK: - ProductTag Operations
    
    func createProductTag(name: String, color: String) {
        let context = viewContext
        let tag = ProductTag(context: context)
        tag.name = name
        tag.color = color
        tag.userId = currentUserId()
        try? context.save()
    }
    
    func fetchProductTags() -> [ProductTag] {
        let request: NSFetchRequest<ProductTag> = ProductTag.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId())
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }
    
    func deleteProductTag(_ tag: ProductTag) {
        let context = viewContext
        context.delete(tag)
        try? context.save()
    }
    
    func addTag(_ tag: ProductTag, toProduct product: UserProduct) {
        product.addToTags(tag)
        try? viewContext.save()
    }
    
    func removeTag(_ tag: ProductTag, fromProduct product: UserProduct) {
        product.removeFromTags(tag)
        try? viewContext.save()
    }
    
    func products(withTag tag: ProductTag) -> [UserProduct] {
        (tag.products as? Set<UserProduct>)?.sorted { ($0.productName ?? "") < ($1.productName ?? "") } ?? []
    }

    // Fetch only products for the current user
    func fetchUserProducts() -> [UserProduct] {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUserId())
        return (try? viewContext.fetch(request)) ?? []
    }
    
    // Increment usage count for a product
    func incrementUsage(id: NSManagedObjectID) {
        let context = container.newBackgroundContext()
        context.performAndWait {
            if let userProduct = try? context.existingObject(with: id) as? UserProduct {
                userProduct.timesUsed += 1
                try? context.save()
            }
        }
    }
}

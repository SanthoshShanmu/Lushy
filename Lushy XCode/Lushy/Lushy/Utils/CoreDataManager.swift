import Foundation
import CoreData
import Combine

extension Date { var msSinceEpoch: Int64 { Int64(self.timeIntervalSince1970 * 1000) } }

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
        // Before loading persistent stores, enable lightweight migration
        container = NSPersistentContainer(name: "Lushy")
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        
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
        barcode: String?,
        productName: String,
        brand: String?,
        imageUrl: String?,
        purchaseDate: Date,
        openDate: Date?,
        periodsAfterOpening: String?,
        vegan: Bool,
        crueltyFree: Bool,
        expiryOverride: Date? = nil,
        shade: String? = nil,
        sizeInMl: Double? = nil,
        spf: Int16? = nil
    ) -> NSManagedObjectID? {
        // Save in main viewContext for consistent updates
        let context = viewContext
        var objectID: NSManagedObjectID?
        context.performAndWait {
            // Avoid creating duplicates only if we have a non-empty barcode
            if let code = barcode, !code.isEmpty {
                let fetchReq: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
                fetchReq.predicate = NSPredicate(format: "barcode == %@ AND userId == %@", code, currentUserId())
                if let existing = (try? context.fetch(fetchReq))?.first {
                    objectID = existing.objectID
                    return
                }
            }
            let product = UserProduct(context: context)
            // Set properties
            product.barcode = (barcode?.isEmpty == true) ? nil : barcode
            product.productName = productName
            product.brand = brand
            product.imageUrl = imageUrl
            product.purchaseDate = purchaseDate
            product.openDate = openDate
            product.periodsAfterOpening = periodsAfterOpening
            product.vegan = vegan
            product.crueltyFree = crueltyFree
            // New metadata
            product.shade = shade
            product.sizeInMl = sizeInMl ?? 0.0
            product.spf = spf ?? 0
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
                print("Product saved locally (optional barcode): \(productName)")
            } catch {
                print("Failed to save user product: \(error)")
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
                            let body: [String: Any] = ["openDate": openDate.msSinceEpoch]
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
                        "finishDate": Date().msSinceEpoch
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
        // Use a private context to avoid validation on incomplete products
        let context = container.newBackgroundContext()
        let bag = BeautyBag(context: context)
        bag.name = name
        bag.color = color
        bag.icon = icon
        bag.createdAt = Date()
        bag.userId = currentUserId()
        do {
            try context.save()  // only saves bag
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
        // Avoid duplicate assignment
        if let existing = (bag.products as? Set<UserProduct>)?.contains(product), existing {
            return
        }
        bag.addToProducts(product)
        try? viewContext.save()
        
        // Sync to backend with bag activity
        if let userId = AuthService.shared.userId,
           let productBackendId = product.backendId,
           let bagBackendId = bag.backendId {
             let url = APIService.shared.baseURL.appendingPathComponent("users")
                 .appendingPathComponent(userId)
                 .appendingPathComponent("products")
                 .appendingPathComponent(productBackendId)
             var request = URLRequest(url: url)
             request.httpMethod = "PUT"
             request.setValue("application/json", forHTTPHeaderField: "Content-Type")
             if let token = AuthService.shared.token {
                 request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
             }
             // Include the bag's backend ID so backend can create activity
             let body: [String: Any] = ["addToBagId": bagBackendId]
             request.httpBody = try? JSONSerialization.data(withJSONObject: body)
             // Send request to sync bag assignment
             URLSession.shared.dataTask(with: request).resume()
         }
    }
    
    func removeProduct(_ product: UserProduct, fromBag bag: BeautyBag) {
        // Disassociate locally first for instant UI, then sync server
        bag.removeFromProducts(product)
        try? viewContext.save()
        
        // Sync removal to backend so server remains the source of truth
        if let userId = AuthService.shared.userId,
           let productBackendId = product.backendId,
           let bagBackendId = bag.backendId {
            let url = APIService.shared.baseURL
                .appendingPathComponent("users")
                .appendingPathComponent(userId)
                .appendingPathComponent("products")
                .appendingPathComponent(productBackendId)
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = AuthService.shared.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let body: [String: Any] = ["removeFromBagId": bagBackendId]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: request).resume()
        }
    }
    
    func products(inBag bag: BeautyBag) -> [UserProduct] {
        (bag.products as? Set<UserProduct>)?.sorted { ($0.productName ?? "") < ($1.productName ?? "") } ?? []
    }

    // MARK: - ProductTag Operations
    
    // Create a new product tag locally, returns its objectID
    @discardableResult
    func createProductTag(name: String, color: String, backendId: String? = nil) -> NSManagedObjectID? {
        // Use a private context so we don't trigger validation on unsaved products
        let context = container.newBackgroundContext()
        let tag = ProductTag(context: context)
        tag.name = name
        tag.color = color
        tag.userId = currentUserId()
        tag.backendId = backendId
        var objectID: NSManagedObjectID?
        do {
            try context.save()  // only saves tag
            objectID = tag.objectID
            // If this tag was created locally (no backendId), persist to server
            if backendId == nil, let userId = AuthService.shared.userId {
                APIService.shared.createTag(userId: userId, name: name, color: color)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { summary in
                        self.updateProductTagBackendId(id: objectID!, backendId: summary.id)
                    })
                    .store(in: &self.tagCancellables)
            }
        } catch {
            print("Failed to create product tag: \(error)")
        }
        return objectID
    }
    
    // Update the backendId for a product tag
    func updateProductTagBackendId(id: NSManagedObjectID, backendId: String) {
        let context = container.newBackgroundContext()
        context.performAndWait {
            if let tag = try? context.existingObject(with: id) as? ProductTag {
                tag.backendId = backendId
                try? context.save()
            }
        }
    }

    // Storage for Combine subscribers to API calls
    private var tagCancellables = Set<AnyCancellable>()

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
        // Associate locally
        product.addToTags(tag)
        try? viewContext.save()
        // Persist to backend
        if let userId = AuthService.shared.userId,
           let prodId = product.backendId,
           let tagId = tag.backendId {
            APIService.shared.updateProductTags(userId: userId, productId: prodId, addTagId: tagId)
        }
    }
    
    func removeTag(_ tag: ProductTag, fromProduct product: UserProduct) {
        // Disassociate locally
        product.removeFromTags(tag)
        try? viewContext.save()
        // Persist removal to backend
        if let userId = AuthService.shared.userId,
           let prodId = product.backendId,
           let tagId = tag.backendId {
            APIService.shared.removeProductTags(userId: userId, productId: prodId, removeTagId: tagId)
        }
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
    
    // Fetch a single UserProduct by its backend ID
    func fetchUserProduct(backendId: String) -> UserProduct? {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "backendId == %@", backendId)
        return (try? viewContext.fetch(request))?.first
    }
    
    // Clear all local UserProduct objects
    func clearUserProducts() {
        let context = viewContext
        context.performAndWait {
            let fetchReq: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
            if let products = try? context.fetch(fetchReq) {
                products.forEach { context.delete($0) }
            }
            do {
                try context.save()
            } catch {
                print("Failed to clear UserProducts: \(error)")
            }
        }
    }
    
    // Clear all local BeautyBag objects
    func clearBeautyBags() {
        let context = viewContext
        context.performAndWait {
            let fetchReq: NSFetchRequest<BeautyBag> = BeautyBag.fetchRequest()
            if let bags = try? context.fetch(fetchReq) {
                bags.forEach { context.delete($0) }
            }
            do {
                try context.save()
            } catch {
                print("Failed to clear BeautyBags: \(error)")
            }
        }
    }

    // Clear all local ProductTag objects
    func clearProductTags() {
        let context = viewContext
        context.performAndWait {
            let fetchReq: NSFetchRequest<ProductTag> = ProductTag.fetchRequest()
            if let tags = try? context.fetch(fetchReq) {
                tags.forEach { context.delete($0) }
            }
            do {
                try context.save()
            } catch {
                print("Failed to clear ProductTags: \(error)")
            }
        }
    }
    
    // Update core product details and sync to backend
    func updateProductDetails(
        id: NSManagedObjectID,
        productName: String,
        brand: String?,
        shade: String?,
        sizeInMl: Double?,
        spf: Int?,
        purchaseDate: Date,
        isOpened: Bool,
        openDate: Date?,
        periodsAfterOpening: String?
    ) {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        context.performAndWait {
            guard let product = try? context.existingObject(with: id) as? UserProduct else { return }

            // Update fields locally
            product.productName = productName
            product.brand = brand
            product.shade = shade
            product.sizeInMl = sizeInMl ?? 0.0
            product.spf = Int16(spf ?? 0)
            product.purchaseDate = purchaseDate

            if isOpened {
                product.openDate = openDate ?? product.openDate ?? Date()
            } else {
                product.openDate = nil
            }
            product.periodsAfterOpening = periodsAfterOpening

            // Recalculate expiry from PAO and open date
            if let od = product.openDate, let pao = product.periodsAfterOpening, let months = extractMonths(from: pao) {
                let newExpiry = Calendar.current.date(byAdding: .month, value: months, to: od)
                // Cancel and reschedule notification if expiry changed
                if product.expireDate != newExpiry {
                    NotificationService.shared.cancelNotification(for: product)
                    product.expireDate = newExpiry
                    if let _ = newExpiry {
                        NotificationService.shared.scheduleExpiryNotification(for: product)
                    }
                } else {
                    product.expireDate = newExpiry
                }
            } else {
                // No PAO or no open date -> clear expiry
                if product.expireDate != nil {
                    NotificationService.shared.cancelNotification(for: product)
                }
                product.expireDate = nil
            }

            do { try context.save() } catch { print("Failed to save edits: \(error)") }

            // Sync to backend if possible
            if let userId = AuthService.shared.userId, let backendId = product.backendId {
                let url = APIService.shared.baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent(userId)
                    .appendingPathComponent("products")
                    .appendingPathComponent(backendId)
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                var body: [String: Any] = [
                    "productName": productName,
                    "brand": brand ?? "",
                    "purchaseDate": purchaseDate.msSinceEpoch
                ]
                if let shade = shade { body["shade"] = shade }
                if let sizeInMl = sizeInMl { body["sizeInMl"] = sizeInMl }
                if let spf = spf { body["spf"] = spf }
                if isOpened {
                    if let od = product.openDate { body["openDate"] = od.msSinceEpoch }
                    if let pao = periodsAfterOpening { body["periodsAfterOpening"] = pao }
                } else {
                    body["openDate"] = NSNull()
                    body["periodsAfterOpening"] = periodsAfterOpening ?? NSNull()
                }
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                URLSession.shared.dataTask(with: request).resume()
            }
        }
    }
}

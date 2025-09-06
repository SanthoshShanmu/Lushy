import Foundation
import CoreData
import Combine
import UIKit

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
        container = NSPersistentContainer(name: "Lushy")
        
        // Force complete database recreation for size/spf field type changes
        self.forceCompleteReset()
        
        // Configure the context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private func forceCompleteReset() {
        print("🔄 Performing COMPLETE Core Data reset for size/spf field migration...")
        
        // Get all store URLs before any operations
        let storeDescriptions = container.persistentStoreDescriptions
        
        // Delete ALL store files first, before trying to load stores
        let fileManager = FileManager.default
        
        for storeDescription in storeDescriptions {
            guard let storeURL = storeDescription.url else { continue }
            
            let storeDirectory = storeURL.deletingLastPathComponent()
            
            do {
                let files = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    let fileName = file.lastPathComponent
                    if fileName.contains("Lushy") || fileName.contains(".sqlite") {
                        try fileManager.removeItem(at: file)
                        print("🗑️ Deleted: \(fileName)")
                    }
                }
            } catch {
                print("Warning: Could not clean database files: \(error)")
            }
        }
        
        // Also clear any cached Core Data metadata
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let coreDataPath = documentsPath.appendingPathComponent("CoreDataModel_CACHE")
            try? fileManager.removeItem(at: coreDataPath)
            print("🗑️ Cleared Core Data cache")
        }
        
        // Force recreation of persistent store descriptions
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.shouldInferMappingModelAutomatically = false
            storeDescription.shouldMigrateStoreAutomatically = false
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        // Now load the persistent stores with fresh configuration
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ Store loading failed after reset: \(error)")
                fatalError("Could not load Core Data store after reset: \(error)")
            } else {
                print("✅ Core Data store loaded successfully after complete reset")
                
                // Clear any potential expression caches by forcing a simple query
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    do {
                        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
                        request.fetchLimit = 1
                        _ = try self.viewContext.fetch(request)
                        print("✅ Core Data expressions validated successfully")
                    } catch {
                        print("⚠️ Expression validation failed: \(error)")
                    }
                }
                
                // Schedule data sync to repopulate
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Try to sync data back from backend
                    SyncService.shared.performInitialSync()
                }
            }
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
        size: String? = nil, // Changed from sizeInMl: Double? to size: String?
        spf: String? = nil, // Changed from spf: Int16? to spf: String?
        price: Double? = nil,
        currency: String? = nil
    ) -> NSManagedObjectID? {
        // Save in main viewContext for consistent updates
        let context = viewContext
        var objectID: NSManagedObjectID?
        context.performAndWait {
            // Remove duplicate prevention - let backend handle duplicates properly
            let product = UserProduct(context: context)
            // Set properties
            product.barcode = (barcode?.isEmpty == true) ? nil : barcode
            product.productName = productName
            product.brand = brand
            
            // Handle image URL - could be file path, URL, or data URL
            if let imageUrl = imageUrl {
                if imageUrl.hasPrefix("data:") {
                    // This is already a data URL (base64), store it directly
                    product.imageUrl = imageUrl
                } else if imageUrl.hasPrefix("http") {
                    // This is a regular URL, keep it as is
                    product.imageUrl = imageUrl
                } else {
                    // This is a local file path, convert to data URL if possible
                    if let imageData = FileManager.default.contents(atPath: imageUrl),
                       let image = UIImage(data: imageData),
                       let jpegData = image.jpegData(compressionQuality: 0.8) {
                        let base64String = jpegData.base64EncodedString()
                        product.imageUrl = "data:image/jpeg;base64,\(base64String)"
                    } else {
                        product.imageUrl = imageUrl
                    }
                }
            }
            
            product.purchaseDate = purchaseDate
            product.openDate = openDate
            product.periodsAfterOpening = periodsAfterOpening
            product.vegan = vegan
            product.crueltyFree = crueltyFree
            // New metadata
            product.shade = shade
            product.size = size
            product.spf = spf
            // Add price and currency
            product.price = price ?? 0.0
            product.currency = currency ?? "USD"
            product.userId = currentUserId()
            product.quantity = 1
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
                
                // Create Usage Journey event for purchasing product
                if let productID = objectID {
                    DispatchQueue.main.async {
                        self.addUsageJourneyEventNew(
                            to: productID,
                            type: .purchase,
                            text: nil,
                            title: nil,
                            rating: 0,
                            date: purchaseDate
                        )
                    }
                }
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
                    
                    // Create Usage Journey event for opening product
                    DispatchQueue.main.async {
                        self.addUsageJourneyEventNew(
                            to: id,
                            type: .open,
                            text: nil,
                            title: nil,
                            rating: 0,
                            date: openDate
                        )
                    }
                    
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
                    
                    // Create Usage Journey event for review
                    DispatchQueue.main.async {
                        self.addUsageJourneyEventNew(
                            to: productID,
                            type: .review,
                            text: text,
                            title: title,
                            rating: Int16(rating)
                        )
                    }
                    
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
                                // Remove the RefreshFeed notification to prevent infinite loops
                                // The Core Data context save will already notify any observers
                            }.resume()
                        }
                    }
                } catch {
                    print("Failed to save review: \(error)")
                }
            }
        }
    }
    
    // Delete a product (now also deletes remotely if synced)
    func deleteProduct(id: NSManagedObjectID) {
        let context = container.newBackgroundContext()
        context.perform {
            guard let userProduct = try? context.existingObject(with: id) as? UserProduct else { return }
            // Cancel any pending notifications for this product
            NotificationService.shared.cancelNotification(for: userProduct)
            let backendId = userProduct.backendId
            let userId = AuthService.shared.userId
            // Optimistically delete locally for instant UI
            context.delete(userProduct)
            do { try context.save() } catch { print("Error deleting product: \(error)") }
            // Notify UI layers
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("ProductDeleted"), object: id)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
            }
            // Attempt remote deletion if identifiers available
            if let backendId = backendId, let userId = userId {
                var request = URLRequest(url: APIService.shared.baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent(userId)
                    .appendingPathComponent("products")
                    .appendingPathComponent(backendId))
                request.httpMethod = "DELETE"
                if let token = AuthService.shared.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                URLSession.shared.dataTask(with: request).resume()
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
                print("Failed to find product for finishing")
                return
            }
            
            // Check if already finished to prevent infinite loops
            if product.isFinished {
                print("Product already finished, skipping")
                return
            }
            
            // Cancel any pending notifications
            NotificationService.shared.cancelNotification(for: product)
            
            // Mark as finished
            let finishDate = Date()
            product.setValue(true, forKey: "isFinished")
            product.setValue(finishDate, forKey: "finishDate")
            product.currentAmount = 0.0 // Ensure amount is 0
            
            do {
                try context.save()
                print("Product marked as finished successfully")
                
                // Create Usage Journey event for finishing product
                DispatchQueue.main.async {
                    self.addUsageJourneyEventNew(
                        to: id,
                        type: .finished,
                        text: nil,
                        title: nil,
                        rating: 0,
                        date: finishDate
                    )
                }
                
                // Sync to backend only once, with retry logic
                if let userId = AuthService.shared.userId, let backendId = product.backendId {
                    DispatchQueue.main.async {
                        self.syncFinishedProductToBackend(userId: userId, backendId: backendId)
                    }
                }
                
                // Notify on the main thread after successful save - but avoid triggering more finish operations
                DispatchQueue.main.async {
                    // Post a specific notification for finished products instead of the generic context save
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ProductFinished"),
                        object: id
                    )
                    // Remove RefreshFeed notification to prevent infinite loops
                    // The Core Data context save will automatically update any views observing Core Data
                }
            } catch {
                print("Error marking product as finished: \(error)")
            }
        }
    }
    
    // Separate method for backend sync with retry logic
    private func syncFinishedProductToBackend(userId: String, backendId: String) {
        let url = APIService.shared.baseURL.appendingPathComponent("users/")
            .appendingPathComponent(userId)
            .appendingPathComponent("products/")
            .appendingPathComponent(backendId)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // Add timeout
        
        if let token = AuthService.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "isFinished": true,
            "finishDate": Date().msSinceEpoch,
            "currentAmount": 0.0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to sync finished product to backend: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        print("Successfully synced finished product to backend")
                        
                        // After successful backend sync, refresh products to get updated quantities
                        // The backend will have decremented quantities for similar products
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            SyncService.shared.fetchRemoteProducts()
                        }
                    } else {
                        print("Backend returned error status: \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        } catch {
            print("Failed to serialize finish request: \(error)")
        }
    }

    // MARK: - BeautyBag Operations
    
    // Create a new beauty bag locally, returns its objectID
    func createBeautyBag(name: String, description: String = "", color: String, icon: String, image: String? = nil, isPrivate: Bool = false, imageData: Data? = nil) -> NSManagedObjectID? {
        // Use a private context to avoid validation on incomplete products
        let context = container.newBackgroundContext()
        let bag = BeautyBag(context: context)
        bag.name = name
        bag.bagDescription = description
        bag.color = color
        bag.icon = icon
        bag.image = image
        bag.isPrivate = isPrivate
        bag.createdAt = Date()
        bag.userId = currentUserId()
        
        // Store image data if provided
        if let imageData = imageData {
            bag.imageData = imageData
        }
        
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

    // Update an existing beauty bag
    func updateBeautyBag(id: NSManagedObjectID, name: String, description: String, color: String, icon: String, image: String? = nil, isPrivate: Bool, imageData: Data? = nil) {
        let context = container.newBackgroundContext()
        context.performAndWait {
            if let bag = try? context.existingObject(with: id) as? BeautyBag {
                bag.name = name
                bag.bagDescription = description
                bag.color = color
                bag.icon = icon
                bag.image = image
                bag.isPrivate = isPrivate
                
                // Update image data if provided
                if let imageData = imageData {
                    bag.imageData = imageData
                }
                
                try? context.save()
            }
        }
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

    // Fetch only products for the current user (excluding finished products by default)
    func fetchUserProducts(includeFinished: Bool = false) -> [UserProduct] {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        if includeFinished {
            // Include all products (for Stats view, etc.)
            request.predicate = NSPredicate(format: "userId == %@", currentUserId())
        } else {
            // Exclude finished products by default
            request.predicate = NSPredicate(format: "userId == %@ AND isFinished != YES", currentUserId())
        }
        
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
        size: String?,
        spf: String?,
        price: Double?,
        currency: String,
        purchaseDate: Date,
        isOpened: Bool,
        openDate: Date?,
        periodsAfterOpening: String?,
        vegan: Bool,
        crueltyFree: Bool,
        imageUrl: String?
    ) {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        context.performAndWait {
            guard let product = try? context.existingObject(with: id) as? UserProduct else { return }

            // Update fields locally
            product.productName = productName
            product.brand = brand
            product.shade = shade
            product.size = size
            product.spf = spf
            product.price = price ?? 0.0
            product.currency = currency
            product.purchaseDate = purchaseDate
            product.vegan = vegan
            product.crueltyFree = crueltyFree

            // Update image if provided
            if let imageUrl = imageUrl {
                product.imageUrl = imageUrl
            }

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
                    "purchaseDate": purchaseDate.msSinceEpoch,
                    "vegan": vegan,
                    "crueltyFree": crueltyFree,
                    "price": price ?? 0.0,
                    "currency": currency
                ]
                if let shade = shade { body["shade"] = shade }
                if let size = size { body["size"] = size }
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
    
    // MARK: - Usage Tracking Operations
    
    // Add a new usage entry
    func addUsageEntry(to productID: NSManagedObjectID, type: String, amount: Double, notes: String? = nil) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            guard let product = try? context.existingObject(with: productID) as? UserProduct else { return }
            
            let usageEntry = UsageEntry(context: context)
            usageEntry.usageType = type
            usageEntry.usageAmount = amount
            usageEntry.notes = notes
            usageEntry.createdAt = Date()
            usageEntry.userId = currentUserId()
            usageEntry.userProduct = product
            
            // Update product's current amount
            let newAmount = max(0, product.currentAmount - amount)
            product.currentAmount = newAmount
            
            // Mark as opened if first usage and not already opened
            if product.openDate == nil {
                product.openDate = Date()
                
                // Calculate expiry if we have PAO
                if let pao = product.periodsAfterOpening, let months = extractMonths(from: pao) {
                    product.expireDate = Calendar.current.date(byAdding: .month, value: months, to: Date())
                    NotificationService.shared.scheduleExpiryNotification(for: product)
                }
            }
            
            do {
                try context.save()
                
                // Sync to backend
                if let userId = AuthService.shared.userId, let backendId = product.backendId {
                    DispatchQueue.main.async {
                        let url = APIService.shared.baseURL
                            .appendingPathComponent("users")
                            .appendingPathComponent(userId)
                            .appendingPathComponent("products")
                            .appendingPathComponent(backendId)
                            .appendingPathComponent("usage")
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        if let token = AuthService.shared.token {
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                        
                        let body: [String: Any] = [
                            "usageType": type,
                            "usageAmount": amount,
                            "notes": notes ?? "",
                            "currentAmount": newAmount
                        ]
                        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                        URLSession.shared.dataTask(with: request).resume()
                    }
                }
            } catch {
                print("Failed to save usage entry: \(error)")
            }
        }
    }
    
    // Fetch usage entries for a product
    func fetchUsageEntries(for productID: NSManagedObjectID) -> [UsageEntry] {
        let request: NSFetchRequest<UsageEntry> = UsageEntry.fetchRequest()
        
        do {
            let product = try viewContext.existingObject(with: productID) as? UserProduct
            request.predicate = NSPredicate(format: "userProduct == %@", product!)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching usage entries: \(error)")
            return []
        }
    }
    
    // Update product's current amount
    func updateProductAmount(id: NSManagedObjectID, newAmount: Double) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            guard let product = try? context.existingObject(with: id) as? UserProduct else { return }
            
            product.currentAmount = max(0, newAmount)
            
            // Mark as finished if empty
            if newAmount <= 0 && !product.isFinished {
                product.setValue(true, forKey: "isFinished")
                product.setValue(Date(), forKey: "finishDate")
                NotificationService.shared.cancelNotification(for: product)
            }
            
            try? context.save()
        }
    }
    
    // MARK: - Usage Journey Operations
    
    // Add a new usage journey event
    func addUsageJourneyEventNew(
        to productID: NSManagedObjectID,
        type: UsageJourneyEvent.EventType,
        text: String?,
        title: String?,
        rating: Int16,
        date: Date = Date()
    ) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            guard let product = try? context.existingObject(with: productID) as? UserProduct else { return }
            
            let event = UsageJourneyEvent(
                context: context,
                type: type,
                text: text,
                title: title,
                rating: rating,
                date: date
            )
            event.userProduct = product
            
            do {
                try context.save()
                print("Usage journey event created: \(type.displayName)")
            } catch {
                print("Failed to save usage journey event: \(error)")
            }
        }
    }
    
    // Fetch usage journey events for a product
    func fetchUsageJourneyEvents(for productID: NSManagedObjectID) -> [UsageJourneyEvent] {
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        
        do {
            let product = try viewContext.existingObject(with: productID) as? UserProduct
            request.predicate = NSPredicate(format: "userProduct == %@", product!)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching usage journey events: \(error)")
            return []
        }
    }
    
    // MARK: - Product Quantity Calculations
    
    /// Count similar active (non-finished) products for quantity display
    func countSimilarActiveProducts(productName: String?, brand: String?, size: String?) -> Int {
        // Use a safer approach that avoids NSPredicate queries with the size field entirely
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        // Only use safe predicates that don't involve the size field
        var predicates: [NSPredicate] = [
            NSPredicate(format: "userId == %@", currentUserId() as NSString),
            NSPredicate(format: "isFinished != YES") // Only count non-finished products
        ]
        
        // Match by product name and brand using safe string comparisons
        if let productName = productName {
            predicates.append(NSPredicate(format: "productName == %@", productName as NSString))
        }
        
        if let brand = brand {
            predicates.append(NSPredicate(format: "brand == %@", brand as NSString))
        }
        
        // Completely avoid using size in NSPredicate - fetch all matching products and filter manually
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let products = try viewContext.fetch(request)
            
            // If no size filter needed, return count directly
            guard let size = size, !size.isEmpty else {
                return products.count
            }
            
            // Manual filtering for size to avoid Core Data expression issues
            let filteredProducts = products.filter { product in
                return product.size == size
            }
            
            return filteredProducts.count
        } catch {
            print("Error counting similar active products: \(error)")
            // Ultimate fallback: return 1 to prevent crashes
            return 1
        }
    }
}

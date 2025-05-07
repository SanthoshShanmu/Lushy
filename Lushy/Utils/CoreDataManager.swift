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
                } catch {
                    print("Failed to save review: \(error)")
                }
            }
        }
    }
    
    // Toggle favorite status
    func toggleFavorite(id: NSManagedObjectID) {
        let context = viewContext
        
        context.perform {
            guard let product = try? context.existingObject(with: id) as? UserProduct else {
                return
            }
            
            // Toggle the favorite status
            product.favorite = !product.favorite
            
            // Save the context immediately
            try? context.save()
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
                
                // Notify on the main thread after successful save
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .NSManagedObjectContextDidSave,
                        object: context
                    )
                }
            } catch {
                print("Error updating product: \(error)")
            }
        }
    }
}

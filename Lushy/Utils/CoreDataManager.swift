import Foundation
import CoreData
import Combine

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    private init() {
        container = NSPersistentContainer(name: "Lushy")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    // MARK: - UserProduct Operations
    
    func saveUserProduct(barcode: String, 
                        productName: String,
                        brand: String?,
                        imageUrl: String?,
                        purchaseDate: Date,
                        openDate: Date?,
                        periodsAfterOpening: String?,
                        vegan: Bool,
                        crueltyFree: Bool) -> NSManagedObjectID? {
        
        let context = container.newBackgroundContext()
        var objectID: NSManagedObjectID?
        
        context.performAndWait {
            let userProduct = NSEntityDescription.insertNewObject(forEntityName: "UserProduct", into: context) as! UserProduct
            
            userProduct.barcode = barcode
            userProduct.productName = productName
            userProduct.brand = brand
            userProduct.imageUrl = imageUrl
            userProduct.purchaseDate = purchaseDate
            userProduct.openDate = openDate
            userProduct.periodsAfterOpening = periodsAfterOpening
            userProduct.vegan = vegan
            userProduct.crueltyFree = crueltyFree
            userProduct.favorite = false
            userProduct.inWishlist = false
            userProduct.comments = []
            userProduct.reviews = []
            
            // Calculate expiry date if opened and has periodsAfterOpening
            if let openDate = openDate, let periodsAfterOpening = periodsAfterOpening {
                if let months = extractMonths(from: periodsAfterOpening) {
                    userProduct.expireDate = Calendar.current.date(byAdding: .month, value: months, to: openDate)
                }
            }
            
            do {
                try context.save()
                objectID = userProduct.objectID
            } catch {
                print("Error saving UserProduct: \(error)")
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
            if let userProduct = context.object(with: id) as? UserProduct {
                let comment = Comment(text: text)
                var comments = userProduct.comments ?? []
                comments.append(comment)
                userProduct.comments = comments
                
                do {
                    try context.save()
                } catch {
                    print("Error saving comment: \(error)")
                }
            }
        }
    }
    
    // Add review to a product
    func addReview(to productID: NSManagedObjectID, rating: Int, title: String, text: String) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            if let userProduct = context.object(with: id) as? UserProduct {
                let review = Review(rating: rating, title: title, text: text)
                var reviews = userProduct.reviews ?? []
                reviews.append(review)
                userProduct.reviews = reviews
                
                do {
                    try context.save()
                } catch {
                    print("Error saving review: \(error)")
                }
            }
        }
    }
    
    // Toggle favorite status
    func toggleFavorite(id: NSManagedObjectID) {
        let context = container.newBackgroundContext()
        
        context.performAndWait {
            if let userProduct = context.object(with: id) as? UserProduct {
                userProduct.favorite = !userProduct.favorite
                
                do {
                    try context.save()
                } catch {
                    print("Error toggling favorite: \(error)")
                }
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
        let pattern = "(\\d+)\\s*[Mm]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        if let match = regex.firstMatch(in: periodString, range: NSRange(periodString.startIndex..., in: periodString)) {
            if let range = Range(match.range(at: 1), in: periodString) {
                return Int(periodString[range])
            }
        }
        return nil
    }
}
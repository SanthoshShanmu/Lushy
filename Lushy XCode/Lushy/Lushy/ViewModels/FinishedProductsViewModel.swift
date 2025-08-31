import Foundation
import CoreData
import Combine

class FinishedProductsViewModel: ObservableObject {
    @Published var finishedProducts: [UserProduct] = []
    @Published var selectedBag: BeautyBag? = nil
    @Published var selectedTag: ProductTag? = nil
    @Published var allBags: [BeautyBag] = []
    @Published var allTags: [ProductTag] = []
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchFinishedProducts()
        
        // Subscribe to context changes to keep the UI updated
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchFinishedProducts()
            }
            .store(in: &cancellables)
    }
    
    func fetchFinishedProducts() {
        fetchAllBagsAndTags()
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "isFinished == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "finishDate", ascending: false)]
        
        do {
            var products = try managedObjectContext.fetch(request)
            if let bag = selectedBag {
                products = products.filter { ($0.bags as? Set<BeautyBag>)?.contains(bag) == true }
            }
            if let tag = selectedTag {
                products = products.filter { ($0.tags as? Set<ProductTag>)?.contains(tag) == true }
            }
            
            // Group products by unique identity (name + brand + size) and keep only one instance per unique product
            var uniqueProducts: [String: UserProduct] = [:]
            
            for product in products {
                let productKey = makeProductKey(for: product)
                
                // If we haven't seen this product before, or if this instance was finished more recently, keep it
                if let existingProduct = uniqueProducts[productKey] {
                    if let currentFinishDate = product.finishDate,
                       let existingFinishDate = existingProduct.finishDate,
                       currentFinishDate > existingFinishDate {
                        uniqueProducts[productKey] = product
                    }
                } else {
                    uniqueProducts[productKey] = product
                }
            }
            
            // Convert back to array and sort by finish date
            finishedProducts = Array(uniqueProducts.values)
                .sorted { product1, product2 in
                    guard let date1 = product1.finishDate,
                          let date2 = product2.finishDate else {
                        return false
                    }
                    return date1 > date2
                }
        } catch {
            print("Error fetching finished products: \(error)")
        }
    }
    
    // Helper method to create a unique key for grouping products
    private func makeProductKey(for product: UserProduct) -> String {
        let name = product.productName ?? ""
        let brand = product.brand ?? ""
        let size = product.sizeInMl > 0 ? String(Int(product.sizeInMl)) : ""
        return "\(brand)|\(name)|\(size)"
    }
    
    func fetchAllBagsAndTags() {
        allBags = CoreDataManager.shared.fetchBeautyBags()
        allTags = CoreDataManager.shared.fetchProductTags()
    }

    func setBagFilter(_ bag: BeautyBag?) {
        selectedBag = bag
        fetchFinishedProducts()
    }

    func setTagFilter(_ tag: ProductTag?) {
        selectedTag = tag
        fetchFinishedProducts()
    }
    
    // Add method to count finished instances of the same product
    func finishedInstancesCount(for product: UserProduct) -> Int {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "isFinished == YES")
        ]
        
        // Match by product name and brand
        if let productName = product.productName {
            predicates.append(NSPredicate(format: "productName == %@", productName))
        }
        
        if let brand = product.brand {
            predicates.append(NSPredicate(format: "brand == %@", brand))
        }
        
        // Match by size if available (within 10ml tolerance)
        if product.sizeInMl > 0 {
            let minSize = product.sizeInMl - 10
            let maxSize = product.sizeInMl + 10
            predicates.append(NSPredicate(format: "sizeInMl >= %f AND sizeInMl <= %f", minSize, maxSize))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let count = try managedObjectContext.count(for: request)
            return count
        } catch {
            print("Error counting finished instances: \(error)")
            return 1
        }
    }
    
    // Add method to count NON-FINISHED instances of the same product
    func activeInstancesCount(for product: UserProduct) -> Int {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "isFinished != YES") // Only count non-finished products
        ]
        
        // Match by product name and brand
        if let productName = product.productName {
            predicates.append(NSPredicate(format: "productName == %@", productName))
        }
        
        if let brand = product.brand {
            predicates.append(NSPredicate(format: "brand == %@", brand))
        }
        
        // Match by size if available (within 10ml tolerance)
        if product.sizeInMl > 0 {
            let minSize = product.sizeInMl - 10
            let maxSize = product.sizeInMl + 10
            predicates.append(NSPredicate(format: "sizeInMl >= %f AND sizeInMl <= %f", minSize, maxSize))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let count = try managedObjectContext.count(for: request)
            return count
        } catch {
            print("Error counting active instances: \(error)")
            return 1
        }
    }
}
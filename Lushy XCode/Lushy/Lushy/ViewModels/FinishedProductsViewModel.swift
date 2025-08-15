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
            finishedProducts = products
        } catch {
            print("Error fetching finished products: \(error)")
        }
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
}
import Foundation
import CoreData
import Combine

class FavoritesViewModel: ObservableObject {
    @Published var favoriteProducts: [UserProduct] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchFavorites()
        
        // Subscribe to context changes to keep the UI updated
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchFavorites()
            }
            .store(in: &cancellables)
    }
    
    // Fetch favorite products from Core Data
    func fetchFavorites() {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "favorite == YES")
        
        do {
            favoriteProducts = try managedObjectContext.fetch(request)
        } catch {
            print("Error fetching favorites: \(error)")
        }
    }
    
    // Toggle favorite status
    func toggleFavorite(product: UserProduct) {
        CoreDataManager.shared.toggleFavorite(id: product.objectID)
    }
}
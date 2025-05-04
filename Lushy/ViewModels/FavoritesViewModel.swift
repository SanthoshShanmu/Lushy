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
        // Store the ID
        let productID = product.objectID
        
        // Toggle in CoreData
        CoreDataManager.shared.toggleFavorite(id: productID)
        
        // Immediately update UI without waiting for notification
        DispatchQueue.main.async {
            // If we're removing from favorites, remove from our array
            if !product.favorite {
                self.favoriteProducts.removeAll { $0.objectID == productID }
            } else {
                // Re-fetch all favorites to ensure proper sorting/filtering
                self.fetchFavorites()
            }
        }
    }
}

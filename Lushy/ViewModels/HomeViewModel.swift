import Foundation
import CoreData
import Combine
import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var openProducts: [UserProduct] = []
    @Published var expiringProducts: [UserProduct] = []
    @Published var storedProducts: [UserProduct] = []
    @Published var selectedProduct: UserProduct?
    @Published var showProductDetail = false
    
    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchProducts()
        
        // Subscribe to context changes to keep the UI updated
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchProducts()
            }
            .store(in: &cancellables)
    }
    
    // Fetch products and sort into sections
    func fetchProducts() {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        do {
            let allProducts = try managedObjectContext.fetch(request)
            
            // Sort products into categories
            let today = Date()
            
            // Products that have been opened
            openProducts = allProducts.filter { product in
                guard let openDate = product.openDate else { return false }
                guard let expireDate = product.expireDate else { return true } // If no expiry, consider open
                return openDate <= today && expireDate > today
            }
            
            // Products that are expiring soon (within 30 days)
            expiringProducts = allProducts.filter { product in
                guard let expireDate = product.expireDate else { return false }
                let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: today)!
                return expireDate <= thirtyDaysFromNow && expireDate > today
            }
            
            // Products in storage (purchased but not opened)
            storedProducts = allProducts.filter { product in
                return product.openDate == nil
            }
            
        } catch {
            print("Error fetching products: \(error)")
        }
    }
    
    // Method for navigating to a specific product (e.g., from notifications)
    func navigateToProduct(with barcode: String) {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", barcode)
        
        do {
            let matchingProducts = try managedObjectContext.fetch(request)
            if let product = matchingProducts.first {
                selectedProduct = product
                showProductDetail = true
            }
        } catch {
            print("Error fetching product with barcode \(barcode): \(error)")
        }
    }
    
    // Mark a product as opened
    func markProductAsOpened(product: UserProduct) {
        CoreDataManager.shared.markProductAsOpened(id: product.objectID, openDate: Date())
        
        // Schedule expiry notification
        NotificationService.shared.scheduleExpiryNotification(for: product)
    }
    
    // Toggle favorite status
    func toggleFavorite(product: UserProduct) {
        CoreDataManager.shared.toggleFavorite(id: product.objectID)
    }
    
    // Delete product
    func deleteProduct(product: UserProduct) {
        // Cancel any pending notifications
        NotificationService.shared.cancelNotification(for: product)
        
        // Delete from Core Data
        CoreDataManager.shared.deleteProduct(id: product.objectID)
    }
}
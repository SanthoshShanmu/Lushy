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
        print("HomeViewModel: initializing")
        
        fetchProducts()
        
        print("HomeViewModel: setting up notification listener")
        
        // Subscribe to context changes to keep the UI updated
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                print("HomeViewModel: received context did save notification")
                self?.fetchProducts()
            }
            .store(in: &cancellables)
        
        print("HomeViewModel: initialization complete")
    }
    
    // Fetch products and sort into sections
    func fetchProducts() {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        
        // Ensure we're on the main thread when fetching and updating UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let allProducts = try self.managedObjectContext.fetch(request)
                
                // Sort products into categories
                let today = Date()
                
                // Products that have been opened
                self.openProducts = allProducts.filter { product in
                    // Skip products that are marked as finished
                    guard product.value(forKey: "isFinished") as? Bool != true else {
                        return false
                    }
                    
                    guard let openDate = product.openDate else { return false }
                    guard let expireDate = product.expireDate else { return true }
                    return openDate <= today && expireDate > today
                }
                
                // Products that are expiring soon (within 30 days)
                self.expiringProducts = allProducts.filter { product in
                    // Skip products that are marked as finished
                    guard product.value(forKey: "isFinished") as? Bool != true else {
                        return false
                    }
                    
                    guard let expireDate = product.expireDate else { return false }
                    let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: today)!
                    return expireDate <= thirtyDaysFromNow && expireDate > today
                }
                
                // Products in storage (purchased but not opened)
                self.storedProducts = allProducts.filter { product in
                    // Skip products that are marked as finished
                    guard product.value(forKey: "isFinished") as? Bool != true else {
                        return false
                    }
                    
                    return product.openDate == nil
                }
                
            } catch {
                print("Error fetching products: \(error)")
            }
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
        // Store the ID before toggling
        let productID = product.objectID
        
        // Toggle favorite status in CoreData
        CoreDataManager.shared.toggleFavorite(id: productID)
        
        // Immediately update the UI for this specific product
        DispatchQueue.main.async {
            // Refresh the specific product in our collections
            if let updatedProduct = try? self.managedObjectContext.existingObject(with: productID) as? UserProduct {
                // Find and update the product in all arrays
                self.updateProductInArrays(updatedProduct)
            }
        }
    }
    
    // Add this helper method to update a product in all arrays
    private func updateProductInArrays(_ updatedProduct: UserProduct) {
        // Update in openProducts
        if let index = openProducts.firstIndex(where: { $0.objectID == updatedProduct.objectID }) {
            openProducts[index] = updatedProduct
        }
        
        // Update in expiringProducts
        if let index = expiringProducts.firstIndex(where: { $0.objectID == updatedProduct.objectID }) {
            expiringProducts[index] = updatedProduct
        }
        
        // Update in storedProducts
        if let index = storedProducts.firstIndex(where: { $0.objectID == updatedProduct.objectID }) {
            storedProducts[index] = updatedProduct
        }
        
        // If this is the selected product, update it too
        if let selected = selectedProduct, selected.objectID == updatedProduct.objectID {
            selectedProduct = updatedProduct
        }
    }
    
    // Delete product
    func deleteProduct(product: UserProduct) {
        // First remove the product from arrays to prevent UI from referencing deleted objects
        openProducts.removeAll { $0.objectID == product.objectID }
        expiringProducts.removeAll { $0.objectID == product.objectID }
        storedProducts.removeAll { $0.objectID == product.objectID }
        
        // If this was the selected product, clear the selection
        if selectedProduct?.objectID == product.objectID {
            selectedProduct = nil
            showProductDetail = false 
        }
        
        // Cancel any pending notifications
        NotificationService.shared.cancelNotification(for: product)
        
        // Then delete from Core Data
        CoreDataManager.shared.deleteProduct(id: product.objectID)
    }
}

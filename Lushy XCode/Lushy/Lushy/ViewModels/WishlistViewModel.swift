import Foundation
import SwiftUI
import Combine

class WishlistViewModel: ObservableObject {
    @Published var wishlistItems: [AppWishlistItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Properties for adding new items
    @Published var newProductName = ""
    @Published var newProductURL = ""
    @Published var newProductNotes = ""
    @Published var newProductImageURL: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    // Method to fetch wishlist items
    func fetchWishlist() {
        isLoading = true
        errorMessage = nil
        
        // Debug print before API call
        print("Fetching wishlist with token: \(AuthService.shared.token ?? "none")")
        
        // Add timeout protection
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isLoading == true {
                    print("Wishlist request timed out after 15 seconds")
                    self?.isLoading = false
                    self?.errorMessage = "Request timed out. Please check your internet connection."
                }
            }
        }
        
        // Use the correct API extension method instead of the old one
        APIService.shared.fetchWishlist() // This calls the APIService+Wishlist extension
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                timeoutTimer.invalidate()
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    print("Wishlist error: \(error)")
                    if error == .authenticationRequired {
                        self?.errorMessage = "Please log in to view your wishlist"
                        NotificationCenter.default.post(name: NSNotification.Name("AuthenticationFailed"), object: nil)
                    } else {
                        self?.errorMessage = "Failed to load wishlist: \(error)"
                    }
                }
            } receiveValue: { [weak self] items in
                self?.wishlistItems = items
                print("Successfully loaded \(items.count) wishlist items")
            }
            .store(in: &cancellables)
    }
    
    // Method to add a new item
    func addWishlistItem() {
        guard !newProductName.isEmpty, !newProductURL.isEmpty else { return }
        
        // Check for duplicates by product name and URL
        let isDuplicate = wishlistItems.contains { item in
            item.productName.lowercased() == newProductName.lowercased() ||
            item.productURL.lowercased() == newProductURL.lowercased()
        }
        
        if isDuplicate {
            errorMessage = "This product is already in your wishlist!"
            return
        }
        
        let item = NewWishlistItem(
            productName: newProductName,
            productURL: newProductURL,
            notes: newProductNotes,
            imageURL: newProductImageURL
        )
        
        isLoading = true
        // Use the correct API extension method
        APIService.shared.addWishlistItem(item) // This calls the APIService+Wishlist extension
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    print("Add wishlist item error: \(error)")
                    self?.errorMessage = "Failed to add item: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] _ in
                print("Successfully added wishlist item")
                // Reset form fields
                self?.newProductName = ""
                self?.newProductURL = ""
                self?.newProductNotes = ""
                self?.newProductImageURL = nil
                
                // Refresh the list
                self?.fetchWishlist()
            }
            .store(in: &cancellables)
    }
    
    // Method to remove an item
    func removeItem(at offsets: IndexSet) {
        guard let index = offsets.first, index < wishlistItems.count else { return }
        let itemToDelete = wishlistItems[index]
        
        // Use the correct API extension method
        APIService.shared.deleteWishlistItem(id: itemToDelete.id.uuidString) // This calls the APIService+Wishlist extension
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Delete wishlist item error: \(error)")
                    self?.errorMessage = "Failed to delete item: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] _ in
                print("Successfully deleted wishlist item")
                // Remove from local array
                self?.wishlistItems.remove(at: index)
            }
            .store(in: &cancellables)
    }
}

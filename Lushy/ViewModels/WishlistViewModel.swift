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
        
        APIService.shared.fetchWishlist()
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
        
        let item = NewWishlistItem(
            productName: newProductName,
            productURL: newProductURL,
            notes: newProductNotes,
            imageURL: newProductImageURL
        )
        
        isLoading = true
        APIService.shared.addWishlistItem(item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to add item: \(error)"
                }
            } receiveValue: { [weak self] _ in
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
        
        APIService.shared.deleteWishlistItem(id: itemToDelete.id.uuidString)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to delete item: \(error)"
                }
            } receiveValue: { [weak self] _ in
                // Remove from local array
                self?.wishlistItems.remove(at: index)
            }
            .store(in: &cancellables)
    }
}

// Only define the new item struct, not WishlistItem
struct NewWishlistItem: Codable {
    let productName: String
    let productURL: String
    let notes: String
    let imageURL: String?
}

import Foundation
import SwiftUI
import Combine

class WishlistViewModel: ObservableObject {
    // Published properties for the view to observe
    @Published var wishlistItems: [WishlistItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Properties for adding new items
    @Published var newProductName = ""
    @Published var newProductURL = ""
    @Published var newProductNotes = ""
    @Published var newProductImageURL: String? = nil
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService = APIService.shared) {
        self.apiService = apiService
    }
    
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
        
        apiService.fetchWishlist { [weak self] result in
            // Cancel the timeout timer
            timeoutTimer.invalidate()
            
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let items):
                    self?.wishlistItems = items
                    print("Successfully loaded \(items.count) wishlist items")
                    
                case .failure(let error):
                    print("Wishlist error: \(error)")
                    if let apiError = error as? APIError, apiError == .authenticationRequired {
                        self?.errorMessage = "Please log in to view your wishlist"
                        // Only post authentication failed for actual auth errors
                        NotificationCenter.default.post(name: NSNotification.Name("AuthenticationFailed"), object: nil)
                    } else {
                        // Handle other errors differently - don't trigger login prompt
                        self?.errorMessage = "Failed to load wishlist: \(error.localizedDescription)"
                    }
                }
            }
        }
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
        apiService.addWishlistItem(item) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    // Reset form fields
                    self?.newProductName = ""
                    self?.newProductURL = ""
                    self?.newProductNotes = ""
                    self?.newProductImageURL = nil
                    
                    // Refresh the list
                    self?.fetchWishlist()
                    
                case .failure(let error):
                    self?.errorMessage = "Failed to add item: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Method to remove an item
    func removeItem(at offsets: IndexSet) {
        guard let index = offsets.first, index < wishlistItems.count else { return }
        let itemToDelete = wishlistItems[index]
        
        apiService.deleteWishlistItem(id: itemToDelete.id.uuidString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local array
                    self?.wishlistItems.remove(at: index)
                    
                case .failure(let error):
                    self?.errorMessage = "Failed to delete item: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Only define the new item struct, not WishlistItem
struct NewWishlistItem: Codable {
    let productName: String
    let productURL: String
    let notes: String
    let imageURL: String?
}

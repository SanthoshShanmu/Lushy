import Foundation
import Combine

class WishlistViewModel: ObservableObject {
    @Published var wishlistItems: [WishlistItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Form data
    @Published var newProductName = ""
    @Published var newProductURL = ""
    @Published var newProductNotes = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchWishlistItems()
    }
    
    func fetchWishlistItems() {
        isLoading = true
        
        APIService.shared.fetchWishlistItems()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to fetch wishlist: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] items in
                self?.wishlistItems = items
            })
            .store(in: &cancellables)
    }
    
    // Add a new wishlist item
    func addWishlistItem() {
        guard !newProductName.isEmpty, !newProductURL.isEmpty else {
            errorMessage = "Product name and URL are required"
            return
        }
        
        // Better URL validation
        if !newProductURL.hasPrefix("http://") && !newProductURL.hasPrefix("https://") {
            newProductURL = "https://" + newProductURL
        }
        
        guard URL(string: newProductURL) != nil else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        let newItem = WishlistItem(
            productName: newProductName,
            productURL: newProductURL,
            notes: newProductNotes
        )
        
        // Add to local array first for UI responsiveness
        wishlistItems.append(newItem)
        
        // Reset form
        resetForm()
        
        // Here we would call the API service to persist the item
        // For now it's just a placeholder since we're using a mock API
    }
    
    // Remove a wishlist item
    func removeItem(at indexSet: IndexSet) {
        wishlistItems.remove(atOffsets: indexSet)
        
        // Here we would call the API service to delete the item
    }
    
    // Reset form fields
    private func resetForm() {
        newProductName = ""
        newProductURL = ""
        newProductNotes = ""
    }
}
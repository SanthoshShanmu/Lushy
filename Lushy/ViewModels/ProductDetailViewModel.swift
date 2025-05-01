import Foundation
import CoreData
import Combine

class ProductDetailViewModel: ObservableObject {
    @Published var product: UserProduct
    @Published var newComment = ""
    @Published var showReviewForm = false
    @Published var reviewRating = 3
    @Published var reviewTitle = ""
    @Published var reviewText = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init(product: UserProduct) {
        self.product = product
    }
    
    // Add a comment to the product
    func addComment() {
        guard !newComment.isEmpty else { return }
        
        CoreDataManager.shared.addComment(to: product.objectID, text: newComment)
        newComment = "" // Reset comment field
    }
    
    // Submit a review for the product
    func submitReview() {
        guard !reviewTitle.isEmpty && !reviewText.isEmpty else { return }
        
        CoreDataManager.shared.addReview(
            to: product.objectID,
            rating: reviewRating,
            title: reviewTitle,
            text: reviewText
        )
        
        // Reset form
        reviewRating = 3
        reviewTitle = ""
        reviewText = ""
        showReviewForm = false
    }
    
    // Mark product as opened
    func markAsOpened() {
        CoreDataManager.shared.markProductAsOpened(id: product.objectID, openDate: Date())
        
        // Schedule expiry notification
        NotificationService.shared.scheduleExpiryNotification(for: product)
    }
    
    // Mark product as empty/finished
    func markAsEmpty() {
        // For now, this just opens the review form
        showReviewForm = true
    }
    
    // Toggle favorite status
    func toggleFavorite() {
        CoreDataManager.shared.toggleFavorite(id: product.objectID)
    }
    
    // Calculate days until expiry
    var daysUntilExpiry: Int? {
        guard let expireDate = product.expireDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let expiry = Calendar.current.startOfDay(for: expireDate)
        
        let components = Calendar.current.dateComponents([.day], from: today, to: expiry)
        return components.day
    }
    
    // Formatted expire date string
    var expiryDateString: String {
        guard let expireDate = product.expireDate else { return "No expiry date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "Expires on \(formatter.string(from: expireDate))"
    }
}

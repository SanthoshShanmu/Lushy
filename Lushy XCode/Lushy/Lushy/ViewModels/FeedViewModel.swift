import Foundation
import Combine

class FeedViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchFeed(for userId: String) {
        isLoading = true
        error = nil
        
        print("FeedViewModel: Fetching feed for user \(userId)")
        
        APIService.shared.fetchUserFeed(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let activities):
                    print("FeedViewModel: Successfully loaded \(activities.count) activities")
                    self?.activities = activities
                    self?.error = nil
                case .failure(let err):
                    print("FeedViewModel: Error loading feed: \(err.localizedDescription)")
                    self?.error = err.localizedDescription
                    self?.activities = []
                }
            }
        }
    }
}

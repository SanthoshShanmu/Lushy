import Foundation
import Combine

class UserSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [UserSummary] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func search() {
        guard !query.isEmpty else {
            results = []
            return
        }
        isLoading = true
        error = nil
        APIService.shared.searchUsers(query: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let users):
                    self?.results = users
                case .failure(let err):
                    self?.error = err.localizedDescription
                }
            }
        }
    }
}

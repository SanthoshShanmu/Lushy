import Foundation
import Combine

class CombinedSearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { search() }
    }
    // Debug: print when search is triggered
    // Search is called via onChange in the view

    @Published var userResults: [UserSummary] = []
    @Published var productResults: [ProductSearchSummary] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var cancellables = Set<AnyCancellable>()

    func search() {
        print("CombinedSearchViewModel.search: querying for '\(query)'")
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.userResults = []
                self.productResults = []
                self.isLoading = false
            }
            return
        }
        isLoading = true
        error = nil

        // Search users
        APIService.shared.searchUsers(query: query) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    self.userResults = users
                case .failure(let err):
                    self.error = err.localizedDescription
                }
            }
        }

        // Search products with fallback
        APIService.shared.searchProducts(query: query) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let products):
                    self.productResults = products
                case .failure(let err):
                    self.error = err.localizedDescription
                }
            }
        }
    }
}
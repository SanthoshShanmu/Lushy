import Foundation
import Combine

class CombinedSearchViewModel: ObservableObject {
    @Published var query: String = ""

    @Published var userResults: [UserSummary] = []
    @Published var productResults: [ProductSearchSummary] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce query to avoid firing multiple rapid network requests
        $query
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.search(for: value)
            }
            .store(in: &cancellables)
    }

    func search() { // legacy call sites
        search(for: query)
    }

    private func search(for value: String) {
        print("CombinedSearchViewModel.search: querying for '\(value)'")
        guard !value.isEmpty else {
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
        APIService.shared.searchUsers(query: value, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let users):
                    self.userResults = users
                case .failure(let err):
                    self.error = err.localizedDescription
                }
            }
        })

        // Search products with fallback
        APIService.shared.searchProducts(query: value) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
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
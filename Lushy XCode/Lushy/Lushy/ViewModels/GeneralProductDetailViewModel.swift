import Foundation
import Combine

class GeneralProductDetailViewModel: ObservableObject {
    @Published var product: BackendUserProduct?
    @Published var isLoading = false
    @Published var error: String?

    private let productId: String
    private let userId: String

    init(userId: String, productId: String) {
        self.userId = userId
        self.productId = productId
        fetchDetail()
    }

    func fetchDetail() {
        isLoading = true
        APIService.shared.fetchUserProduct(userId: userId, productId: productId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let prod):
                    self.product = prod
                case .failure(let err):
                    self.error = err.localizedDescription
                }
            }
        }
    }
}
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
        
        // Detect if productId is a barcode (8-13 digits) or ObjectId (24-char hex string)
        let isBarcode = isValidBarcode(productId)
        
        if isBarcode {
            // Use barcode-based endpoint
            APIService.shared.fetchUserProductByBarcode(userId: userId, barcode: productId) { result in
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
        } else {
            // Use ObjectId-based endpoint (existing behavior)
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
    
    // Helper function to detect if a string is a valid barcode
    private func isValidBarcode(_ value: String) -> Bool {
        // Barcode pattern: 8-13 digits
        let barcodePattern = "^\\d{8,13}$"
        let regex = try! NSRegularExpression(pattern: barcodePattern)
        let range = NSRange(location: 0, length: value.utf16.count)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }
}
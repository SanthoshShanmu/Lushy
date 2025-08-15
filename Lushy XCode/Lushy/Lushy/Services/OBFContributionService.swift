import Foundation
import Combine
import UIKit
import SwiftUI

// DEPRECATED: This service is no longer used.
// All OBF contributions now go through the secure backend proxy.
// This class is kept for backward compatibility but should not be used.
@available(*, deprecated, message: "Use APIService.contributeToOBFViaBackend() instead")
class OBFContributionService {
    static let shared = OBFContributionService()
    
    private init() {}
    
    // Legacy methods kept for compilation compatibility only
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    var hasCredentials: Bool { false }
    
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    var isUploading: Bool { false }
    
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    func testConnection(completion: @escaping (Bool) -> Void) {
        completion(false)
    }
    
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    func uploadProduct(
        barcode: String?,
        name: String,
        brand: String,
        category: String,
        periodsAfterOpening: String,
        productImage: UIImage? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let error = NSError(domain: "OBFContributionService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Direct OBF contributions are disabled. Use backend proxy instead."
        ])
        completion(.failure(error))
    }
    
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    func testContribution(completion: @escaping (Result<String, Error>) -> Void) {
        let error = NSError(domain: "OBFContributionService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Direct OBF contributions are disabled. Use backend proxy instead."
        ])
        completion(.failure(error))
    }
    
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    func debugCredentialStatus() -> String {
        return "Direct OBF contributions are disabled. All contributions go through secure backend proxy."
    }
    
    @available(*, deprecated, message: "Use backend proxy for OBF contributions")
    func storedUserId() -> String? { nil }
}

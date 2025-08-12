import Foundation
import Combine
import UIKit
import SwiftUI

class OBFContributionService {
    static let shared = OBFContributionService()
    
    private let baseUrl = "https://world.openbeautyfacts.org/cgi"
    
    // Request identifiers to track uploads in progress
    private var pendingUploads = Set<UUID>()
    
    private init() {}
    
    // System credentials fetched from Info.plist (populate via build settings / xcconfig, not source control)
    private func getCredentials() -> (userId: String, password: String)? {
        guard let user = Bundle.main.object(forInfoDictionaryKey: "OBF_SYSTEM_USER_ID") as? String, !user.isEmpty,
              let pass = Bundle.main.object(forInfoDictionaryKey: "OBF_SYSTEM_PASSWORD") as? String, !pass.isEmpty else {
            return nil
        }
        return (user, pass)
    }
    
    // Public flag
    var hasCredentials: Bool { getCredentials() != nil }
    
    // Legacy API (no longer used; kept to avoid compile errors if referenced elsewhere)
    @available(*, deprecated, message: "Manual credentials no longer supported. Provide system credentials via Info.plist.")
    func setCredentials(userId: String, password: String) { /* no-op */ }
    @available(*, deprecated, message: "Manual credentials no longer supported.")
    func clearCredentials() { /* no-op */ }
    
    var isUploading: Bool { !pendingUploads.isEmpty }
    
    /// Format PAO to match required format (e.g., "12 M" not "12 months")
    private func formatPAO(_ pao: String) -> String {
        // Extract numbers from string
        let monthsValue = pao.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !monthsValue.isEmpty {
            return "\(monthsValue) M"
        }
        return pao
    }
    
    /// Validate barcode format
    private func isValidBarcode(_ barcode: String) -> Bool {
        let numbers = barcode.filter { $0.isNumber }
        return numbers.count >= 8 && numbers.count <= 13
    }
    
    /// Test connection to Open Beauty Facts
    func testConnection(completion: @escaping (Bool) -> Void) {
        // Use a search query instead of looking for a specific product
        let testURL = URL(string: "https://world.openbeautyfacts.org/api/v2/search?categories_tags=makeup&page_size=1")!
        
        print("Testing OBF connection to: \(testURL)")
        
        let task = URLSession.shared.dataTask(with: testURL) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("OBF test connection response: \(httpResponse.statusCode)")
                
                // Print response for debugging
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response preview: \(responseString.prefix(200))...")
                }
                
                // Any response (even 404) means the API is connected - the issue is that product doesn't exist
                completion(true)
            } else if let error = error {
                print("OBF connection error: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(false)
            }
        }
        task.resume()
    }
    
    /// Upload a new product to Open Beauty Facts
    func uploadProduct(
        barcode: String?,
        name: String,
        brand: String,
        category: String,
        periodsAfterOpening: String,
        productImage: UIImage? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("⭐️ Starting OBF upload for product: \(name)")
        guard let creds = getCredentials() else {
            let err = NSError(domain: "OBFContributionService", code: -10, userInfo: [NSLocalizedDescriptionKey: "OBF contribution temporarily unavailable."])
            print("❌ OBF upload aborted: missing system credentials (check Info.plist keys OBF_SYSTEM_USER_ID / OBF_SYSTEM_PASSWORD)")
            completion(.failure(err))
            return
        }
        
        // Format PAO to match required format
        let formattedPAO = formatPAO(periodsAfterOpening)
        
        // Build request parameters
        var parameters: [String: String] = [
            "user_id": creds.userId,
            "password": creds.password,
            "product_name": name,
            "brands": brand,
            "categories": category,
            "periods_after_opening": formattedPAO,
            "lang": "en"
        ]
        
        // Add barcode if provided
        if let barcode = barcode, !barcode.isEmpty {
            if isValidBarcode(barcode) {
                parameters["code"] = barcode
                print("Using barcode: \(barcode)")
            } else {
                print("Invalid barcode format: \(barcode)")
            }
        }
        
        // Create unique ID for this upload
        let uploadId = UUID()
        pendingUploads.insert(uploadId)
        
        // Create the product first
        createProduct(parameters: parameters) { [weak self] result in
            switch result {
            case .success(let productId):
                print("Successfully created product with ID: \(productId)")
                
                // Only attempt image upload if we have a valid barcode/code parameter
                if let image = productImage, let code = parameters["code"], !code.isEmpty {
                    self?.uploadProductImage(productId: code, image: image) { imageResult in
                        switch imageResult {
                        case .success:
                            print("Successfully uploaded image for product: \(code)")
                        case .failure(let error):
                            print("Failed to upload image: \(error.localizedDescription)")
                        }
                        
                        self?.pendingUploads.remove(uploadId)
                        completion(.success(productId))
                    }
                } else {
                    if productImage != nil {
                        print("Skipping image upload because no valid barcode/code was provided.")
                    }
                    self?.pendingUploads.remove(uploadId)
                    completion(.success(productId))
                }
                
            case .failure(let error):
                print("Failed to create product: \(error.localizedDescription)")
                self?.pendingUploads.remove(uploadId)
                completion(.failure(error))
            }
        }
    }
    
    /// Create a product on Open Beauty Facts
    private func createProduct(parameters: [String: String], completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "\(baseUrl)/product_jqm2.pl"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "OBFContributionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Lushy/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        
        // Debug information (sanitize sensitive fields)
        print("⭐️ Uploading product to OBF with parameters:")
        var sanitized = parameters
        if sanitized["password"] != nil { sanitized["password"] = "********" }
        if sanitized["user_id"] != nil { sanitized["user_id"] = "(redacted)" }
        print(sanitized)
        
        // Build form data
        let formData = parameters.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        // Execute request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle basic errors
            if let error = error {
                print("❌ OBF network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("❌ OBF invalid response or no data")
                completion(.failure(NSError(domain: "OBFContributionService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data or invalid response"])))
                return
            }
            
            // Always print the full response for debugging
            print("📄 OBF status code: \(httpResponse.statusCode)")
            if let responseText = String(data: data, encoding: .utf8) {
                print("📄 OBF response: \(responseText)")
            }
            
            // Consider anything in 200-299 range as success
            if (200...299).contains(httpResponse.statusCode) {
                // For successful response, use the barcode if available, or generate a unique ID
                if let barcode = parameters["code"], !barcode.isEmpty {
                    print("✅ Product successfully uploaded with barcode: \(barcode)")
                    completion(.success(barcode))
                } else {
                    let generatedId = "generated-\(UUID().uuidString.prefix(8))"
                    print("✅ Product successfully uploaded with generated ID: \(generatedId)")
                    completion(.success(generatedId))
                }
                return
            }
            
            // Handle non-success status codes
            completion(.failure(NSError(domain: "OBFContributionService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])) )
        }
        task.resume()
    }
    
    /// Upload an image for a product
    private func uploadProductImage(productId: String, image: UIImage, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "OBFContributionService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])))
            return
        }
        
        // Resize image if too large
        let finalImageData: Data
        if imageData.count > 2 * 1024 * 1024 {
            if let resizedImage = image.resized(to: CGSize(width: 1200, height: 1200)),
               let resizedData = resizedImage.jpegData(compressionQuality: 0.7) {
                finalImageData = resizedData
            } else {
                finalImageData = imageData
            }
        } else {
            finalImageData = imageData
        }
        
        // Ensure we have credentials
        guard let creds = getCredentials() else {
            completion(.failure(NSError(domain: "OBFContributionService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing system OBF credentials."])) )
            return
        }
        
        let urlString = "\(baseUrl)/product_image_upload.pl"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "OBFContributionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create form data
        var formData = Data()
        
        // Add form fields
        let fields = [
            "code": productId,
            "imagefield": "front",
            "user_id": creds.userId,
            "password": creds.password
        ]
        
        for (key, value) in fields {
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            formData.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add image data
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"imgupload_front\"; filename=\"product.jpg\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(finalImageData)
        formData.append("\r\n".data(using: .utf8)!)
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        // Execute request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Log response
            if let data = data, let responseText = String(data: data, encoding: .utf8) {
                print("Image upload response: \(responseText)")
            }
            
            // For image upload we consider it successful if we got any response
            completion(.success(true))
        }
        task.resume()
    }
    
    /// Retrieve stored user id (non-sensitive). Returns nil if none (system credentials hidden)
    func storedUserId() -> String? {
        guard let creds = getCredentials() else { return nil }
        return creds.userId
    }
}

// Extension to resize images
extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

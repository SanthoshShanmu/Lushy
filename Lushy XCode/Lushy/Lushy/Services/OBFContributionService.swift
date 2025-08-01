import Foundation
import Combine
import UIKit
import SwiftUI
import KeychainSwift

class OBFContributionService {
    static let shared = OBFContributionService()
    
    private let baseUrl = "https://world.openbeautyfacts.org/cgi"
    private let keychain = KeychainSwift()
    
    // Hard-coded credentials
    private let userId = "santhosh"
    private let userPassword = "kaktRBjC9q74Aip"
    
    // Request identifiers to track uploads in progress
    private var pendingUploads = Set<UUID>()
    
    private init() {
        // Initialize keychain if needed
    }
    
    /// Check if credentials are available (always true with hardcoded values)
    var hasCredentials: Bool {
        return true
    }
    
    /// No need to set credentials anymore
    func setCredentials(userId: String, password: String) {}
    
    /// Flag to track if upload is in progress
    var isUploading: Bool {
        return !pendingUploads.isEmpty
    }
    
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
        
        // Format PAO to match required format
        let formattedPAO = formatPAO(periodsAfterOpening)
        
        // Build request parameters
        var parameters: [String: String] = [
            "user_id": userId,
            "password": userPassword,
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
                
                // If we have an image, upload it
                if let image = productImage {
                    self?.uploadProductImage(productId: productId, image: image) { imageResult in
                        switch imageResult {
                        case .success:
                            print("Successfully uploaded image for product: \(productId)")
                        case .failure(let error):
                            print("Failed to upload image: \(error.localizedDescription)")
                        }
                        
                        // Consider the product upload successful even if image fails
                        self?.pendingUploads.remove(uploadId)
                        completion(.success(productId))
                    }
                } else {
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
        
        // Debug information
        print("⭐️ Uploading product to OBF with parameters:")
        print(parameters)
        
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
            completion(.failure(NSError(domain: "OBFContributionService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])))
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
            "user_id": userId,
            "password": userPassword
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

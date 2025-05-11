import Foundation
import Combine
import SwiftUI
import AVFoundation
import CoreData

class ScannerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var showManualEntry = false
    @Published var scannedBarcode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var scannedProduct: Product?
    @Published var ethicsInfo: EthicsInfo?
    
    // Properties for manual entry
    @Published var manualBarcode = ""
    @Published var manualProductName = ""
    @Published var manualBrand = ""
    
    // Form data for adding product
    @Published var purchaseDate = Date()
    @Published var openDate: Date?
    @Published var isProductOpen = false {
        didSet {
            if isProductOpen && openDate == nil {
                openDate = Date()
            }
        }
    }
    
    // New properties for improved workflow
    @Published var productNotFound = false
    @Published var showProductAddedSuccess = false
    @Published var isContributingToOBF = false
    
    private var barcodeScannerService = BarcodeScannerService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to barcode scanner result
        barcodeScannerService.$scannedBarcode
            .compactMap { $0 } // Filter out nil values
            .sink { [weak self] barcode in
                guard let self = self else { return }
                self.scannedBarcode = barcode
                self.fetchProduct(barcode: barcode)
                self.isScanning = false // Stop scanning after finding a barcode
            }
            .store(in: &cancellables)
        
        // Subscribe to barcode scanner errors
        barcodeScannerService.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                switch error {
                case .cameraAccessDenied:
                    self?.errorMessage = "Camera access is required to scan barcodes."
                case .cameraSetupFailed:
                    self?.errorMessage = "Failed to setup camera."
                case .barcodeDetectionFailed:
                    self?.errorMessage = "Could not detect barcode."
                }
                self?.isScanning = false
            }
            .store(in: &cancellables)
    }
    
    func startScanning() {
        isScanning = true
    }
    
    func stopScanning() {
        isScanning = false
        barcodeScannerService.stopScanning()
    }
    
    // Use the BarcodeScannerService for camera setup instead of duplicating code
    func setupCaptureSession() -> Result<AVCaptureVideoPreviewLayer, Error> {
        let result = barcodeScannerService.setupCaptureSession()
        
        // Start scanning when setup is successful
        if case .success = result {
            DispatchQueue.main.async { [weak self] in
                self?.isScanning = true
            }
        }
        
        return result.mapError { $0 as Error }
    }
    
    // Fetch product information from barcode
    func fetchProduct(barcode: String, autoAddIfFound: Bool = false) {
        isLoading = true
        errorMessage = nil
        productNotFound = false
        
        APIService.shared.fetchProduct(barcode: barcode)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    switch error {
                    case .invalidURL:
                        self?.errorMessage = "Cannot access product database."
                    case .invalidResponse:
                        self?.errorMessage = "Invalid response from product database."
                    case .decodingError:
                        self?.errorMessage = "Could not process product information."
                    case .networkError:
                        self?.errorMessage = "Network error. Please check your connection."
                    case .productNotFound:
                        // Product not found in OpenBeautyFacts
                        self?.productNotFound = true
                        self?.manualBarcode = barcode
                        if autoAddIfFound {
                            self?.showManualEntry = true
                        }
                    default:
                        self?.errorMessage = "An unknown error occurred."
                    }
                }
            }, receiveValue: { [weak self] product in
                guard let self = self else { return }
                self.scannedProduct = product
                
                // Populate manual fields in case needed later
                if !product.code.isEmpty {
                    self.manualBarcode = product.code
                }
                if let productName = product.productName {
                    self.manualProductName = productName
                }
                if let brand = product.brands {
                    self.manualBrand = brand
                }
                
                // Auto-add to bag if requested
                if autoAddIfFound {
                    if let _ = self.saveProduct() {
                        self.showProductAddedSuccess = true
                    } else {
                        self.errorMessage = "Failed to save product"
                    }
                }
                
                self.fetchEthicsInfo(for: product)
            })
            .store(in: &cancellables)
    }
    
    // Fetch ethics information for the brand
    private func fetchEthicsInfo(for product: Product) {
        guard let brand = product.brands else {
            // If no brand is available, set default values
            self.ethicsInfo = EthicsInfo(vegan: false, crueltyFree: false)
            return
        }
        
        APIService.shared.fetchEthicsInfo(brand: brand)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(_) = completion {
                    // Default to false if can't fetch
                    self?.ethicsInfo = EthicsInfo(vegan: false, crueltyFree: false)
                }
            }, receiveValue: { [weak self] ethicsInfo in
                self?.ethicsInfo = ethicsInfo
            })
            .store(in: &cancellables)
    }
    
    // Function to decode batch code
    private func decodeBatchCode(_ batchCode: String) -> (manufactureDate: Date?, expiryEstimate: Date?)? {
        guard !batchCode.isEmpty else { return nil }
        
        // Common pattern: Year+Julian date (e.g., 2024-180)
        let julianPattern = "([0-9]{4})[-/]?([0-9]{3})"
        if let julianRegex = try? NSRegularExpression(pattern: julianPattern),
           let match = julianRegex.firstMatch(in: batchCode, range: NSRange(batchCode.startIndex..., in: batchCode)) {
            
            if let yearRange = Range(match.range(at: 1), in: batchCode),
               let dayRange = Range(match.range(at: 2), in: batchCode),
               let year = Int(batchCode[yearRange]),
               let day = Int(batchCode[dayRange]) {
                
                var dateComponents = DateComponents()
                dateComponents.year = year
                dateComponents.day = day
                
                if let manufactureDate = Calendar.current.date(from: dateComponents) {
                    // Default to 36 months shelf life
                    let expiryEstimate = Calendar.current.date(byAdding: .month, value: 36, to: manufactureDate)
                    return (manufactureDate, expiryEstimate)
                }
            }
        }
        
        // Month/year formats (e.g., 0324 for March 2024)
        let monthYearPattern = "([0-9]{2})([0-9]{2})"
        if let monthYearRegex = try? NSRegularExpression(pattern: monthYearPattern),
           let match = monthYearRegex.firstMatch(in: batchCode, range: NSRange(batchCode.startIndex..., in: batchCode)) {
            
            if let monthRange = Range(match.range(at: 1), in: batchCode),
               let yearRange = Range(match.range(at: 2), in: batchCode),
               let month = Int(batchCode[monthRange]),
               let year = Int(batchCode[yearRange]) {
                
                var dateComponents = DateComponents()
                dateComponents.year = 2000 + year
                dateComponents.month = month
                dateComponents.day = 1
                
                if let manufactureDate = Calendar.current.date(from: dateComponents) {
                    // Default to 36 months shelf life
                    let expiryEstimate = Calendar.current.date(byAdding: .month, value: 36, to: manufactureDate)
                    return (manufactureDate, expiryEstimate)
                }
            }
        }
        
        return nil
    }
    
    // Save the product to local storage
    func saveProduct() -> NSManagedObjectID? {
        guard let product = scannedProduct else {
            // Check if manual entry has required fields
            if !manualProductName.isEmpty && !manualBarcode.isEmpty {
                return saveManualProduct()
            }
            errorMessage = "No product information available"
            return nil
        }
        
        let openDateValue = isProductOpen ? openDate : nil
        
        // Determine PAO value - use batch code fallback if needed
        var paoValue = product.periodsAfterOpening
        var expiryDate: Date? = nil
        
        // If product has no PAO but has batch code, try to decode it
        if paoValue == nil, let batchCode = product.batchCode {
            if let batchInfo = decodeBatchCode(batchCode) {
                // Set PAO to 36 months as fallback
                paoValue = "36 months"
                
                // If product will be opened now, calculate expiry from today
                if isProductOpen && openDate != nil {
                    expiryDate = Calendar.current.date(byAdding: .month, value: 36, to: openDate!)
                } else {
                    // Otherwise use the estimated expiry from batch code
                    expiryDate = batchInfo.expiryEstimate
                }
            }
        }
        
        return CoreDataManager.shared.saveUserProduct(
            barcode: product.code,
            productName: product.productName ?? "Unknown Product",
            brand: product.brands,
            imageUrl: product.imageUrl,
            purchaseDate: purchaseDate,
            openDate: openDateValue,
            periodsAfterOpening: paoValue,
            vegan: ethicsInfo?.vegan ?? false,
            crueltyFree: ethicsInfo?.crueltyFree ?? false,
            expiryOverride: expiryDate
        )
    }
    
    // Save a manually entered product
    func saveManualProduct(periodsAfterOpening: String? = nil, productImage: UIImage? = nil) -> NSManagedObjectID? {
        // Save locally
        let objectID = CoreDataManager.shared.saveUserProduct(
            barcode: manualBarcode,
            productName: manualProductName,
            brand: manualBrand,
            imageUrl: nil,
            purchaseDate: purchaseDate,
            openDate: isProductOpen ? openDate : nil,
            periodsAfterOpening: periodsAfterOpening,
            vegan: false,
            crueltyFree: false
        )
        
        // If saved successfully, always contribute to OBF regardless of lookup status
        // The API will handle duplicates appropriately
        if objectID != nil && !manualProductName.isEmpty {
            print("📱 Product saved locally, now uploading to OBF")
            
            // Set this flag to true to show the spinner
            isContributingToOBF = true
            
            // Start the contribution
            silentlyContributeToOBF(productImage: productImage)
        }
        
        return objectID
    }
    
    // Format PAO from "12 M" to "12 months" for storage
    private func formatPAOForStorage(_ pao: String?) -> String? {
        guard let pao = pao else { return nil }
        
        if pao.hasSuffix(" M") {
            if let months = Int(pao.replacingOccurrences(of: " M", with: "")) {
                return "\(months) months"
            }
        }
        return pao
    }
    
    // Contribute to OpenBeautyFacts silently
    func silentlyContributeToOBF(productImage: UIImage? = nil) {
        guard !manualProductName.isEmpty else { return }
        
        isContributingToOBF = true
        print("Starting OBF contribution for \(manualProductName)")
        
        // Use default PAO if not specified
        let pao = "12 M" // Default to 12 months if not specified
        
        // Determine a reasonable category based on product name
        let category = determineCategory(from: manualProductName)
        
        OBFContributionService.shared.uploadProduct(
            barcode: manualBarcode.isEmpty ? nil : manualBarcode,
            name: manualProductName,
            brand: manualBrand.isEmpty ? "Unknown" : manualBrand,
            category: category,
            periodsAfterOpening: pao,
            productImage: productImage
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isContributingToOBF = false
                
                switch result {
                case .success(let productId):
                    print("Successfully uploaded to OBF with ID: \(productId)")
                    
                    // Increment contribution count
                    let count = UserDefaults.standard.integer(forKey: "obf_contribution_count")
                    UserDefaults.standard.set(count + 1, forKey: "obf_contribution_count")
                    
                    // Store the product ID for reference
                    var contributedProducts = UserDefaults.standard.stringArray(forKey: "obf_contributed_products") ?? []
                    contributedProducts.append(productId)
                    UserDefaults.standard.set(contributedProducts, forKey: "obf_contributed_products")
                    
                    // Post notification for success toast
                    NotificationCenter.default.post(name: NSNotification.Name("OBFContributionSuccess"), object: nil)
                    
                case .failure(let error):
                    print("OBF upload failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Simple category determination based on product name
    private func determineCategory(from productName: String) -> String {
        let lowercaseName = productName.lowercased()
        
        if lowercaseName.contains("lipstick") || lowercaseName.contains("lip") {
            return "Lip Makeup"
        } else if lowercaseName.contains("mascara") || lowercaseName.contains("eyeshadow") || 
                  lowercaseName.contains("eyeliner") || lowercaseName.contains("eye") {
            return "Eye Makeup"
        } else if lowercaseName.contains("foundation") || lowercaseName.contains("powder") || 
                  lowercaseName.contains("blush") || lowercaseName.contains("concealer") {
            return "Face Makeup"
        } else if lowercaseName.contains("moisturizer") || lowercaseName.contains("cream") ||
                  lowercaseName.contains("serum") {
            return "Skincare"
        } else if lowercaseName.contains("shampoo") || lowercaseName.contains("conditioner") ||
                  lowercaseName.contains("hair") {
            return "Haircare"
        } else if lowercaseName.contains("perfume") || lowercaseName.contains("fragrance") ||
                  lowercaseName.contains("cologne") {
            return "Fragrance"
        } else if lowercaseName.contains("nail") || lowercaseName.contains("polish") {
            return "Nail Care"
        } else {
            return "Makeup" // Default category
        }
    }
    
    // Reset after adding product
    func reset() {
        scannedBarcode = nil
        scannedProduct = nil
        ethicsInfo = nil
        errorMessage = nil
        isLoading = false
        manualBarcode = ""
        manualProductName = ""
        manualBrand = ""
        isProductOpen = false
        openDate = nil
        purchaseDate = Date()
    }
    
    // Store external publisher subscriptions
    func store(_ cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
    }
}

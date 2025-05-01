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
    
    private var barcodeScannerService = BarcodeScannerService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to barcode scanner result
        barcodeScannerService.$scannedBarcode
            .compactMap { $0 }
            .sink { [weak self] barcode in
                self?.scannedBarcode = barcode
                self?.fetchProduct(barcode: barcode)
            }
            .store(in: &cancellables)
        
        // Subscribe to barcode scanner errors
        barcodeScannerService.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                switch error {
                case .cameraAccessDenied:
                    self?.errorMessage = "Camera access denied. Please enable camera access in Settings."
                case .cameraSetupFailed:
                    self?.errorMessage = "Failed to set up camera."
                case .barcodeDetectionFailed:
                    self?.errorMessage = "Failed to detect barcode."
                }
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
    
    func setupCaptureSession() -> Result<AVCaptureVideoPreviewLayer, BarcodeScannerError> {
        return barcodeScannerService.setupCaptureSession()
    }
    
    // Fetch product information from barcode
    func fetchProduct(barcode: String) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.fetchProduct(barcode: barcode)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to fetch product: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] product in
                self?.scannedProduct = product
                
                // If we have a brand, fetch ethics info
                if let brand = product.brands {
                    self?.fetchEthicsInfo(brand: brand)
                }
            })
            .store(in: &cancellables)
    }
    
    // Fetch ethics information for the brand
    private func fetchEthicsInfo(brand: String) {
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
        
        return CoreDataManager.shared.saveUserProduct(
            barcode: product.code,
            productName: product.productName ?? "Unknown Product",
            brand: product.brands,
            imageUrl: product.imageUrl,
            purchaseDate: purchaseDate,
            openDate: openDateValue,
            periodsAfterOpening: product.periodsAfterOpening,
            vegan: ethicsInfo?.vegan ?? false,
            crueltyFree: ethicsInfo?.crueltyFree ?? false
        )
    }
    
    // Save a manually entered product
    private func saveManualProduct() -> NSManagedObjectID? {
        let openDateValue = isProductOpen ? openDate : nil
        
        return CoreDataManager.shared.saveUserProduct(
            barcode: manualBarcode,
            productName: manualProductName,
            brand: manualBrand,
            imageUrl: nil,
            purchaseDate: purchaseDate,
            openDate: openDateValue,
            periodsAfterOpening: nil, // Manual entry doesn't have this info
            vegan: false, // Default values
            crueltyFree: false
        )
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
}

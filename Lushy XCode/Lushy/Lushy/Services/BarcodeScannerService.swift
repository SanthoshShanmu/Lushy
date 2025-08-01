import AVFoundation
import UIKit
import Combine

enum BarcodeScannerError: Error {
    case cameraAccessDenied
    case cameraSetupFailed
    case barcodeDetectionFailed
}

class BarcodeScannerService: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedBarcode: String?
    @Published var error: BarcodeScannerError?
    
    private let captureSession = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Setup the camera and barcode detection
    func setupCaptureSession() -> Result<AVCaptureVideoPreviewLayer, BarcodeScannerError> {
        // Check camera permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .denied, .restricted:
            return .failure(.cameraAccessDenied)
        case .notDetermined:
            // Request permission and handle asynchronously
            AVCaptureDevice.requestAccess(for: .video) { _ in
                // Handle response asynchronously if needed
            }
            // For now return error, user will need to restart scanner after granting permission
            return .failure(.cameraAccessDenied)
        case .authorized:
            break // Continue with setup
        @unknown default:
            return .failure(.cameraAccessDenied)
        }
        
        // Configure camera input
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return .failure(.cameraSetupFailed)
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return .failure(.cameraSetupFailed)
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return .failure(.cameraSetupFailed)
        }
        
        // Configure metadata output for barcode detection
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr]
        } else {
            return .failure(.cameraSetupFailed)
        }
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer = previewLayer
        
        // Start running in background to not block UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
        
        return .success(previewLayer)
    }
    
    // Clean up when scanner is dismissed
    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // AVCaptureMetadataOutputObjectsDelegate method to process detected barcodes
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            // Publish the scanned barcode
            scannedBarcode = stringValue
            
            // Stop scanning once a barcode is detected
            captureSession.stopRunning()
        }
    }
}

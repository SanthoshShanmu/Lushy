import SwiftUI
import AVFoundation

struct ScannerView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showCameraPermissionAlert = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Camera view
            if viewModel.isScanning {
                CameraPreviewView(viewModel: viewModel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.lushyPink, lineWidth: 4)
                            .frame(width: 280, height: 280)
                            .padding()
                            .shadow(color: Color.lushyPink.opacity(0.7), radius: 10, x: 0, y: 0)
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            Text("Position barcode within the frame")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 0)
                                .padding(.bottom, 60)
                        }
                    )
            } else {
                // Scanner not active view
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.fromHex("#1E1E1E")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    VStack(spacing: 30) {
                        // Icon
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.lushyPink)
                            .padding(20)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .shadow(color: Color.lushyPink.opacity(0.3), radius: 20, x: 0, y: 0)
                            )
                            .padding(.bottom, 20)
                        
                        // Scan button
                        Button(action: {
                            viewModel.startScanning()
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Start Scanning")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .padding(.vertical, 18)
                            .frame(width: 250)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.lushyPink)
                                    .shadow(color: Color.lushyPink.opacity(0.6), radius: 15, x: 0, y: 5)
                            )
                            .foregroundColor(.white)
                        }
                        
                        // Manual entry button
                        Button(action: {
                            viewModel.showManualEntry = true
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Manual Entry")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .padding(.vertical, 18)
                            .frame(width: 250)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.lushyPurple)
                                    .shadow(color: Color.lushyPurple.opacity(0.6), radius: 15, x: 0, y: 5)
                            )
                            .foregroundColor(.white)
                        }
                    }
                )
            }
            
            // Show loading indicator while fetching product
            if viewModel.isLoading {
                Color.black.opacity(0.7)
                    .overlay(
                        ProgressView("Fetching product information...")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    )
            }
            
            // Show error message if any
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                        .padding()
                    
                    Button(action: {
                        viewModel.errorMessage = nil
                        viewModel.startScanning()
                    }) {
                        Text("Try Again")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 30)
                }
            }
            
            // Show product found screen
            if viewModel.scannedProduct != nil {
                ProductFoundView(viewModel: viewModel)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isScanning {
                    Button(action: {
                        viewModel.stopScanning()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showManualEntry) {
            ManualEntryView(viewModel: viewModel)
        }
        .alert(isPresented: $showCameraPermissionAlert) {
            Alert(
                title: Text("Camera Access Denied"),
                message: Text("Please enable camera access for this app in your device settings."),
                primaryButton: .default(Text("Open Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // User has already granted permission
            break
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if (!granted) {
                    DispatchQueue.main.async {
                        self.showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // Show alert to direct user to settings
            showCameraPermissionAlert = true
        @unknown default:
            break
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    var viewModel: ScannerViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let result = viewModel.setupCaptureSession()
        switch result {
        case .success(let previewLayer):
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        case .failure(let error):
            viewModel.errorMessage = "Camera setup failed: \(error.localizedDescription)"
            viewModel.stopScanning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update
    }
}

struct ProductFoundView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showingAlert = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            
            VStack(spacing: 15) {
                Text("Product Found")
                    .font(.title)
                    .foregroundColor(.white)
                
                if let product = viewModel.scannedProduct {
                    if let imageUrlString = product.imageUrl, let imageUrl = URL(string: imageUrlString) {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 150, height: 150)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150)
                                    .cornerRadius(8)
                            case .failure:
                                Image(systemName: "photo")
                                    .frame(width: 150, height: 150)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(.bottom, 10)
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)
                    }
                    
                    Text(product.productName ?? "Unknown Product")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if let brand = product.brands {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        if viewModel.ethicsInfo?.vegan ?? false {
                            Label("Vegan", systemImage: "leaf.fill")
                                .foregroundColor(.green)
                        }
                        
                        if viewModel.ethicsInfo?.crueltyFree ?? false {
                            Label("Cruelty-Free", systemImage: "heart.fill")
                                .foregroundColor(.pink)
                        }
                    }
                    .padding(.vertical, 5)
                    
                    Divider()
                        .background(Color.gray)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        DatePicker("Purchase Date", selection: $viewModel.purchaseDate, displayedComponents: .date)
                            .foregroundColor(.white)
                        
                        Toggle("Product is already open", isOn: $viewModel.isProductOpen)
                            .foregroundColor(.white)
                        
                        if viewModel.isProductOpen {
                            DatePicker(
                                "Open Date",
                                selection: Binding(
                                    get: { viewModel.openDate ?? Date() },
                                    set: { viewModel.openDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.reset()
                            viewModel.startScanning()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            if let _ = viewModel.saveProduct() {
                                showingAlert = true
                            } else {
                                viewModel.errorMessage = "Failed to save product"
                            }
                        }) {
                            Text("Add to My Bag")
                                .fontWeight(.medium)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
            .padding()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Product Added"),
                message: Text("The product has been added to your bag."),
                dismissButton: .default(Text("OK")) {
                    viewModel.reset()
                }
            )
        }
    }
}

struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScannerView(viewModel: ScannerViewModel())
        }
    }
}

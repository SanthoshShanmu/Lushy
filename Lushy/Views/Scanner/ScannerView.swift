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
                    .padding(.bottom)
                }
            }
            
            // Product not found view
            if viewModel.productNotFound {
                ProductNotFoundView(viewModel: viewModel)
            }
            
            // Show product found screen
            if viewModel.scannedProduct != nil && !viewModel.productNotFound {
                ProductFoundView(viewModel: viewModel)
            }
            
            // Product successfully added message
            if viewModel.showProductAddedSuccess {
                VStack {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Product Added Successfully!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(viewModel.scannedProduct?.productName ?? "Product")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button(action: {
                            viewModel.showProductAddedSuccess = false
                            viewModel.reset()
                        }) {
                            Text("Done")
                                .fontWeight(.medium)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 30)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(15)
                    .padding()
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.showProductAddedSuccess)
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
        
        // Set up capture session using BarcodeScannerService through the ViewModel
        let result = viewModel.setupCaptureSession()
        
        // Handle result after view creation to avoid warnings
        DispatchQueue.main.async {
            switch result {
            case .success(let previewLayer):
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            case .failure(let error):
                viewModel.errorMessage = "Camera setup failed: \(error.localizedDescription)"
                viewModel.isScanning = false
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

struct ProductFoundView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
    @State private var allTags: [ProductTag] = []
    @State private var newTagName: String = ""
    @State private var newTagColor: String = "blue"
    
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
                    
                    // Tag selection UI
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Tags")
                            .font(.headline)
                            .foregroundColor(.white)
                        if allTags.isEmpty {
                            Text("No tags yet. Create one below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(allTags, id: \.objectID) { tag in
                                Button(action: {
                                    if selectedTagIDs.contains(tag.objectID) {
                                        selectedTagIDs.remove(tag.objectID)
                                    } else {
                                        selectedTagIDs.insert(tag.objectID)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "tag")
                                            .foregroundColor(Color(tag.color ?? "blue"))
                                        Text(tag.name ?? "Unnamed Tag")
                                            .foregroundColor(.white)
                                        Spacer()
                                        if selectedTagIDs.contains(tag.objectID) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        // Quick add new tag
                        HStack {
                            TextField("New Tag", text: $newTagName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Picker("Color", selection: $newTagColor) {
                                ForEach(["lushyPink", "lushyPurple", "lushyMint", "lushyPeach", "blue", "green"], id: \.self) { color in
                                    Text(color.capitalized)
                                }
                            }
                            .frame(width: 80)
                            Button("Add") {
                                if !newTagName.isEmpty {
                                    CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
                                    allTags = CoreDataManager.shared.fetchProductTags()
                                    newTagName = ""
                                    newTagColor = "blue"
                                }
                            }.disabled(newTagName.isEmpty)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        if let objectID = viewModel.saveProduct() {
                            // Assign tags
                            let context = CoreDataManager.shared.viewContext
                            if let userProduct = try? context.existingObject(with: objectID) as? UserProduct {
                                for tagID in selectedTagIDs {
                                    if let tag = try? context.existingObject(with: tagID) as? ProductTag {
                                        userProduct.addToTags(tag)
                                    }
                                }
                                try? context.save()
                            }
                            viewModel.showProductAddedSuccess = true
                        } else {
                            viewModel.errorMessage = "Failed to save product"
                        }
                    }) {
                        Text("Add to My Bag")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top)
                    
                    Button(action: {
                        viewModel.reset()
                        viewModel.startScanning()
                    }) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 5)
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
            .padding()
        }
        .onAppear {
            allTags = CoreDataManager.shared.fetchProductTags()
        }
    }
}

struct ProductNotFoundView: View {
    @ObservedObject var viewModel: ScannerViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Product Not Found")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("This product isn't in our database yet. Let's add it!")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    // Go to manual entry with barcode filled in
                    viewModel.showManualEntry = true
                }) {
                    Text("Continue to Manual Entry")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
                
                Button(action: {
                    viewModel.productNotFound = false
                    viewModel.reset()
                    viewModel.startScanning()
                }) {
                    Text("Scan Another Product")
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 5)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
            .padding()
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

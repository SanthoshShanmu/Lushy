import SwiftUI
import AVFoundation
import CoreData
import Combine

struct ScannerView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showCameraPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.clear.pastelBackground().edgesIgnoringSafeArea(.all)
                
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
                    // Scanner not active view with pastel background
                    ZStack {
                        Color.clear.pastelBackground().edgesIgnoringSafeArea(.all)
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
                    }
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
                    VStack(spacing: 16) {
                        Text(errorMessage)
                            .foregroundColor(.lushyPink)
                        
                        Button("Try Again") {
                            viewModel.reset()
                        }
                        .neumorphicButtonStyle()
                    }
                    .glassCard(cornerRadius: 18)
                    .padding(.bottom)
                }

                // Product not found view
                if viewModel.productNotFound {
                    ProductNotFoundView(viewModel: viewModel)
                        .glassCard(cornerRadius: 18)
                }

                // Show product found screen
                if viewModel.scannedProduct != nil && !viewModel.productNotFound {
                    ProductFoundView(viewModel: viewModel)
                        .glassCard(cornerRadius: 18)
                }

                // Product successfully added message
                if viewModel.showProductAddedSuccess {
                    VStack(spacing: 20) {
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
                            }
                            .neumorphicButtonStyle()
                        }
                        .glassCard(cornerRadius: 18)
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $viewModel.showProductDetail) {
                if let product = viewModel.selectedUserProduct {
                    ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                }
            }
        } // NavigationStack
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
    @State private var newTagColor: String = "lushyPink"
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
    @State private var allBags: [BeautyBag] = []
    @State private var newBagName: String = ""
    @State private var syncCancellable: AnyCancellable?  // Combine token for sync
    @State private var bagCancellables = Set<AnyCancellable>()  // for bag creation
    
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
                    
                    // Ethics toggles for user to modify
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ethics Information")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            // Vegan toggle
                            Button(action: {
                                viewModel.isVegan.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.isVegan ? "leaf.fill" : "leaf")
                                        .foregroundColor(viewModel.isVegan ? .green : .gray)
                                        .font(.system(size: 16))
                                    Text("Vegan")
                                        .font(.caption)
                                        .foregroundColor(viewModel.isVegan ? .green : .white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(viewModel.isVegan ? Color.green.opacity(0.2) : Color.gray.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.isVegan ? Color.green : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Cruelty-free toggle
                            Button(action: {
                                viewModel.isCrueltyFree.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.isCrueltyFree ? "heart.fill" : "heart")
                                        .foregroundColor(viewModel.isCrueltyFree ? .pink : .gray)
                                        .font(.system(size: 16))
                                    Text("Cruelty-Free")
                                        .font(.caption)
                                        .foregroundColor(viewModel.isCrueltyFree ? .pink : .white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(viewModel.isCrueltyFree ? Color.pink.opacity(0.2) : Color.gray.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.isCrueltyFree ? Color.pink : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    
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
                                            .foregroundColor(Color(tag.color ?? "lushyPink"))
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
                                ForEach(["lushyPink", "lushyPurple", "mossGreen", "lushyPeach"], id: \.self) { color in
                                    Text(color.capitalized)
                                }
                            }
                            .frame(width: 80)
                            Button("Add") {
                                if !newTagName.isEmpty {
                                    _ = CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
                                    allTags = CoreDataManager.shared.fetchProductTags()
                                    newTagName = ""
                                    newTagColor = "lushyPink"
                                }
                            }.disabled(newTagName.isEmpty)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Bag selection UI
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add to Bag")
                            .font(.headline)
                            .foregroundColor(.white)
                        if allBags.isEmpty {
                            Text("No bags yet. Create one below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(allBags, id: \.objectID) { bag in
                                Button(action: {
                                    if selectedBagIDs.contains(bag.objectID) {
                                        selectedBagIDs.remove(bag.objectID)
                                    } else {
                                        selectedBagIDs.insert(bag.objectID)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "bag")
                                            .foregroundColor(.white)
                                        Text(bag.name ?? "Unnamed Bag")
                                            .foregroundColor(.white)
                                        Spacer()
                                        if selectedBagIDs.contains(bag.objectID) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        // Quick add new bag
                        HStack {
                            TextField("New Bag", text: $newBagName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("Add") {
                                guard !newBagName.isEmpty else { return }
                                if let userId = AuthService.shared.userId {
                                    APIService.shared.createBag(userId: userId, name: newBagName)
                                        .receive(on: DispatchQueue.main)
                                        .sink(receiveCompletion: { _ in }, receiveValue: { summary in
                                            if let newId = CoreDataManager.shared.createBeautyBag(name: summary.name, color: "lushyPink", icon: "bag.fill") {
                                                CoreDataManager.shared.updateBeautyBagBackendId(id: newId, backendId: summary.id)
                                            }
                                            allBags = CoreDataManager.shared.fetchBeautyBags()
                                            newBagName = ""
                                        })
                                        .store(in: &bagCancellables)
                                } else {
                                    _ = CoreDataManager.shared.createBeautyBag(name: newBagName, color: "lushyPink", icon: "bag.fill")
                                    allBags = CoreDataManager.shared.fetchBeautyBags()
                                    newBagName = ""
                                }
                            }.disabled(newBagName.isEmpty)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        // Show processing toast
                        NotificationCenter.default.post(name: NSNotification.Name("ShowProcessingToast"), object: nil, userInfo: ["key": "processing-toast"])
                        let context = CoreDataManager.shared.viewContext
                        guard let objectID = viewModel.saveProduct(),
                              let userProduct = try? context.existingObject(with: objectID) as? UserProduct else {
                            viewModel.errorMessage = "Failed to save product"
                            return
                        }
                        // Sync to backend then link tags and bags
                        let cancellable = APIService.shared.syncProductWithBackend(product: userProduct)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                // Hide processing toast on failure
                                NotificationCenter.default.post(name: NSNotification.Name("HideProcessingToast"), object: nil, userInfo: ["key": "processing-toast"])
                                if case .failure(let error) = completion {
                                    viewModel.errorMessage = error.localizedDescription
                                }
                            }, receiveValue: { backendId in
                                // Hide processing toast on success
                                NotificationCenter.default.post(name: NSNotification.Name("HideProcessingToast"), object: nil, userInfo: ["key": "processing-toast"])
                                userProduct.backendId = backendId
                                try? context.save()
                                // Attach selected tags
                                for tagID in selectedTagIDs {
                                    if let tag = try? context.existingObject(with: tagID) as? ProductTag {
                                        CoreDataManager.shared.addTag(tag, toProduct: userProduct)
                                    }
                                }
                                // Attach selected bags
                                for bagID in selectedBagIDs {
                                    if let bag = try? context.existingObject(with: bagID) as? BeautyBag {
                                        CoreDataManager.shared.addProduct(userProduct, toBag: bag)
                                    }
                                }
                                // Refresh UI
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
                                DispatchQueue.main.async {
                                    viewModel.selectedUserProduct = userProduct
                                    viewModel.showProductDetail = true
                                }
                            })
                        syncCancellable = cancellable
                        bagCancellables.insert(cancellable)
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
            allBags = CoreDataManager.shared.fetchBeautyBags()
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

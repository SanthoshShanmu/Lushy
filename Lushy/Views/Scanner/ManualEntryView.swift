import SwiftUI
import PhotosUI
import CoreData  // Add this import

struct ManualEntryView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = "Failed to add product. Please ensure product name is filled in."
    @Environment(\.presentationMode) var presentationMode
    
    // Image capture
    @State private var productImage: UIImage? = nil
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    
    // Period After Opening
    @State private var periodsAfterOpening = "12 M"
    
    // Common PAO options (using correct OBF format)
    private let paoOptions = ["3 M", "6 M", "9 M", "12 M", "18 M", "24 M", "30 M", "36 M", "48 M"]
    
    @State private var showingOBFSuccessToast = false
    @State private var showingProcessingToast = false
    
    // Bag and tag selection
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
    @State private var allBags: [BeautyBag] = []
    @State private var allTags: [ProductTag] = []
    @State private var newTagName: String = ""
    @State private var newTagColor: String = "blue"
    
    var body: some View {
        NavigationView {
            Form {
                // Product Lookup Section
                Section(header: Text("Product Lookup")) {
                    HStack {
                        TextField("Barcode", text: $viewModel.manualBarcode)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            if !viewModel.manualBarcode.isEmpty {
                                viewModel.fetchProduct(barcode: viewModel.manualBarcode)
                            } else {
                                errorMessage = "Please enter a barcode to look up"
                                showingErrorAlert = true
                            }
                        }) {
                            Text("Look Up")
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.manualBarcode.isEmpty)
                    }
                    
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Searching...")
                            Spacer()
                        }
                    }
                    
                    if viewModel.productNotFound {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Product not in database. You're adding a new product!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Product Information Section
                Section(header: Text("Product Information")) {
                    TextField("Product Name (Required)", text: $viewModel.manualProductName)
                    
                    TextField("Brand (Optional)", text: $viewModel.manualBrand)
                    
                    // Image selection
                    HStack {
                        if let image = productImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Button(action: {
                                isShowingCamera = true
                            }) {
                                Label("Take Photo", systemImage: "camera")
                            }
                            .padding(.vertical, 5)
                            
                            Button(action: {
                                isShowingImagePicker = true
                            }) {
                                Label("Select Photo", systemImage: "photo")
                            }
                            .padding(.vertical, 5)
                        }
                        .padding(.leading, 10)
                    }
                    .padding(.vertical, 5)
                }
                
                // Usage Information Section
                Section(header: Text("Usage Information")) {
                    DatePicker(
                        "Purchase Date",
                        selection: $viewModel.purchaseDate,
                        displayedComponents: .date
                    )
                    
                    Toggle("Product is already opened", isOn: $viewModel.isProductOpen)
                    
                    if viewModel.isProductOpen {
                        DatePicker(
                            "Open Date",
                            selection: Binding(
                                get: { viewModel.openDate ?? Date() },
                                set: { viewModel.openDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                    
                    // Period After Opening selection
                    Picker("Period After Opening", selection: $periodsAfterOpening) {
                        ForEach(paoOptions, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Bag selection section
                Section(header: Text("Add to Beauty Bags")) {
                    if allBags.isEmpty {
                        Text("No bags yet. Create one from the Bags tab.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allBags, id: \.objectID) { bag in
                            MultipleSelectionRow(
                                title: bag.name ?? "Unnamed Bag",
                                isSelected: selectedBagIDs.contains(bag.objectID),
                                icon: bag.icon,
                                color: bag.color
                            ) {
                                if selectedBagIDs.contains(bag.objectID) {
                                    selectedBagIDs.remove(bag.objectID)
                                } else {
                                    selectedBagIDs.insert(bag.objectID)
                                }
                            }
                        }
                    }
                }
                
                // Tag selection section
                Section(header: Text("Add Tags")) {
                    if allTags.isEmpty {
                        Text("No tags yet. Create one below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allTags, id: \.objectID) { tag in
                            MultipleSelectionRow(
                                title: tag.name ?? "Unnamed Tag",
                                isSelected: selectedTagIDs.contains(tag.objectID),
                                icon: "tag",
                                color: tag.color
                            ) {
                                if selectedTagIDs.contains(tag.objectID) {
                                    selectedTagIDs.remove(tag.objectID)
                                } else {
                                    selectedTagIDs.insert(tag.objectID)
                                }
                            }
                        }
                    }
                    // Quick add new tag
                    HStack {
                        TextField("New Tag", text: $newTagName)
                        Picker("Color", selection: $newTagColor) {
                            ForEach(["lushyPink", "lushyPurple", "lushyMint", "lushyPeach", "blue", "green"], id: \.self) { color in
                                Text(color.capitalized)
                            }
                        }
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
                
                // Save Section
                Section {
                    Button(action: {
                        saveProduct()
                    }) {
                        Text("Save Product")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(viewModel.manualProductName.isEmpty)
                }
            }
            .navigationTitle("Add Product")
            .alert(isPresented: $showingErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(selectedImage: $productImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $isShowingCamera) {
                ImagePicker(selectedImage: $productImage, sourceType: .camera)
            }
#if compiler(>=5.9) && canImport(SwiftUI)
            // Use new API for iOS 17+
            .onChange(of: productImage) { oldValue, newValue in
                // Update UI when image is selected
            }
#else
            // Use old API for iOS 16 and earlier
            .onChange(of: productImage) { _ in
                // Update UI when image is selected
            }
#endif
            .onAppear {
                // If we come from product not found, make sure user knows they're adding a new product
                if viewModel.productNotFound {
                    // The barcode is already filled in by the view model
                }
                // Test OBF connectivity  
                OBFContributionService.shared.testConnection { isConnected in
                    DispatchQueue.main.async {
                        print("✅ OBF connection test result: \(isConnected ? "Connected" : "Not connected")")
                    }
                }
                allBags = CoreDataManager.shared.fetchBeautyBags()
                allTags = CoreDataManager.shared.fetchProductTags()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isContributingToOBF {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .overlay(
                Group {
                    if showingOBFSuccessToast {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Contributed to Open Beauty Facts")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                            .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingOBFSuccessToast = false
                                }
                            }
                        }
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OBFContributionSuccess"))) { _ in
                withAnimation {
                    showingOBFSuccessToast = true
                }
            }
            // Toast overlay for status indicators
            .overlay(
                ZStack {
                    // OBF Success toast
                    if showingOBFSuccessToast {
                        VStack {
                            Spacer()
                            HStack {
                                if viewModel.isContributingToOBF {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                
                                Text(viewModel.isContributingToOBF ? 
                                     "Contributing to Open Beauty Facts..." : 
                                     "Contributed to Open Beauty Facts")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                            .padding(.bottom, 20)
                        }
                    }
                    
                    // Processing toast (shown when initial save occurs)
                    if showingProcessingToast {
                        VStack {
                            Spacer()
                            HStack {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                                Text("Saving product...")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OBFContributionSuccess"))) { _ in
                print("Received OBF contribution success notification")
                withAnimation {
                    showingOBFSuccessToast = true
                    // Don't hide automatically - it will be dismissed with the view
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowProcessingToast"))) { notification in
                if let userInfo = notification.userInfo, userInfo["key"] as? String == "processing-toast" {
                    withAnimation {
                        showingProcessingToast = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideProcessingToast"))) { notification in
                if let userInfo = notification.userInfo, userInfo["key"] as? String == "processing-toast" {
                    withAnimation {
                        showingProcessingToast = false
                    }
                }
            }
        }
    }
    
    private func saveProduct() {
        if viewModel.manualProductName.isEmpty {
            errorMessage = "Product name is required"
            showingErrorAlert = true
            return
        }
        
        // Add indicator that we're processing
        let processingToast = showProcessingToast()
        
        // Save locally and contribute to OBF if needed
        if let objectID = viewModel.saveManualProduct(periodsAfterOpening: periodsAfterOpening, productImage: productImage) {
            // Assign bags and tags
            let context = CoreDataManager.shared.viewContext
            if let product = try? context.existingObject(with: objectID) as? UserProduct {
                for bagID in selectedBagIDs {
                    if let bag = try? context.existingObject(with: bagID) as? BeautyBag {
                        product.addToBags(bag)
                    }
                }
                for tagID in selectedTagIDs {
                    if let tag = try? context.existingObject(with: tagID) as? ProductTag {
                        product.addToTags(tag)
                    }
                }
                try? context.save()
            }
            print("Product saved locally with ID: \(objectID)")
            
            // Wait for OBF contribution to complete before dismissing
            // Only dismiss after 2 seconds to ensure upload has time to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                processingToast()  // Dismiss processing toast
                
                if self.viewModel.isContributingToOBF {
                    print("OBF upload in progress - waiting to complete")
                    
                    // Show uploading indicator
                    self.showingOBFSuccessToast = true
                    
                    // Check every second if uploading is complete
                    var checkCount = 0
                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                        checkCount += 1
                        
                        if !self.viewModel.isContributingToOBF || checkCount > 10 {
                            timer.invalidate()
                            DispatchQueue.main.async {
                                self.viewModel.reset()
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                } else {
                    // No contribution needed, just dismiss
                    self.viewModel.reset()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        } else {
            processingToast()  // Dismiss processing toast
            errorMessage = "Failed to save product"
            showingErrorAlert = true
        }
    }
    
    // Add this helper function to show a temporary processing toast
    private func showProcessingToast() -> (() -> Void) {
        let key = "processing-toast"
        let notification = NotificationCenter.default
        
        // Post notification to show processing
        notification.post(name: NSNotification.Name("ShowProcessingToast"), object: nil, userInfo: ["key": key])
        
        // Return a function that can dismiss this specific toast
        return {
            notification.post(name: NSNotification.Name("HideProcessingToast"), object: nil, userInfo: ["key": key])
        }
    }
}

// ImagePicker for camera and photo library access
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Check if the requested source type is available
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            // Fallback to photo library if camera isn't available
            picker.sourceType = .photoLibrary
        }
        
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Helper for multi-select rows
struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let icon: String?
    let color: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(Color(color ?? "lushyPink"))
                }
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView(viewModel: ScannerViewModel())
    }
}

import SwiftUI
import PhotosUI
import CoreData

struct ManualEntryView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = "Failed to add product. Please ensure product name is filled in."
    @Environment(\.presentationMode) var presentationMode

    // Image capture
    @State private var productImage: UIImage? = nil
    enum ImageSourceType { case none, camera, library }
    @State private var imageSource: ImageSourceType = .none

    // Period After Opening
    @State private var periodsAfterOpening = "12 M"
    private let paoOptions = ["3 M","6 M","9 M","12 M","18 M","24 M","30 M","36 M","48 M"]

    // Bag & Tag selection
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
    @State private var allBags: [BeautyBag] = []
    @State private var allTags: [ProductTag] = []
    @State private var newTagName: String = ""
    @State private var newTagColor: String = "blue"

    @State private var showingOBFSuccessToast = false
    @State private var showingProcessingToast = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.pastelBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        productLookupSection()
                        productInformationSection()
                        usageInformationSection()
                        bagSelectionSection()
                        tagSelectionSection()
                        saveButtonsSection()
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Product")
            .alert(isPresented: $showingErrorAlert) {
                Alert(title: Text("Error"),
                      message: Text(errorMessage),
                      dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: Binding<Bool>(
                get: { imageSource != .none },
                set: { if !$0 { imageSource = .none } }
            )) {
                if imageSource == .camera {
                    ImagePicker(selectedImage: $productImage, sourceType: .camera)
                } else if imageSource == .library {
                    ImagePicker(selectedImage: $productImage, sourceType: .photoLibrary)
                }
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

    @ViewBuilder private func productLookupSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Lookup").font(.headline)
            HStack(spacing: 12) {
                TextField("Barcode", text: $viewModel.manualBarcode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Look Up") {
                    if viewModel.manualBarcode.isEmpty {
                        errorMessage = "Please enter a barcode to look up"
                        showingErrorAlert = true
                    } else {
                        viewModel.fetchProduct(barcode: viewModel.manualBarcode)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.manualBarcode.isEmpty)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func productInformationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Information").font(.headline)
            TextField("Product Name (Required)", text: $viewModel.manualProductName)
                .textFieldStyle(.roundedBorder)
            TextField("Brand (Optional)", text: $viewModel.manualBrand)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 20) {
                if let img = productImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray))
                }
                VStack(spacing: 8) {
                    Button("Take Photo") { imageSource = .camera }
                    Button("Select Photo") { imageSource = .library }
                }
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func usageInformationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Information").font(.headline)
            DatePicker("Purchase Date", selection: $viewModel.purchaseDate, displayedComponents: .date)
            Toggle("Product is already opened", isOn: $viewModel.isProductOpen)
            if viewModel.isProductOpen {
                DatePicker("Open Date",
                           selection: Binding(get: { viewModel.openDate ?? Date() },
                                               set: { viewModel.openDate = $0 }),
                           displayedComponents: .date)
                Picker("PAO", selection: $periodsAfterOpening) {
                    ForEach(paoOptions, id: \.self) { Text($0) }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func bagSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Beauty Bags").font(.headline)
            if allBags.isEmpty {
                Text("No bags yet. Create one from the Bags tab.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(allBags, id: \.objectID) { bag in
                    MultipleSelectionRow(title: bag.name ?? "Unnamed Bag",
                                         isSelected: selectedBagIDs.contains(bag.objectID),
                                         icon: bag.icon,
                                         color: bag.color) {
                        selectedBagIDs.toggleMembership(of: bag.objectID)
                    }
                }
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func tagSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Tags").font(.headline)
            if allTags.isEmpty {
                Text("No tags yet. Create one below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(allTags, id: \.objectID) { tag in
                    MultipleSelectionRow(title: tag.name ?? "Unnamed Tag",
                                         isSelected: selectedTagIDs.contains(tag.objectID),
                                         icon: "tag",
                                         color: tag.color) {
                        selectedTagIDs.toggleMembership(of: tag.objectID)
                    }
                }
            }
            HStack {
                TextField("New Tag", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                Picker("Color", selection: $newTagColor) {
                    ForEach(["lushyPink","lushyPurple","lushyMint","lushyPeach","blue","green"], id: \.self) {
                        Text($0.capitalized)
                    }
                }
                Button("Add") {
                    CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
                    allTags = CoreDataManager.shared.fetchProductTags()
                    newTagName = ""
                }
                .disabled(newTagName.isEmpty)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func saveButtonsSection() -> some View {
        HStack(spacing: 20) {
            Button("Save") {
                _ = viewModel.saveManualProduct()
            }
            .neumorphicButtonStyle()
            Button("Cancel") {
                viewModel.showManualEntry = false
            }
            .neumorphicButtonStyle()
        }
    }
}

// Helper for toggling membership in a Set
fileprivate extension Set where Element: Hashable {
    mutating func toggleMembership(of element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}

// ImagePicker for camera and photo library access
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode
    var onDismiss: (() -> Void)?
    
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
            parent.onDismiss?()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
            parent.onDismiss?()
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

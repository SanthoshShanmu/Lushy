import SwiftUI
import PhotosUI
import CoreData
import Combine

struct ManualEntryView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.presentationMode) var presentationMode

    // Image capture
    @State private var productImage: UIImage? = nil
    enum ImageSourceType { case none, camera, library }
    @State private var imageSource: ImageSourceType = .none

    // Period After Opening
    @State private var periodsAfterOpening = ""
    @State private var paoOptions: [String] = []
    @State private var paoLabels: [String: String] = [:]
    @State private var paoCancellable: AnyCancellable?

    // Bag & Tag selection
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
    @StateObject private var tagViewModel = TagViewModel()
    @State private var newTagName: String = ""
    @State private var newTagColor: String = "blue"
    @State private var tagCancellables = Set<AnyCancellable>()

    @State private var showingOBFSuccessToast = false
    @State private var showingProcessingToast = false
    @State private var isSaving = false  // Block UI during save

    // Manual lookup states
    @State private var manualFetchedProduct: Product? = nil
    @State private var manualLookupError: String = ""
    @State private var showManualLookupError = false
    @State private var lookupCancellable: AnyCancellable? = nil

    // Add bag view model and sheet state
    @StateObject private var bagViewModel = BeautyBagViewModel()
    @State private var showAddBagSheet = false

    // At top of ManualEntryView, add syncCancellable state
    @State private var syncCancellable: AnyCancellable?  // for product sync

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
                .disabled(isSaving)
            }
            .navigationTitle("Add Product")
            .overlay(
                Group {
                    if isSaving {
                        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        ProgressView("Saving...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            )
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
                // Load bags and tags for selection
                bagViewModel.fetchBags()
                tagViewModel.fetchTags()

               // Fetch PAO taxonomy for period-after-opening options
               paoCancellable = APIService.shared.fetchPAOTaxonomy()
                   .receive(on: DispatchQueue.main)
                   .sink(receiveCompletion: { _ in }, receiveValue: { dict in
                       paoLabels = dict
                       // Sort by numeric month value
                       let sortedKeys = dict.keys.sorted { lhs, rhs in
                           let lhsNum = Int(lhs.trimmingCharacters(in: CharacterSet.letters)) ?? 0
                           let rhsNum = Int(rhs.trimmingCharacters(in: CharacterSet.letters)) ?? 0
                           return lhsNum < rhsNum
                       }
                       paoOptions = sortedKeys
                       if periodsAfterOpening.isEmpty, let first = sortedKeys.first {
                           periodsAfterOpening = first
                       }
                   })
                // Subscribe to refresh notifications to handle remote sync and DB clears
                NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTags"))
                    .receive(on: RunLoop.main)
                    .sink { _ in tagViewModel.fetchTags() }
                    .store(in: &tagCancellables)
                NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBags"))
                    .receive(on: RunLoop.main)
                    .sink { _ in bagViewModel.fetchBags() }
                    .store(in: &tagCancellables)
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
                        // Perform manual lookup without affecting scanner
                        lookupCancellable = APIService.shared.fetchProduct(barcode: viewModel.manualBarcode)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    manualLookupError = error.localizedDescription
                                    showManualLookupError = true
                                }
                            }, receiveValue: { product in
                                manualFetchedProduct = product
                                // prefill manual fields
                                viewModel.manualProductName = product.productName ?? ""
                                viewModel.manualBrand = product.brands ?? ""
                                if let pao = product.periodsAfterOpening {
                                    periodsAfterOpening = pao
                                }
                            })
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.manualBarcode.isEmpty)
                .alert(isPresented: $showManualLookupError) {
                    Alert(title: Text("Lookup Error"), message: Text(manualLookupError), dismissButton: .default(Text("OK")))
                }
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
                // Display local image if selected, else show fetched product image
                if let img = productImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let urlString = manualFetchedProduct?.imageUrl,
                          let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 100, height: 100)
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray))
                        @unknown default:
                            EmptyView()
                        }
                    }
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
                    ForEach(paoOptions, id: \.self) { code in
                        Text(paoLabels[code] ?? code).tag(code)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func bagSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add to Beauty Bags").font(.headline)
                Spacer()
                Button(action: { showAddBagSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.lushyPink)
                }
            }
            .padding(.bottom, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if bagViewModel.bags.isEmpty {
                        Text("No bags yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(bagViewModel.bags, id: \.objectID) { bag in
                        MultipleSelectionRow(
                            title: bag.name ?? "Unnamed Bag",
                            isSelected: selectedBagIDs.contains(bag.objectID),
                            icon: bag.icon,
                            color: bag.color
                        ) {
                            selectedBagIDs.toggleMembership(of: bag.objectID)
                        }
                    }
                }
            }
        }
        .glassCard(cornerRadius: 20)
        .onAppear {
            bagViewModel.fetchBags()
        }
        .sheet(isPresented: $showAddBagSheet, onDismiss: {
            bagViewModel.fetchBags()
        }) {
            AddBagSheet(viewModel: bagViewModel)
        }
    }

    @ViewBuilder private func tagSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Tags").font(.headline)
            if tagViewModel.tags.isEmpty {
                Text("No tags yet. Create one below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(tagViewModel.tags, id: \.objectID) { tag in
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
                    guard !newTagName.isEmpty else { return }
                    // Delegate creation to TagViewModel (handles remote & local sync)
                    tagViewModel.newTagName = newTagName
                    tagViewModel.newTagColor = newTagColor
                    tagViewModel.createTag()
                    // Clear local form
                    newTagName = ""
                    newTagColor = "blue"
                }
                .disabled(newTagName.isEmpty)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func saveButtonsSection() -> some View {
        HStack(spacing: 20) {
            Button("Save") {
                isSaving = true
                let context = CoreDataManager.shared.viewContext
                // 1) Save locally
                guard let objectID = viewModel.saveManualProduct(productImage: productImage) else {
                    isSaving = false
                    errorMessage = "Failed to save product locally."
                    showingErrorAlert = true
                    return
                }
                guard let userProduct = try? context.existingObject(with: objectID) as? UserProduct else {
                    isSaving = false
                    errorMessage = "Failed to fetch saved product."
                    showingErrorAlert = true
                    return
                }
                // 2) Attach selected tags locally so payload will include them
                for tagID in selectedTagIDs {
                    if let tag = try? context.existingObject(with: tagID) as? ProductTag {
                        userProduct.addToTags(tag)
                    }
                }
                // 3) Attach selected bags locally
                for bagID in selectedBagIDs {
                    if let bag = try? context.existingObject(with: bagID) as? BeautyBag {
                        userProduct.addToBags(bag)
                    }
                }
                try? context.save()
                // 4) Create user product on backend with tags & bags
                let userId = AuthService.shared.userId ?? ""
                let url = APIService.shared.baseURL
                    .appendingPathComponent("users")
                    .appendingPathComponent(userId)
                    .appendingPathComponent("products")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.token {
                    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                // Build body payload
                let productTags = selectedTagIDs.compactMap { try? context.existingObject(with: $0) as? ProductTag }.compactMap { $0.backendId }
                let productBags = selectedBagIDs.compactMap { try? context.existingObject(with: $0) as? BeautyBag }.compactMap { $0.backendId }
                var body: [String: Any] = [
                    "barcode": userProduct.barcode ?? "",
                    "productName": userProduct.productName ?? "",
                    "brand": userProduct.brand ?? "",
                    "imageUrl": userProduct.imageUrl ?? "",
                    "purchaseDate": userProduct.purchaseDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
                    "vegan": userProduct.vegan,
                    "crueltyFree": userProduct.crueltyFree,
                    "favorite": userProduct.favorite
                ]
                if !productTags.isEmpty { body["tags"] = productTags }
                if !productBags.isEmpty { body["bags"] = productBags }
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                struct CreateResponse: Decodable {
                    let status: String
                    let data: DataContainer
                    struct DataContainer: Decodable { let product: BackendUserProduct }
                }
                URLSession.shared.dataTaskPublisher(for: request)
                    .tryMap { data, response -> String in
                        guard let http = response as? HTTPURLResponse,
                              (200...299).contains(http.statusCode) else {
                            throw APIError.invalidResponse
                        }
                        // Parse JSON for the new product ID
                        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let dataObj = json["data"] as? [String: Any],
                              let prod = dataObj["product"] as? [String: Any],
                              let id = prod["_id"] as? String else {
                            throw APIError.decodingError
                        }
                        return id
                    }
                    .mapError { error in (error as? APIError) ?? .customError(error.localizedDescription) }
                    .receive(on: RunLoop.main)
                    .sink(receiveCompletion: { completion in
                        isSaving = false
                        if case .failure(let err) = completion {
                            errorMessage = err.localizedDescription
                            showingErrorAlert = true
                        }
                    }, receiveValue: { backendId in
                        // Persist backendId locally
                        userProduct.backendId = backendId
                        try? context.save()
                        // Dismiss and navigate
                        NotificationCenter.default.post(name: .init("RefreshProfile"), object: nil)
                        NotificationCenter.default.post(name: .init("RefreshFeed"), object: nil)
                        presentationMode.wrappedValue.dismiss()
                        viewModel.selectedUserProduct = userProduct
                        viewModel.showProductDetail = true
                    })
                    .store(in: &tagCancellables)
            }
            .disabled(isSaving)
            .neumorphicButtonStyle()

            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
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

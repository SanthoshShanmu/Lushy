import SwiftUI
import PhotosUI
import CoreData
import Combine

struct ManualEntryView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss

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
    @State private var newTagColor: String = "lushyPink"
    @State private var tagCancellables = Set<AnyCancellable>()

    @State private var showingProcessingToast = false
    @State private var isSaving = false  // Block UI during save

    // Manual lookup states - separate from scanner state
    @State private var manualFetchedProduct: Product? = nil
    @State private var manualLookupError: String = ""
    @State private var showManualLookupError = false
    @State private var manualProductNotFound = false  // Local state for manual entry
    @State private var lookupCancellable: AnyCancellable? = nil

    // Add bag view model and sheet state
    @StateObject private var bagViewModel = BeautyBagViewModel()
    @State private var showAddBagSheet = false

    // Guard against losing edits
    @State private var showDiscardAlert = false

    // At top of ManualEntryView, add syncCancellable state
    @State private var syncCancellable: AnyCancellable?  // for product sync

    // Add state for bag assign sheet
    @State private var showBagAssignSheet = false

    // Consider there are unsaved changes if any input is filled/selected or an image chosen
    private var hasUnsavedChanges: Bool {
        if isSaving { return false }
        return !(viewModel.manualBarcode.isEmpty &&
                 viewModel.manualProductName.isEmpty &&
                 viewModel.manualBrand.isEmpty &&
                 viewModel.manualShade.isEmpty &&
                 viewModel.manualSizeInMl.isEmpty &&
                 viewModel.manualSpf.isEmpty &&
                 productImage == nil &&
                 periodsAfterOpening.isEmpty &&
                 selectedBagIDs.isEmpty &&
                 selectedTagIDs.isEmpty &&
                 manualFetchedProduct == nil &&
                 !viewModel.isProductOpen &&
                 viewModel.openDate == nil)
    }

    // Simple local barcode validation: 8-13 digits
    private var isManualBarcodeValid: Bool {
        let digits = viewModel.manualBarcode.filter { $0.isNumber }
        return digits.count >= 8 && digits.count <= 13
    }

    @FocusState private var focusField: Field?
    private enum Field { case productName, brand, shade, size, spf, barcode }

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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        if hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges && !isSaving)
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
            // Error toast with retry
            .overlay(alignment: .bottom) {
                if showingErrorAlert && !errorMessage.isEmpty {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white)
                            Text(errorMessage).foregroundColor(.white).font(.subheadline)
                            Spacer(minLength: 8)
                            Button("Retry") { attemptSave() }
                                .padding(8)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(14)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert("Discard changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to close?")
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
                // If we come from product not found in scanner, transfer that state to local state
                if viewModel.productNotFound {
                    // Transfer the scanner's "not found" state to local state
                    manualProductNotFound = true
                    // Reset the scanner's state so it doesn't interfere
                    viewModel.productNotFound = false
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
                    // Removed OBF contribution progress indicator
                }
            }
            // Unified toast overlay (processing)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if showingProcessingToast {
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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowProcessingToast"))) { notification in
                if let userInfo = notification.userInfo, userInfo["key"] as? String == "processing-toast" {
                    withAnimation { showingProcessingToast = true }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideProcessingToast"))) { notification in
                if let userInfo = notification.userInfo, userInfo["key"] as? String == "processing-toast" {
                    withAnimation { showingProcessingToast = false }
                }
            }
        }
        .onDisappear {
            // Reset manual entry state for next presentation
            viewModel.manualBarcode = ""
            viewModel.manualProductName = ""
            viewModel.manualBrand = ""
            viewModel.manualShade = ""
            viewModel.manualSizeInMl = ""
            viewModel.manualSpf = ""
            viewModel.isProductOpen = false
            viewModel.openDate = nil
            viewModel.purchaseDate = Date()
            productImage = nil
            periodsAfterOpening = ""
            paoOptions = []
            paoLabels = [:]
            selectedBagIDs.removeAll()
            selectedTagIDs.removeAll()
            newTagName = ""
            newTagColor = "lushyPink"
            isSaving = false
            showingErrorAlert = false
            errorMessage = ""
            // Reset local manual lookup state
            manualFetchedProduct = nil
            manualProductNotFound = false
            manualLookupError = ""
            showManualLookupError = false
            // Cancel subscriptions to avoid leaks
            paoCancellable?.cancel(); paoCancellable = nil
            lookupCancellable?.cancel(); lookupCancellable = nil
            syncCancellable?.cancel(); syncCancellable = nil
            tagCancellables.removeAll()
        }
    }

    // MARK: - Sections
    @ViewBuilder private func productLookupSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Lookup").font(.headline)
            HStack(spacing: 12) {
                TextField("Barcode", text: $viewModel.manualBarcode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusField, equals: .barcode)
                Button("Look Up") {
                    if viewModel.manualBarcode.isEmpty {
                        errorMessage = "Please enter a barcode to look up"
                        showingErrorAlert = true
                    } else {
                        // Reset prior state - use local state only
                        manualFetchedProduct = nil
                        manualProductNotFound = false
                        manualLookupError = ""
                        showManualLookupError = false
                        
                        // Perform manual lookup without affecting scanner state
                        lookupCancellable = APIService.shared.fetchProduct(barcode: viewModel.manualBarcode)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    if error == .productNotFound {
                                        // Use local state - don't affect shared viewModel
                                        manualProductNotFound = true
                                        manualLookupError = "Product not found in database. Please enter details below to add it."
                                        showManualLookupError = false
                                        // Clear any previously fetched product
                                        manualFetchedProduct = nil
                                        focusField = .productName
                                    } else {
                                        manualProductNotFound = false
                                        manualLookupError = error.localizedDescription
                                        showManualLookupError = true
                                    }
                                }
                            }, receiveValue: { product in
                                manualFetchedProduct = product
                                viewModel.manualProductName = product.productName ?? ""
                                viewModel.manualBrand = product.brands ?? ""
                                if let pao = product.periodsAfterOpening { periodsAfterOpening = pao }
                                manualProductNotFound = false
                            })
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.manualBarcode.isEmpty)
            }
            // Inline barcode validation hint
            if !viewModel.manualBarcode.isEmpty && !isManualBarcodeValid {
                Text("Invalid barcode format (8-13 digits)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            // Inline not-found / error banner - use local state
            if manualProductNotFound {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                    Text(manualLookupError.isEmpty ? "Product not found. Please enter details below to add it to your collection." : manualLookupError)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if showManualLookupError && !manualLookupError.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                    Text(manualLookupError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func productInformationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Information").font(.headline)
            if manualProductNotFound {
                Text("Enter the product details below. We'll save it locally and sync to your account; the core data may also be sent anonymously to improve the catalog.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            TextField("Product Name (Required)", text: $viewModel.manualProductName)
                .textFieldStyle(.roundedBorder)
                .focused($focusField, equals: .productName)
            TextField("Brand (Optional)", text: $viewModel.manualBrand)
                .textFieldStyle(.roundedBorder)
            
            // Ethics toggles in a nice card layout
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
                                .font(.system(size: 18))
                            Text("Vegan")
                                .font(.subheadline)
                                .foregroundColor(viewModel.isVegan ? .green : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.isVegan ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
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
                                .font(.system(size: 18))
                            Text("Cruelty-Free")
                                .font(.subheadline)
                                .foregroundColor(viewModel.isCrueltyFree ? .pink : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.isCrueltyFree ? Color.pink.opacity(0.15) : Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.isCrueltyFree ? Color.pink : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
            .padding(.vertical, 4)
            
            // Metadata inputs
            TextField("Shade (Optional)", text: $viewModel.manualShade)
                .textFieldStyle(.roundedBorder)
            TextField("Size (ml, Optional)", text: $viewModel.manualSizeInMl)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("SPF (Optional)", text: $viewModel.manualSpf)
                .keyboardType(.numberPad)
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
            }
            // PAO now independent of opened state
            Text("Period After Opening (PAO)").font(.subheadline).foregroundColor(.secondary)
            HStack {
                ForEach(["3M","6M","12M","24M"], id: \.self) { code in
                    Button(action: { periodsAfterOpening = code }) {
                        Text(code)
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background((periodsAfterOpening == code ? Color.lushyPurple : Color.gray.opacity(0.2)))
                            .foregroundColor(periodsAfterOpening == code ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
                Button("Clear") { periodsAfterOpening = "" }
                    .font(.caption)
            }
            Picker("PAO", selection: $periodsAfterOpening) {
                ForEach(paoOptions, id: \.self) { code in
                    Text(paoLabels[code] ?? code).tag(code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            // Expiry / advisory
            if !periodsAfterOpening.isEmpty {
                if let preview = expiryPreview(openDate: viewModel.openDate, pao: periodsAfterOpening), viewModel.isProductOpen {
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.mossGreen)
                        Text("Will set expiry to \(preview)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !viewModel.isProductOpen {
                    HStack {
                        Image(systemName: "info.circle").foregroundColor(.secondary)
                        Text("PAO will apply once you mark the product as opened.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .glassCard(cornerRadius: 20)
    }

    private func expiryPreview(openDate: Date?, pao: String) -> String? {
        guard let open = openDate else { return nil }
        // Parse digits from PAO like "6M", "12M"
        let months = Int(pao.trimmingCharacters(in: CharacterSet.letters)) ?? 0
        guard months > 0 else { return nil }
        if let date = Calendar.current.date(byAdding: .month, value: months, to: open) {
            let df = DateFormatter(); df.dateStyle = .medium
            return df.string(from: date)
        }
        return nil
    }

    @ViewBuilder private func bagSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add to Beauty Bags").font(.headline)
                Spacer()
                Button(action: { showBagAssignSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.lushyPink)
                }
            }
            .padding(.bottom, 4)
            
            // Display selected bags
            if selectedBagIDs.isEmpty {
                Text("No bags selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(bagViewModel.bags.filter { selectedBagIDs.contains($0.objectID) }, id: \.objectID) { bag in
                            HStack(spacing: 6) {
                                Image(systemName: bag.icon ?? "bag.fill")
                                    .foregroundColor(Color(bag.color ?? "lushyPink"))
                                Text(bag.name ?? "Unnamed Bag")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(bag.color ?? "lushyPink").opacity(0.15))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .glassCard(cornerRadius: 20)
        .onAppear {
            bagViewModel.fetchBags()
        }
        .sheet(isPresented: $showBagAssignSheet) {
            ManualEntryBagAssignSheet(
                bagViewModel: bagViewModel,
                selectedBagIDs: $selectedBagIDs,
                isPresented: $showBagAssignSheet
            )
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
                    ForEach(["lushyPink","lushyPurple","mossGreen","lushyPeach"], id: \.self) {
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
                    newTagColor = "lushyPink"
                }
                .disabled(newTagName.isEmpty)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder private func saveButtonsSection() -> some View {
        HStack(spacing: 20) {
            Button("Save") { attemptSave() }
                .disabled(isSaving || viewModel.manualProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .neumorphicButtonStyle()

            Button("Cancel") {
                if hasUnsavedChanges { showDiscardAlert = true } else { dismiss() }
            }
            .neumorphicButtonStyle()
        }
    }

    private func attemptSave() {
        // Require a product name
        if viewModel.manualProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter a product name."
            showingErrorAlert = true
            return
        }

        isSaving = true
        showingErrorAlert = false
        let context = CoreDataManager.shared.viewContext
        
        // 1) Save locally first WITHOUT attaching bags/tags yet
        guard let objectID = viewModel.saveManualProduct(periodsAfterOpening: periodsAfterOpening, productImage: productImage) else {
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

        // Store selections for use after sync succeeds
        let pendingTagIDs = selectedTagIDs
        let pendingBagIDs = selectedBagIDs
        
        // Build tags/bags arrays for backend sync payload
        var tagBackendIds: [String] = []
        var bagBackendIds: [String] = []
        
        for tagID in pendingTagIDs {
            if let tag = try? context.existingObject(with: tagID) as? ProductTag,
               let backendId = tag.backendId {
                tagBackendIds.append(backendId)
            }
        }
        for bagID in pendingBagIDs {
            if let bag = try? context.existingObject(with: bagID) as? BeautyBag,
               let backendId = bag.backendId {
                bagBackendIds.append(backendId)
            }
        }
        
        // Temporarily attach for sync payload (will be removed if sync fails)
        for tagID in pendingTagIDs {
            if let tag = try? context.existingObject(with: tagID) as? ProductTag { 
                userProduct.addToTags(tag) 
            }
        }
        for bagID in pendingBagIDs {
            if let bag = try? context.existingObject(with: bagID) as? BeautyBag { 
                userProduct.addToBags(bag) 
            }
        }
        try? context.save()

        // 2) Sync to backend
        print("ManualEntryView: Starting backend sync for product localID=\(objectID)")
        syncCancellable = APIService.shared.syncProductWithBackend(product: userProduct)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let err):
                    print("ManualEntryView: Sync failed -> \(err.localizedDescription)")
                    // IMPORTANT: Remove local associations since sync failed
                    for tagID in pendingTagIDs {
                        if let tag = try? context.existingObject(with: tagID) as? ProductTag {
                            userProduct.removeFromTags(tag)
                        }
                    }
                    for bagID in pendingBagIDs {
                        if let bag = try? context.existingObject(with: bagID) as? BeautyBag {
                            userProduct.removeFromBags(bag)
                        }
                    }
                    try? context.save()
                    
                    self.isSaving = false
                    self.errorMessage = err.localizedDescription
                    self.showingErrorAlert = true
                case .finished:
                    break
                }
            }, receiveValue: { backendId in
                print("ManualEntryView: Sync success backendId=\(backendId)")
                userProduct.backendId = backendId
                // Associations are already attached and will remain since sync succeeded
                try? context.save()
                
                // 3) Navigate without excessive notifications
                self.isSaving = false
                self.viewModel.selectedUserProduct = userProduct
                self.viewModel.showProductDetail = true
                self.dismiss()
            })
    }

    // Removed misplaced onDisappear block here
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
    @Environment(\.dismiss) private var dismiss
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
            parent.dismiss()
            parent.onDismiss?()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
                        .foregroundColor(.lushyPink)
                }
            }
        }
    }
}

// MARK: - Manual Entry Bag Assign Sheet
struct ManualEntryBagAssignSheet: View {
    @ObservedObject var bagViewModel: BeautyBagViewModel
    @Binding var selectedBagIDs: Set<NSManagedObjectID>
    @Binding var isPresented: Bool
    @State private var newBagName = ""
    @State private var newBagIcon = "bag.fill"
    @State private var newBagColor = "lushyPink"
    
    // Predefined options for bag creation - updated with sparkles for Special Occasions
    private let iconOptions = ["bag.fill","sparkles","case.fill","suitcase.fill","heart.fill","star.fill"]
    private let colorOptions = ["lushyPink","lushyPurple","mossGreen","lushyPeach"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select Beauty Bags")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    if bagViewModel.bags.isEmpty {
                        Text("You have no bags yet. Create one below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
                        ForEach(bagViewModel.bags, id: \.self) { bag in
                            let selected = selectedBagIDs.contains(bag.objectID)
                            Button(action: { toggle(bag) }) {
                                VStack(spacing: 10) {
                                    Image(systemName: bag.icon ?? "bag.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(Color(bag.color ?? "lushyPink"))
                                    Text(bag.name ?? "Bag")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(bag.color ?? "lushyPink").opacity(selected ? 0.18 : 0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(selected ? Color(bag.color ?? "lushyPink") : Color.clear, lineWidth: 2)
                                        )
                                )
                                .overlay(
                                    Group { if selected { Image(systemName: "checkmark.circle.fill").foregroundColor(Color(bag.color ?? "lushyPink")).offset(x: 50, y: -50) } }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .animation(.spring(), value: selectedBagIDs)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create New Bag")
                            .font(.headline)
                        TextField("Bag Name", text: $newBagName)
                            .textFieldStyle(.roundedBorder)
                        
                        // Icon selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Icon").font(.caption).foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(iconOptions, id: \.self) { icon in
                                        let selected = (icon == newBagIcon)
                                        Button(action: { newBagIcon = icon }) {
                                            Image(systemName: icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(selected ? .white : .lushyPurple)
                                                .padding(12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(selected ? Color.lushyPurple : Color.lushyPurple.opacity(0.12))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(selected ? Color.lushyPurple : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Color selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Color").font(.caption).foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                ForEach(colorOptions, id: \.self) { colorName in
                                    let selected = (colorName == newBagColor)
                                    Button(action: { newBagColor = colorName }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(colorName))
                                                .frame(width: 34, height: 34)
                                            if selected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .shadow(radius: 2)
                                            }
                                        }
                                        .overlay(Circle().stroke(selected ? Color.white : Color.clear, lineWidth: 2))
                                        .shadow(color: Color(colorName).opacity(0.4), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Button(action: createBag) {
                            Label("Add Bag", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.lushyPink.opacity(newBagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 0.9)))
                                .foregroundColor(.white)
                        }
                        .disabled(newBagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("Assign Bags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { isPresented = false } }
            }
        }
    }

    private func toggle(_ bag: BeautyBag) { 
        if selectedBagIDs.contains(bag.objectID) { 
            selectedBagIDs.remove(bag.objectID) 
        } else { 
            selectedBagIDs.insert(bag.objectID) 
        } 
    }
    
    private func createBag() {
        // Create bag using the BeautyBagViewModel
        bagViewModel.newBagName = newBagName
        bagViewModel.newBagIcon = newBagIcon
        bagViewModel.newBagColor = newBagColor
        bagViewModel.createBag()
        
        // Clear form
        newBagName = ""
        newBagIcon = "bag.fill"
        newBagColor = "lushyPink"
    }
}

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView(viewModel: ScannerViewModel())
    }
}

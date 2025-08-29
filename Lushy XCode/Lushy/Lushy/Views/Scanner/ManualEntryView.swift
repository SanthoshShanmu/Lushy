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
    @State private var showTagAssignSheet = false

    // Consider there are unsaved changes if any input is filled/selected or an image chosen
    private var hasUnsavedChanges: Bool {
        if isSaving { return false }
        
        // Simplified check - only check if essential fields have content
        return !viewModel.manualProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !viewModel.manualBrand.isEmpty ||
               !selectedBagIDs.isEmpty ||
               !selectedTagIDs.isEmpty ||
               productImage != nil
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
                
                // Load bags and tags asynchronously to avoid blocking UI
                DispatchQueue.main.async {
                    bagViewModel.fetchBags()
                    tagViewModel.fetchTags()
                }

               // Fetch PAO taxonomy asynchronously
               DispatchQueue.main.async {
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
               }
                
                // Subscribe to refresh notifications asynchronously
                DispatchQueue.main.async {
                    NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTags"))
                        .receive(on: RunLoop.main)
                        .sink { _ in tagViewModel.fetchTags() }
                        .store(in: &tagCancellables)
                    NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBags"))
                        .receive(on: RunLoop.main)
                        .sink { _ in bagViewModel.fetchBags() }
                        .store(in: &tagCancellables)
                }
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
            // Only cancel ongoing operations - don't reset all state
            paoCancellable?.cancel()
            paoCancellable = nil
            lookupCancellable?.cancel()
            lookupCancellable = nil
            syncCancellable?.cancel()
            syncCancellable = nil
            
            // Cancel tag subscriptions safely
            for cancellable in tagCancellables {
                cancellable.cancel()
            }
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
            
            // Add price field
            HStack {
                TextField("Price (Optional)", text: $viewModel.manualPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Picker("Currency", selection: $viewModel.manualCurrency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR") 
                    Text("GBP").tag("GBP")
                    Text("NOK").tag("NOK")
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }
            
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Period After Opening (PAO)").font(.subheadline).foregroundColor(.secondary)
                Text("How many months is this product good for after opening?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Clean dropdown for PAO selection
                Picker("Select PAO", selection: $periodsAfterOpening) {
                    Text("Don't know / Not specified").tag("")
                    ForEach(["3M", "6M", "9M", "12M", "18M", "24M", "36M"], id: \.self) { months in
                        let monthNumber = months.replacingOccurrences(of: "M", with: "")
                        Text("\(monthNumber) months").tag(months)
                    }
                    // Add any additional options from backend
                    ForEach(paoOptions.filter { !["3M", "6M", "9M", "12M", "18M", "24M", "36M"].contains($0) }, id: \.self) { code in
                        Text(paoLabels[code] ?? code).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Helper text
                if periodsAfterOpening.isEmpty {
                    Text("💡 Most makeup products are good for 6-12 months after opening")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    // Expiry preview / advisory
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
                                // Compact view: ALWAYS show icon only, never custom images
                                if let icon = bag.icon, icon.count == 1 {
                                    // Emoji icon
                                    Text(icon)
                                        .font(.system(size: 14))
                                } else {
                                    // System icon with bag color
                                    Image(systemName: bag.icon ?? "bag.fill")
                                        .foregroundColor(Color(bag.color ?? "lushyPink"))
                                        .font(.system(size: 14))
                                }
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
            ModernBagAssignSheet(
                bagViewModel: bagViewModel,
                selectedBagIDs: $selectedBagIDs,
                isPresented: $showBagAssignSheet
            )
        }
    }

    @ViewBuilder private func tagSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Tags").font(.headline)
                Spacer()
                Button(action: { showTagAssignSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.lushyPink)
                }
            }
            .padding(.bottom, 4)
            
            // Display selected tags
            if selectedTagIDs.isEmpty {
                Text("No tags selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tagViewModel.tags.filter { selectedTagIDs.contains($0.objectID) }, id: \.objectID) { tag in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 10, height: 10)
                                Text(tag.name ?? "Unnamed Tag")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(tag.color ?? "lushyPink").opacity(0.15))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .glassCard(cornerRadius: 20)
        .sheet(isPresented: $showTagAssignSheet) {
            ManualEntryTagAssignSheet(
                tagViewModel: tagViewModel,
                selectedTagIDs: $selectedTagIDs,
                isPresented: $showTagAssignSheet
            )
        }
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

// MARK: - Modern Bag Assign Sheet (for Manual Entry)
struct ModernBagAssignSheet: View {
    @ObservedObject var bagViewModel: BeautyBagViewModel
    @Binding var selectedBagIDs: Set<NSManagedObjectID>
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingIconSelector = false
    @State private var showingImagePicker = false
    @State private var bagImage: UIImage? = nil
    @State private var imageSource: ImageSourceType = .none
    
    enum ImageSourceType {
        case none, camera, library
    }
    
    private let colorOptions = ["lushyPink", "lushyPurple", "mossGreen", "lushyPeach"]
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.06),
                    Color.lushyPurple.opacity(0.03),
                    Color.lushyCream.opacity(0.2),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Button("Cancel") { 
                        presentationMode.wrappedValue.dismiss() 
                    }
                    .foregroundColor(.lushyPink)
                    .font(.body)
                    
                    Spacer()
                    
                    Text("Assign Bags")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Save") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                    .font(.body)
                    .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.95))
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with live preview
                        VStack(spacing: 20) {
                            Text("Select Beauty Bags")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.lushyPink, .lushyPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Choose which bags to add your product to")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        VStack(spacing: 24) {
                            // Existing bags selection
                            if bagViewModel.bags.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "bag.badge.plus")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No bags yet")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Create your first beauty bag below")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 40)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
                                    ForEach(bagViewModel.bags, id: \.self) { bag in
                                        let selected = selectedBagIDs.contains(bag.objectID)
                                        Button(action: { toggle(bag) }) {
                                            VStack(spacing: 10) {
                                                // Show icon only, never custom images in assignment view
                                                if let icon = bag.icon, icon.count == 1 {
                                                    // Emoji icon
                                                    Text(icon)
                                                        .font(.system(size: 28))
                                                } else {
                                                    // System icon
                                                    Image(systemName: bag.icon ?? "bag.fill")
                                                        .font(.system(size: 28, weight: .semibold))
                                                        .foregroundColor(Color(bag.color ?? "lushyPink"))
                                                }
                                                
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
                                                Group { 
                                                    if selected { 
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(Color(bag.color ?? "lushyPink"))
                                                            .offset(x: 50, y: -50) 
                                                    } 
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .animation(.spring(), value: selectedBagIDs)
                                .padding(.horizontal, 24)
                            }
                            
                            // Create new bag section
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Create New Bag")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                // Live preview
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(bagViewModel.newBagColor).opacity(0.15))
                                            .frame(width: 80, height: 80)
                                        
                                        // Show custom image if available, otherwise show icon
                                        if let bagImage = bagImage {
                                            Image(uiImage: bagImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 70, height: 70)
                                                .clipShape(Circle())
                                        } else if bagViewModel.newBagIcon.count == 1 {
                                            // Emoji icon
                                            Text(bagViewModel.newBagIcon)
                                                .font(.system(size: 32))
                                        } else {
                                            // System icon
                                            Image(systemName: bagViewModel.newBagIcon)
                                                .font(.system(size: 32, weight: .medium))
                                                .foregroundColor(Color(bagViewModel.newBagColor))
                                        }
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text(bagViewModel.newBagName.isEmpty ? "Bag Name" : bagViewModel.newBagName)
                                            .font(.headline)
                                            .foregroundColor(bagViewModel.newBagName.isEmpty ? .secondary : .primary)
                                        
                                        if !bagViewModel.newBagDescription.isEmpty {
                                            Text(bagViewModel.newBagDescription)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                                .padding(24)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.9))
                                        .shadow(color: Color(bagViewModel.newBagColor).opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                
                                // Name input
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Bag Name")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Enter bag name...", text: $bagViewModel.newBagName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                }
                                
                                // Description input
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Description (Optional)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Add a description for your bag...", text: $bagViewModel.newBagDescription, axis: .vertical)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .lineLimit(2...4)
                                        .font(.body)
                                }
                                
                                // Icon selection
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Choose Icon")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Button(action: { showingIconSelector = true }) {
                                        HStack {
                                            if bagViewModel.newBagIcon.count == 1 {
                                                // Emoji icon
                                                Text(bagViewModel.newBagIcon)
                                                    .font(.system(size: 24))
                                            } else {
                                                // System icon
                                                Image(systemName: bagViewModel.newBagIcon)
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(Color(bagViewModel.newBagColor))
                                            }
                                            
                                            Text("Tap to choose icon")
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Color selection
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Choose Color")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 16) {
                                        ForEach(colorOptions, id: \.self) { colorName in
                                            let isSelected = colorName == bagViewModel.newBagColor
                                            Button(action: { bagViewModel.newBagColor = colorName }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color(colorName))
                                                        .frame(width: 50, height: 50)
                                                    
                                                    if isSelected {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 20, weight: .bold))
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                                .overlay(
                                                    Circle()
                                                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                                                )
                                                .shadow(color: Color(colorName).opacity(0.4), radius: isSelected ? 8 : 4, x: 0, y: 2)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        Spacer()
                                    }
                                }
                                
                                // Create button
                                Button(action: {
                                    bagViewModel.createBag(with: bagImage)
                                    // Auto-select the newly created bag
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if let newBag = bagViewModel.bags.first(where: { $0.name == bagViewModel.newBagName }) {
                                            selectedBagIDs.insert(newBag.objectID)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Create Bag")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.lushyPink, Color.lushyPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color.lushyPink.opacity(0.4), radius: 8, x: 0, y: 4)
                                }
                                .disabled(bagViewModel.newBagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showingIconSelector) {
            IconSelectorView(selectedIcon: $bagViewModel.newBagIcon, icons: [
                "bag.fill", "case.fill", "suitcase.fill", "backpack.fill",
                "sparkles", "star.fill", "heart.fill", "leaf.fill",
                "💄", "✨", "🌸", "💅", "🎀", "💖", "🌺", "🦋"
            ], onIconSelected: { _ in })
        }
    }
    
    private func toggle(_ bag: BeautyBag) {
        if selectedBagIDs.contains(bag.objectID) {
            selectedBagIDs.remove(bag.objectID)
        } else {
            selectedBagIDs.insert(bag.objectID)
        }
    }
}

// MARK: - Manual Entry Tag Assign Sheet
struct ManualEntryTagAssignSheet: View {
    @ObservedObject var tagViewModel: TagViewModel
    @Binding var selectedTagIDs: Set<NSManagedObjectID>
    @Binding var isPresented: Bool
    @State private var newTagName = ""
    @State private var newTagColor = "lushyPink"
    
    private let colorOptions = ["lushyPink","lushyPurple","mossGreen","lushyPeach"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select Tags")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    if tagViewModel.tags.isEmpty {
                        Text("You have no tags yet. Create one below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Use grid layout like beauty bags for consistency
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                        ForEach(tagViewModel.tags, id: \.self) { tag in
                            let selected = selectedTagIDs.contains(tag.objectID)
                            Button(action: { toggle(tag) }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(tag.color ?? "lushyPink"))
                                        .frame(width: 32, height: 32)
                                    Text(tag.name ?? "Tag")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(tag.color ?? "lushyPink").opacity(selected ? 0.18 : 0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selected ? Color(tag.color ?? "lushyPink") : Color.clear, lineWidth: 2)
                                        )
                                )
                                .overlay(
                                    Group { if selected { Image(systemName: "checkmark.circle.fill").foregroundColor(Color(tag.color ?? "lushyPink")).offset(x: 45, y: -45) } }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .animation(.spring(), value: selectedTagIDs)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create New Tag")
                            .font(.headline)
                        TextField("Tag Name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                        
                        // Color selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Color").font(.caption).foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                ForEach(colorOptions, id: \.self) { colorName in
                                    let selected = (colorName == newTagColor)
                                    Button(action: { newTagColor = colorName }) {
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
                        
                        Button(action: createTag) {
                            Label("Add Tag", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.lushyPurple.opacity(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 0.9)))
                                .foregroundColor(.white)
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("Assign Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { isPresented = false } }
            }
        }
    }

    private func toggle(_ tag: ProductTag) {
        if selectedTagIDs.contains(tag.objectID) {
            selectedTagIDs.remove(tag.objectID)
        } else {
            selectedTagIDs.insert(tag.objectID)
        }
    }
    
    private func createTag() {
        // Create tag using the TagViewModel
        tagViewModel.newTagName = newTagName
        tagViewModel.newTagColor = newTagColor
        tagViewModel.createTag()
        
        // Auto-select the newly created tag
        if let newTag = tagViewModel.tags.first(where: { ($0.name ?? "") == newTagName }) {
            selectedTagIDs.insert(newTag.objectID)
        }
        
        // Clear form
        newTagName = ""
        newTagColor = "lushyPink"
    }
}

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView(viewModel: ScannerViewModel())
    }
}

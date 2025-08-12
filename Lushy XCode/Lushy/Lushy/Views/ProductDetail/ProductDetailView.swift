import SwiftUI
import CoreData
import Combine
import UIKit

struct ProductDetailView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    // Edit sheet state
    @State private var showEditSheet = false
    @State private var editName: String = ""
    @State private var editBrand: String = ""
    @State private var editShade: String = ""
    @State private var editSizeText: String = ""
    @State private var editSpfText: String = ""
    @State private var editPurchaseDate: Date = Date()
    @State private var editIsOpened: Bool = false
    @State private var editOpenDate: Date = Date()
    @State private var editPAO: String = ""
    @State private var paoLabels: [String: String] = [:]
    @State private var paoOptions: [String] = []
    @State private var paoCancellable: AnyCancellable?
    // New: combined associations sheet
    @State private var showAssociationsSheet = false
    // New: guard against discarding unsaved edit changes
    @State private var showDiscardEditConfirm = false
    // New: unified assign sheet toggle and edit discard confirmation
    @State private var showAssignSheet = false
    @State private var showEditDiscardConfirm = false
    // New: state for removing from bag(s)
    @State private var showRemoveFromBagAlert = false
    @State private var bagToRemove: BeautyBag?
    @State private var showNoBagAlert = false
    
    // Helper to refetch PAO taxonomy on demand
    private func fetchPAOTaxonomy() {
        paoCancellable = APIService.shared.fetchPAOTaxonomy()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                // No-op; UI offers retry if options remain empty
            }, receiveValue: { dict in
                paoLabels = dict
                let sortedKeys = dict.keys.sorted { lhs, rhs in
                    let lhsNum = Int(lhs.trimmingCharacters(in: CharacterSet.letters)) ?? 0
                    let rhsNum = Int(rhs.trimmingCharacters(in: CharacterSet.letters)) ?? 0
                    return lhsNum < rhsNum
                }
                paoOptions = sortedKeys
            })
    }
    
    // Expiry preview helper used in the edit sheet
    private func expiryPreview(openDate: Date, pao: String) -> String? {
        let months = Int(pao.trimmingCharacters(in: CharacterSet.letters)) ?? 0
        guard months > 0 else { return nil }
        if let date = Calendar.current.date(byAdding: .month, value: months, to: openDate) {
            let df = DateFormatter(); df.dateStyle = .medium
            return df.string(from: date)
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // Dreamy gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.1),
                    Color.lushyPurple.opacity(0.05),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Product header with dreamy styling
                    _PrettyProductHeader(viewModel: viewModel)
                    
                    // Compliance & Dates
                    _PrettyComplianceSection(viewModel: viewModel)
                    
                    // Usage info with soft cards
                    _PrettyUsageInfo(viewModel: viewModel)
                    
                    // Actions with bubbly buttons
                    _PrettyActionButtons(viewModel: viewModel)
                    
                    // Comments with soft styling
                    _PrettyCommentsSection(viewModel: viewModel)
                    
                    // Reviews with girly theme
                    _PrettyReviewsSection(viewModel: viewModel)
                    
                    // Bags & Tags with soft design
                    _PrettyBagsSection(viewModel: viewModel, showAssignSheet: $showAssignSheet)
                    _PrettyTagsSection(viewModel: viewModel, showAssignSheet: $showAssignSheet)
                    
                    // Soft delete option (now: remove from bag(s))
                    Button(action: {
                        let bags = viewModel.bagsForProduct()
                        if bags.isEmpty {
                            showNoBagAlert = true
                        } else if bags.count == 1 {
                            bagToRemove = bags.first
                            showRemoveFromBagAlert = true
                        } else {
                            // Open assign sheet to uncheck desired bag(s)
                            showAssignSheet = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bag.badge.minus")
                                .font(.system(size: 14, weight: .medium))
                            Text("Remove from beauty bag")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .refreshable {
                viewModel.fetchBagsAndTags()
                viewModel.refreshRemoteDetail()
            }
        }
        .navigationTitle("Beauty Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Delete full product
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Remove Product", systemImage: "trash")
                    }
                    // Remove from bag(s)
                    Button {
                        let bags = viewModel.bagsForProduct()
                        if bags.isEmpty { showNoBagAlert = true }
                        else if bags.count == 1 { bagToRemove = bags.first; showRemoveFromBagAlert = true }
                        else { showAssignSheet = true }
                    } label: {
                        Label("Remove from Bag(s)…", systemImage: "bag.badge.minus")
                    }
                    
                    Button {
                        viewModel.toggleFavorite()
                    } label: {
                        Label(
                            viewModel.product.favorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: viewModel.product.favorite ? "heart.slash" : "heart"
                        )
                    }
                    
                    Button {
                        // Prefill edit fields
                        editName = viewModel.product.productName ?? ""
                        editBrand = viewModel.product.brand ?? ""
                        editShade = viewModel.product.shade ?? ""
                        editSizeText = viewModel.product.sizeInMl > 0 ? String(format: "%.0f", viewModel.product.sizeInMl) : ""
                        editSpfText = viewModel.product.spf > 0 ? String(viewModel.product.spf) : ""
                        editPurchaseDate = viewModel.product.purchaseDate ?? Date()
                        editIsOpened = viewModel.product.openDate != nil
                        editOpenDate = viewModel.product.openDate ?? Date()
                        editPAO = viewModel.product.periodsAfterOpening ?? ""
                        // Fetch PAO taxonomy
                        fetchPAOTaxonomy()
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    if let barcode = viewModel.product.barcode, !barcode.isEmpty {
                        Button {
                            UIPasteboard.general.string = barcode
                        } label: {
                            Label("Copy Barcode", systemImage: "doc.on.doc")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.lushyPink)
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Remove Product"),
                message: Text("Are you sure you want to remove this beauty item? This action cannot be undone."),
                primaryButton: .destructive(Text("Remove")) {
                    viewModel.deleteProduct()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        // Alert for removing from a single bag
        .alert(isPresented: $showRemoveFromBagAlert) {
            Alert(
                title: Text("Remove from bag"),
                message: Text("Remove this product from '\(bagToRemove?.name ?? "Bag")'?"),
                primaryButton: .destructive(Text("Remove")) {
                    if let bag = bagToRemove { viewModel.removeProductFromBag(bag) }
                },
                secondaryButton: .cancel()
            )
        }
        // Info if product is not in any bag
        .alert(isPresented: $showNoBagAlert) {
            Alert(
                title: Text("Not in any bag"),
                message: Text("This product is not assigned to a beauty bag."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: Binding(get: { viewModel.showReviewForm }, set: { viewModel.showReviewForm = $0 })) {
            ReviewFormView(viewModel: viewModel)
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Details")) {
                        TextField("Name", text: $editName)
                        TextField("Brand", text: $editBrand)
                        TextField("Shade", text: $editShade)
                        TextField("Size (ml)", text: $editSizeText)
                            .keyboardType(.decimalPad)
                        TextField("SPF", text: $editSpfText)
                            .keyboardType(.numberPad)
                    }
                    Section(header: Text("Dates")) {
                        DatePicker("Purchase Date", selection: $editPurchaseDate, displayedComponents: .date)
                        Toggle("Opened", isOn: $editIsOpened)
                        if editIsOpened {
                            DatePicker("Open Date", selection: $editOpenDate, displayedComponents: .date)
                            Picker("PAO", selection: $editPAO) {
                                ForEach(paoOptions, id: \.self) { code in
                                    Text(paoLabels[code] ?? code).tag(code)
                                }
                            }
                            // Quick PAO presets for better UX
                            HStack(spacing: 8) {
                                ForEach(["3M","6M","12M","24M"], id: \.self) { code in
                                    Button(action: { editPAO = code }) {
                                        Text(paoLabels[code] ?? code)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background((editPAO == code ? Color.lushyPurple : Color.gray.opacity(0.2)))
                                            .foregroundColor(editPAO == code ? .white : .primary)
                                            .cornerRadius(12)
                                    }
                                }
                                Button("Clear") { editPAO = "" }
                                    .font(.caption)
                            }
                            // PAO taxonomy retry if list is empty
                            if paoOptions.isEmpty {
                                Button("Retry PAO Load") { fetchPAOTaxonomy() }
                                    .font(.caption)
                            }
                            // Expiry preview when PAO is set
                            if !editPAO.isEmpty, let preview = expiryPreview(openDate: editOpenDate, pao: editPAO) {
                                HStack {
                                    Image(systemName: "calendar").foregroundColor(.lushyMint)
                                    Text("Will set expiry to \(preview)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Edit Product")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            if editHasChanges {
                                showEditDiscardConfirm = true
                            } else {
                                showEditSheet = false
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            let sizeVal = Double(editSizeText)
                            let spfVal = Int(editSpfText)
                            viewModel.updateDetails(
                                productName: editName,
                                brand: editBrand.isEmpty ? nil : editBrand,
                                shade: editShade.isEmpty ? nil : editShade,
                                sizeInMl: sizeVal,
                                spf: spfVal,
                                purchaseDate: editPurchaseDate,
                                isOpened: editIsOpened,
                                openDate: editIsOpened ? editOpenDate : nil,
                                periodsAfterOpening: editIsOpened ? (editPAO.isEmpty ? nil : editPAO) : nil
                            )
                            showEditSheet = false
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                // Prevent swipe-down dismiss if there are unsaved edits
                .interactiveDismissDisabled(editHasChanges)
                .alert("Discard changes?", isPresented: $showEditDiscardConfirm) {
                    Button("Keep Editing", role: .cancel) {}
                    Button("Discard", role: .destructive) { showEditSheet = false }
                } message: {
                    Text("You have unsaved edits. Do you want to discard them?")
                }
            }
        }
        // Unified Assign Tags & Bags Sheet
        .sheet(isPresented: $showAssignSheet) {
            AssignTagsBagsSheet(viewModel: viewModel, isPresented: $showAssignSheet)
        }
        // Error toast overlay with Retry
        .overlay(alignment: .bottom) {
            if let err = viewModel.error, !err.isEmpty {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white)
                        Text(err).foregroundColor(.white).font(.subheadline)
                        Spacer(minLength: 8)
                        Button("Retry") {
                            viewModel.refreshRemoteDetail()
                            viewModel.error = nil
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        Button(action: { viewModel.error = nil }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                        }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProductDeleted"))) { note in
            if let deletedId = note.object as? NSManagedObjectID,
               deletedId.uriRepresentation() == viewModel.product.objectID.uriRepresentation() {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            // Always refresh from backend when this view appears
            viewModel.fetchBagsAndTags()
            viewModel.refreshRemoteDetail()
        }
    }
    
    // Utility functions used by multiple components
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func isExpiringSoon(_ date: Date) -> Bool {
        let now = Date()
        let twoWeeks = 14 * 24 * 60 * 60
        return date.timeIntervalSince(now) < Double(twoWeeks)
    }
    
    // Track if edit form has changes to guard against loss
    private var editHasChanges: Bool {
        let currentName = viewModel.product.productName ?? ""
        let currentBrand = viewModel.product.brand ?? ""
        let currentShade = viewModel.product.shade ?? ""
        let currentSize = viewModel.product.sizeInMl > 0 ? String(format: "%.0f", viewModel.product.sizeInMl) : ""
        let currentSpf = viewModel.product.spf > 0 ? String(viewModel.product.spf) : ""
        if editName != currentName { return true }
        if editBrand != currentBrand { return true }
        if editShade != currentShade { return true }
        if editSizeText != currentSize { return true }
        if editSpfText != currentSpf { return true }
        let currentPurchase = viewModel.product.purchaseDate ?? Date()
        if Calendar.current.startOfDay(for: editPurchaseDate) != Calendar.current.startOfDay(for: currentPurchase) { return true }
        if editIsOpened != (viewModel.product.openDate != nil) { return true }
        if editIsOpened {
            if let pOpen = viewModel.product.openDate {
                if Calendar.current.startOfDay(for: editOpenDate) != Calendar.current.startOfDay(for: pOpen) { return true }
            } else { return true }
            if editPAO != (viewModel.product.periodsAfterOpening ?? "") { return true }
        }
        return false
    }
}

// Create prettier components for product detail

// MARK: - Pretty Product Header
struct _PrettyProductHeader: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Product image with soft shadow
            if let imageUrl = viewModel.product.imageUrl {
                HStack {
                    Spacer()
                    // Attempt to load from local file path
                    let fileURL = URL(fileURLWithPath: imageUrl)
                    if FileManager.default.fileExists(atPath: fileURL.path),
                       let uiImage = UIImage(contentsOfFile: fileURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .shadow(color: .lushyPink.opacity(0.2), radius: 15, x: 0, y: 8)
                    } else if let remoteURL = URL(string: imageUrl) {
                        AsyncImage(url: remoteURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.lushyPink.opacity(0.1), Color.lushyPurple.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 30))
                                        .foregroundColor(.lushyPink.opacity(0.3))
                                )
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: .lushyPink.opacity(0.2), radius: 15, x: 0, y: 8)
                    }
                    Spacer()
                }
            }
            
            // Product info with dreamy styling
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.product.brand ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPurple)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Text(viewModel.product.productName ?? "Unnamed Product")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Display metadata as styled tags
                HStack(spacing: 8) {
                    if let shade = viewModel.product.shade, !shade.isEmpty {
                        Text(shade)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPurple.opacity(0.2))
                            .foregroundColor(.lushyPurple)
                            .cornerRadius(12)
                    }
                    if viewModel.product.sizeInMl > 0 {
                        Text("\(String(format: "%.0f", viewModel.product.sizeInMl)) ml")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyMint.opacity(0.2))
                            .foregroundColor(.lushyMint)
                            .cornerRadius(12)
                    }
                    if viewModel.product.spf > 0 {
                        Text("SPF \(viewModel.product.spf)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPeach.opacity(0.2))
                            .foregroundColor(.lushyPeach)
                            .cornerRadius(12)
                    }
                }
                
                // Expiry countdown
                if let days = viewModel.daysUntilExpiry {
                    Text(days > 0 ? "Expires in \(days) days" : "Expired")
                        .font(.subheadline)
                        .foregroundColor(days > 7 ? .green : (days > 0 ? .orange : .red))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Compliance & Dates Section
private struct _PrettyComplianceSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.lushyMint)
                Text("Compliance & Dates")
                    .font(.headline)
            }
            .padding(.bottom, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                if let purchase = viewModel.product.purchaseDate {
                    HStack {
                        Text("Purchased:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateString(purchase))
                    }
                }
                if let open = viewModel.product.openDate {
                    HStack {
                        Text("Opened:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateString(open))
                    }
                }
                if let pao = viewModel.product.periodsAfterOpening, !pao.isEmpty {
                    HStack {
                        Text("PAO:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(pao)
                    }
                }
                HStack {
                    Text("Expiry:")
                        .foregroundColor(.secondary)
                    Spacer()
                    if let expire = viewModel.product.expireDate {
                        Text(dateString(expire))
                            .foregroundColor(viewModel.daysUntilExpiry ?? 999 > 7 ? .green : ((viewModel.daysUntilExpiry ?? 0) > 0 ? .orange : .red))
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                    }
                }
                Divider().padding(.vertical, 4)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "shield.checkerboard")
                        .foregroundColor(.lushyPurple)
                    Text(viewModel.complianceAdvisory)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }
}

// MARK: - Pretty Usage Info
struct _PrettyUsageInfo: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.lushyPink)
                Text("Usage Stats")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 15) {
                _PrettyStatCard(
                    title: "Times Used",
                    value: "\(viewModel.product.timesUsed)",
                    icon: "wand.and.stars",
                    color: .lushyPink
                )
                
                _PrettyStatCard(
                    title: "Love Rating",
                    value: String(format: "%.1f", viewModel.rating),
                    icon: "heart.fill",
                    color: .lushyPurple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Pretty Stat Card
struct _PrettyStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.05), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Pretty Action Buttons
struct _PrettyActionButtons: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.toggleFavorite()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.product.favorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewModel.product.favorite ? "Loved" : "Love It")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(viewModel.product.favorite ? .white : .lushyPink)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                viewModel.product.favorite ?
                                    LinearGradient(colors: [.lushyPink, .lushyPurple], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.lushyPink.opacity(0.3), lineWidth: viewModel.product.favorite ? 0 : 1.5)
                            ))
                }

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.incrementUsage()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Used It")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(colors: [.lushyMint, .lushyPeach], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
            }
            .padding(.horizontal)
            
            Button(action: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                viewModel.showReviewForm = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Write a Review")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.lushyPurple)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.lushyPurple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.lushyPurple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
            
            // Finish product button
            Button(action: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                viewModel.markAsEmpty()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Finish Product")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(colors: [.lushyPeach, .lushyMint], startPoint: .leading, endPoint: .trailing)
                        )
            )}
            .padding(.horizontal)
        }
    }
}

// MARK: - Comments Section Component
private struct _PrettyCommentsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
            
            commentsContent
            
            HStack {
                TextField("Add a comment", text: $viewModel.newComment)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button(action: {
                    viewModel.addComment()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.lushyPink)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .disabled(viewModel.newComment.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var commentsContent: some View {
        if let comments = viewModel.product.comments as? Set<Comment>, !comments.isEmpty {
            ForEach(Array(comments), id: \.self) { comment in
                CommentView(comment: comment)
            }
        } else {
            Text("No comments yet.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Reviews Section Component
private struct _PrettyReviewsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviews")
                .font(.headline)
            
            reviewsContent
            
            Button(action: {
                viewModel.showReviewForm = true
            }) {
                Label("Write a Review", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var reviewsContent: some View {
        if let reviews = viewModel.product.reviews as? Set<Review>, !reviews.isEmpty {
            ForEach(Array(reviews), id: \.self) { review in
                reviewRow(review)
            }
        } else {
            Text("No reviews yet.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(review.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Spacer()
                
                starRating(rating: Int(review.rating))
            }
            
            Text(review.text ?? "")
                .font(.caption)
                .padding(.top, 1)
            
            Text(formatDate(review.createdAt ?? Date()))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            Divider()
        }
        .padding(.bottom, 8)
    }
    
    private func starRating(rating: Int) -> some View {
        HStack {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Bags Section
private struct _PrettyBagsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var showAssignSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Beauty Bags")
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.fetchBagsAndTags()
                    showAssignSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
            if viewModel.bagsForProduct().isEmpty {
                Text("Not in any bag.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.bagsForProduct(), id: \.self) { bag in
                    HStack {
                        Image(systemName: bag.icon ?? "bag.fill")
                            .foregroundColor(Color(bag.color ?? "lushyPink"))
                        Text(bag.name ?? "Unnamed Bag")
                        Spacer()
                        Button(action: { viewModel.removeProductFromBag(bag) }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Tags Section
private struct _PrettyTagsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var showAssignSheet: Bool

    @State private var newTagName = ""
    @State private var newTagColor = "lushyPink"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.fetchBagsAndTags()
                    showAssignSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
            if viewModel.tagsForProduct().isEmpty {
                Text("No tags.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.tagsForProduct(), id: \.self) { tag in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 10, height: 10)
                                Text(tag.name ?? "")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Button(action: { viewModel.removeTagFromProduct(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(tag.color ?? "lushyPink").opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Unified sheet to assign Tags & Bags together
private struct AssignTagsBagsSheet: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var isPresented: Bool
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
    @State private var newTagName = ""
    @State private var newTagColor = "lushyPink"
    @State private var newBagName = ""
    @State private var newBagIcon = "bag.fill"
    @State private var newBagColor = "lushyPink"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Bags")) {
                    if viewModel.allBags.isEmpty {
                        Text("No bags yet").foregroundColor(.secondary)
                    }
                    ForEach(viewModel.allBags, id: \.self) { bag in
                        Button(action: { toggle(bag: bag) }) {
                            HStack {
                                Image(systemName: bag.icon ?? "bag.fill")
                                    .foregroundColor(Color(bag.color ?? "lushyPink"))
                                Text(bag.name ?? "Unnamed Bag")
                                Spacer()
                                if selectedBagIDs.contains(bag.objectID) {
                                    Image(systemName: "checkmark").foregroundColor(.lushyPink)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Create Bag").font(.subheadline)
                        TextField("Name", text: $newBagName)
                        HStack {
                            TextField("Icon (SF Symbol)", text: $newBagIcon)
                            TextField("Color token", text: $newBagColor)
                        }
                        Button("Add Bag") {
                            if let newId = CoreDataManager.shared.createBeautyBag(name: newBagName, color: newBagColor, icon: newBagIcon) {
                                if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: newId) as? BeautyBag {
                                    selectedBagIDs.insert(bag.objectID)
                                }
                            }
                            newBagName = ""; newBagIcon = "bag.fill"; newBagColor = "lushyPink"
                            viewModel.fetchBagsAndTags()
                        }.disabled(newBagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section(header: Text("Tags")) {
                    if viewModel.allTags.isEmpty {
                        Text("No tags yet").foregroundColor(.secondary)
                    }
                    ForEach(viewModel.allTags, id: \.self) { tag in
                        Button(action: { toggle(tag: tag) }) {
                            HStack {
                                Circle().fill(Color(tag.color ?? "lushyPink")).frame(width: 14, height: 14)
                                Text(tag.name ?? "Unnamed Tag")
                                Spacer()
                                if selectedTagIDs.contains(tag.objectID) {
                                    Image(systemName: "checkmark").foregroundColor(.lushyPink)
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("New Tag", text: $newTagName)
                        Picker("Color", selection: $newTagColor) {
                            ForEach(["lushyPink","lushyPurple","lushyMint","lushyPeach"], id: \.self) { c in
                                Text(c.capitalized).tag(c)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        Button("Add") {
                            CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
                            newTagName = ""; newTagColor = "lushyPink"
                            viewModel.fetchBagsAndTags()
                        }.disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Assign Tags & Bags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { applyChanges(); isPresented = false }
                }
            }
            .onAppear {
                // initialize selections from current relationships
                selectedBagIDs = Set(viewModel.bagsForProduct().map { $0.objectID })
                selectedTagIDs = Set(viewModel.tagsForProduct().map { $0.objectID })
            }
        }
    }

    private func toggle(bag: BeautyBag) { if selectedBagIDs.contains(bag.objectID) { selectedBagIDs.remove(bag.objectID) } else { selectedBagIDs.insert(bag.objectID) } }
    private func toggle(tag: ProductTag) { if selectedTagIDs.contains(tag.objectID) { selectedTagIDs.remove(tag.objectID) } else { selectedTagIDs.insert(tag.objectID) } }

    private func applyChanges() {
        // Bags
        let currentBags = Set(viewModel.bagsForProduct().map { $0.objectID })
        let toAddBags = selectedBagIDs.subtracting(currentBags)
        let toRemoveBags = currentBags.subtracting(selectedBagIDs)
        for id in toAddBags {
            if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? BeautyBag {
                viewModel.addProductToBag(bag)
            }
        }
        for id in toRemoveBags {
            if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? BeautyBag {
                viewModel.removeProductFromBag(bag)
            }
        }
        // Tags
        let currentTags = Set(viewModel.tagsForProduct().map { $0.objectID })
        let toAddTags = selectedTagIDs.subtracting(currentTags)
        let toRemoveTags = currentTags.subtracting(selectedTagIDs)
        for id in toAddTags {
            if let tag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? ProductTag {
                viewModel.addTagToProduct(tag)
            }
        }
        for id in toRemoveTags {
            if let tag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? ProductTag {
                viewModel.removeTagFromProduct(tag)
            }
        }
    }
}

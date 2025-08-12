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
    // Track if user manually changed certain fields to avoid overriding after remote sync
    @State private var userEditedShade = false
    @State private var userEditedSize = false
    @State private var userEditedSpf = false
    // New: combined associations sheet
    @State private var showAssociationsSheet = false
    // New: guard against discarding unsaved edit changes
    @State private var showDiscardEditConfirm = false
    // New: unified assign sheet toggle and edit discard confirmation
    @State private var showAssignSheet = false
    @State private var showEditDiscardConfirm = false
    // Restore cancellable for PAO fetch
    @State private var paoCancellable: AnyCancellable?
    // Track if user manually changed PAO so we stop auto-syncing it
    @State private var userEditedPAO = false
    @State private var showBagAssignSheet = false
    @State private var showTagAssignSheet = false
    
    // Extracted background gradient to reduce body complexity (fixes type-check slowdown)
    private var backgroundGradient: LinearGradient {
        let colors: [Color] = [
            Color.lushyPink.opacity(0.1),
            Color.lushyPurple.opacity(0.05),
            Color.white
        ]
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // Fallback PAO options if taxonomy fetch fails or is empty
    private let fallbackPAOOptions = ["3M","6M","9M","12M","18M","24M","36M"]
    
    // Precomputed PAO list to reduce type-check complexity
    private var allPAOCodes: [String] {
        let union = Set(fallbackPAOOptions).union(Set(paoOptions))
        return union.sorted { (a,b) in
            let aNum = Int(a.trimmingCharacters(in: CharacterSet.letters)) ?? 0
            let bNum = Int(b.trimmingCharacters(in: CharacterSet.letters)) ?? 0
            return aNum < bNum
        }
    }
    
    // Helper to refetch PAO taxonomy on demand
    private func fetchPAOTaxonomy() {
        paoCancellable = APIService.shared.fetchPAOTaxonomy()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if paoOptions.isEmpty { paoLabels = Dictionary(uniqueKeysWithValues: fallbackPAOOptions.map { ($0, $0) }); paoOptions = fallbackPAOOptions }
            }, receiveValue: { dict in
                var normalized: [String:String] = [:]
                for (rawKey, label) in dict { normalized[rawKey.replacingOccurrences(of: " ", with: "")] = label }
                // Always include quick presets even if backend omits them
                for preset in fallbackPAOOptions where normalized[preset] == nil { normalized[preset] = preset }
                paoLabels = normalized
                let sortedKeys = normalized.keys.sorted { lhs, rhs in
                    let lhsNum = Int(lhs.trimmingCharacters(in: CharacterSet.letters)) ?? 0
                    let rhsNum = Int(rhs.trimmingCharacters(in: CharacterSet.letters)) ?? 0
                    return lhsNum < rhsNum
                }
                paoOptions = sortedKeys
                if !editPAO.isEmpty && !paoOptions.contains(editPAO) { paoOptions.append(editPAO) }
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
    
    // Break out scroll main content
    private var mainScrollContent: some View {
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
                _PrettyBagsSection(viewModel: viewModel, showBagAssignSheet: $showBagAssignSheet)
                _PrettyTagsSection(viewModel: viewModel, showTagAssignSheet: $showTagAssignSheet)
            }
            .padding(.bottom, 30)
        }
        .refreshable {
            viewModel.fetchBagsAndTags(); viewModel.refreshRemoteDetail()
        }
    }
    
    // Error overlay extracted
    @ViewBuilder private var errorOverlay: some View {
        if let err = viewModel.error, !err.isEmpty {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white)
                    Text(err).foregroundColor(.white).font(.subheadline)
                    Spacer(minLength: 8)
                    Button("Retry") { viewModel.refreshRemoteDetail(); viewModel.error = nil }
                        .padding(8).background(Color.white.opacity(0.2)).cornerRadius(8).foregroundColor(.white)
                    Button(action: { viewModel.error = nil }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white) }
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
    
    // Extracted toolbar menu to reduce type-check complexity in body
    private var moreMenu: some View {
        Menu {
            // Delete full product
            Button(role: .destructive) { showingDeleteAlert = true } label: {
                Label("Remove Product", systemImage: "trash")
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
                prepareEditSheet()
                showEditSheet = true
            } label: { Label("Edit", systemImage: "pencil") }
            
            if let barcode = viewModel.product.barcode, !barcode.isEmpty {
                Button { UIPasteboard.general.string = barcode } label: {
                    Label("Copy Barcode", systemImage: "doc.on.doc")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.lushyPink)
        }
    }
    
    // Helper to prepare edit sheet values (single source of truth)
    private func prepareEditSheet() {
        let p = viewModel.product
        editName = p.productName ?? ""
        editBrand = p.brand ?? ""
        editShade = p.shade ?? ""
        editSizeText = p.sizeInMl > 0 ? String(format: "%.0f", p.sizeInMl) : ""
        editSpfText = p.spf > 0 ? String(p.spf) : ""
        editPurchaseDate = p.purchaseDate ?? Date()
        editIsOpened = p.openDate != nil
        editOpenDate = p.openDate ?? Date()
        editPAO = (p.periodsAfterOpening ?? "").replacingOccurrences(of: " ", with: "")
        userEditedShade = false
        userEditedSize = false
        userEditedSpf = false
        userEditedPAO = false
        if paoOptions.isEmpty { paoLabels = Dictionary(uniqueKeysWithValues: fallbackPAOOptions.map { ($0, $0) }); paoOptions = fallbackPAOOptions }
        if !editPAO.isEmpty && !paoOptions.contains(editPAO) { paoOptions.append(editPAO) }
        fetchPAOTaxonomy()
    }
    
    // Sync current product fields into edit form unless user already modified them
    private func syncEditFieldsFromProduct(force: Bool) {
        // Only proceed if sheet is showing or forced
        if !showEditSheet && !force { return }
        let p = viewModel.product
        // Name & brand always sync if force OR fields still match previous baseline (empty when opened)
        if force || editName.isEmpty { editName = p.productName ?? "" }
        if force || editBrand.isEmpty { editBrand = p.brand ?? "" }
        if force || (!userEditedShade) { editShade = p.shade ?? "" }
        if force || (!userEditedSize) { editSizeText = p.sizeInMl > 0 ? String(format: "%.0f", p.sizeInMl) : "" }
        if force || (!userEditedSpf) { editSpfText = p.spf > 0 ? String(p.spf) : "" }
        if force || editPurchaseDate == Date() { editPurchaseDate = p.purchaseDate ?? Date() }
        editIsOpened = p.openDate != nil
        if let od = p.openDate { editOpenDate = od }
        if (force || editPAO.isEmpty) && !userEditedPAO { editPAO = (p.periodsAfterOpening ?? "").replacingOccurrences(of: " ", with: "") }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dreamy gradient background (extracted)
            backgroundGradient.ignoresSafeArea()
            
            mainScrollContent
            
            errorOverlay
        }
        .navigationTitle("Beauty Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                moreMenu
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
        .sheet(isPresented: Binding(get: { viewModel.showReviewForm }, set: { viewModel.showReviewForm = $0 })) {
            ReviewFormView(viewModel: viewModel)
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Details")) {
                        TextField("Name", text: $editName)
                        TextField("Brand", text: $editBrand)
                        TextField("Shade", text: Binding(get: { editShade }, set: { editShade = $0; userEditedShade = true }))
                        TextField("Size (ml)", text: Binding(get: { editSizeText }, set: { editSizeText = $0; userEditedSize = true }))
                            .keyboardType(.decimalPad)
                        TextField("SPF", text: Binding(get: { editSpfText }, set: { editSpfText = $0; userEditedSpf = true }))
                            .keyboardType(.numberPad)
                    }
                    Section(header: Text("Dates")) {
                        DatePicker("Purchase Date", selection: $editPurchaseDate, displayedComponents: .date)
                        Toggle("Opened", isOn: $editIsOpened)
                        if editIsOpened {
                            DatePicker("Open Date", selection: $editOpenDate, displayedComponents: .date)
                        }
                    }
                    // Simplified PAO selection UX (chips only)
                    Section(header: Text("Shelf Life (PAO)")) {
                        VStack(alignment: .leading, spacing: 8) {
                            FlexibleChips(data: ["None"] + allPAOCodes, selection: $editPAO, labels: paoLabels)
                            HStack(spacing: 12) {
                                if !editPAO.isEmpty { Button("Clear") { editPAO = "" }.font(.caption) }
                                if paoOptions.isEmpty { Button("Retry Load") { fetchPAOTaxonomy() }.font(.caption) }
                                Spacer()
                            }
                            // Expiry preview / advisory
                            if !editPAO.isEmpty {
                                if editIsOpened, let preview = expiryPreview(openDate: editOpenDate, pao: editPAO) {
                                    HStack { Image(systemName: "calendar").foregroundColor(.lushyMint); Text("Will set expiry to \(preview)").font(.caption).foregroundColor(.secondary) }
                                } else if !editIsOpened {
                                    HStack { Image(systemName: "info.circle").foregroundColor(.secondary); Text("PAO applies once product is marked opened.").font(.caption).foregroundColor(.secondary) }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Edit Product")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            if editHasChanges { showEditDiscardConfirm = true } else { showEditSheet = false }
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
                                periodsAfterOpening: editPAO.isEmpty ? nil : editPAO
                            )
                            showEditSheet = false
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .interactiveDismissDisabled(editHasChanges)
                .alert("Discard changes?", isPresented: $showEditDiscardConfirm) {
                    Button("Keep Editing", role: .cancel) {}
                    Button("Discard", role: .destructive) { showEditSheet = false }
                } message: { Text("You have unsaved edits. Do you want to discard them?") }
                .onAppear { syncEditFieldsFromProduct(force: true) }
                .onReceive(viewModel.$product) { _ in syncEditFieldsFromProduct(force: false) }
            }
        }
        // Separate Bag Assign Sheet
        .sheet(isPresented: $showBagAssignSheet) {
            BagAssignSheet(viewModel: viewModel, isPresented: $showBagAssignSheet)
        }
        // Separate Tag Assign Sheet
        .sheet(isPresented: $showTagAssignSheet) {
            TagAssignSheet(viewModel: viewModel, isPresented: $showTagAssignSheet)
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
        }
        // PAO comparison now independent of opened state
        if editPAO != (viewModel.product.periodsAfterOpening ?? "") { return true }
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
    
    // Local formatter to avoid referencing outer scope helper
    private func dateString(_ date: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; return df.string(from: date)
    }
    
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
            
            Text(dateString(review.createdAt ?? Date()))
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
}

// MARK: - Bags Section
private struct _PrettyBagsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var showBagAssignSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Beauty Bags")
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.fetchBagsAndTags()
                    showBagAssignSheet = true
                }) { Image(systemName: "plus") }
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
    @Binding var showTagAssignSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.fetchBagsAndTags()
                    showTagAssignSheet = true
                }) { Image(systemName: "plus") }
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(tag.color ?? "lushyPink").opacity(0.15))
                            .cornerRadius(14)
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

// Separate Bag Assign Sheet
private struct BagAssignSheet: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var isPresented: Bool
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
    @State private var newBagName = ""
    @State private var newBagIcon = "bag.fill"
    @State private var newBagColor = "lushyPink"
    // Added predefined options instead of free text fields
    private let iconOptions = ["bag.fill","shippingbox.fill","case.fill","suitcase.fill","heart.fill","star.fill"]
    private let colorOptions = ["lushyPink","lushyPurple","lushyMint","lushyPeach"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select Beauty Bags")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    if viewModel.allBags.isEmpty {
                        Text("You have no bags yet. Create one below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
                        ForEach(viewModel.allBags, id: \.self) { bag in
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
                                    ForEach(iconOptions, id: \ .self) { icon in
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
                                ForEach(colorOptions, id: \ .self) { colorName in
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
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { applyChanges(); isPresented = false } }
            }
            .onAppear { selectedBagIDs = Set(viewModel.bagsForProduct().map { $0.objectID }) }
        }
    }

    private func toggle(_ bag: BeautyBag) { if selectedBagIDs.contains(bag.objectID) { selectedBagIDs.remove(bag.objectID) } else { selectedBagIDs.insert(bag.objectID) } }
    private func createBag() {
        if let newId = CoreDataManager.shared.createBeautyBag(name: newBagName, color: newBagColor, icon: newBagIcon),
           let bag = try? CoreDataManager.shared.viewContext.existingObject(with: newId) as? BeautyBag {
            selectedBagIDs.insert(bag.objectID)
            viewModel.fetchBagsAndTags()
        }
        newBagName = ""; newBagIcon = "bag.fill"; newBagColor = "lushyPink"
    }
    private func applyChanges() {
        let current = Set(viewModel.bagsForProduct().map { $0.objectID })
        let toAdd = selectedBagIDs.subtracting(current)
        let toRemove = current.subtracting(selectedBagIDs)
        for id in toAdd { if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? BeautyBag { viewModel.addProductToBag(bag) } }
        for id in toRemove { if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? BeautyBag { viewModel.removeProductFromBag(bag) } }
    }
}

// Separate Tag Assign Sheet
private struct TagAssignSheet: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var isPresented: Bool
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
    @State private var newTagName = ""
    @State private var newTagColor = "lushyPink"
    private let colorOptions = ["lushyPink","lushyPurple","lushyMint","lushyPeach"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select Tags")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    if viewModel.allTags.isEmpty {
                        Text("You have no tags yet. Create one below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    FlowLayout(viewModel.allTags) { tag in
                        let selected = selectedTagIDs.contains(tag.objectID)
                        Button(action: { toggle(tag) }) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(tag.color ?? "lushyPink")).frame(width: 10, height: 10)
                                Text(tag.name ?? "Tag")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(tag.color ?? "lushyPink").opacity(selected ? 0.28 : 0.12))
                                    .overlay(
                                        Capsule().stroke(selected ? Color(tag.color ?? "lushyPink") : Color.clear, lineWidth: 2)
                                    )
                            )
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .animation(.easeInOut, value: selectedTagIDs)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create New Tag")
                            .font(.headline)
                        TextField("Tag Name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                        Picker("Color", selection: $newTagColor) {
                            ForEach(colorOptions, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Button(action: createTag) {
                            Label("Add Tag", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.lushyPurple.opacity(newTagName.isEmpty ? 0.3 : 0.9)))
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
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { applyChanges(); isPresented = false } }
            }
            .onAppear { selectedTagIDs = Set(viewModel.tagsForProduct().map { $0.objectID }) }
        }
    }

    private func toggle(_ tag: ProductTag) { if selectedTagIDs.contains(tag.objectID) { selectedTagIDs.remove(tag.objectID) } else { selectedTagIDs.insert(tag.objectID) } }
    private func createTag() {
        CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
        viewModel.fetchBagsAndTags()
        if let newTag = viewModel.allTags.first(where: { ($0.name ?? "") == newTagName }) {
            selectedTagIDs.insert(newTag.objectID)
        }
        newTagName = ""; newTagColor = "lushyPink"
    }
    private func applyChanges() {
        let current = Set(viewModel.tagsForProduct().map { $0.objectID })
        let toAdd = selectedTagIDs.subtracting(current)
        let toRemove = current.subtracting(selectedTagIDs)
        for id in toAdd { if let tag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? ProductTag { viewModel.addTagToProduct(tag) } }
        for id in toRemove { if let tag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? ProductTag { viewModel.removeTagFromProduct(tag) } }
    }
}

// Simple flow layout for tag chips
private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Index == Int {
    let data: Data
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.1.id) { _, element in
                content(element)
                    .padding(4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > g.size.width { width = 0; height -= d.height }
                        let result = width
                        if element.id == data.last?.id { width = 0 } else { width -= d.width }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if element.id == data.last?.id { height = 0 }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View { GeometryReader { geo -> Color in DispatchQueue.main.async { binding.wrappedValue = geo.size.height }; return Color.clear } }
}

// Add FlexibleChips used in edit sheet
private struct FlexibleChips: View {
    let data: [String]
    @Binding var selection: String
    let labels: [String:String]
    private let columns = [GridItem(.adaptive(minimum: 54), spacing: 8)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(data, id: \.self) { item in
                let isNone = (item == "None")
                let isSelected = selection.isEmpty && isNone || (!isNone && selection == item)
                Button(action: { selection = isNone ? "" : item }) {
                    Text(isNone ? "None" : (labels[item] ?? item))
                        .font(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? Color.lushyPurple : Color.gray.opacity(0.15))
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.default, value: selection)
    }
}

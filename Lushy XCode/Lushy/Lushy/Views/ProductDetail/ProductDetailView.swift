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
    @State private var showUsageJourney = false
    
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
                // Product header with dreamy styling and favorite heart in top-right
                _PrettyProductHeader(viewModel: viewModel)
                
                // Action buttons (favorite and mark as finished)
                _PrettyActionButtons(viewModel: viewModel)
                
                // Move Beauty Bags and Tags before usage tracking
                _PrettyBagsSection(viewModel: viewModel, showBagAssignSheet: $showBagAssignSheet)
                _PrettyTagsSection(viewModel: viewModel, showTagAssignSheet: $showTagAssignSheet)
                
                // Product Insights & Dates (renamed from Compliance)
                _PrettyProductInsightsSection(viewModel: viewModel)
                
                // Usage info with soft cards
                _PrettyUsageInfo(viewModel: viewModel)
                
                // Beauty Journey preview (renamed from Usage Journey)
                _PrettyBeautyJourneySection(viewModel: viewModel)
                
                // Reviews with girly theme - full width
                reviewsSection
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
            
            // Only show edit button if product is not finished
            if (!viewModel.isEditingDisabled) {
                Button {
                    prepareEditSheet()
                    showEditSheet = true
                } label: { Label("Edit", systemImage: "pencil") }
            }
            
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
        // Do minimal work here - just show the sheet immediately
        // All data preparation will happen in ProductEditView.onAppear
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
            SimpleProductEditView(
                viewModel: viewModel,
                isPresented: $showEditSheet
            )
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
    
    // Reviews section
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Reviews")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                // Show loading indicator when fetching reviews
                if viewModel.isLoadingReviews {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // User's own reviews
            if let reviews = viewModel.product.reviews as? Set<Review>, !reviews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Review")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(reviews), id: \.objectID) { review in
                        reviewRow(review)
                    }
                }
                
                // Add divider if there are also community reviews
                if let allReviews = viewModel.allReviewsForProduct, !allReviews.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                }
            }
            
            // Community reviews from all users
            if let allReviews = viewModel.allReviewsForProduct, !allReviews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Community Reviews (\(allReviews.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(allReviews) { review in
                        reviewRow(review)
                    }
                }
            } else if !viewModel.isLoadingReviews && viewModel.allReviewsForProduct?.isEmpty == true {
                Text("No community reviews yet for this product")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Show review form button or message based on product state
            if !viewModel.hasUserReviewed && viewModel.product.isFinished {
                Button("Write a Review") {
                    viewModel.showReviewForm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("LushyPrimary"))
            } else if !viewModel.hasUserReviewed && !viewModel.product.isFinished {
                Text("Finish this product to write a review")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color("lushyBackground"))
        .cornerRadius(12)
    }
    
    // Helper function to display review rows for both user reviews and backend reviews
    @ViewBuilder
    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                // Date
                if let date = review.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Review title
            if let title = review.title, !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Review text
            if let text = review.text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    @ViewBuilder
    private func reviewRow(_ review: BackendReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // User info for community reviews
                if let user = review.user {
                    HStack(spacing: 6) {
                        // Profile image placeholder
                        Circle()
                            .fill(Color.lushyPink.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.lushyPink)
                            )
                        
                        Text(user.name)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                // Date
                Text(review.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Review title
            if !review.title.isEmpty {
                Text(review.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Review text
            if !review.text.isEmpty {
                Text(review.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// Create prettier components for product detail

// MARK: - Pretty Product Header
struct _PrettyProductHeader: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Product image with favorite heart in top-right corner
            ZStack(alignment: .topTrailing) {
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
                
                // Favorite heart button in top-right corner
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.toggleFavorite()
                }) {
                    ZStack {
                        if viewModel.isFavoriteLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: viewModel.isFavorited ? "heart.fill" : "heart")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(viewModel.isFavorited ? .lushyPink : .gray)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
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
                
                // Display metadata as styled tags with improved logic
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
                            .background(Color("mossGreen", bundle: nil).opacity(0.2))
                            .foregroundColor(Color("mossGreen", bundle: nil))
                            .cornerRadius(12)
                    }
                    // Travel-size-friendly tag for products less than 100ml
                    if viewModel.product.sizeInMl > 0 && viewModel.product.sizeInMl < 100 {
                        Text("Travel-Size-Friendly")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.mossGreen.opacity(0.2))
                            .foregroundColor(.mossGreen)
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
                    // Add quantity display
                    if viewModel.product.quantity > 1 {
                        Text("Qty: \(viewModel.product.quantity)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPink.opacity(0.2))
                            .foregroundColor(.lushyPink)
                            .cornerRadius(12)
                    }
                }
                
                // Certification tags (Vegan, Cruelty-Free)
                HStack(spacing: 8) {
                    if viewModel.product.vegan {
                        Text("Vegan")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                    }
                    if viewModel.product.crueltyFree {
                        Text("Cruelty-Free")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
                
                // Best Before countdown (updated from Expiry)
                if let days = viewModel.daysUntilExpiry {
                    Text(days > 0 ? "Best before \(days) days" : "Past best before date")
                        .font(.subheadline)
                        .foregroundColor(days > 7 ? .green : (days > 0 ? .orange : .red))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Pretty Product Insights Section
private struct _PrettyProductInsightsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.mossGreen)
                Text("Product Insights & Dates")
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
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20))
                    .foregroundColor(.lushyPink)
                Text("Usage Tracking")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            // Enhanced usage tracking interface
            UsageTrackingView(usageViewModel: viewModel.usageTrackingViewModel)
                .padding(.horizontal)
        }
    }
}

// MARK: - Pretty Action Buttons
struct _PrettyActionButtons: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            // Mark as Finished Button (only show if product is not finished)
            if !viewModel.product.isFinished {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.markAsEmpty()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Mark as Finished")
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
                                LinearGradient(
                                    colors: [.green, .mossGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
            } else {
                // Show finished status for completed products
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                    Text("Product Finished")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
                        )
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Beauty Journey Section Component
private struct _PrettyBeautyJourneySection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        NavigationLink(destination: UsageJourneyView(product: viewModel.product)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundColor(.lushyPink)
                    Text("Beauty Journey")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Track your experience with this product over time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Journey preview stats
                HStack(spacing: 20) {
                    JourneyStatItem(
                        icon: "calendar",
                        label: "Events",
                        value: "\(journeyEventCount)",
                        color: .mossGreen
                    )
                    
                    JourneyStatItem(
                        icon: "bubble.left.fill",
                        label: "Thoughts",
                        value: "\(thoughtCount)",
                        color: .lushyPeach
                    )
                    
                    JourneyStatItem(
                        icon: "clock",
                        label: "Days",
                        value: "\(daysSincePurchase)",
                        color: .lushyPink
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.lushyPink.opacity(0.05), Color.lushyPurple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var journeyEventCount: Int {
        // Count only meaningful journey events (purchase, open, finish, thoughts)
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", viewModel.product)
        
        let journeyEvents = (try? CoreDataManager.shared.viewContext.count(for: request)) ?? 0
        
        // Add milestone events
        var milestoneCount = 0
        if viewModel.product.purchaseDate != nil { milestoneCount += 1 }
        if viewModel.product.openDate != nil { milestoneCount += 1 }
        if viewModel.product.isFinished { milestoneCount += 1 }
        
        return milestoneCount + journeyEvents
    }
    
    private var thoughtCount: Int {
        // Count only journey events with type "thought"
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@ AND eventType == %@", viewModel.product, "thought")
        return (try? CoreDataManager.shared.viewContext.count(for: request)) ?? 0
    }
    
    private var reviewCount: Int {
        return (viewModel.product.reviews as? Set<Review>)?.count ?? 0
    }
    
    private var daysSincePurchase: Int {
        guard let purchaseDate = viewModel.product.purchaseDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: purchaseDate, to: Date()).day ?? 0
    }
}

struct JourneyStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                // Only show plus button if product is not finished
                if !viewModel.isEditingDisabled {
                    Button(action: {
                        viewModel.fetchBagsAndTags()
                        showBagAssignSheet = true
                    }) { Image(systemName: "plus") }
                }
            }
            if viewModel.bagsForProduct().isEmpty {
                Text("Not in any bag.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.bagsForProduct(), id: \.self) { bag in
                    HStack {
                        // Small/compact view: ALWAYS show icon only, never custom images
                        if let icon = bag.icon, icon.count == 1 {
                            // Emoji icon
                            Text(icon)
                                .font(.system(size: 16))
                        } else {
                            // System icon with bag color
                            Image(systemName: bag.icon ?? "bag.fill")
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                        }
                        Text(bag.name ?? "Unnamed Bag")
                        Spacer()
                        // Only show remove button if product is not finished
                        if !viewModel.isEditingDisabled {
                            Button(action: { viewModel.removeProductFromBag(bag) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
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
                // Only show plus button if product is not finished
                if (!viewModel.isEditingDisabled) {
                    Button(action: {
                        viewModel.fetchBagsAndTags()
                        showTagAssignSheet = true
                    }) { Image(systemName: "plus") }
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
                                // Only show remove button if product is not finished
                                if !viewModel.isEditingDisabled {
                                    Button(action: { viewModel.removeTagFromProduct(tag) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// Separate Bag Assign Sheet
private struct BagAssignSheet: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var isPresented: Bool
    @StateObject private var bagViewModel = BeautyBagViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedBagIDs: Set<NSManagedObjectID> = []
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
                    
                    Text("Select Beauty Bags")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Save") {
                        applyChanges()
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
                                                    // System icon with bag color
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
                                                .font(.system(size: 36))
                                        } else {
                                            // System icon
                                            Image(systemName: bagViewModel.newBagIcon)
                                                .font(.system(size: 36, weight: .medium))
                                                .foregroundColor(Color(bagViewModel.newBagColor))
                                        }
                                    }
                                    .shadow(color: Color(bagViewModel.newBagColor).opacity(0.1), radius: 8, x: 0, y: 4)
                                    
                                    if !bagViewModel.newBagName.isEmpty {
                                        Text(bagViewModel.newBagName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
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
                                                Text(bagViewModel.newBagIcon)
                                                    .font(.system(size: 20))
                                            } else {
                                                Image(systemName: bagViewModel.newBagIcon)
                                                    .font(.system(size: 20))
                                                    .foregroundColor(Color(bagViewModel.newBagColor))
                                            }
                                            
                                            Text("Choose Icon")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
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
        .onAppear {
            selectedBagIDs = Set(viewModel.bagsForProduct().map { $0.objectID })
            bagViewModel.fetchBags()
        }
        .sheet(isPresented: $showingIconSelector) {
            IconSelectorView(selectedIcon: $bagViewModel.newBagIcon, icons: [
                "bag.fill", "case.fill", "suitcase.fill", "backpack.fill",
                "sparkles", "star.fill", "heart.fill", "leaf.fill",
                "💄", "✨", "🌸", "💅", "🎀", "💖", "🌺", "🦋"
            ], onIconSelected: { _ in })
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $bagImage, sourceType: imageSource == .camera ? .camera : .photoLibrary)
        }
    }
    
    private func toggle(_ bag: BeautyBag) {
        if selectedBagIDs.contains(bag.objectID) {
            selectedBagIDs.remove(bag.objectID)
        } else {
            selectedBagIDs.insert(bag.objectID)
        }
    }
    
    private func applyChanges() {
        let current = Set(viewModel.bagsForProduct().map { $0.objectID })
        let toAdd = selectedBagIDs.subtracting(current)
        let toRemove = current.subtracting(selectedBagIDs)
        for id in toAdd { 
            if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? BeautyBag { 
                viewModel.addProductToBag(bag) 
            } 
        }
        for id in toRemove { 
            if let bag = try? CoreDataManager.shared.viewContext.existingObject(with: id) as? BeautyBag { 
                viewModel.removeProductFromBag(bag) 
            } 
        }
    }
}

// Separate Tag Assign Sheet
private struct TagAssignSheet: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var isPresented: Bool
    @State private var selectedTagIDs: Set<NSManagedObjectID> = []
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

// MARK: - Simple Product Edit View (No Freezing)
struct SimpleProductEditView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var isPresented: Bool
    
    // Basic edit fields
    @State private var editName: String = ""
    @State private var editBrand: String = ""
    @State private var editShade: String = ""
    @State private var editSize: String = ""
    @State private var editSpf: String = ""
    @State private var editPrice: String = ""
    @State private var editCurrency: String = "USD"
    @State private var editPurchaseDate: Date = Date()
    @State private var editIsOpened: Bool = false
    @State private var editOpenDate: Date = Date()
    @State private var editPAO: String = ""
    @State private var editIsVegan: Bool = false
    @State private var editIsCrueltyFree: Bool = false
    
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Product Information") {
                    TextField("Product Name", text: $editName)
                    TextField("Brand", text: $editBrand)
                    TextField("Shade", text: $editShade)
                    TextField("Size (ml)", text: $editSize)
                        .keyboardType(.decimalPad)
                    TextField("SPF", text: $editSpf)
                        .keyboardType(.numberPad)
                    
                    HStack {
                        TextField("Price", text: $editPrice)
                            .keyboardType(.decimalPad)
                        Picker("Currency", selection: $editCurrency) {
                            Text("USD").tag("USD")
                            Text("EUR").tag("EUR") 
                            Text("GBP").tag("GBP")
                            Text("NOK").tag("NOK")
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Ethics") {
                    Toggle("Vegan", isOn: $editIsVegan)
                    Toggle("Cruelty-Free", isOn: $editIsCrueltyFree)
                }
                
                Section("Usage Information") {
                    DatePicker("Purchase Date", selection: $editPurchaseDate, displayedComponents: .date)
                    Toggle("Product is opened", isOn: $editIsOpened)
                    
                    if editIsOpened {
                        DatePicker("Open Date", selection: $editOpenDate, displayedComponents: .date)
                    }
                    
                    Picker("Period After Opening", selection: $editPAO) {
                        Text("Not specified").tag("")
                        Text("3 months").tag("3M")
                        Text("6 months").tag("6M")
                        Text("12 months").tag("12M")
                        Text("18 months").tag("18M")
                        Text("24 months").tag("24M")
                        Text("36 months").tag("36M")
                    }
                }
            }
            .navigationTitle("Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(editName.isEmpty || isSaving)
                }
            }
            .onAppear {
                loadCurrentData()
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }
    
    private func loadCurrentData() {
        let product = viewModel.product
        editName = product.productName ?? ""
        editBrand = product.brand ?? ""
        editShade = product.shade ?? ""
        editSize = product.sizeInMl > 0 ? String(format: "%.0f", product.sizeInMl) : ""
        editSpf = product.spf > 0 ? String(product.spf) : ""
        editPrice = product.price > 0 ? String(format: "%.2f", product.price) : ""
        editCurrency = product.currency ?? "USD"
        editPurchaseDate = product.purchaseDate ?? Date()
        editIsOpened = product.openDate != nil
        editOpenDate = product.openDate ?? Date()
        editPAO = product.periodsAfterOpening ?? ""
        editIsVegan = product.vegan
        editIsCrueltyFree = product.crueltyFree
    }
    
    private func saveChanges() {
        guard !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Product name is required"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        let sizeValue = Double(editSize) ?? 0
        let spfValue = Int(editSpf) ?? 0
        let priceValue = Double(editPrice) ?? 0
        
        viewModel.updateDetails(
            productName: editName,
            brand: editBrand.isEmpty ? nil : editBrand,
            shade: editShade.isEmpty ? nil : editShade,
            sizeInMl: sizeValue > 0 ? sizeValue : nil,
            spf: spfValue,
            price: priceValue > 0 ? priceValue : nil,
            currency: editCurrency,
            purchaseDate: editPurchaseDate,
            isOpened: editIsOpened,
            openDate: editIsOpened ? editOpenDate : nil,
            periodsAfterOpening: editPAO.isEmpty ? nil : editPAO,
            vegan: editIsVegan,
            crueltyFree: editIsCrueltyFree,
            newImage: nil
        )
        
        isSaving = false
        isPresented = false
    }
}

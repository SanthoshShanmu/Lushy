import SwiftUI
import CoreData
import Combine

// Comprehensive finished product detail view that's identical to ProductDetailView 
// but excludes interactive sections and shows read-only information
struct FinishedProductDetailView: View {
    let product: UserProduct
    @Environment(\.presentationMode) var presentationMode
    @State private var showUsageJourney = false
    
    // Add state to force refresh when reviews are added
    @State private var reviewsRefreshTrigger = 0
    @State private var refreshedProduct: UserProduct? = nil
    
    // Add usage tracking view model - FIXED: Pass the product parameter
    @StateObject private var usageTrackingViewModel: UsageTrackingViewModel
    
    // Initialize the view model in the init method
    init(product: UserProduct) {
        self.product = product
        self._usageTrackingViewModel = StateObject(wrappedValue: UsageTrackingViewModel(product: product))
    }
    
    var currentProduct: UserProduct {
        refreshedProduct ?? product
    }
    
    // Extracted background gradient to match ProductDetailView
    private var backgroundGradient: LinearGradient {
        let colors: [Color] = [
            Color.lushyPink.opacity(0.1),
            Color.lushyPurple.opacity(0.05),
            Color.white
        ]
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Same dreamy gradient background as ProductDetailView
            backgroundGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Product header with dreamy styling (now with favorite functionality)
                    _FinishedProductHeader(product: currentProduct)
                    
                    // Finished status indicator (replaces action buttons)
                    _FinishedStatusIndicator(product: currentProduct)
                    
                    // Product Insights & Dates (same as regular product view)
                    _FinishedProductInsightsSection(product: currentProduct)
                    
                    // Beauty Journey preview (read-only, same as regular product view)
                    _FinishedBeautyJourneySection(product: currentProduct, showUsageJourney: $showUsageJourney)
                    
                    // Reviews section (read-only, shows user's review and community reviews)
                    _FinishedReviewsSection(product: currentProduct, refreshTrigger: reviewsRefreshTrigger)
                }
                .padding(.bottom, 30)
            }
            .refreshable {
                // Force refresh the product object and reviews when user pulls to refresh
                refreshProduct()
            }
        }
        .navigationTitle("Finished Product")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUsageJourney) {
            UsageJourneyView(product: currentProduct, usageTrackingViewModel: usageTrackingViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Force refresh when Core Data context changes
            refreshProduct()
        }
        .onAppear {
            // Initial refresh to ensure we have the latest data
            refreshProduct()
        }
    }
    
    private func refreshProduct() {
        // Refresh the managed object context to get latest data
        CoreDataManager.shared.viewContext.refresh(product, mergeChanges: true)
        
        // Force a UI update by updating the refresh trigger
        reviewsRefreshTrigger += 1
        
        // Update the refreshed product reference
        refreshedProduct = product
    }
    
    // Utility functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Finished Product Header (now with favorite functionality)
struct _FinishedProductHeader: View {
    let product: UserProduct
    @StateObject private var favoriteService = ProductFavoriteService.shared
    @State private var isFavorited = false
    @State private var favoriteCount = 0
    @State private var isFavoriteLoading = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Product image with favorite heart in top-right corner (FIXED: positioned like regular ProductDetailView)
            ZStack(alignment: .topTrailing) {
                if let imageUrl = product.imageUrl {
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
                
                // Favorite heart button in top-right corner (FIXED: positioned outside image like regular ProductDetailView)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    toggleFavorite()
                }) {
                    ZStack {
                        if isFavoriteLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(isFavorited ? .lushyPink : .gray)
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
                Text(product.brand ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPurple)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Text(product.productName ?? "Unnamed Product")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Display metadata as styled tags
                HStack(spacing: 8) {
                    if let shade = product.shade, !shade.isEmpty {
                        Text(shade)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPurple.opacity(0.2))
                            .foregroundColor(.lushyPurple)
                            .cornerRadius(12)
                    }
                    if let size = product.size, !size.isEmpty {
                        Text("\(size)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color("mossGreen", bundle: nil).opacity(0.2))
                            .foregroundColor(Color("mossGreen", bundle: nil))
                            .cornerRadius(12)
                    }
                    if let spf = product.spf, !spf.isEmpty {
                        Text("SPF \(spf)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPeach.opacity(0.2))
                            .foregroundColor(.lushyPeach)
                            .cornerRadius(12)
                    }
                }
                
                // Certification tags (Vegan, Cruelty-Free)
                HStack(spacing: 8) {
                    if product.vegan {
                        Text("Vegan")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                    }
                    if product.crueltyFree {
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
            }
            .padding(.horizontal)
        }
        .onAppear {
            loadFavoriteStatus()
        }
    }
    
    private func loadFavoriteStatus() {
        guard let barcode = product.barcode,
              let userId = AuthService.shared.userId else { return }
        
        favoriteService.getFavoriteStatus(barcode: barcode, userId: userId)
            .sink { completion in
                if case .failure = completion {
                    // Handle error silently for finished products
                }
            } receiveValue: { [self] response in
                DispatchQueue.main.async {
                    self.isFavorited = response.data.isFavorited
                    self.favoriteCount = response.data.favoriteCount
                }
            }
            .store(in: &cancellables)
    }
    
    private func toggleFavorite() {
        guard let barcode = product.barcode,
              let userId = AuthService.shared.userId else { return }
        
        isFavoriteLoading = true
        
        favoriteService.toggleFavorite(barcode: barcode, userId: userId)
            .sink { completion in
                DispatchQueue.main.async {
                    self.isFavoriteLoading = false
                    if case .failure = completion {
                        // Handle error silently for finished products
                    }
                }
            } receiveValue: { [self] response in
                DispatchQueue.main.async {
                    self.isFavoriteLoading = false
                    self.isFavorited = response.data.product.isFavorited
                    self.favoriteCount = response.data.product.favoriteCount
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Finished Status Indicator (replaces action buttons)
struct _FinishedStatusIndicator: View {
    let product: UserProduct
    
    var body: some View {
        VStack(spacing: 15) {
            // Finished status indicator
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
                Text("Product Finished")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                if let finishDate = product.finishDate {
                    Text("on \(DateFormatter.mediumDate.string(from: finishDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
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
        .padding(.horizontal)
    }
}

// MARK: - Finished Product Insights Section (identical to regular view)
private struct _FinishedProductInsightsSection: View {
    let product: UserProduct
    
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
                if let purchase = product.purchaseDate {
                    HStack {
                        Text("Purchased:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateString(purchase))
                    }
                }
                if let open = product.openDate {
                    HStack {
                        Text("Opened:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateString(open))
                    }
                }
                if let finish = product.finishDate {
                    HStack {
                        Text("Finished:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateString(finish))
                    }
                }
                if let pao = product.periodsAfterOpening, !pao.isEmpty {
                    HStack {
                        Text("PAO:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(pao)
                    }
                }
                
                // Usage summary
                if product.timesUsed > 0 {
                    HStack {
                        Text("Times Used:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(product.timesUsed)")
                    }
                }
                
                // Usage duration
                if let openDate = product.openDate, let finishDate = product.finishDate {
                    let days = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
                    HStack {
                        Text("Usage Duration:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(usageDurationText(days: days))
                    }
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
    
    private func usageDurationText(days: Int) -> String {
        if days < 7 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s")"
        }
    }
}

// MARK: - Finished Beauty Journey Section (read-only, identical to regular view)
private struct _FinishedBeautyJourneySection: View {
    let product: UserProduct
    @Binding var showUsageJourney: Bool
    
    var body: some View {
        Button(action: {
            showUsageJourney = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundColor(.lushyPink)
                    Text("Usage Journey")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("View your complete experience with this finished product")
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
        .padding(.horizontal)
    }
    
    // FIXED: Use lazy computation and force refresh to ensure accurate count
    private var journeyEventCount: Int {
        // Force context refresh to ensure we have latest data
        CoreDataManager.shared.viewContext.refreshAllObjects()
        
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        
        let journeyEvents = (try? CoreDataManager.shared.viewContext.count(for: request)) ?? 0
        
        // Count usage entries (which also appear in the timeline)
        let usageEntries = CoreDataManager.shared.fetchUsageEntries(for: product.objectID)
        let usageEntryCount = usageEntries.count
        
        // Create initial events if they don't exist (similar to UsageJourneyViewModel)
        DispatchQueue.main.async {
            self.ensureInitialEventsExist()
        }
        
        return journeyEvents + usageEntryCount
    }
    
    // Helper to ensure initial events are created (matching UsageJourneyViewModel logic)
    private func ensureInitialEventsExist() {
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        
        let existingEvents = (try? context.fetch(request)) ?? []
        
        // Create purchase event if needed
        if let purchaseDate = product.purchaseDate,
           !existingEvents.contains(where: { $0.eventType == "purchase" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .purchase,
                text: nil,
                title: nil,
                rating: 0,
                date: purchaseDate
            )
        }
        
        // Create open event if needed
        if let openDate = product.openDate,
           !existingEvents.contains(where: { $0.eventType == "open" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .open,
                text: nil,
                title: nil,
                rating: 0,
                date: openDate
            )
        }
        
        // Create finished event if needed
        if product.isFinished,
           !existingEvents.contains(where: { $0.eventType == "finished" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .finished,
                text: nil,
                title: nil,
                rating: 0,
                date: product.finishDate ?? Date()
            )
        }
    }
    
    private var thoughtCount: Int {
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@ AND eventType == %@", product, "thought")
        return (try? CoreDataManager.shared.viewContext.count(for: request)) ?? 0
    }
    
    private var daysSincePurchase: Int {
        guard let purchaseDate = product.purchaseDate else { return 0 }
        let endDate = product.finishDate ?? Date()
        return Calendar.current.dateComponents([.day], from: purchaseDate, to: endDate).day ?? 0
    }
}

// MARK: - Finished Reviews Section (read-only with community reviews)
private struct _FinishedReviewsSection: View {
    let product: UserProduct
    let refreshTrigger: Int
    
    // Add @State to track refreshed product and community reviews
    @State private var refreshedProduct: UserProduct?
    @State private var allReviewsForProduct: [BackendReview]? = nil
    @State private var isLoadingReviews = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Reviews")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                // Show loading indicator when fetching reviews
                if isLoadingReviews {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Use refreshed product if available, otherwise use original
            let currentProduct = refreshedProduct ?? product
            let currentUserId = AuthService.shared.userId
            
            // FIXED: Check for user's reviews in BOTH local Core Data AND backend reviews
            let userHasLocalReview = (currentProduct.reviews as? Set<Review>)?.isEmpty == false
            // FIXED: Simplified and more robust user ID matching for backend reviews
            let userHasBackendReview = allReviewsForProduct?.contains { review in
                guard let userId = currentUserId, let reviewUserId = review.user?.id else { return false }
                // Simple direct comparison - both should be ObjectId strings
                return reviewUserId == userId
            } ?? false
            let userHasAnyReview = userHasLocalReview || userHasBackendReview
            
            // User's own reviews section - show if user has ANY review (local OR backend)
            if userHasAnyReview {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Review")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    // Show local Core Data reviews first
                    if let reviews = currentProduct.reviews as? Set<Review>, !reviews.isEmpty {
                        ForEach(Array(reviews), id: \.objectID) { review in
                            reviewRow(review)
                        }
                    }
                    
                    // Show backend reviews from current user if no local reviews
                    if !userHasLocalReview, let allReviews = allReviewsForProduct {
                        let userBackendReviews = allReviews.filter { review in
                            guard let userId = currentUserId, let reviewUserId = review.user?.id else { return false }
                            // Use the same simple direct comparison
                            return reviewUserId == userId
                        }
                        
                        ForEach(userBackendReviews) { review in
                            reviewRow(review)
                        }
                    }
                }
                
                // Add divider if there are also community reviews from other users
                if let allReviews = allReviewsForProduct, 
                   let currentUserId = currentUserId,
                   allReviews.contains(where: { $0.user?.id != currentUserId }) {
                    Divider()
                        .padding(.vertical, 8)
                }
            }
            
            // Community reviews from OTHER users ONLY
            if let allReviews = allReviewsForProduct, !allReviews.isEmpty {
                let otherUsersReviews = allReviews.filter { review in
                    guard let userId = currentUserId, let reviewUserId = review.user?.id else { return true }
                    // Use simple direct comparison - exclude current user's reviews
                    return reviewUserId != userId
                }
                
                if !otherUsersReviews.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Community Reviews (\(otherUsersReviews.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(otherUsersReviews) { review in
                            reviewRow(review)
                        }
                    }
                }
            }
            
            // FIXED: Only show "No review written" if user has NO reviews anywhere
            if !userHasAnyReview && !isLoadingReviews {
                Text("No review written for this finished product")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Show community reviews empty state only if no other users have reviewed
            if let allReviews = allReviewsForProduct, !allReviews.isEmpty {
                let currentUserId = AuthService.shared.userId
                let otherUsersReviews = allReviews.filter { review in
                    guard let currentUserId = currentUserId else { return true }
                    return review.user?.id != currentUserId
                }
                
                if otherUsersReviews.isEmpty && !isLoadingReviews {
                    Text("No community reviews yet for this product")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            } else if !isLoadingReviews && allReviewsForProduct?.isEmpty == true {
                Text("No community reviews yet for this product")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color("lushyBackground"))
        .cornerRadius(12)
        .padding(.horizontal)
        .onAppear {
            refreshProductData()
            loadAllReviews()
        }
        .onChange(of: refreshTrigger) {
            refreshProductData()
            loadAllReviews()
        }
    }
    
    private func refreshProductData() {
        // Refresh the product from Core Data to get latest relationships
        DispatchQueue.main.async {
            do {
                let context = CoreDataManager.shared.viewContext
                // Re-fetch the product to ensure we have the latest data
                if let refreshed = try? context.existingObject(with: product.objectID) as? UserProduct {
                    // Force refresh of the reviews relationship
                    context.refresh(refreshed, mergeChanges: true)
                    self.refreshedProduct = refreshed
                    print("✅ Refreshed finished product data - Reviews count: \((refreshed.reviews as? Set<Review>)?.count ?? 0)")
                }
            }
        }
    }
    
    private func loadAllReviews() {
        guard let barcode = product.barcode, !barcode.isEmpty else {
            print("❌ Cannot load reviews: Product has no barcode")
            return
        }
        
        // Prevent multiple concurrent loading calls
        guard !isLoadingReviews else {
            print("⚠️ Review loading already in progress, skipping")
            return
        }
        
        isLoadingReviews = true
        print("🔄 Loading all reviews for finished product with barcode: \(barcode)")
        
        APIService.shared.getAllReviewsForProduct(barcode: barcode)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoadingReviews = false
                    switch completion {
                    case .failure(let error):
                        print("❌ Failed to load reviews for finished product: \(error)")
                        self.allReviewsForProduct = []
                    case .finished:
                        break
                    }
                },
                receiveValue: { reviews in
                    self.allReviewsForProduct = reviews
                    print("✅ Loaded \(reviews.count) community reviews for finished product")
                }
            )
            .store(in: &cancellables)
    }
    
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

#Preview {
    let context = CoreDataManager.shared.viewContext
    let sampleProduct = UserProduct(context: context)
    sampleProduct.productName = "Sample Finished Product"
    sampleProduct.brand = "Sample Brand"
    sampleProduct.isFinished = true
    sampleProduct.finishDate = Date()
    sampleProduct.purchaseDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())
    sampleProduct.openDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())
    
    return FinishedProductDetailView(product: sampleProduct)
}
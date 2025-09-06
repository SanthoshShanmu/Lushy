import SwiftUI

struct AllProductsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @StateObject private var allProductsViewModel = AllProductsViewModel()
    @State private var selectedTags: Set<ProductTag> = []
    @State private var wishlistMessage: String?
    @State private var showingWishlistAlert = false
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.08),
                    Color.lushyPurple.opacity(0.04),
                    Color.lushyCream.opacity(0.3),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header section
                    headerSection
                    
                    // Products grid
                    if allProductsViewModel.filteredProducts.isEmpty {
                        emptyStateView
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(allProductsViewModel.filteredProducts) { summary in
                                // Check if viewing own profile or another user's profile
                                if viewModel.isViewingOwnProfile {
                                    // For own profile, try to find the local UserProduct first
                                    if let localProduct = CoreDataManager.shared.fetchUserProduct(backendId: summary.id) {
                                        // Use full ProductDetailView for owned products with complete Core Data object
                                        NavigationLink(destination: ProductDetailView(viewModel: ProductDetailViewModel(product: localProduct))) {
                                            AllProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                                        }
                                    } else {
                                        // Fallback to GeneralProductDetailView if Core Data object not found
                                        NavigationLink(destination: GeneralProductDetailView(userId: viewModel.targetUserId, productId: summary.id)) {
                                            AllProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                                        }
                                    }
                                } else {
                                    // For other users' profiles, use general product detail view
                                    NavigationLink(destination: GeneralProductDetailView(userId: viewModel.targetUserId, productId: summary.id)) {
                                        AllProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Filter by Tags") {
                        Button("Clear All Filters", action: {
                            selectedTags.removeAll()
                            allProductsViewModel.setTagFilters([])
                        })
                        .disabled(selectedTags.isEmpty)
                        
                        ForEach(allProductsViewModel.allTags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                                allProductsViewModel.setTagFilters(Array(selectedTags))
                            }) {
                                HStack {
                                    Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedTags.contains(tag) ? .lushyPink : .secondary)
                                    Circle()
                                        .fill(Color(tag.color ?? "lushyPink"))
                                        .frame(width: 12, height: 12)
                                    Text(tag.name ?? "Unnamed Tag")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                        if !selectedTags.isEmpty {
                            Text("\(selectedTags.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.lushyPink)
                                .clipShape(Circle())
                        }
                    }
                    .foregroundColor(.lushyPink)
                }
            }
        }
        .onAppear {
            // Set the products from the parent view model
            if let products = viewModel.profile?.products {
                allProductsViewModel.setProducts(products)
            }
            allProductsViewModel.fetchAllTags()
        }
        .alert("Wishlist", isPresented: $showingWishlistAlert) {
            Button("OK") { wishlistMessage = nil }
        } message: {
            Text(wishlistMessage ?? "")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Products")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.lushyPink, .lushyPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("\(allProductsViewModel.filteredProducts.count) product\(allProductsViewModel.filteredProducts.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Active filters indicator
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 10, height: 10)
                                Text(tag.name ?? "Tag")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    selectedTags.remove(tag)
                                    allProductsViewModel.setTagFilters(Array(selectedTags))
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(tag.color ?? "lushyPink").opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.lushyPink.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Products Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPink)
                
                if !selectedTags.isEmpty {
                    Text("Try removing some filters or select different tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No products available in this collection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 40)
    }
}

// MARK: - All Product Card
struct AllProductCard: View {
    let product: UserProductSummary
    var viewModel: UserProfileViewModel
    @Binding var wishlistMessage: String?
    @Binding var showingWishlistAlert: Bool

    // Computed property for wishlist status
    private var isAdded: Bool {
        viewModel.addedWishlistIds.contains(product.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Product image section
            ZStack {
                // Background gradient for image area
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.1),
                        Color.lushyPurple.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Product image - now uses imageUrl from UserProductSummary
                if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        VStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 100)
                    .clipped()
                } else {
                    // Fallback when no image URL is available
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundColor(.lushyPink.opacity(0.6))
                        
                        Text("No Image")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                }
            }
            .frame(height: 100)
            .cornerRadius(12, corners: [.topLeft, .topRight])
            
            // Product info section
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    if let brand = product.brand {
                        Text(brand.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.lushyPurple)
                            .tracking(0.5)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Wishlist button for other users' profiles
                if !viewModel.isViewingOwnProfile {
                    Button(action: {
                        guard !isAdded else { return }
                        viewModel.addProductToWishlist(productId: product.id) { result in
                            switch result {
                            case .success:
                                wishlistMessage = "Added to wishlist! 💕"
                            case .failure(let error):
                                wishlistMessage = error.localizedDescription
                            }
                            showingWishlistAlert = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                            Text(isAdded ? "Added" : "Add to Wishlist")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(isAdded)
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.lushyPink.opacity(0.2), Color.lushyPurple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - All Products View Model
class AllProductsViewModel: ObservableObject {
    @Published var allProducts: [UserProductSummary] = []
    @Published var filteredProducts: [UserProductSummary] = []
    @Published var allTags: [ProductTag] = []
    @Published var selectedTags: [ProductTag] = []
    
    func setProducts(_ products: [UserProductSummary]) {
        // Filter out finished products
        let activeProducts = products.filter { !($0.isFinished == true) }
        self.allProducts = activeProducts
        self.filteredProducts = activeProducts
    }
    
    func fetchAllTags() {
        allTags = CoreDataManager.shared.fetchProductTags()
    }
    
    func setTagFilters(_ tags: [ProductTag]) {
        selectedTags = tags
        filterProducts()
    }
    
    private func filterProducts() {
        if selectedTags.isEmpty {
            filteredProducts = allProducts
        } else {
            // Filter products that have ANY of the selected tags (OR logic)
            var taggedProductIds: Set<String> = []
            
            for tag in selectedTags {
                let localTaggedProductIds = CoreDataManager.shared.products(withTag: tag).compactMap { $0.backendId }
                taggedProductIds.formUnion(localTaggedProductIds)
            }
            
            filteredProducts = allProducts.filter { taggedProductIds.contains($0.id) }
        }
    }
}
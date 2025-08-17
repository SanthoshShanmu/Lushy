import SwiftUI

struct AllProductsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    @StateObject private var allProductsViewModel = AllProductsViewModel()
    @State private var selectedTag: ProductTag?
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
                                // Create a local UserProduct for navigation
                                let localProduct: UserProduct = {
                                    if let existing = CoreDataManager.shared.fetchUserProduct(backendId: summary.id) {
                                        return existing
                                    } else {
                                        let context = CoreDataManager.shared.viewContext
                                        let stub = UserProduct(context: context)
                                        stub.backendId = summary.id
                                        stub.productName = summary.name
                                        stub.brand = summary.brand
                                        stub.userId = viewModel.currentUserId
                                        try? context.save()
                                        return stub
                                    }
                                }()
                                NavigationLink(destination: ProductDetailView(viewModel: ProductDetailViewModel(product: localProduct))) {
                                    AllProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("All Products")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Filter by Tag") {
                        Button("All Tags", action: { selectedTag = nil; allProductsViewModel.setTagFilter(nil) })
                        ForEach(allProductsViewModel.allTags, id: \.self) { tag in
                            Button(action: { 
                                selectedTag = tag
                                allProductsViewModel.setTagFilter(tag) 
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color(tag.color ?? "lushyPink"))
                                        .frame(width: 12, height: 12)
                                    Text(tag.name ?? "Unnamed Tag")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
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
                    Text("💄 All Products")
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
            
            // Active filter indicator
            if let selectedTag = selectedTag {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(selectedTag.color ?? "lushyPink"))
                            .frame(width: 12, height: 12)
                        Text("Filtered by: \(selectedTag.name ?? "Tag")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            self.selectedTag = nil
                            allProductsViewModel.setTagFilter(nil)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(selectedTag.color ?? "lushyPink").opacity(0.1))
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding(.horizontal)
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
                
                if selectedTag != nil {
                    Text("Try removing the filter or select a different tag")
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
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
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
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isAdded)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.lushyMint.opacity(0.1),
                            Color.lushyCream.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }
}

// MARK: - All Products View Model
class AllProductsViewModel: ObservableObject {
    @Published var allProducts: [UserProductSummary] = []
    @Published var filteredProducts: [UserProductSummary] = []
    @Published var allTags: [ProductTag] = []
    @Published var selectedTag: ProductTag?
    
    func setProducts(_ products: [UserProductSummary]) {
        // Filter out finished products
        let activeProducts = products.filter { !($0.isFinished == true) }
        self.allProducts = activeProducts
        self.filteredProducts = activeProducts
    }
    
    func fetchAllTags() {
        allTags = CoreDataManager.shared.fetchProductTags()
    }
    
    func setTagFilter(_ tag: ProductTag?) {
        selectedTag = tag
        filterProducts()
    }
    
    private func filterProducts() {
        if let tag = selectedTag {
            // For tag filtering, we need to check which products have this tag
            // Since we're working with UserProductSummary, we'll need to cross-reference with local data
            let localTaggedProductIds = CoreDataManager.shared.products(withTag: tag).compactMap { $0.backendId }
            filteredProducts = allProducts.filter { localTaggedProductIds.contains($0.id) }
        } else {
            filteredProducts = allProducts
        }
    }
}
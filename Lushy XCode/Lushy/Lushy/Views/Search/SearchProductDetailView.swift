import SwiftUI
import Combine

// Comprehensive product detail view for search results
struct SearchProductDetailView: View {
    let product: ProductSearchSummary
    @StateObject private var viewModel: SearchProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingWishlistAlert = false
    @State private var wishlistMessage: String?
    // Add separate alert state for collection
    @State private var showingCollectionAlert = false
    @State private var collectionMessage: String?
    
    init(product: ProductSearchSummary, currentUserId: String) {
        self.product = product
        self._viewModel = StateObject(wrappedValue: SearchProductDetailViewModel(product: product, currentUserId: currentUserId))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Product Image and Basic Info
                productHeaderSection
                
                // Product Details
                productDetailsSection
                
                // Ethics Information
                ethicsSection
                
                // Actions
                actionsSection
                
                // Users Who Own This Product
                usersWhoOwnSection
            }
            .padding()
        }
        .navigationTitle(product.productName)
        .navigationBarTitleDisplayMode(.large)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.05),
                    Color.lushyPurple.opacity(0.03),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            viewModel.loadUsersWhoOwnProduct()
        }
        .alert("Wishlist", isPresented: $showingWishlistAlert) {
            Button("OK") { wishlistMessage = nil }
        } message: {
            Text(wishlistMessage ?? "")
        }
        // Add separate alert for collection
        .alert("Collection", isPresented: $showingCollectionAlert) {
            Button("OK") { collectionMessage = nil }
        } message: {
            Text(collectionMessage ?? "")
        }
    }
    
    private var productHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Product Image
            HStack {
                Spacer()
                AsyncImage(url: URL(string: product.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 200, height: 200)
                .cornerRadius(16)
                .shadow(radius: 8)
                Spacer()
            }
            
            // Product Name and Brand
            VStack(alignment: .leading, spacing: 8) {
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                Text(product.productName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var productDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Product Details")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.lushyPurple)
            
            VStack(spacing: 12) {
                if !product.barcode.isEmpty {
                    detailRow(label: "Barcode", value: product.barcode)
                }
                
                if let category = product.category, !category.isEmpty {
                    detailRow(label: "Category", value: category.capitalized)
                }
                
                if let shade = product.shade, !shade.isEmpty {
                    detailRow(label: "Shade", value: shade)
                }
                
                if let sizeInMl = product.sizeInMl, sizeInMl > 0 {
                    detailRow(label: "Size", value: "\(String(format: "%.0f", sizeInMl)) ml")
                }
                
                if let spf = product.spf, spf > 0 {
                    detailRow(label: "SPF", value: "\(spf)")
                }
                
                if let pao = product.periodsAfterOpening, !pao.isEmpty {
                    detailRow(label: "Period After Opening", value: pao)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var ethicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ethics & Sustainability")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.lushyPurple)
            
            HStack(spacing: 20) {
                ethicsTag(label: "Vegan", isTrue: product.vegan, icon: "leaf.fill")
                ethicsTag(label: "Cruelty Free", isTrue: product.crueltyFree, icon: "heart.fill")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Add to My Collection
            Button(action: {
                viewModel.addToCollection { result in
                    switch result {
                    case .success:
                        collectionMessage = "Added to your collection! 🎉"
                        showingCollectionAlert = true
                    case .failure(let error):
                        collectionMessage = "Failed to add to collection: \(error.localizedDescription)"
                        showingCollectionAlert = true
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to My Collection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            
            // Add to Wishlist / Remove from Wishlist
            Button(action: {
                if viewModel.isProductInWishlist {
                    // Remove from wishlist
                    viewModel.removeFromWishlist { result in
                        switch result {
                        case .success:
                            wishlistMessage = "Removed from wishlist! 💔"
                            showingWishlistAlert = true
                        case .failure(let error):
                            wishlistMessage = "Failed to remove from wishlist: \(error.localizedDescription)"
                            showingWishlistAlert = true
                        }
                    }
                } else {
                    // Add to wishlist
                    viewModel.addToWishlist { result in
                        switch result {
                        case .success:
                            wishlistMessage = "Added to wishlist! 💕"
                            showingWishlistAlert = true
                        case .failure(let error):
                            wishlistMessage = "Failed to add to wishlist: \(error.localizedDescription)"
                            showingWishlistAlert = true
                        }
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isProductInWishlist ? "heart.slash.fill" : "heart.fill")
                    Text(viewModel.isProductInWishlist ? "Remove from Wishlist" : "Add to Wishlist")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: viewModel.isProductInWishlist ? 
                            [Color.red.opacity(0.6), Color.red.opacity(0.4)] :
                            [Color.mossGreen, Color.lushyCream]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(viewModel.isProductInWishlist ? .white : .lushyPurple)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var usersWhoOwnSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friends who have this product")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.lushyPurple)
            
            if viewModel.isLoadingUsers {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                    Spacer()
                }
                .padding()
            } else if viewModel.usersWhoOwnProduct.isEmpty {
                Text("None of your friends have this product yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.usersWhoOwnProduct, id: \.id) { user in
                        UserRowView(user: user)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func ethicsTag(label: String, isTrue: Bool, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTrue ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
        )
        .foregroundColor(isTrue ? .green : .gray)
    }
}

struct UserRowView: View {
    let user: UserSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image or initials
            if let profileImageUrl = user.profileImage, !profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: "\(APIService.shared.staticBaseURL)\(profileImageUrl)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.lushyPink.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                .scaleEffect(0.7)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.lushyPink.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.name.prefix(1))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.lushyPurple)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
        )
    }
}
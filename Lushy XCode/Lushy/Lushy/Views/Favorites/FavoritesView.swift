import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @State private var showProductDetail = false
    @State private var selectedProductBarcode: String? = nil

    var body: some View {
        ZStack {
            // Dreamy gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.1),
                    Color.lushyPurple.opacity(0.05),
                    Color.lushyCream.opacity(0.3),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationView {
                ScrollView {
                    if viewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                .scaleEffect(1.5)
                            Text("Loading your favorites...")
                                .font(.subheadline)
                                .foregroundColor(.lushyPink)
                        }
                        .padding(.top, 60)
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.lushyPink.opacity(0.6))
                            Text("Failed to Load Favorites")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.lushyPurple)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 60)
                    } else if viewModel.favoriteProducts.isEmpty {
                        VStack(spacing: 24) {
                            // Beautiful empty state
                            VStack(spacing: 16) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.lushyPink, .lushyPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("No Favorites Yet")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.lushyPurple)
                                
                                Text("Heart products you love to see them here! ✨")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 32)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.lushyPink.opacity(0.3), .lushyPurple.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .shadow(color: .lushyPink.opacity(0.1), radius: 20, x: 0, y: 10)
                        }
                        .padding(.top, 60)
                        .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 20) {
                            // Header with count
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("💖 Your Favorites")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.lushyPink, .lushyPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("\(viewModel.favoriteProducts.count) beloved product\(viewModel.favoriteProducts.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            // Beautiful product grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 20) {
                                ForEach(viewModel.favoriteProducts) { product in
                                    BackendFavoriteCard(product: product)
                                        .onTapGesture {
                                            selectedProductBarcode = product.product.barcode
                                            showProductDetail = true
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Section("Filter by Bag") {
                                Button("All Bags", action: { viewModel.setBagFilter(nil) })
                                ForEach(viewModel.allBags, id: \.self) { bag in
                                    Button(action: { viewModel.setBagFilter(bag) }) {
                                        Label(bag.name ?? "Unnamed Bag", systemImage: bag.icon ?? "bag.fill")
                                    }
                                }
                            }

                            Section("Filter by Tag") {
                                Button("All Tags", action: { viewModel.setTagFilter(nil) })
                                ForEach(viewModel.allTags, id: \.self) { tag in
                                    Button(action: { viewModel.setTagFilter(tag) }) {
                                        Label(tag.name ?? "Unnamed Tag", systemImage: "tag")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.lushyPink)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(.lushyPink.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .onAppear {
                    viewModel.fetchFavorites()
                }
                .navigationDestination(isPresented: $showProductDetail) {
                    if let barcode = selectedProductBarcode {
                        GeneralProductDetailView(userId: AuthService.shared.userId ?? "", productId: barcode)
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Favorite Card
struct EnhancedFavoriteCard: View {
    let product: UserProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Product Image with heart overlay
            ZStack(alignment: .topTrailing) {
                if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                    // Try local file first
                    let fileURL = URL(fileURLWithPath: imageUrl)
                    if FileManager.default.fileExists(atPath: fileURL.path),
                       let uiImage = UIImage(contentsOfFile: fileURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    } else if let remoteURL = URL(string: imageUrl) {
                        AsyncImage(url: remoteURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            productPlaceholder
                        }
                        .frame(height: 120)
                        .clipped()
                    } else {
                        productPlaceholder
                    }
                } else {
                    productPlaceholder
                }
                
                // Favorite heart indicator
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.lushyPink)
                            .shadow(color: .lushyPink.opacity(0.4), radius: 4, x: 0, y: 2)
                    )
                    .padding(12)
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 8) {
                // Brand
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.lushyPurple)
                        .tracking(0.5)
                }
                
                // Product Name
                Text(product.productName ?? "Unnamed Product")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Tags and metadata
                HStack(spacing: 6) {
                    if let shade = product.shade, !shade.isEmpty {
                        Text(shade)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.lushyPurple.opacity(0.15))
                            .foregroundColor(.lushyPurple)
                            .cornerRadius(6)
                    }
                    
                    if let size = product.size, !size.isEmpty {
                        Text(size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Status indicators
                HStack(spacing: 8) {
                    if product.openDate != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "circle.dotted")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Opened")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if product.isFinished {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Finished")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.lushyPink.opacity(0.2), .lushyPurple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .lushyPink.opacity(0.08), radius: 12, x: 0, y: 6)
        .scaleEffect(1.0)
    }
    
    private var productPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [.lushyPink.opacity(0.1), .lushyPurple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.lushyPink.opacity(0.5))
                    Text("No Image")
                        .font(.caption2)
                        .foregroundColor(.lushyPink.opacity(0.7))
                }
            )
    }
}

// MARK: - Backend Favorite Card for new favorites system
struct BackendFavoriteCard: View {
    let product: UserFavoritesResponse.FavoriteProductSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Product Image with heart overlay and favorite count
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: product.product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    productPlaceholder
                }
                .frame(height: 120)
                .clipped()
                
                // Favorite heart indicator with count
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.lushyPink)
                                .shadow(color: .lushyPink.opacity(0.4), radius: 4, x: 0, y: 2)
                        )
                    
                    if product.product.favoriteCount > 1 {
                        Text("\(product.product.favoriteCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.lushyPink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.9))
                            )
                    }
                }
                .padding(12)
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 8) {
                // Brand
                if let brand = product.product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.lushyPurple)
                        .tracking(0.5)
                }
                
                // Product Name
                Text(product.product.productName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Instance count and tags
                HStack(spacing: 6) {
                    if product.totalInstances > 1 {
                        Text("\(product.totalInstances) owned")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.mossGreen.opacity(0.15))
                            .foregroundColor(.mossGreen)
                            .cornerRadius(6)
                    }
                    
                    // Show first tag if available
                    if let firstTag = product.tags.first {
                        let tagColor = Color.fromHex(firstTag.color)
                        let backgroundColor = tagColor.opacity(0.15)
                        
                        Text(firstTag.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(backgroundColor)
                            .foregroundColor(tagColor)
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
                
                // Status indicators
                HStack(spacing: 8) {
                    if product.openDate != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "circle.dotted")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Opened")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if product.isFinished {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Finished")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
                
                // Ethics badges
                HStack(spacing: 6) {
                    if product.product.vegan {
                        HStack(spacing: 2) {
                            Image(systemName: "leaf.fill")
                                .font(.caption2)
                            Text("Vegan")
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    }
                    
                    if product.product.crueltyFree {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text("CF")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.lushyPink.opacity(0.2), .lushyPurple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .lushyPink.opacity(0.08), radius: 12, x: 0, y: 6)
    }
    
    private var productPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [.lushyPink.opacity(0.1), .lushyPurple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.lushyPink.opacity(0.5))
                    Text("No Image")
                        .font(.caption2)
                        .foregroundColor(.lushyPink.opacity(0.7))
                }
            )
    }
}

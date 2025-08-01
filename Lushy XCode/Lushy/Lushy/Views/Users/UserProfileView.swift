import SwiftUI

struct UserProfileView: View {
    @StateObject var viewModel: UserProfileViewModel
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
            
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                        .scaleEffect(1.5)
                    Text("Loading profile...")
                        .font(.subheadline)
                        .foregroundColor(.lushyPink)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.lushyPink.opacity(0.6))
                    Text("Profile Unavailable")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.lushyPink)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else if let profile = viewModel.profile {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        ProfileHeaderView(profile: profile, viewModel: viewModel)
                        
                        // Stats Section (customized)
                        HStack(spacing: 30) {
                            // Followers
                            if viewModel.isViewingOwnProfile {
                                NavigationLink(destination: FollowersListView(followers: profile.followers ?? [], currentUserId: viewModel.currentUserId)) {
                                    StatItem(
                                        icon: "heart.fill",
                                        count: profile.followers?.count ?? 0,
                                        label: "Followers",
                                        color: .lushyPink
                                    )
                                }
                            } else {
                                StatItem(
                                    icon: "heart.fill",
                                    count: profile.followers?.count ?? 0,
                                    label: "Followers",
                                    color: .lushyPink
                                )
                            }

                            // Following
                            if viewModel.isViewingOwnProfile {
                                NavigationLink(destination: FollowingListView(following: profile.following ?? [], currentUserId: viewModel.currentUserId)) {
                                    StatItem(
                                        icon: "person.2.fill",
                                        count: profile.following?.count ?? 0,
                                        label: "Following",
                                        color: .lushyPurple
                                    )
                                }
                            } else {
                                StatItem(
                                    icon: "person.2.fill",
                                    count: profile.following?.count ?? 0,
                                    label: "Following",
                                    color: .lushyPurple
                                )
                            }

                            // Bags
                            StatItem(
                                icon: "bag.fill",
                                count: viewModel.bags.count,
                                label: "Bags",
                                color: .lushyMint
                            )
                        }
                        .padding(.horizontal)
                        
                        // Favorites Section
                        if !viewModel.favorites.isEmpty {
                            FavoritesSection(favorites: viewModel.favorites)
                        }

                        // Beauty Bags Section as horizontal scroll
                        if !viewModel.bags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bag.fill")
                                        .foregroundColor(.lushyPink)
                                    Text("Beauty Bags")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.bags, id: \.id) { bagSummary in
                                            let bagView = Group {
                                                if viewModel.isViewingOwnProfile,
                                                   let cdBag = CoreDataManager.shared.fetchBeautyBags().first(where: {
                                                       $0.backendId == bagSummary.id ||
                                                       $0.objectID.uriRepresentation().absoluteString == bagSummary.id
                                                   }) {
                                                    NavigationLink(destination: BeautyBagDetailView(bag: cdBag)) {
                                                        BagCard(bag: bagSummary)
                                                    }
                                                } else {
                                                    BagCard(bag: bagSummary)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .contextMenu {
                                                if viewModel.isViewingOwnProfile {
                                                    Button(role: .destructive) {
                                                        viewModel.deleteBag(summary: bagSummary)
                                                    } label: {
                                                        Label("Delete Bag", systemImage: "trash")
                                                    }
                                                }
                                            }
                                            bagView
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Products Section
                        if let products = profile.products, !products.isEmpty {
                            ProductsSection(products: products, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                        }
                        
                        // Empty state for own profile
                        if viewModel.isViewingOwnProfile && (profile.products?.isEmpty ?? true) && (profile.bags?.isEmpty ?? true) {
                            EmptyProfilePrompt()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Always fetch profile data (including own account)
            viewModel.fetchProfile(force: true)
        }
        .alert("Wishlist", isPresented: $showingWishlistAlert) {
            Button("OK") { wishlistMessage = nil }
        } message: {
            Text(wishlistMessage ?? "")
        }
    }
}

// MARK: - Profile Header Component
struct ProfileHeaderView: View {
    let profile: UserProfile
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture & Name
            VStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.lushyPink.opacity(0.7),
                                Color.lushyPurple.opacity(0.5),
                                Color.lushyMint.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(profile.name.prefix(1).uppercased())
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.lushyPink.opacity(0.3), radius: 12, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    Text(profile.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(profile.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Follow Button (if viewing another user's profile)
            if !viewModel.isViewingOwnProfile {
                Button(action: {
                    viewModel.isFollowing ? viewModel.unfollow() : viewModel.follow()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isFollowing ? "heart.fill" : "heart")
                        Text(viewModel.isFollowing ? "Following" : "Follow")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isFollowing ? .white : .lushyPink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if viewModel.isFollowing {
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.lushyPink, lineWidth: viewModel.isFollowing ? 0 : 2)
                    )
                    .cornerRadius(25)
                    .shadow(color: viewModel.isFollowing ? Color.lushyPink.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isFollowing)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Stats Section
struct StatsSection: View {
    let profile: UserProfile
    
    var body: some View {
        HStack(spacing: 30) {
            StatItem(
                icon: "heart.fill",
                count: profile.followers?.count ?? 0,
                label: "Followers",
                color: .lushyPink
            )
            
            StatItem(
                icon: "person.2.fill",
                count: profile.following?.count ?? 0,
                label: "Following",
                color: .lushyPurple
            )
            
            StatItem(
                icon: "bag.fill",
                count: profile.bags?.count ?? 0,
                label: "Bags",
                color: .lushyMint
            )
        }
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.8))
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Favorites Section
struct FavoritesSection: View {
    let favorites: [UserProductSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.lushyPink)
                Text("Favorites")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(favorites) { product in
                    FavoriteCard(product: product)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}

struct FavoriteCard: View {
    let product: UserProductSummary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundColor(.lushyPink)
            Text(product.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.lushyPink.opacity(0.1), Color.lushyCream.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Beauty Bags Section
struct BeautyBagsSection: View {
    let bags: [BeautyBagSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(.lushyPink)
                Text("Beauty Bags")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(bags) { bag in
                    BagCard(bag: bag)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}

struct BagCard: View {
    let bag: BeautyBagSummary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bag.fill")
                .font(.title2)
                .foregroundColor(.lushyPink)
            
            Text(bag.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.lushyPink.opacity(0.1),
                            Color.lushyPurple.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Products Section
struct ProductsSection: View {
    let products: [UserProductSummary]
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var wishlistMessage: String?
    @Binding var showingWishlistAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.lushyPink)
                Text("Products")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(products) { summary in
                    // Fetch or create a local UserProduct for navigation
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
                        ProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                    }
                 }
             }
         }
         .padding()
         .background(
             RoundedRectangle(cornerRadius: 20)
                 .fill(Color.white.opacity(0.9))
                 .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
         )
     }
}

struct ProductCard: View {
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

// MARK: - Empty Profile Prompt
struct EmptyProfilePrompt: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 50))
                .foregroundColor(.lushyPink.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Start Your Beauty Journey! ✨")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPink)
                
                Text("Add your first product or create a beauty bag to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
}

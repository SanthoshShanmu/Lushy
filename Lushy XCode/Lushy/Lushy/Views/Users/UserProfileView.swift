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
                        
                        // Stats Section (only show for own profile)
                        if viewModel.isViewingOwnProfile {
                            HStack(spacing: 20) {
                                // Followers
                                NavigationLink(destination: FollowersListView(followers: profile.followers ?? [], currentUserId: viewModel.currentUserId)) {
                                    StatItem(
                                        icon: "heart.fill",
                                        count: profile.followers?.count ?? 0,
                                        label: "Followers",
                                        color: .lushyPink
                                    )
                                }

                                // Following
                                NavigationLink(destination: FollowingListView(following: profile.following ?? [], currentUserId: viewModel.currentUserId)) {
                                    StatItem(
                                        icon: "person.2.fill",
                                        count: profile.following?.count ?? 0,
                                        label: "Following",
                                        color: .lushyPurple
                                    )
                                }

                                // Products (active only) - Make clickable
                                NavigationLink(destination: AllProductsView(viewModel: viewModel)) {
                                    StatItem(
                                        icon: "sparkles",
                                        count: viewModel.activeProductsCount,
                                        label: "Products",
                                        color: .mossGreen
                                    )
                                }
                                
                                // Finished Products - Make clickable
                                NavigationLink(destination: FinishedProductsView()) {
                                    StatItem(
                                        icon: "checkmark.circle.fill",
                                        count: viewModel.finishedProductsCount,
                                        label: "Finished",
                                        color: .lushyPeach
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

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
                                            // Use local Core Data bag with imageData instead of summary
                                            if let cdBag = CoreDataManager.shared.fetchBeautyBags().first(where: {
                                                $0.backendId == bagSummary.id ||
                                                $0.objectID.uriRepresentation().absoluteString == bagSummary.id
                                            }) {
                                                Group {
                                                    if viewModel.isViewingOwnProfile {
                                                        NavigationLink(destination: BeautyBagDetailView(bag: cdBag)) {
                                                            LocalBagCard(bag: cdBag)
                                                                .frame(width: 140)
                                                        }
                                                    } else {
                                                        LocalBagCard(bag: cdBag)
                                                            .frame(width: 140)
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
                                            } else {
                                                // Fallback to summary if no local bag found
                                                Group {
                                                    if viewModel.isViewingOwnProfile {
                                                        BagCard(bag: bagSummary)
                                                            .frame(width: 140)
                                                    } else {
                                                        BagCard(bag: bagSummary)
                                                            .frame(width: 140)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                            }
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
    @State private var showingProfileSharing = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Section - Horizontal Layout with Image on Left
            HStack(alignment: .top, spacing: 20) {
                // Profile Image on the Left
                ProfileImageView(profile: profile, viewModel: viewModel)
                
                // Stats and Bio on the Right
                VStack(alignment: .leading, spacing: 16) {
                    // User Name and Username
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("@\(profile.username)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    
                    // Bio Section
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Mini Stats Row (only show for other users' profiles)
                    if !viewModel.isViewingOwnProfile {
                        HStack(spacing: 16) {
                            MiniStatItem(
                                count: profile.followers?.count ?? 0,
                                label: "Followers",
                                color: .lushyPink
                            )
                            
                            MiniStatItem(
                                count: profile.following?.count ?? 0,
                                label: "Following",
                                color: .lushyPurple
                            )
                            
                            MiniStatItem(
                                count: viewModel.activeProductsCount,
                                label: "Products",
                                color: .mossGreen
                            )
                            
                            MiniStatItem(
                                count: viewModel.finishedProductsCount,
                                label: "Finished",
                                color: .lushyPeach
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
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
            } else {
                // Edit Profile and Share Buttons (if viewing own profile)
                HStack(spacing: 12) {
                    // Edit Profile Button
                    NavigationLink(destination: ProfileEditView(currentUser: profile)) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("Edit Profile")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.8))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    
                    // Share Profile Button
                    Button(action: {
                        showingProfileSharing = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("Share")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.lushyPink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.lushyPink.opacity(0.1),
                                            Color.lushyPurple.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.lushyPink.opacity(0.15), radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.lushyPink.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .sheet(isPresented: $showingProfileSharing) {
                        ProfileSharingView()
                    }
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Profile Image Component
struct ProfileImageView: View {
    let profile: UserProfile
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack {
            if let profileImageUrl = profile.profileImage,
               !profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: "\(APIService.shared.staticBaseURL)\(profileImageUrl)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.lushyPink.opacity(0.7),
                                    Color.lushyPurple.opacity(0.5),
                                    Color.mossGreen.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(color: Color.lushyPink.opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                // Default avatar with initials
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.lushyPink.opacity(0.7),
                                Color.lushyPurple.opacity(0.5),
                                Color.mossGreen.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(profile.name.prefix(1).uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.lushyPink.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Mini Stat Item for Compact Display
struct MiniStatItem: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
                color: .mossGreen
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
                    // Use GeneralProductDetailView for all favorite product navigation
                    NavigationLink(destination: GeneralProductDetailView(userId: AuthService.shared.userId ?? "", productId: product.id)) {
                        FavoriteCard(product: product)
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
        VStack(spacing: 0) {
            // Large image/icon section - inspired by collection covers (like ModernBagCard)
            ZStack {
                // Background for the image area
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(bag.color ?? "lushyPink").opacity(0.2),
                                Color(bag.color ?? "lushyPink").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                
                // Large view: show custom image if available, otherwise show icon
                if let imageUrl = bag.image, !imageUrl.isEmpty {
                    // Custom image from camera/photo library - large and prominent
                    AsyncImage(url: URL(string: "\(APIService.shared.staticBaseURL)\(imageUrl)")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Fallback to icon while loading
                        if let icon = bag.icon, icon.count == 1 {
                            Text(icon)
                                .font(.system(size: 32))
                        } else {
                            Image(systemName: bag.icon ?? "bag.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                        }
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    // Icon overlay when no custom image
                    VStack(spacing: 6) {
                        if let icon = bag.icon, icon.count == 1 {
                            // Emoji icon - larger for prominence
                            Text(icon)
                                .font(.system(size: 32))
                        } else {
                            // System icon with bag color - larger and more prominent
                            Image(systemName: bag.icon ?? "bag.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                        }
                    }
                }
            }
            
            // Bottom section with name and description - more compact
            VStack(spacing: 4) {
                Text(bag.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Show description if available - smaller and more subtle
                if let description = bag.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
                
                // Privacy indicator - more subtle
                if bag.isPrivate == true {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Private")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
                
                // Subtle accent line
                Rectangle()
                    .fill(Color(bag.color ?? "lushyPink").opacity(0.3))
                    .frame(width: 20, height: 2)
                    .cornerRadius(1)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .frame(height: bag.description?.isEmpty == false || bag.isPrivate == true ? 160 : 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(bag.color ?? "lushyPink").opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(bag.color ?? "lushyPink").opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Local Bag Card for Core Data BeautyBag objects
struct LocalBagCard: View {
    let bag: BeautyBag
    
    var body: some View {
        VStack(spacing: 0) {
            // Large image/icon section - inspired by collection covers (like ModernBagCard)
            ZStack {
                // Background for the image area
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(bag.color ?? "lushyPink").opacity(0.2),
                                Color(bag.color ?? "lushyPink").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                
                // Large view: show custom image if available, otherwise show icon
                if let imageData = bag.imageData, let customImage = UIImage(data: imageData) {
                    // Custom image from camera/photo library - large and prominent
                    Image(uiImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    // Icon overlay when no custom image
                    VStack(spacing: 6) {
                        if let icon = bag.icon, icon.count == 1 {
                            // Emoji icon - larger for prominence
                            Text(icon)
                                .font(.system(size: 32))
                        } else {
                            // System icon with bag color - larger and more prominent
                            Image(systemName: bag.icon ?? "bag.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                        }
                    }
                }
            }
            
            // Bottom section with name and description - more compact
            VStack(spacing: 4) {
                Text(bag.name ?? "Unnamed Bag")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Show description if available - smaller and more subtle
                if let description = bag.bagDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
                
                // Privacy indicator - more subtle
                if bag.isPrivate {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Private")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
                
                // Subtle accent line
                Rectangle()
                    .fill(Color(bag.color ?? "lushyPink").opacity(0.3))
                    .frame(width: 20, height: 2)
                    .cornerRadius(1)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .frame(height: bag.bagDescription?.isEmpty == false || bag.isPrivate ? 160 : 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(bag.color ?? "lushyPink").opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(bag.color ?? "lushyPink").opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Products Section
struct ProductsSection: View {
    let products: [UserProductSummary]
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var wishlistMessage: String?
    @Binding var showingWishlistAlert: Bool

    // Filter out finished products for main display
    private var activeProducts: [UserProductSummary] {
        return products.filter { !($0.isFinished == true) }
    }
    
    // Show only top 5 most recent products for preview
    private var recentProducts: [UserProductSummary] {
        return Array(activeProducts.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.lushyPink)
                Text("Products")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                // Show "Show All" button if there are more than 5 products
                if activeProducts.count > 5 {
                    NavigationLink(destination: AllProductsView(viewModel: viewModel)) {
                        HStack(spacing: 4) {
                            Text("Show All")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.lushyPink)
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(recentProducts) { summary in
                    ProductNavigationView(
                        summary: summary,
                        viewModel: viewModel,
                        wishlistMessage: $wishlistMessage,
                        showingWishlistAlert: $showingWishlistAlert
                    )
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
    
    // Helper to find local product with multiple lookup strategies
    private func findLocalProduct(for summary: UserProductSummary) -> UserProduct? {
        // Try multiple strategies to find the local product
        
        // Strategy 1: Find by backend ID
        if let localProduct = CoreDataManager.shared.fetchUserProduct(backendId: summary.id) {
            return localProduct
        }
        
        // Strategy 2: Find by barcode if available
        if let barcode = summary.barcode, !barcode.isEmpty {
            let allProducts = CoreDataManager.shared.fetchUserProducts()
            if let productByBarcode = allProducts.first(where: { $0.barcode == barcode }) {
                return productByBarcode
            }
        }
        
        // Strategy 3: Find by name and brand combination
        let allProducts = CoreDataManager.shared.fetchUserProducts()
        if let productByDetails = allProducts.first(where: { 
            $0.productName == summary.name && $0.brand == summary.brand 
        }) {
            return productByDetails
        }
        
        return nil
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

// MARK: - Product Card Component
struct ProductCard: View {
    let product: UserProductSummary
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var wishlistMessage: String?
    @Binding var showingWishlistAlert: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Product Image
            if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                        )
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.lushyPink.opacity(0.3), Color.lushyPurple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Show favorite indicator if this is a favorite
                if product.isFavorite == true {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("Favorite")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Product Navigation View
struct ProductNavigationView: View {
    let summary: UserProductSummary
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var wishlistMessage: String?
    @Binding var showingWishlistAlert: Bool
    
    var body: some View {
        if viewModel.isViewingOwnProfile {
            // For own profile, try to find the local UserProduct first
            let localProduct = findLocalProduct(for: summary)
            if let localProduct = localProduct {
                // Use full ProductDetailView for owned products with complete Core Data object
                NavigationLink(destination: ProductDetailView(viewModel: ProductDetailViewModel(product: localProduct))) {
                    ProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                }
            } else {
                // Fallback to GeneralProductDetailView if Core Data object not found
                NavigationLink(destination: GeneralProductDetailView(userId: viewModel.targetUserId, productId: summary.id)) {
                    ProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
                }
            }
        } else {
            // For other users' profiles, use general product detail view
            NavigationLink(destination: GeneralProductDetailView(userId: viewModel.targetUserId, productId: summary.id)) {
                ProductCard(product: summary, viewModel: viewModel, wishlistMessage: $wishlistMessage, showingWishlistAlert: $showingWishlistAlert)
            }
        }
    }
    
    // Helper to find local product with multiple lookup strategies
    private func findLocalProduct(for summary: UserProductSummary) -> UserProduct? {
        // Try multiple strategies to find the local product
        
        // Strategy 1: Find by backend ID
        if let localProduct = CoreDataManager.shared.fetchUserProduct(backendId: summary.id) {
            return localProduct
        }
        
        // Strategy 2: Find by barcode if available
        if let barcode = summary.barcode, !barcode.isEmpty {
            let allProducts = CoreDataManager.shared.fetchUserProducts()
            if let productByBarcode = allProducts.first(where: { $0.barcode == barcode }) {
                return productByBarcode
            }
        }
        
        // Strategy 3: Find by name and brand combination
        let allProducts = CoreDataManager.shared.fetchUserProducts()
        if let productByDetails = allProducts.first(where: { 
            $0.productName == summary.name && $0.brand == summary.brand 
        }) {
            return productByDetails
        }
        
        return nil
    }
}

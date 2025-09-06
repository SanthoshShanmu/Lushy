import SwiftUI
import Combine

struct FeedView: View {
    @StateObject var viewModel: FeedViewModel
    let currentUserId: String
    @StateObject private var userSearchViewModel = UserSearchViewModel()
    @State private var selectedUser: UserSummary?
    
    // Add smaller subviews for each state
    @ViewBuilder private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: LushyPalette.pink))
                .scaleEffect(1.5)
            Text("Loading your feed...")
                .lushyCaption()
        }
        .glassCard()
    }

    @ViewBuilder private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 50))
                .foregroundStyle(LushyPalette.gradientPrimary.opacity(0.6))
            Text("Oops! Something went wrong")
                .lushyTitle()
            Text(error)
                .lushyCaption()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .glassCard()
    }

    @ViewBuilder private var emptyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(LushyPalette.gradientPrimary)
            VStack(spacing: 8) {
                Text("Your feed is empty! ✨")
                    .lushyTitle()
                Text("Follow friends to see their beauty journey")
                    .lushyCaption()
                    .multilineTextAlignment(.center)
            }
            NavigationLink(destination: UserSearchView(viewModel: userSearchViewModel, currentUserId: currentUserId)) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Find Friends")
                }
                .neumorphicButtonStyle()
            }
        }
        .glassCard()
    }

    // Extracted navigation link for activities
    @ViewBuilder private func activityLink(for activity: Activity) -> some View {
        if activity.type == "bundled_product_added" {
            // Bundled activities - show bundled card without navigation
            BundledActivityCard(activity: activity, currentUserId: currentUserId)
        } else if activity.targetType == "UserProduct", let productId = activity.targetId {
            NavigationLink(destination: GeneralProductDetailView(userId: currentUserId, productId: productId)) {
                if activity.type == "review_added" {
                    ReviewActivityCard(activity: activity, currentUserId: currentUserId)
                } else {
                    ActivityCard(activity: activity, currentUserId: currentUserId)
                }
            }
        } else {
            NavigationLink(value: activity.user) {
                if activity.type == "review_added" {
                    ReviewActivityCard(activity: activity, currentUserId: currentUserId)
                } else {
                    ActivityCard(activity: activity, currentUserId: currentUserId)
                }
            }
        }
    }

    @ViewBuilder private var listView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.activities) { activity in
                    activityLink(for: activity)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder private var content: some View {
        ZStack {
            Color.clear.pastelBackground()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.activities.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .onAppear { viewModel.fetchFeed(for: currentUserId) }
        .onChange(of: currentUserId) { _, newUserId in viewModel.fetchFeed(for: newUserId) }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFeed"))
            .debounce(for: .milliseconds(1000), scheduler: RunLoop.main) // Add 1 second debouncing
        ) { _ in 
            // Only refresh if not already loading to prevent loops
            if !viewModel.isLoading {
                viewModel.fetchFeed(for: currentUserId) 
            }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .refreshable { viewModel.fetchFeed(for: currentUserId) }
                .navigationDestination(for: UserSummary.self) { user in
                    UserProfileView(viewModel: UserProfileViewModel(currentUserId: currentUserId, targetUserId: user.id))
                        .id(user.id)
                }
        }
    }
}

// MARK: - Activity Card Component
struct ActivityCard: View {
    let activity: Activity
    let currentUserId: String
    
    @State private var likesCount: Int = 0
    @State private var isLiked = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact header
            HStack(spacing: 12) {
                // Smaller, more elegant profile image
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.7), Color.lushyPurple.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(activity.user.name.prefix(1).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 1) {
                    NavigationLink(value: activity.user) {
                        Text(activity.user.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(timeAgoString(from: activity.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Minimal activity icon
                Image(systemName: activityIcon(for: activity.type))
                    .font(.caption)
                    .foregroundColor(.lushyPink)
                    .padding(6)
                    .background(Color.lushyPink.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Compact content section
            HStack(alignment: .top, spacing: 12) {
                // Smaller circular product image
                Group {
                    if let imageUrl = extractImageUrl(), !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.lushyPink)
                                )
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16))
                                    .foregroundColor(.lushyPink.opacity(0.6))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                // Compact content - only show description, no duplicate product name
                VStack(alignment: .leading, spacing: 6) {
                    if let description = activity.description {
                        Text(description)
                            .font(.subheadline)
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Minimal interaction bar
            HStack(spacing: 16) {
                Button(action: {
                    APIService.shared.likeActivity(activityId: activity.id) { result in
                        if case .success(let response) = result {
                            DispatchQueue.main.async {
                                likesCount = response.likes
                                isLiked = response.liked
                            }
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isLiked ? .red : .secondary)
                        if likesCount > 0 {
                            Text("\(likesCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            likesCount = activity.likes ?? 0
            isLiked = activity.liked ?? false
        }
    }
    
    private func extractProductName() -> String? {
        guard let description = activity.description else { return nil }
        
        if description.contains("Added ") && description.contains(" to their collection") {
            let start = description.index(description.startIndex, offsetBy: 6) // "Added ".count
            let end = description.range(of: " to their collection")?.lowerBound ?? description.endIndex
            return String(description[start..<end])
        }
        
        return nil
    }
    
    private func extractImageUrl() -> String? {
        return activity.imageUrl
    }
    
    private func activityIcon(for type: String) -> String {
        switch type {
        case "product_added":
            return "plus.circle.fill"
        case "review_added":
            return "star.fill"
        case "favorite_product":
            return "heart.fill"
        case "unfavorite_product":
            return "heart"
        case "opened_product":
            return "circle.dotted"
        case "finished_product":
            return "checkmark.circle.fill"
        case "add_to_bag":
            return "bag.fill.badge.plus"
        case "bag_created":
            return "bag.fill"
        default:
            return "sparkles"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        return date.timeAgoDisplay
    }
}

// MARK: - Review Activity Card Component
struct ReviewActivityCard: View {
    let activity: Activity
    let currentUserId: String
    @State private var likesCount: Int = 0
    @State private var commentsCount: Int = 0
    @State private var showCommentSheet = false
    @State private var isLiked = false
    @State private var commentList: [CommentSummary] = []

    var body: some View {
        VStack(spacing: 0) {
            // Compact header - consistent with other cards
            HStack(spacing: 12) {
                // User profile image
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.7), Color.lushyPurple.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(activity.user.name.prefix(1).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    NavigationLink(value: activity.user) {
                        Text(activity.user.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Added a review")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Review star icon - consistent with other activity icons
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.lushyPink)
                    .padding(6)
                    .background(Color.lushyPink.opacity(0.1))
                    .clipShape(Circle())
                
                Text(timeAgoString(from: activity.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Special review content section with gradient background
            VStack(spacing: 0) {
                // Product header with gradient background to make reviews special
                LinearGradient(
                    gradient: Gradient(colors: [Color.lushyPink.opacity(0.8), Color.lushyPurple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 80)
                .overlay(
                    HStack(spacing: 12) {
                        // Product image
                        Group {
                            if let imageUrl = activity.imageUrl, !imageUrl.isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "sparkles")
                                                .font(.title3)
                                                .foregroundColor(.white.opacity(0.7))
                                        )
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "sparkles")
                                            .font(.title3)
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Product name and rating in the gradient section
                            if let reviewData = activity.reviewData {
                                Text("Reviewed \(reviewData.productName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                // Star rating
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= reviewData.rating ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            } else if let description = activity.description {
                                Text(extractProductNameFromDescription(from: description) ?? "Product")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                )
                
                // Review content section
                VStack(alignment: .leading, spacing: 8) {
                    if let reviewData = activity.reviewData {
                        // Review title
                        if !reviewData.title.isEmpty {
                            Text(reviewData.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        
                        // Review text
                        if !reviewData.text.isEmpty {
                            Text(reviewData.text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    } else if let description = activity.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
            }
            .padding(.top, 8)

            // Interaction bar - consistent with other cards
            HStack(spacing: 16) {
                Button(action: {
                    APIService.shared.likeActivity(activityId: activity.id) { result in
                        if case .success(let response) = result {
                            DispatchQueue.main.async {
                                likesCount = response.likes
                                isLiked = response.liked
                            }
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isLiked ? .red : .secondary)
                        if likesCount > 0 {
                            Text("\(likesCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showCommentSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        if commentsCount > 0 {
                            Text("\(commentsCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        )
        .onAppear {
            likesCount = activity.likes ?? 0
            isLiked = activity.liked ?? false
            commentsCount = activity.comments?.count ?? 0
            commentList = activity.comments ?? []
        }
        .sheet(isPresented: $showCommentSheet) {
            CommentBottomSheetView(
                activityId: activity.id,
                commentList: commentList,
                commentsCount: commentsCount
            ) { newComments, newCount in
                commentList = newComments
                commentsCount = newCount
            }
        }
    }
    
    // Helper function to extract product name from description as fallback
    private func extractProductNameFromDescription(from description: String) -> String? {
        // Try to extract product name from various description patterns
        if description.contains("Reviewed ") {
            let components = description.components(separatedBy: "Reviewed ")
            return components.last
        }
        
        return nil
    }

    private func timeAgoString(from date: Date) -> String {
        return date.timeAgoDisplay
    }
}

// MARK: - Bundled Activity Card Component
struct BundledActivityCard: View {
    let activity: Activity
    let currentUserId: String
    @State private var likesCount: Int = 0
    @State private var isLiked: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact header
            HStack(spacing: 12) {
                // Smaller, elegant profile image
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.7), Color.lushyPurple.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(activity.user.name.prefix(1).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 1) {
                    NavigationLink(value: activity.user) {
                        Text(activity.user.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(timeAgoString(from: activity.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Count badge
                if let bundledActivities = activity.bundledActivities {
                    Text("\(bundledActivities.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.mossGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.mossGreen.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Compact description
            HStack {
                Text(activity.description ?? "Added products to their collection")
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            
            // Compact product grid
            if let bundledActivities = activity.bundledActivities {
                HStack(spacing: 8) {
                    ForEach(Array(bundledActivities.prefix(3)), id: \.id) { bundledActivity in
                        compactProductCard(bundledActivity)
                    }
                    
                    if bundledActivities.count > 3 {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("+\(bundledActivities.count - 3)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                )
                            Text("more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Minimal interaction bar
            HStack(spacing: 16) {
                Button(action: {
                    APIService.shared.likeActivity(activityId: activity.id) { result in
                        if case .success(let response) = result {
                            DispatchQueue.main.async {
                                likesCount = response.likes
                                isLiked = response.liked
                            }
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isLiked ? .red : .secondary)
                        if likesCount > 0 {
                            Text("\(likesCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            likesCount = activity.likes ?? 0
            isLiked = activity.liked ?? false
        }
    }
    
    private func compactProductCard(_ bundledActivity: BundledActivityItem) -> some View {
        NavigationLink(destination: GeneralProductDetailView(userId: currentUserId, productId: bundledActivity.targetId ?? "")) {
            VStack(spacing: 4) {
                // Small circular product image
                Group {
                    if let imageUrl = bundledActivity.imageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .tint(.mossGreen)
                                )
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.mossGreen.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundColor(.mossGreen.opacity(0.6))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.mossGreen.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                // Compact product name
                if bundledActivity.description != nil {
                    let productName = extractProductName(from: bundledActivity.description!)
                    Text(productName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(width: 50)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func extractProductName(from description: String) -> String {
        // Extract product name from "Added {productName} to their collection"
        if description.hasPrefix("Added ") && description.contains(" to their collection") {
            let start = description.index(description.startIndex, offsetBy: 6) // "Added ".count
            let end = description.range(of: " to their collection")?.lowerBound ?? description.endIndex
            return String(description[start..<end])
        }
        return "Product"
    }
    
    private func timeAgoString(from date: Date) -> String {
        return date.timeAgoDisplay
    }
}

// MARK: - General Product Detail View
struct GeneralProductDetailView: View {
    @StateObject private var viewModel: GeneralProductDetailViewModel
    @State private var showingWishlistAlert = false
    @State private var wishlistMessage: String?
    @State private var alertTitle: String = "Success"
    
    private let currentUserId: String
    private let productOwnerId: String
    
    init(userId: String, productId: String) {
        self.currentUserId = AuthService.shared.userId ?? ""
        self.productOwnerId = userId
        self._viewModel = StateObject(wrappedValue: GeneralProductDetailViewModel(userId: userId, productId: productId))
    }
    
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
                    Text("Loading product details...")
                        .font(.subheadline)
                        .foregroundColor(.lushyPink)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.lushyPink.opacity(0.6))
                    Text("Product Unavailable")
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
            } else if let product = viewModel.product {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Product Header
                        GeneralProductHeader(product: product)
                        
                        // Product Details
                        GeneralProductDetails(product: product, isCurrentUser: currentUserId == productOwnerId)
                        
                        // Ethics Information
                        if product.product.vegan || product.product.crueltyFree {
                            GeneralEthicsSection(product: product.product)
                        }
                        
                        // Add to Collection/Wishlist Actions
                        GeneralProductActions(
                            product: product.product,
                            wishlistMessage: $wishlistMessage,
                            showingWishlistAlert: $showingWishlistAlert,
                            alertTitle: $alertTitle
                        )
                    }
                    .padding()
                }
            } else {
                Text("No product details available")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(viewModel.product?.product.productName ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showingWishlistAlert) {
            Button("OK") { 
                wishlistMessage = nil
                alertTitle = "Success"
            }
        } message: {
            Text(wishlistMessage ?? "")
        }
    }
}

// MARK: - General Product Header
private struct GeneralProductHeader: View {
    let product: BackendUserProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Product Image
            HStack {
                Spacer()
                AsyncImage(url: URL(string: product.product.imageUrl ?? "")) { image in
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
            
            // Product Info
            VStack(alignment: .leading, spacing: 8) {
                if let brand = product.product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.lushyPurple)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                Text(product.product.productName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Product metadata tags
                HStack(spacing: 8) {
                    if let shade = product.product.shade, !shade.isEmpty {
                        Text(shade)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPurple.opacity(0.2))
                            .foregroundColor(.lushyPurple)
                            .cornerRadius(12)
                    }
                    if let size = product.product.size, !size.isEmpty {
                        Text(size)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let spf = product.product.spf, !spf.isEmpty {
                        Text("SPF \(spf)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPeach.opacity(0.2))
                            .foregroundColor(.lushyPeach)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - General Product Details
private struct GeneralProductDetails: View {
    let product: BackendUserProduct
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Product Details")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.lushyPurple)
            
            VStack(spacing: 12) {
                if !product.product.barcode.isEmpty {
                    detailRow(label: "Barcode", value: product.product.barcode)
                }
                
                if let category = product.product.category, !category.isEmpty {
                    detailRow(label: "Category", value: category.capitalized)
                }
                
                if let pao = product.product.periodsAfterOpening, !pao.isEmpty {
                    detailRow(label: "Period After Opening", value: pao)
                }
                
                // Fix: Remove optional binding since purchaseDate is not optional
                detailRow(label: "Owner purchased", value: DateFormatter.medium.string(from: product.purchaseDate))
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
}

// MARK: - General Ethics Section
private struct GeneralEthicsSection: View {
    let product: BackendProductCatalog
    
    var body: some View {
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

// MARK: - General Product Actions
private struct GeneralProductActions: View {
    let product: BackendProductCatalog
    @Binding var wishlistMessage: String?
    @Binding var showingWishlistAlert: Bool
    @Binding var alertTitle: String
    @State private var isAddingToCollection = false
    @State private var isAddingToWishlist = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var wishlistItems: [AppWishlistItem] = []
    @State private var isLoadingWishlist = false
    
    // Separate alert states for collection and wishlist
    @State private var showingCollectionAlert = false
    @State private var collectionMessage: String?
    
    // Computed property to check if product is already in wishlist
    private var isProductInWishlist: Bool {
        return wishlistItems.contains { item in
            item.productName.lowercased() == product.productName.lowercased() ||
            item.productURL.lowercased().contains(product.barcode.lowercased())
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Add to My Collection
            Button(action: {
                addToCollection()
            }) {
                HStack(spacing: 8) {
                    if isAddingToCollection {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
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
            .disabled(isAddingToCollection)
            
            // Add to Wishlist
            Button(action: {
                addToWishlist()
            }) {
                HStack(spacing: 8) {
                    if isAddingToWishlist {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .mossGreen))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isProductInWishlist ? "checkmark.circle.fill" : "heart.fill")
                    }
                    Text(isProductInWishlist ? "Already in Wishlist" : "Add to Wishlist")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: isProductInWishlist ? 
                            [Color.gray.opacity(0.3), Color.gray.opacity(0.2)] :
                            [Color.mossGreen, Color.lushyCream]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(isProductInWishlist ? .secondary : .lushyPurple)
                .cornerRadius(12)
            }
            .disabled(isAddingToWishlist || isProductInWishlist)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            loadWishlist()
        }
        // Separate alert for collection
        .alert("Collection", isPresented: $showingCollectionAlert) {
            Button("OK") { 
                collectionMessage = nil
            }
        } message: {
            Text(collectionMessage ?? "")
        }
        // Keep existing alert for wishlist
        .alert("Wishlist", isPresented: $showingWishlistAlert) {
            Button("OK") { 
                wishlistMessage = nil
            }
        } message: {
            Text(wishlistMessage ?? "")
        }
    }
    
    private func loadWishlist() {
        isLoadingWishlist = true
        
        APIService.shared.fetchWishlist()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoadingWishlist = false
                if case .failure(let error) = completion {
                    print("Failed to load wishlist: \(error)")
                }
            } receiveValue: { items in
                wishlistItems = items
            }
            .store(in: &cancellables)
    }
    
    private func addToCollection() {
        isAddingToCollection = true
        
        APIService.shared.addProductToCollection(
            barcode: product.barcode,
            productName: product.productName,
            brand: product.brand,
            imageUrl: product.imageUrl
        ) { result in
            DispatchQueue.main.async {
                isAddingToCollection = false
                
                switch result {
                case .success(_):
                    collectionMessage = "Added to your collection! 🎉"
                    showingCollectionAlert = true
                case .failure(let error):
                    collectionMessage = "Failed to add to collection: \(error.localizedDescription)"
                    showingCollectionAlert = true
                }
            }
        }
    }
    
    private func addToWishlist() {
        // Check for duplicates before adding
        if isProductInWishlist {
            wishlistMessage = "This product is already in your wishlist!"
            showingWishlistAlert = true
            return
        }
        
        isAddingToWishlist = true
        
        let wishlistItem = NewWishlistItem(
            productName: product.productName,
            productURL: "https://lushy.app/product/\(product.barcode)",
            notes: "Added from user's profile",
            imageURL: product.imageUrl
        )
        
        APIService.shared.addWishlistItem(wishlistItem)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isAddingToWishlist = false
                
                if case .failure(let error) = completion {
                    wishlistMessage = "Failed to add to wishlist: \(error.localizedDescription)"
                    showingWishlistAlert = true
                }
            } receiveValue: { _ in
                // Refresh wishlist after successful addition
                loadWishlist()
                wishlistMessage = "Added to wishlist! 💕"
                showingWishlistAlert = true
            }
            .store(in: &cancellables)
    }
}

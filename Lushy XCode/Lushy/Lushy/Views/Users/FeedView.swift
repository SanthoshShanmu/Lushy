import SwiftUI

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
                    Text(activity.user.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
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
                
                // Compact content
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
                    
                    if let productName = extractProductName() {
                        Text(productName)
                            .font(.caption)
                            .foregroundColor(.lushyPink)
                            .fontWeight(.semibold)
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
    
    private func timeAgoString(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        // Try full ISO8601 with fractional seconds
        formatter.formatOptions = [
            .withFullDate, .withTime,
            .withFractionalSeconds,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        if let date = formatter.date(from: dateString) {
            return date.timeAgoDisplay
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [
            .withFullDate, .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        if let date = formatter.date(from: dateString) {
            return date.timeAgoDisplay
        }
        return "Unknown"
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
            // Compact header
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
                    Text(activity.user.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Just show "Added a review" - the specific details are in the purple section
                    Text("Added a review")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(timeAgoString(from: activity.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main review card content with gradient background
            VStack(spacing: 0) {
                // Product header with gradient background
                LinearGradient(
                    gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)
                .overlay(
                    HStack(spacing: 16) {
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
                                                .font(.title2)
                                                .foregroundColor(.white.opacity(0.7))
                                        )
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "sparkles")
                                            .font(.title2)
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Product name and rating in the purple section
                            if let reviewData = activity.reviewData {
                                Text("\(reviewData.productName) and gave it \(reviewData.rating) star\(reviewData.rating == 1 ? "" : "s")")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                // Brand
                                if let brand = reviewData.brand, !brand.isEmpty {
                                    Text("By \(brand)")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                }
                            } else {
                                // Fallback: try to extract from description or show placeholder
                                Text(extractProductNameFromDescription() ?? "Product")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                )
                .cornerRadius(16, corners: [.topLeft, .topRight])
                
                // Review content section - only show the actual review content, no duplicates
                VStack(alignment: .leading, spacing: 12) {
                    if let reviewData = activity.reviewData {
                        // Star rating
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= reviewData.rating ? "star.fill" : "star")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                            }
                            Spacer()
                        }
                        
                        // Review title
                        if !reviewData.title.isEmpty {
                            Text(reviewData.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        
                        // Review text
                        if !reviewData.text.isEmpty {
                            Text(reviewData.text)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                        }
                    } else {
                        // Fallback: Show basic rating if available, but no duplicate description
                        if let rating = activity.rating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundColor(.yellow)
                                }
                                Spacer()
                            }
                        }
                        
                        // Only show description if no reviewData exists
                        if activity.reviewData == nil, let description = activity.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(4)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Interaction bar
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
                        Image(systemName: "bubble.left")
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
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            print("🐛 ReviewActivityCard Debug:")
            print("Activity ID: \(activity.id)")
            print("Activity Type: \(activity.type)")
            print("Review Data: \(String(describing: activity.reviewData))")
            if let reviewData = activity.reviewData {
                print("Product Name: \(reviewData.productName)")
                print("Brand: \(String(describing: reviewData.brand))")
                print("Title: \(reviewData.title)")
                print("Text: \(reviewData.text)")
                print("Rating: \(reviewData.rating)")
            }
            print("Image URL: \(String(describing: activity.imageUrl))")
            print("Description: \(String(describing: activity.description))")
            
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
    private func extractProductNameFromDescription() -> String? {
        guard let description = activity.description else { return nil }
        
        // Try to extract product name from various description patterns
        if description.contains("Reviewed ") {
            let components = description.components(separatedBy: "Reviewed ")
            return components.last
        }
        
        return nil
    }

    private func timeAgoString(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date.timeAgoDisplay
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [
            .withFullDate, .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        if let date = formatter.date(from: dateString) {
            return date.timeAgoDisplay
        }
        return "Unknown"
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
                    Text(activity.user.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
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
                        .foregroundColor(.lushyMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.lushyMint.opacity(0.1))
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
                                    .tint(.lushyMint)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.lushyMint.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(.lushyMint.opacity(0.6))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.lushyMint.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            // Compact product name
            if let description = bundledActivity.description {
                let productName = extractProductName(from: description)
                Text(productName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 50)
            }
        }
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
    
    private func timeAgoString(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        // Try full ISO8601 with fractional seconds
        formatter.formatOptions = [
            .withFullDate, .withTime,
            .withFractionalSeconds,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        if let date = formatter.date(from: dateString) {
            return date.timeAgoDisplay
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [
            .withFullDate, .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        if let date = formatter.date(from: dateString) {
            return date.timeAgoDisplay
        }
        return "Unknown time"
    }
}

// MARK: - General Product Detail View
struct GeneralProductDetailView: View {
    @StateObject private var viewModel: GeneralProductDetailViewModel
    init(userId: String, productId: String) {
        _viewModel = StateObject(wrappedValue: GeneralProductDetailViewModel(userId: userId, productId: productId))
    }
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text(error).foregroundColor(.red).multilineTextAlignment(.center).padding()
            } else if let product = viewModel.product {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let urlString = product.imageUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.3) }
                                .frame(maxWidth: .infinity, maxHeight: 200)
                        }
                        Text(product.productName)
                            .font(.title2).fontWeight(.bold)
                        if let brand = product.brand {
                            Text(brand).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            } else {
                Text("No product details available").foregroundColor(.secondary)
            }
        }
        .navigationTitle(viewModel.product?.productName ?? "Product")
    }
}

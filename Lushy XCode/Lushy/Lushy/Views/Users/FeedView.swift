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
        if activity.targetType == "UserProduct", let productId = activity.targetId {
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
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.activities) { activity in
                    activityLink(for: activity)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .feedCard()
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFeed"))) { _ in viewModel.fetchFeed(for: currentUserId) }
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
    @State private var commentsCount: Int = 0
    @State private var showCommentSheet = false
    @State private var newCommentText = ""
    @State private var isLiked = false
    @State private var commentList: [CommentSummary] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Profile picture placeholder with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.6), Color.lushyPurple.opacity(0.4)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(activity.user.name.prefix(1).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.user.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(timeAgoString(from: activity.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Activity type icon
                Image(systemName: activityIcon(for: activity.type))
                    .font(.title3)
                    .foregroundColor(.lushyPink)
            }
            
            if let description = activity.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

            // Interaction Bar
            HStack(spacing: 20) {
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
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(likesCount)")
                            .font(.caption)
                    }
                }
                Button(action: {
                    showCommentSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        Text("\(commentsCount)")
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .padding(.top, 8)

        }
        .onAppear {
            likesCount = activity.likes ?? 0
            commentsCount = activity.comments?.count ?? 0
            isLiked = activity.liked ?? false
            commentList = activity.comments ?? []
        }
        .sheet(isPresented: $showCommentSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    Text("Comments")
                        .font(.headline)
                        .padding(.top)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(commentList) { comment in
                                VStack(alignment: .leading) {
                                    Text(comment.user.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(comment.text)
                                        .font(.body)
                                    Text(comment.createdAt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                    HStack {
                        TextField("Add a comment...", text: $newCommentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Submit") {
                            APIService.shared.commentOnActivity(activityId: activity.id, text: newCommentText) { result in
                                if case .success(let comments) = result {
                                    DispatchQueue.main.async {
                                        commentList = comments
                                        commentsCount = comments.count
                                        newCommentText = ""
                                        showCommentSheet = false
                                    }
                                }
                            }
                        }
                        .disabled(newCommentText.isEmpty)
                    }
                    .padding()
                    Spacer()
                }
                .navigationBarTitle("Comments", displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showCommentSheet = false }
                    }
                }
            }
        }
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
    @State private var newCommentText = ""
    @State private var isLiked = false  // track if user has liked this activity
    @State private var commentList: [CommentSummary] = []

    var body: some View {
        // Expand entire card to full width
        VStack(spacing: 0) {
            // Outer white card background
            VStack(alignment: .leading, spacing: 0) {
                // User header
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.lushyPink.opacity(0.6), Color.lushyPurple.opacity(0.4)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(activity.user.name.prefix(1).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.user.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        // Subtitle: Reviewed product
                        Text("Reviewed \(extractedTitle)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(LushyPalette.pink)
                    }
                    Spacer()
                    Text(timeAgoString(from: activity.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12) // Vertical padding only

                // Gradient review block
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.lushyPink.opacity(0.8), Color.lushyPurple.opacity(0.9)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        Text(extractedTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        // Review text
                        if let reviewText = activity.description {
                            Text(reviewText)
                                .font(.body)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Star rating
                        if let rating = activity.rating {
                            HStack(spacing: 4) {
                                ForEach(0..<5) { idx in
                                    Image(systemName: idx < rating ? "star.fill" : "star")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16) // Added horizontal padding
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(12, corners: [.topLeft, .topRight])
            }
            .frame(maxWidth: .infinity) // Expand to full available width
            
            // Interaction Bar
            HStack(spacing: 20) {
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
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(likesCount)")
                            .font(.caption)
                    }
                }
                Button(action: {
                    showCommentSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        Text("\(commentsCount)")
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear {
            likesCount = activity.likes ?? 0
            commentsCount = activity.comments?.count ?? 0
            // Initialize liked state from backend
            isLiked = activity.liked ?? false
            commentList = activity.comments ?? []
        }
        .sheet(isPresented: $showCommentSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    Text("Comments")
                        .font(.headline)
                        .padding(.top)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(commentList) { comment in
                                VStack(alignment: .leading) {
                                    Text(comment.user.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(comment.text)
                                        .font(.body)
                                    Text(comment.createdAt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                    HStack {
                        TextField("Add a comment...", text: $newCommentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Submit") {
                            APIService.shared.commentOnActivity(activityId: activity.id, text: newCommentText) { result in
                                if case .success(let comments) = result {
                                    DispatchQueue.main.async {
                                        commentList = comments
                                        commentsCount = comments.count
                                        newCommentText = ""
                                        showCommentSheet = false
                                    }
                                }
                            }
                        }
                        .disabled(newCommentText.isEmpty)
                    }
                    .padding()
                    Spacer()
                }
                .navigationBarTitle("Comments", displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showCommentSheet = false }
                    }
                }
            }
        }
    }

    // Extract product title from description
    private var extractedTitle: String {
        guard let desc = activity.description,
              desc.hasPrefix("Reviewed ") else { return "" }
        let trimmed = desc.dropFirst("Reviewed ".count)
        return String(trimmed).components(separatedBy: " and").first ?? String(trimmed)
    }

    // Utility function to format createdAt string as time ago
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

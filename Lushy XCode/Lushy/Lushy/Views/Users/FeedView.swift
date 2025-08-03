import SwiftUI

struct FeedView: View {
    @StateObject var viewModel: FeedViewModel
    let currentUserId: String
    @StateObject private var userSearchViewModel = UserSearchViewModel()
    @State private var selectedUser: UserSummary?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .pastelBackground()

                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: LushyPalette.pink))
                            .scaleEffect(1.5)
                        Text("Loading your feed...")
                            .lushyCaption()
                    }
                    .glassCard()

                } else if let error = viewModel.error {
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

                } else if viewModel.activities.isEmpty {
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

                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.activities) { activity in
                                NavigationLink(value: activity.user) {
                                    if activity.type == "review_added" {
                                        ReviewActivityCard(activity: activity, currentUserId: currentUserId)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        ActivityCard(activity: activity, currentUserId: currentUserId)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .feedCard()
                            }
                        }
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .refreshable {
                        viewModel.fetchFeed(for: currentUserId)
                    }
                }
            }
            .onAppear {
                viewModel.fetchFeed(for: currentUserId)
            }
            .onChange(of: currentUserId) { _, newUserId in
                viewModel.fetchFeed(for: newUserId)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFeed"))) { _ in
                viewModel.fetchFeed(for: currentUserId)
            }
            .navigationDestination(for: UserSummary.self) { user in
                UserProfileView(viewModel: UserProfileViewModel(currentUserId: currentUserId, targetUserId: user.id))
                    .id(user.id) // Ensure correct reload for different user profiles
            }
        }
    }
}

// MARK: - Activity Card Component
struct ActivityCard: View {
    let activity: Activity
    let currentUserId: String
    
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
        }
        // Removed internal padding and background
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
        }
        .sheet(isPresented: $showCommentSheet) {
            VStack(spacing: 16) {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Button("Submit") {
                    APIService.shared.commentOnActivity(activityId: activity.id, text: newCommentText) { result in
                        if case .success(let comments) = result {
                            DispatchQueue.main.async {
                                commentsCount = comments.count
                                newCommentText = ""
                                showCommentSheet = false
                            }
                        }
                    }
                }
                .disabled(newCommentText.isEmpty)
                .padding()
                Spacer()
            }
            .padding()
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

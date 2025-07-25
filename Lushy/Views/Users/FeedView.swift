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
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.activities) { activity in
                                NavigationLink(value: activity.user) {
                                    ActivityCard(activity: activity, currentUserId: currentUserId)
                                        .glassCard()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top)
                    }
                    .refreshable {
                        viewModel.fetchFeed(for: currentUserId)
                    }
                }
            }
            .navigationTitle("✨ Beauty Feed")
            .navigationBarTitleDisplayMode(.large)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
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
        guard let date = formatter.date(from: dateString) else {
            return "Unknown"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

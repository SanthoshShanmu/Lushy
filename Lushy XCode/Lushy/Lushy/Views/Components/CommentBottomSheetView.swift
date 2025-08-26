import SwiftUI

struct CommentBottomSheetView: View {
    let activityId: String
    @State var commentList: [CommentSummary]
    @State var commentsCount: Int
    @State private var newCommentText = ""
    @State private var currentUserName: String = "User"
    @Environment(\.dismiss) private var dismiss
    
    let onCommentAdded: (([CommentSummary], Int) -> Void)?
    
    init(activityId: String, commentList: [CommentSummary], commentsCount: Int, onCommentAdded: (([CommentSummary], Int) -> Void)? = nil) {
        self.activityId = activityId
        self._commentList = State(initialValue: commentList)
        self._commentsCount = State(initialValue: commentsCount)
        self.onCommentAdded = onCommentAdded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("Comments")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(commentsCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.lushyPink.opacity(0.1))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 20)
            }
            
            // Comments list
            if commentList.isEmpty {
                emptyCommentsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(commentList) { comment in
                            CommentRowView(comment: comment, activityId: activityId)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            
            Spacer()
            
            // Comment input
            commentInputView
        }
        .background(
            Color.white
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .onAppear {
            loadCurrentUserProfile()
        }
    }
    
    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundColor(.lushyPink.opacity(0.6))
            
            Text("No comments yet")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
    
    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Current user avatar - use initials from fetched user name
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.lushyPink, .lushyPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(currentUserName.prefix(1).uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                // Text input
                HStack {
                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    
                    if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: submitComment) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.lushyPink, .lushyPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
    
    private func loadCurrentUserProfile() {
        guard let userId = AuthService.shared.userId else {
            currentUserName = "User"
            return
        }
        
        APIService.shared.fetchUserProfile(userId: userId) { result in
            DispatchQueue.main.async {
                if case .success(let wrapper) = result {
                    currentUserName = wrapper.user.name
                }
            }
        }
    }
    
    private func submitComment() {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        APIService.shared.commentOnActivity(activityId: activityId, text: trimmedText) { result in
            DispatchQueue.main.async {
                if case .success(let comments) = result {
                    self.commentList = comments
                    self.commentsCount = comments.count
                    self.onCommentAdded?(comments, comments.count)
                    self.newCommentText = ""
                }
            }
        }
    }
}

struct CommentRowView: View {
    let comment: CommentSummary
    let activityId: String
    @State private var likesCount: Int = 0
    @State private var isLiked: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar - show actual profile picture instead of just initials
            Group {
                if let profileImageUrl = comment.user.profileImage,
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
                                        Color.lushyMint.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    // Fallback to initials if no profile image
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
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(comment.user.name.prefix(1).uppercased())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }
            }
            
            // Comment content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.user.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Comment interaction - like button with working functionality
                HStack(spacing: 16) {
                    Button(action: {
                        APIService.shared.likeComment(activityId: activityId, commentId: comment.id) { result in
                            DispatchQueue.main.async {
                                if case .success(let response) = result {
                                    likesCount = response.likes
                                    isLiked = response.liked
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(isLiked ? .red : .secondary)
                            
                            if likesCount > 0 {
                                Text("\(likesCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .onAppear {
            likesCount = comment.likes ?? 0
            isLiked = comment.liked ?? false
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        return date.timeAgoDisplay
    }
}

#Preview {
    CommentBottomSheetView(
        activityId: "sample",
        commentList: [],
        commentsCount: 0
    )
}
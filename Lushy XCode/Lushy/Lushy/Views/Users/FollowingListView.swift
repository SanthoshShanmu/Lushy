import SwiftUI

struct FollowingListView: View {
    let following: [UserSummary]
    let currentUserId: String
    
    var body: some View {
        List(following, id: \.id) { user in
            NavigationLink(destination: UserProfileView(
                viewModel: UserProfileViewModel(
                    currentUserId: currentUserId,
                    targetUserId: user.id
                )
            )) {
                HStack(spacing: 12) {
                    // Profile image or initials
                    if let profileImageUrl = user.profileImage,
                       !profileImageUrl.isEmpty {
                        AsyncImage(url: URL(string: "\(APIService.shared.staticBaseURL)\(profileImageUrl)")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.lushyPink)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                )
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.lushyPink)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(user.name.prefix(1).uppercased())
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.headline)
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
    }
}
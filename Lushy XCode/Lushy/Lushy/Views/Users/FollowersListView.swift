import SwiftUI

struct FollowersListView: View {
    let followers: [UserSummary]
    let currentUserId: String
    
    var body: some View {
        List(followers) { user in
            NavigationLink(destination: UserProfileView(
                viewModel: UserProfileViewModel(
                    currentUserId: currentUserId,
                    targetUserId: user.id
                )
            )) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.headline)
                        if let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
    }
}
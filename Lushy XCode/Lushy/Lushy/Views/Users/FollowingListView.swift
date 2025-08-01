import SwiftUI

struct FollowingListView: View {
    let following: [UserSummary]
    let currentUserId: String
    
    var body: some View {
        List(following) { user in
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
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
    }
}
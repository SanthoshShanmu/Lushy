import SwiftUI

struct UserSearchView: View {
    @StateObject var viewModel = UserSearchViewModel()
    let currentUserId: String
    @State private var selectedUser: UserSummary?
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .pastelBackground()

                VStack(spacing: 16) {
                    // Search field
                    TextField("Search users...", text: $searchText)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .onChange(of: searchText) { _, newValue in
                            viewModel.query = newValue
                            viewModel.search()
                        }

                    if viewModel.results.isEmpty {
                        Text("No users found")
                            .lushyCaption()
                            .glassCard(cornerRadius: 16)
                            .padding(.horizontal, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.results) { user in
                                    NavigationLink(value: user) {
                                        userRow(user: user)
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Search Users")
            .navigationDestination(for: UserSummary.self) { user in
                UserProfileView(viewModel: UserProfileViewModel(currentUserId: currentUserId, targetUserId: user.id))
                    .id(user.id)
            }
        }
    }
    
    // Extract user row into a separate function to simplify the view hierarchy
    @ViewBuilder private func userRow(user: UserSummary) -> some View {
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
                        .fill(LushyPalette.gradientPrimary)
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
                    .fill(LushyPalette.gradientPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(user.name.prefix(1))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }
}

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
                        .onChange(of: searchText) {
                            viewModel.query = searchText
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
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(LushyPalette.gradientPrimary)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Text(user.name.prefix(1))
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                )
                                            VStack(alignment: .leading) {
                                                Text(user.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                if let email = user.email {
                                                    Text(email)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .glassCard(cornerRadius: 16)
                                        .padding(.horizontal, 20)
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
                    .id(user.id) // Ensure view reloads when navigating to different profiles
            }
        }
    }
}

import SwiftUI

struct UserSearchView: View {
    @StateObject var viewModel = UserSearchViewModel()
    let currentUserId: String
    @State private var selectedUser: UserSummary?
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search users by name or email", text: $viewModel.query, onCommit: {
                        viewModel.search()
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    Button(action: { viewModel.search() }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.error {
                    Text(error).foregroundColor(.red)
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    Text("No users found.").foregroundColor(.secondary)
                } else {
                    List(viewModel.results) { user in
                        NavigationLink(value: user) {
                            VStack(alignment: .leading) {
                                Text(user.name).font(.headline)
                                if let email = user.email {
                                    Text(email).font(.subheadline).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Search Users")
            .navigationDestination(for: UserSummary.self) { user in
                UserProfileView(viewModel: UserProfileViewModel(currentUserId: currentUserId, targetUserId: user.id))
            }
        }
    }
}

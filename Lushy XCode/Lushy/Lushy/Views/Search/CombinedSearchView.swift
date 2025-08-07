import SwiftUI

struct CombinedSearchView: View {
    @StateObject var viewModel = CombinedSearchViewModel()
    let currentUserId: String

    // Subview for user row
    @ViewBuilder private func userRow(_ user: UserSummary) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LushyPalette.gradientPrimary)
                .frame(width: 44, height: 44)
                .overlay(Text(user.name.prefix(1)).font(.headline).fontWeight(.semibold).foregroundColor(.white))
            VStack(alignment: .leading) {
                Text(user.name).font(.subheadline).fontWeight(.medium)
                if let email = user.email {
                    Text(email).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }

    // Subview for product row
    @ViewBuilder private func productRow(_ product: ProductSearchSummary) -> some View {
        HStack(spacing: 12) {
            if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                    .frame(width: 44, height: 44).cornerRadius(8)
            } else {
                Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 44, height: 44).cornerRadius(8)
            }
            VStack(alignment: .leading) {
                Text(product.productName).font(.subheadline).fontWeight(.medium)
                if let brand = product.brand { Text(brand).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
        }
        .padding()
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search field
            TextField("Search users or products...", text: $viewModel.query)
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .onChange(of: viewModel.query) { _ in viewModel.search() }
                .onSubmit { viewModel.search() }

            // Results or states
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LushyPalette.pink))
                    .scaleEffect(1.2)
            } else if let err = viewModel.error {
                Text(err)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            } else if viewModel.userResults.isEmpty && viewModel.productResults.isEmpty {
                Text("No results found")
                    .lushyCaption()
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Users section
                        if !viewModel.userResults.isEmpty {
                            Text("Users").font(.headline).padding(.top)
                            ForEach(viewModel.userResults) { user in
                                NavigationLink(destination: UserProfileView(viewModel: UserProfileViewModel(currentUserId: currentUserId, targetUserId: user.id))) {
                                    userRow(user)
                                }
                            }
                        }
                        // Products section
                        if !viewModel.productResults.isEmpty {
                            Text("Products").font(.headline).padding(.top)
                            ForEach(viewModel.productResults, id: \.id) { prod in
                                NavigationLink(destination: ProductSlideshowView(products: [prod], currentUserId: currentUserId)) {
                                    productRow(prod)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                // Debug count
                Text("Found \(viewModel.productResults.count) products")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            Spacer()
        }
        .padding(.top, 20)
        .background(
            Color.clear
                .pastelBackground()
                .ignoresSafeArea()
        )
        // NavigationStack and title provided by parent ContentView
        // Explicit NavigationLink(destination:) handles navigation push
    }
}

struct ProductSlideshowView: View {
    let products: [ProductSearchSummary]
    let currentUserId: String
    @State private var currentPage: Int = 0
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(products.indices, id: \.self) { idx in
                    let p = products[idx]
                    AsyncImage(url: URL(string: p.imageUrl ?? "")) { img in img.resizable().scaledToFit() }
                        placeholder: { Color.gray.opacity(0.3) }
                        .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle())
            .frame(height: 300) // fixed height to prevent infinite layout

            VStack(alignment: .leading, spacing: 8) {
                Text(products.first?.productName ?? "").font(.title2).fontWeight(.bold)
                if let brand = products.first?.brand {
                    Text(brand).font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding()
            Spacer()
        }
        .navigationTitle(products.first?.productName ?? "Product")
    }
}

struct CombinedSearchView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedSearchView(currentUserId: "test")
    }
}
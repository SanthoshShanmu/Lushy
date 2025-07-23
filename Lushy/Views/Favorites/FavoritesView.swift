import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @State private var showProductDetail = false
    @State private var selectedProduct: UserProduct? = nil

    var body: some View {
        ZStack {
            Color.clear.pastelBackground()

            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.favoriteProducts.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "star")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LushyPalette.gradientPrimary)
                                Text("You haven't added any favorites yet. Mark products as favorite in your bag.")
                                    .lushyCaption()
                                    .multilineTextAlignment(.center)
                            }
                            .glassCard(cornerRadius: 20)
                            .padding()
                        } else {
                            ForEach(viewModel.favoriteProducts) { product in
                                PrettyProductRow(product: product)
                                    .glassCard(cornerRadius: 16)
                                    .onTapGesture {
                                        selectedProduct = product
                                        showProductDetail = true
                                    }
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .navigationTitle("Favorites")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Section("Filter by Bag") {
                                Button("All Bags", action: { viewModel.setBagFilter(nil) })
                                ForEach(viewModel.allBags, id: \.self) { bag in
                                    Button(action: { viewModel.setBagFilter(bag) }) {
                                        Label(bag.name ?? "Unnamed Bag", systemImage: bag.icon ?? "bag.fill")
                                    }
                                }
                            }

                            Section("Filter by Tag") {
                                Button("All Tags", action: { viewModel.setTagFilter(nil) })
                                ForEach(viewModel.allTags, id: \.self) { tag in
                                    Button(action: { viewModel.setTagFilter(tag) }) {
                                        Label(tag.name ?? "Unnamed Tag", systemImage: "tag")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .neumorphicButtonStyle()
                    }
                }
                .onAppear {
                    viewModel.fetchFavorites()
                }
                .sheet(isPresented: $showProductDetail) {
                    if let product = selectedProduct {
                        ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                    }
                }
            }
        }
    }
}

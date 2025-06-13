import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @State private var showProductDetail = false
    @State private var selectedProduct: UserProduct? = nil
    
    var body: some View {
        ZStack {
            BubblyBackground()
            NavigationView {
                List {
                    if viewModel.favoriteProducts.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "star")
                                .font(.system(size: 40))
                                .foregroundColor(.lushyPink)
                            Text("You haven't added any favorites yet. Mark products as favorite in your bag.")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .bubblyCard()
                    } else {
                        ForEach(viewModel.favoriteProducts) { product in
                            PrettyProductRow(product: product)
                                .bubblyCard()
                                .onTapGesture {
                                    selectedProduct = product
                                    showProductDetail = true
                                }
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .navigationTitle("Favorites")
                .sheet(isPresented: $showProductDetail) {
                    if let product = selectedProduct {
                        ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                            .onAppear {
                                // Ensure the view is fully loaded with product data
                                DispatchQueue.main.async {
                                    // Force view to refresh if needed
                                    viewModel.objectWillChange.send()
                                }
                            }
                    }
                }
                .onAppear {
                    viewModel.fetchFavorites()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            // Bag filter
                            Menu {
                                Button("All Bags", action: { viewModel.setBagFilter(nil) })
                                ForEach(viewModel.allBags, id: \.self) { bag in
                                    Button(action: { viewModel.setBagFilter(bag) }) {
                                        Label(bag.name ?? "Unnamed Bag", systemImage: bag.icon ?? "bag.fill")
                                    }
                                }
                            } label: {
                                Label(viewModel.selectedBag?.name ?? "All Bags", systemImage: "bag")
                            }
                            // Tag filter
                            Menu {
                                Button("All Tags", action: { viewModel.setTagFilter(nil) })
                                ForEach(viewModel.allTags, id: \.self) { tag in
                                    Button(action: { viewModel.setTagFilter(tag) }) {
                                        Label(tag.name ?? "Unnamed Tag", systemImage: "tag")
                                    }
                                }
                            } label: {
                                Label(viewModel.selectedTag?.name ?? "All Tags", systemImage: "tag")
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18))
                                .foregroundColor(.lushyPurple)
                                .padding(10)
                                .background(Color.lushyPurple.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
    }
}

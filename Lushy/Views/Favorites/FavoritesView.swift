import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel
    @State private var showProductDetail = false
    @State private var selectedProduct: UserProduct? = nil
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.favoriteProducts.isEmpty {
                    Text("You haven't added any favorites yet. Mark products as favorite in your bag.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(viewModel.favoriteProducts) { product in
                        ProductRow(product: product)
                            .onTapGesture {
                                selectedProduct = product
                                showProductDetail = true
                            }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Favorites")
            .sheet(isPresented: $showProductDetail, onDismiss: {
                selectedProduct = nil
            }) {
                if let product = selectedProduct {
                    ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                }
            }
            .onAppear {
                viewModel.fetchFavorites()
            }
        }
    }
}
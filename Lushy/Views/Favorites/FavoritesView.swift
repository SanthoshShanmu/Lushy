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
                    // Ensure we have the latest data for this product
                    if let refreshedProduct = try? CoreDataManager.shared.viewContext.existingObject(with: product.objectID) as? UserProduct {
                        ProductDetailView(viewModel: ProductDetailViewModel(product: refreshedProduct))
                    } else {
                        // Fallback to the selected product if refresh fails
                        ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                    }
                }
            }
            .onAppear {
                viewModel.fetchFavorites()
            }
        }
    }
}

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var showOpenProducts = true
    @State private var showExpiringProducts = true
    @State private var showStoredProducts = true
    
    var body: some View {
        NavigationView {
            List {
                if !viewModel.openProducts.isEmpty && showOpenProducts {
                    Section(header: Text("Open Products")) {
                        ForEach(viewModel.openProducts) { product in
                            ProductRow(product: product)
                                .onTapGesture {
                                    viewModel.selectedProduct = product
                                    viewModel.showProductDetail = true
                                }
                            }
                    }
                }
                
                if !viewModel.expiringProducts.isEmpty && showExpiringProducts {
                    Section(header: Text("Expiring Soon")) {
                        ForEach(viewModel.expiringProducts) { product in
                            ProductRow(product: product)
                                .onTapGesture {
                                    viewModel.selectedProduct = product
                                    viewModel.showProductDetail = true
                                }
                            }
                    }
                }
                
                if !viewModel.storedProducts.isEmpty && showStoredProducts {
                    Section(header: Text("In Storage")) {
                        ForEach(viewModel.storedProducts) { product in
                            ProductRow(product: product)
                                .onTapGesture {
                                    viewModel.selectedProduct = product
                                    viewModel.showProductDetail = true
                                }
                            }
                    }
                }
                
                if viewModel.openProducts.isEmpty && viewModel.expiringProducts.isEmpty && viewModel.storedProducts.isEmpty {
                    Text("No products yet. Tap the Scanner tab to add your first product!")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("My Bag")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Open Products", isOn: $showOpenProducts)
                        Toggle("Expiring Soon", isOn: $showExpiringProducts) 
                        Toggle("In Storage", isOn: $showStoredProducts)
                    } label: {
                        Label("Filter", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showProductDetail, onDismiss: {
                viewModel.selectedProduct = nil
            }) {
                if let product = viewModel.selectedProduct {
                    ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                }
            }
            .onAppear {
                viewModel.fetchProducts()
            }
        }
    }
}
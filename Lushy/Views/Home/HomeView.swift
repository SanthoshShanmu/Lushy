import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var showOpenProducts = true
    @State private var showExpiringProducts = true
    @State private var showStoredProducts = true
    @State private var showBagFilterMenu = false
    @State private var showTagFilterMenu = false
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                homeContent
            }
        } else {
            NavigationView {
                homeContent
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                HStack {
                    Text("My Beauty Bag")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Menu {
                        Toggle("Open Products", isOn: $showOpenProducts)
                        Toggle("Expiring Soon", isOn: $showExpiringProducts)
                        Toggle("In Storage", isOn: $showStoredProducts)
                        Divider()
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
                .padding(.horizontal, 20)
                .padding(.top, 15)
                
                if !viewModel.openProducts.isEmpty && showOpenProducts {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Open Products")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                        
                        ForEach(viewModel.openProducts) { product in
                            PrettyProductRow(product: product)
                                .contentShape(Rectangle())  // Makes the entire row tappable
                                .onTapGesture {
                                    viewModel.selectedProduct = product
                                    viewModel.showProductDetail = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        confirmDeleteProduct(product)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                if !viewModel.expiringProducts.isEmpty && showExpiringProducts {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Expiring Soon")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                        
                        ForEach(viewModel.expiringProducts) { product in
                            PrettyProductRow(product: product)
                                .contentShape(Rectangle())  // Makes the entire row tappable
                                .onTapGesture {
                                    viewModel.selectedProduct = product
                                    viewModel.showProductDetail = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        confirmDeleteProduct(product)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                if !viewModel.storedProducts.isEmpty && showStoredProducts {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("In Storage")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                        
                        ForEach(viewModel.storedProducts) { product in
                            PrettyProductRow(product: product)
                                .contentShape(Rectangle())  // Makes the entire row tappable
                                .onTapGesture {
                                    viewModel.selectedProduct = product
                                    viewModel.showProductDetail = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        confirmDeleteProduct(product)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                if viewModel.openProducts.isEmpty && viewModel.expiringProducts.isEmpty && viewModel.storedProducts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(.lushyPink)
                            .padding()
                            .background(Circle().fill(Color.lushyPink.opacity(0.1)))
                        
                        Text("No products yet!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap the Scanner tab to add your first product")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        NavigationLink(destination: ScannerView(viewModel: ScannerViewModel())) {
                            Text("Start Scanning")
                                .padding()
                                .frame(width: 200)
                                .background(Color.lushyPink)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color.lushyPink.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.top, 10)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.lushyBackground.opacity(0.3).edgesIgnoringSafeArea(.all))
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
    
    private func confirmDeleteProduct(_ product: UserProduct) {
        let alert = UIAlertController(
            title: "Delete \(product.productName ?? "Product")?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            viewModel.deleteProduct(product: product)
        })
        
        // Get the UIWindow to present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

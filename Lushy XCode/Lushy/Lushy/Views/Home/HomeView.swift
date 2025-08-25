import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var selectedTab: Tab
    @State private var showOpenProducts = true
    @State private var showExpiringProducts = true
    @State private var showStoredProducts = true
    @State private var showBagFilterMenu = false
    @State private var showTagFilterMenu = false
    @State private var sparkleAnimation = false
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // All Products entry if desired
                        // Individual bag entries
                        ForEach(viewModel.allBags, id: \.self) { bag in
                            NavigationLink(destination: BeautyBagDetailView(bag: bag)) {
                                VStack(spacing: 8) {
                                    Image(systemName: bag.icon ?? "bag.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.mossGreen)
                                    Text(bag.name ?? "Unnamed Bag")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.lushyCream.opacity(0.3)))
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Select a Beauty Bag")
                .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.allBags, id: \.self) { bag in
                            NavigationLink(destination: BeautyBagDetailView(bag: bag)) {
                                VStack(spacing: 8) {
                                    Image(systemName: bag.icon ?? "bag.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.mossGreen)
                                    Text(bag.name ?? "Unnamed Bag")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.lushyCream.opacity(0.3)))
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Select a Beauty Bag")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    @ViewBuilder
    private func productSection(title: String, subtitle: String, products: [UserProduct], accentColor: Color) -> some View {
        // group duplicates
        let grouped = Dictionary(grouping: products, by: { $0.barcode ?? $0.productName ?? UUID().uuidString })
        let items = grouped.map { (key, group) in (product: group.first!, count: group.count) }

        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(products.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                ForEach(items, id: \ .product.objectID) { item in
                    ZStack(alignment: .topTrailing) {
                        PrettyProductRow(product: item.product)
                        if item.count > 1 {
                            Text("×\(item.count)")
                                .font(.caption2)
                                .padding(6)
                                .background(Circle().fill(Color.lushyPink))
                                .foregroundColor(.white)
                                .offset(x: -8, y: 8)
                        }
                    }
                    .bubblyCard(cornerRadius: 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedProduct = item.product
                            viewModel.showProductDetail = true
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            confirmDeleteProduct(item.product)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    .transition(.asymmetric(
                        insertion: .slide.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
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

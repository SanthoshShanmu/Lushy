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
                homeContent
            }
            .sheet(isPresented: $viewModel.showProductDetail) {
                if let product = viewModel.selectedProduct {
                    ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                }
            }
        } else {
            NavigationView {
                homeContent
            }
            .sheet(isPresented: $viewModel.showProductDetail) {
                if let product = viewModel.selectedProduct {
                    ProductDetailView(viewModel: ProductDetailViewModel(product: product))
                }
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        ZStack {
            // Enhanced girly background with sparkles
            Color.lushyBackground
                .ignoresSafeArea()
            
            BubblyBackground()
            
            // Floating sparkles
            ForEach(0..<8, id: \.self) { index in
                SparkleShape()
                    .fill(LinearGradient(
                        colors: [Color.lushyPink, Color.lushyPurple, Color.lushyMint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: CGFloat.random(in: 8...16), height: CGFloat.random(in: 8...16))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: sparkleAnimation
                    )
            }
            
            ScrollView {
                VStack(spacing: 30) {
                    // Enhanced Header with girly styling
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("My Beauty Bag")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.lushyPink, Color.lushyPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .lushyPink.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            Text("✨ Keep your beauty organized")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        // Enhanced filter menu with girly styling
                        Menu {
                            Section("Visibility") {
                                Toggle("Open Products", isOn: $showOpenProducts)
                                Toggle("Expiring Soon", isOn: $showExpiringProducts)
                                Toggle("In Storage", isOn: $showStoredProducts)
                            }
                            
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
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.lushyPink, Color.lushyPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: .lushyPink.opacity(0.3), radius: 8, x: 0, y: 4)
                                .scaleEffect(sparkleAnimation ? 1.05 : 1.0)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    
                    // Product sections with enhanced styling
                    if !viewModel.openProducts.isEmpty && showOpenProducts {
                        productSection(
                            title: "💖 Open Products",
                            subtitle: "Currently using",
                            products: viewModel.openProducts,
                            accentColor: .lushyPink
                        )
                    }
                    
                    if !viewModel.expiringProducts.isEmpty && showExpiringProducts {
                        productSection(
                            title: "⏰ Expiring Soon",
                            subtitle: "Use these first!",
                            products: viewModel.expiringProducts,
                            accentColor: .orange
                        )
                    }
                    
                    if !viewModel.storedProducts.isEmpty && showStoredProducts {
                        productSection(
                            title: "🎀 In Storage",
                            subtitle: "Safely stored away",
                            products: viewModel.storedProducts,
                            accentColor: .lushyMint
                        )
                    }
                    
                    // Add some bottom padding for safe area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 100)
                }
            }
        }
        .onAppear {
            sparkleAnimation.toggle()
        }
    }
    
    @ViewBuilder
    private func productSection(title: String, subtitle: String, products: [UserProduct], accentColor: Color) -> some View {
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
                ForEach(products) { product in
                    PrettyProductRow(product: product)
                        .bubblyCard(cornerRadius: 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedProduct = product
                                viewModel.showProductDetail = true
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                confirmDeleteProduct(product)
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

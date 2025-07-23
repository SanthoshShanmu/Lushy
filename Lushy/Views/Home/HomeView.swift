import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var selectedTab: Tab
    @State private var showingBagOverview = true
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
            Color.clear
            .pastelBackground()
            if showingBagOverview {
                ScrollView {
                    Text("Choose a Beauty Bag")
                        .lushyTitle()
                        .padding(.top, 20)
                    LazyVStack(spacing: 20) {
                        // All Products card
                        VStack(spacing: 12) {
                            Image(systemName: "bag.fill")
                                .font(.largeTitle)
                                .foregroundStyle(LushyPalette.gradientPrimary)
                            
                            Text("All Products")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.lushyCream.opacity(0.3)))
                        .onTapGesture {
                            viewModel.setBagFilter(nil)
                            showingBagOverview = false
                        }
                        
                        // Individual bags
                        ForEach(viewModel.allBags, id: \.self) { bag in
                            VStack(spacing: 8) {
                                Image(systemName: bag.icon ?? "bag.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.lushyMint)
                                
                                Text(bag.name ?? "Unnamed")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.lushyCream.opacity(0.3)))
                            .onTapGesture {
                                viewModel.setBagFilter(bag)
                                showingBagOverview = false
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Color.clear.pastelBackground()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Enhanced Header with girly styling
                        HStack {
                            if !showingBagOverview {
                                Button(action: { showingBagOverview = true }) {
                                    Image(systemName: "chevron.left")
                                        .font(.title2)
                                        .foregroundColor(LushyPalette.pink)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(showingBagOverview ? "My Beauty Bag" : (viewModel.selectedBag?.name ?? "All Products"))
                                    .lushyTitle()
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
                            }
                            .neumorphicButtonStyle()
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
                            .glassCard(cornerRadius: 22)
                        }
                        
                        if !viewModel.expiringProducts.isEmpty && showExpiringProducts {
                            productSection(
                                title: "⏰ Expiring Soon",
                                subtitle: "Use these first!",
                                products: viewModel.expiringProducts,
                                accentColor: .orange
                            )
                            .glassCard(cornerRadius: 22)
                        }
                        
                        if !viewModel.storedProducts.isEmpty && showStoredProducts {
                            productSection(
                                title: "🎀 In Storage",
                                subtitle: "Safely stored away",
                                products: viewModel.storedProducts,
                                accentColor: .lushyMint
                            )
                            .glassCard(cornerRadius: 22)
                        }
                        
                        // Add some bottom padding for safe area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 100)
                    }
                }
            }
        }
        .onAppear {
            sparkleAnimation.toggle()
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

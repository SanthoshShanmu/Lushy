import SwiftUI
import CoreData

struct BeautyBagDetailView: View {
    let bag: BeautyBag
    @StateObject private var viewModel = BeautyBagViewModel()
    @StateObject private var productViewModel = UserProductViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingAddProducts = false
    @State private var showingEditBag = false
    @State private var showingDeleteAlert = false
    
    var bagProducts: [UserProduct] {
        viewModel.products(in: bag)
    }
    
    var body: some View {
        // Extract all complex expressions to computed properties
        let bagColor = Color(bag.color ?? "lushyPink")
        let gradientColors = [
            bagColor.opacity(0.08),
            Color.lushyPurple.opacity(0.04),
            Color.lushyCream.opacity(0.3),
            Color.white
        ]
        let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Extract icon/image display logic to reduce complexity
        let iconBackgroundColor = bagColor.opacity(0.15)
        let iconForegroundColor = bagColor
        
        return ZStack {
            backgroundGradient.ignoresSafeArea()
            mainScrollContent(iconBackgroundColor: iconBackgroundColor, iconForegroundColor: iconForegroundColor)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditBag = true }) {
                        Label("Edit Bag", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete Bag", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(Color(bag.color ?? "lushyPink"))
                }
            }
        }
        .sheet(isPresented: $showingAddProducts) {
            AddProductsToBagView(bag: bag, viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditBag) {
            ModernEditBagSheet(viewModel: viewModel, bag: bag)
        }
        .alert("Delete Bag", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteBag(bag)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this bag? This action cannot be undone.")
        }
        .onAppear {
            viewModel.fetchBags()
            productViewModel.fetchUserProducts()
        }
    }
    
    // Extract main scroll content to reduce complexity
    private func mainScrollContent(iconBackgroundColor: Color, iconForegroundColor: Color) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection(iconBackgroundColor: iconBackgroundColor, iconForegroundColor: iconForegroundColor)
                productsSection
                Spacer(minLength: 100)
            }
        }
    }
    
    // Extract header section
    private func headerSection(iconBackgroundColor: Color, iconForegroundColor: Color) -> some View {
        VStack(spacing: 16) {
            bagIconView(iconBackgroundColor: iconBackgroundColor, iconForegroundColor: iconForegroundColor)
            bagInfoSection
            statsSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // Extract bag info section
    private var bagInfoSection: some View {
        VStack(spacing: 8) {
            Text(bag.name ?? "Unnamed Bag")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(bag.color ?? "lushyPink"), .lushyPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
            
            if let description = bag.bagDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if bag.isPrivate {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("Private Bag")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // Extract stats section
    private var statsSection: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(bagProducts.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(bag.color ?? "lushyPink"))
                Text("Products")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 30)
            
            VStack(spacing: 4) {
                Text(bag.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text("Created")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color(bag.color ?? "lushyPink").opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // Extract products section
    private var productsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Products in this bag")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showingAddProducts = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(bag.color ?? "lushyPink"), .lushyPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color(bag.color ?? "lushyPink").opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 24)
            
            if bagProducts.isEmpty {
                emptyStateView
            } else {
                productsGridView
            }
        }
    }
    
    // Extract empty state
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No products in this bag yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { showingAddProducts = true }) {
                Text("Add your first product")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(bag.color ?? "lushyPink"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(bag.color ?? "lushyPink"), lineWidth: 1.5)
                            .background(Color(bag.color ?? "lushyPink").opacity(0.05))
                    )
            }
        }
        .padding(.vertical, 40)
    }
    
    // Extract products grid
    private var productsGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 16) {
            ForEach(bagProducts, id: \.self) { product in
                BagProductCard(product: product, bag: bag, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // Extracted bag icon view
    private func bagIconView(iconBackgroundColor: Color, iconForegroundColor: Color) -> some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 120, height: 120)
            
            if let imageData = bag.imageData, let customImage = UIImage(data: imageData) {
                Image(uiImage: customImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
            } else if let icon = bag.icon, icon.count == 1 {
                Text(icon)
                    .font(.system(size: 50))
            } else {
                Image(systemName: bag.icon ?? "bag.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(iconForegroundColor)
            }
        }
    }
}

// MARK: - Bag Product Card
struct BagProductCard: View {
    let product: UserProduct
    let bag: BeautyBag
    @ObservedObject var viewModel: BeautyBagViewModel
    @State private var showingRemoveAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Product image
            AsyncImage(url: URL(string: product.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Product info
            VStack(spacing: 6) {
                Text(product.productName ?? "Unknown Product")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Remove rating display since UserProduct doesn't have rating property
                // Rating functionality would need to be implemented separately if needed
            }
        }
        .padding(12)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .contextMenu {
            Button(action: { showingRemoveAlert = true }) {
                Label("Remove from bag", systemImage: "minus.circle")
            }
        }
        .alert("Remove Product", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                viewModel.removeProduct(product, from: bag)
            }
        } message: {
            Text("Remove \(product.productName ?? "this product") from \(bag.name ?? "this bag")?")
        }
    }
}

// MARK: - Add Products to Bag View
struct AddProductsToBagView: View {
    let bag: BeautyBag
    @ObservedObject var viewModel: BeautyBagViewModel
    @StateObject private var productViewModel = UserProductViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var selectedProducts: Set<UserProduct> = []
    
    var filteredProducts: [UserProduct] {
        let bagProductIDs = Set(viewModel.products(in: bag).map { $0.objectID })
        let availableProducts = productViewModel.userProducts.filter { !bagProductIDs.contains($0.objectID) }
        
        if searchText.isEmpty {
            return availableProducts
        } else {
            return availableProducts.filter { product in
                (product.productName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (product.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search products...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Products list
                if filteredProducts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "No products available to add" : "No products found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Add some products to your collection first")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProducts, id: \.self) { product in
                                ProductSelectionRow(
                                    product: product,
                                    isSelected: selectedProducts.contains(product),
                                    onToggle: {
                                        if selectedProducts.contains(product) {
                                            selectedProducts.remove(product)
                                        } else {
                                            selectedProducts.insert(product)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                
                // Add button
                if !selectedProducts.isEmpty {
                    Button(action: {
                        for product in selectedProducts {
                            viewModel.addProduct(product, to: bag)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Add \(selectedProducts.count) Product\(selectedProducts.count == 1 ? "" : "s")")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(bag.color ?? "lushyPink"), .lushyPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Add Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            productViewModel.fetchUserProducts()
        }
    }
}

// MARK: - Product Selection Row
struct ProductSelectionRow: View {
    let product: UserProduct
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Product image
            AsyncImage(url: URL(string: product.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName ?? "Unknown Product")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Remove rating display since UserProduct doesn't have rating property
                // Rating functionality would need to be implemented separately if needed
            }
            
            Spacer()
            
            // Selection indicator
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .lushyPink : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.lushyPink.opacity(0.1) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.lushyPink : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            onToggle()
        }
    }
}
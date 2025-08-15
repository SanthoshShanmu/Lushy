import SwiftUI

struct FinishedProductsView: View {
    @StateObject private var viewModel = FinishedProductsViewModel()
    @State private var selectedProduct: UserProduct?
    @State private var showProductDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.1),
                        Color.lushyPurple.opacity(0.05),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.finishedProducts.isEmpty {
                            emptyStateView
                        } else {
                            // Header with count
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("✅ Finished Products")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.lushyPeach, .lushyPink],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        
                                        Text("\(viewModel.finishedProducts.count) completed product\(viewModel.finishedProducts.count == 1 ? "" : "s")")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 20)
                                
                                // Product list
                                LazyVStack(spacing: 16) {
                                    ForEach(viewModel.finishedProducts, id: \.objectID) { product in
                                        FinishedProductCard(product: product)
                                            .environmentObject(viewModel)
                                            .onTapGesture {
                                                selectedProduct = product
                                                showProductDetail = true
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Finished Products")
            .navigationBarTitleDisplayMode(.inline)
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
                                    HStack {
                                        Circle()
                                            .fill(Color(tag.color ?? "lushyPink"))
                                            .frame(width: 12, height: 12)
                                        Text(tag.name ?? "Unnamed Tag")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundColor(.lushyPink)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(viewModel: ProductDetailViewModel(product: product))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.lushyPeach.opacity(0.3), .lushyPink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.lushyPeach)
                }
                
                VStack(spacing: 8) {
                    Text("No Finished Products Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Products you've finished using will appear here. Keep using your products to build your completion history!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Finished Product Card
private struct FinishedProductCard: View {
    let product: UserProduct
    @EnvironmentObject private var viewModel: FinishedProductsViewModel
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Product image
            ZStack {
                AsyncImage(url: URL(string: product.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.lushyPink.opacity(0.3), .lushyPurple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 24))
                                .foregroundColor(.lushyPink.opacity(0.5))
                        )
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Show finished instances count (not total quantity)
                let finishedCount = viewModel.finishedInstancesCount(for: product)
                if finishedCount > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("×\(finishedCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                )
                                .offset(x: 8, y: -8)
                        }
                        Spacer()
                    }
                }
            }
            
            // Product info
            VStack(alignment: .leading, spacing: 6) {
                // Brand
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.lushyPurple)
                        .tracking(0.5)
                }
                
                // Product name
                Text(product.productName ?? "Unnamed Product")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Finish date
                if let finishDate = product.finishDate {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Finished \(dateString(finishDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show finished instances count if more than 1
                let finishedCount = viewModel.finishedInstancesCount(for: product)
                if finishedCount > 1 {
                    Text("Finished: \(finishedCount) times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            Spacer()
            
            // Completion indicator
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 30, height: 30)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.green.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    FinishedProductsView()
}
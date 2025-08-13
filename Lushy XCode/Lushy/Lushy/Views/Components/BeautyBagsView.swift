import SwiftUI

struct BeautyBagsView: View {
    @StateObject private var viewModel = BeautyBagViewModel()
    @State private var showingAddBag = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.bags, id: \.self) { bag in
                    NavigationLink(destination: BeautyBagDetailView(bag: bag)) {
                        HStack {
                            Image(systemName: bag.icon ?? "bag.fill")
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                                .padding(8)
                                .background(Circle().fill(Color(bag.color ?? "lushyPink").opacity(0.12)))
                            Text(bag.name ?? "Unnamed Bag")
                        }
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.lushyPink.opacity(0.06), radius: 3, x: 0, y: 2)
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { viewModel.bags[$0] }.forEach(viewModel.deleteBag)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color.lushyBackground.opacity(0.2))
            .navigationTitle("Beauty Bags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddBag = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.lushyPink)
                            .padding(8)
                            .background(Circle().fill(Color.lushyPink.opacity(0.12)))
                    }
                }
            }
            .sheet(isPresented: $showingAddBag) {
                AddBagSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.fetchBags()
            }
        }
    }
}

struct AddBagSheet: View {
    @ObservedObject var viewModel: BeautyBagViewModel
    @Environment(\.presentationMode) var presentationMode
    let iconOptions = ["bag.fill", "shippingbox.fill", "case.fill", "suitcase.fill", "heart.fill", "star.fill"]
    let colorOptions = ["lushyPink", "lushyPurple", "lushyMint", "lushyPeach"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bag Details")) {
                    TextField("Bag Name", text: $viewModel.newBagName)
                    Picker("Icon", selection: $viewModel.newBagIcon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Label(icon, systemImage: icon)
                        }
                    }
                    Picker("Color", selection: $viewModel.newBagColor) {
                        ForEach(colorOptions, id: \.self) { color in
                            Text(color.capitalized)
                        }
                    }
                }
                Section {
                    Button("Create Bag") {
                        viewModel.createBag()
                        presentationMode.wrappedValue.dismiss()
                    }.disabled(viewModel.newBagName.isEmpty)
                }
            }
            .navigationTitle("New Beauty Bag")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct BeautyBagDetailView: View {
    let bag: BeautyBag
    @StateObject private var viewModel = BeautyBagViewModel()
    @State private var showHowToAdd = false
    // Inject shared tab selection so we can switch tabs directly
    @EnvironmentObject private var tabSelection: TabSelection
    @Environment(\.dismiss) private var dismiss

    // Empty state view
    @ViewBuilder private var emptyStateView: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.lushyPink.opacity(0.15), .lushyPurple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                Image(systemName: "bag.badge.plus")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundColor(.lushyPink)
            }
            VStack(spacing: 8) {
                Text("This bag is feeling a little empty ✨")
                    .font(.title3).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Start by scanning a product barcode or add one manually to curate your collection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            HStack(spacing: 14) {
                Button(action: {
                    // Directly switch to the Scan tab instead of using NotificationCenter
                    withAnimation { tabSelection.selected = .scan }
                    // Dismiss this detail view after switching tabs
                    dismiss()
                }) {
                    Label("Scan Product", systemImage: "barcode.viewfinder")
                        .padding(.vertical, 14).padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [.lushyPink, .lushyPurple], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Button(action: { showHowToAdd = true }) {
                    Label("How to Add", systemImage: "questionmark.circle")
                        .padding(.vertical, 14).padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color.lushyPink.opacity(0.12))
                        .foregroundColor(.lushyPink)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showHowToAdd) {
            VStack(spacing: 24) {
                Text("Adding Products")
                    .font(.title2).fontWeight(.bold)
                VStack(alignment: .leading, spacing: 16) {
                    Label("Tap Scan tab to scan a barcode and auto‑fill details.", systemImage: "barcode.viewfinder")
                    Label("Or use Manual Entry from the scanner for products without barcodes.", systemImage: "square.and.pencil")
                    Label("After adding, assign it to this bag in the product detail screen.", systemImage: "bag")
                }
                .font(.callout)
                .foregroundColor(.secondary)
                Button("Got it") { showHowToAdd = false }
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.lushyPink))
                    .foregroundColor(.white)
            }
            .padding(30)
            .presentationDetents([.medium])
        }
    }

    var body: some View {
        let products = viewModel.products(in: bag)
        Group {
            if products.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(products, id: \.self) { product in
                            NavigationLink(destination: ProductDetailView(viewModel: ProductDetailViewModel(product: product))) {
                                PrettyProductRow(product: product)
                                    .frame(height: 80)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(bag.name ?? "Bag")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchBags()
            SyncService.shared.fetchRemoteProducts()
        }
    }
}

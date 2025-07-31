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
    let colorOptions = ["lushyPink", "lushyPurple", "lushyMint", "lushyPeach", "blue", "green"]

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
    @State private var isGridView: Bool = false

    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            Picker("", selection: $isGridView) {
                Label("List", systemImage: "list.bullet").tag(false)
                Label("Grid", systemImage: "square.grid.2x2.fill").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            if isGridView {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(viewModel.products(in: bag), id: \.self) { product in
                            NavigationLink(destination: ProductDetailView(viewModel: ProductDetailViewModel(product: product))) {
                                VStack(spacing: 8) {
                                    // Optional thumbnail image
                                    if let imageUrl = product.imageUrl,
                                       let url = URL(string: imageUrl), url.isFileURL,
                                       let uiImage = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    Text(product.productName ?? "Unnamed Product")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.products(in: bag), id: \.self) { product in
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
         }
     }
 }

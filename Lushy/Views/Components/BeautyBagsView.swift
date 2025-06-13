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

    var body: some View {
        List {
            ForEach(viewModel.products(in: bag), id: \.self) { product in
                Text(product.productName ?? "Unnamed Product")
            }
        }
        .navigationTitle(bag.name ?? "Bag")
        .onAppear {
            viewModel.fetchBags()
        }
    }
}

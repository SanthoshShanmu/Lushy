import SwiftUI

struct WishlistView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @State private var showingAddItemSheet = false
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.wishlistItems.isEmpty {
                    Text("Your wishlist is empty. Tap the + button to add items.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(viewModel.wishlistItems) { item in
                        WishlistItemRow(item: item)
                    }
                    .onDelete { indexSet in
                        viewModel.removeItem(at: indexSet)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Wishlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddItemSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddWishlistItemView(viewModel: viewModel)
            }
            .overlay(
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading wishlist...")
                            .padding()
                            .background(Color.secondary.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        VStack {
                            Spacer()
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(10)
                                .padding()
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        viewModel.errorMessage = nil
                                    }
                                }
                        }
                    }
                }
            )
            .onAppear {
                viewModel.fetchWishlistItems()
            }
        }
    }
}

struct WishlistItemRow: View {
    let item: WishlistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.productName)
                .font(.headline)
            
            if let url = URL(string: item.productURL) {
                Link(destination: url) {
                    Text(item.productURL)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 5)
    }
}

struct AddWishlistItemView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    TextField("Product Name", text: $viewModel.newProductName)
                    
                    TextField("Product URL", text: $viewModel.newProductURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    ZStack(alignment: .topLeading) {
                        if viewModel.newProductNotes.isEmpty {
                            Text("Notes (optional)")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $viewModel.newProductNotes)
                            .frame(minHeight: 100)
                    }
                }
                
                Section {
                    Button(action: {
                        viewModel.addWishlistItem()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Add to Wishlist")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(viewModel.newProductName.isEmpty || viewModel.newProductURL.isEmpty)
                }
            }
            .navigationTitle("Add to Wishlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
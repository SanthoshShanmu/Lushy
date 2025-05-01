import SwiftUI

struct ManualEntryView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Barcode", text: $viewModel.manualBarcode)
                        .keyboardType(.numberPad)
                    
                    TextField("Product Name", text: $viewModel.manualProductName)
                    
                    TextField("Brand", text: $viewModel.manualBrand)
                } header: {
                    Text("Product Details")
                }
                
                Section {
                    DatePicker("Purchase Date", selection: $viewModel.purchaseDate, displayedComponents: .date)
                    
                    Toggle("Product is already open", isOn: $viewModel.isProductOpen)
                    
                    if viewModel.isProductOpen {
                        DatePicker(
                            "Open Date",
                            selection: Binding(
                                get: { viewModel.openDate ?? Date() },
                                set: { viewModel.openDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Usage Information")
                }
                
                Section {
                    Button(action: {
                        if viewModel.manualBarcode.isEmpty || viewModel.manualProductName.isEmpty {
                            showingErrorAlert = true
                            return
                        }
                        
                        if let _ = viewModel.saveProduct() {
                            showingSuccessAlert = true
                        } else {
                            showingErrorAlert = true
                        }
                    }) {
                        Text("Save Product")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    
                    Button(action: {
                        // Try to look up product by barcode if entered
                        if !viewModel.manualBarcode.isEmpty {
                            viewModel.fetchProduct(barcode: viewModel.manualBarcode)
                        }
                    }) {
                        Text("Look Up by Barcode")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.green)
                    .disabled(viewModel.manualBarcode.isEmpty)
                }
            }
            .navigationTitle("Manual Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showingSuccessAlert) {
                Alert(
                    title: Text("Product Added"),
                    message: Text("The product has been added to your bag."),
                    dismissButton: .default(Text("OK")) {
                        viewModel.reset()
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .overlay(
                Group {
                    if viewModel.isLoading {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .overlay(
                                ProgressView("Fetching product information...")
                                    .padding()
                                    .background(Color.secondary.opacity(0.7))
                                    .cornerRadius(10)
                            )
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
        }
    }
}

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView(viewModel: ScannerViewModel())
    }
}

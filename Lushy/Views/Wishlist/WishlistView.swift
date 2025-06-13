import Foundation
import SwiftUI

struct WishlistView: View {
    @StateObject private var viewModel = WishlistViewModel()
    @State private var showingAddItem = false
    @State private var showingLoginPrompt = false
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            VStack {
                if !authManager.isAuthenticated {
                    // Show login prompt if not authenticated
                    VStack(spacing: 20) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.lushyPink)
                        
                        Text("Login Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please log in to view your wishlist")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Login") {
                            showingLoginPrompt = true
                        }
                        .buttonStyle(LushyButtonStyle(backgroundColor: .lushyPink, foregroundColor: .white))
                    }
                    .padding()
                } else if viewModel.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading wishlist...")
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Oops!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            viewModel.fetchWishlist()
                        }
                        .buttonStyle(LushyButtonStyle(backgroundColor: .lushyPink, foregroundColor: .white))
                    }
                    .padding()
                } else if viewModel.wishlistItems.isEmpty {
                    // Empty state view
                    VStack(spacing: 20) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.lushyPink)
                        
                        Text("Your Wishlist is Empty")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Items you add to your wishlist will appear here")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // Your wishlist items display
                    List {
                        ForEach(viewModel.wishlistItems) { item in
                            WishlistItemRow(item: item)
                        }
                        .onDelete(perform: viewModel.removeItem)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isAuthenticated {
                        Button(action: { showingAddItem = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddWishlistItemView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingLoginPrompt) {
                LoginView(isLoggedIn: .constant(false))
                    .environmentObject(authManager)
                    .onDisappear {
                        if authManager.isAuthenticated {
                            // Add a short delay to ensure the token is properly saved
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                print("Login sheet dismissed, refreshing wishlist with token: \(AuthService.shared.token ?? "none")")
                                viewModel.fetchWishlist()
                            }
                        }
                    }
            }
        }
        .onAppear {
            // Debug print to check auth state
            print("WishlistView appeared, authenticated: \(authManager.isAuthenticated), token: \(AuthService.shared.token ?? "none")")
            if authManager.isAuthenticated {
                viewModel.fetchWishlist()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AuthenticationFailed"))) { _ in
            showingLoginPrompt = true
        }
    }
}

struct WishlistItemRow: View {
    let item: AppWishlistItem
    
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
                    }
                    .buttonStyle(LushyButtonStyle(backgroundColor: .lushyPink, foregroundColor: .white, isLarge: true))
                    .listRowBackground(Color.clear)
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

import Foundation
import SwiftUI

struct WishlistView: View {
    @StateObject private var viewModel = WishlistViewModel()
    @State private var showingLoginPrompt = false
    @State private var showingProductNotFound = false
    @State private var productNotFoundMessage = ""
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.pastelBackground()

                VStack {
                    if !authManager.isAuthenticated {
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(LushyPalette.gradientSecondary)
                                    .frame(width: 120, height: 120)

                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(LushyPalette.gradientPrimary)
                            }
                            
                            VStack(spacing: 12) {
                                Text("💕 Login Required 💕")
                                    .lushyTitle()
                                
                                Text("Please log in to view your dreamy wishlist ✨")
                                    .lushySubheadline()
                            }
                            
                            Button("Login") { showingLoginPrompt = true }
                                .neumorphicButtonStyle()
                        }
                        .glassCard()
                        .padding(32)
                         .padding(.horizontal, 20)
                    } else if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LushyPalette.pink))
                                .scaleEffect(1.2)
                            Text("Loading your wishlist... ✨")
                                .lushyCaption()
                        }
                        .glassCard(cornerRadius: 16)
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            VStack(spacing: 8) {
                                Text("Oops! 😅")
                                    .lushyTitle()
                                
                                Text(errorMessage)
                                    .lushyCaption()
                            }
                            
                            Button("Try Again") { viewModel.fetchWishlist() }
                                .neumorphicButtonStyle()
                        }
                        .glassCard()
                        .padding(32)
                    } else if viewModel.wishlistItems.isEmpty {
                        VStack(spacing: 24) {
                            Image(systemName: "heart.circle")
                                .font(.system(size: 80))
                                .foregroundStyle(LushyPalette.gradientPrimary.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Your wishlist is empty 💖")
                                    .lushyHeadline()
                                
                                Text("Products you add to your wishlist from search and product views will appear here!")
                                    .lushyCaption()
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .glassCard()
                        .padding(20)
                    } else {
                        // Enhanced wishlist items display
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.wishlistItems) { item in
                                    NavigationLink(destination: SearchProductDetailView(
                                        product: createProductSummary(from: item),
                                        currentUserId: AuthService.shared.userId ?? ""
                                    )) {
                                        WishlistItemRow(item: item)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .onSwipe(perform: { direction in
                                        if direction == .leading {
                                            // Handle delete
                                            if let index = viewModel.wishlistItems.firstIndex(where: { $0.id == item.id }) {
                                                viewModel.removeItem(at: IndexSet(integer: index))
                                            }
                                        }
                                    })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("💕 Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingLoginPrompt) {
                LoginView(isLoggedIn: .constant(false))
                    .environmentObject(authManager)
                    .onDisappear {
                        if authManager.isAuthenticated {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                print("Login sheet dismissed, refreshing wishlist with token: \(AuthService.shared.token ?? "none")")
                                viewModel.fetchWishlist()
                            }
                        }
                    }
            }
            .alert("Product Not Found", isPresented: $showingProductNotFound) {
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(productNotFoundMessage)
            }
        }
        .onAppear {
            print("WishlistView appeared, authenticated: \(authManager.isAuthenticated), token: \(AuthService.shared.token ?? "none")")
            if authManager.isAuthenticated {
                viewModel.fetchWishlist()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AuthenticationFailed"))) { _ in
            showingLoginPrompt = true
        }
    }
    
    // Helper function to extract barcode from wishlist URLs for ProductSearchSummary
    private func extractBarcodeFromWishlistURL(_ urlString: String) -> String? {
        if urlString.contains("lushy.app/product/") {
            let components = urlString.components(separatedBy: "lushy.app/product/")
            if components.count > 1 {
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    // Create ProductSearchSummary from wishlist item
    private func createProductSummary(from item: AppWishlistItem) -> ProductSearchSummary {
        return ProductSearchSummary(
            id: item.id,
            barcode: extractBarcodeFromWishlistURL(item.productURL) ?? "",
            productName: item.productName,
            brand: "",
            imageUrl: item.imageURL,
            vegan: false,
            crueltyFree: false,
            periodsAfterOpening: nil,
            category: nil,
            shade: nil,
            size: nil, // Changed from sizeInMl: nil
            spf: nil
        )
    }
}

struct WishlistItemRow: View {
    let item: AppWishlistItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Product image placeholder with gradient
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.lushyPink.opacity(0.3), Color.mossGreen.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.lushyPink)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(item.productName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPurple)
                    .lineLimit(2)
                
                // Remove the direct link - tapping anywhere will now handle navigation
                HStack(spacing: 4) {
                    Image(systemName: "heart.circle.fill")
                        .font(.caption)
                    Text("Tap to view details")
                        .font(.caption)
                }
                .foregroundColor(.lushyPink)
                
                if (!item.notes.isEmpty) {
                    Text(item.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Favorite heart
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundColor(.lushyPink)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.9),
                            Color.lushyPink.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.lushyPink.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct AddWishlistItemView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Girly gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.1),
                        Color.lushyCream.opacity(0.3),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("✨ Add to Wishlist ✨")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Tell us about your dream product!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Form sections
                        VStack(spacing: 20) {
                            // Product Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Product Name")
                                    .font(.headline)
                                    .foregroundColor(.lushyPurple)
                                
                                TextField("Enter product name", text: $viewModel.newProductName)
                                    .textFieldStyle(LushyTextFieldStyle())
                            }
                            
                            // Product URL
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Product URL")
                                    .font(.headline)
                                    .foregroundColor(.lushyPurple)
                                
                                TextField("https://...", text: $viewModel.newProductURL)
                                    .textFieldStyle(LushyTextFieldStyle())
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.lushyPurple)
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
                                        )
                                        .frame(minHeight: 100)
                                    
                                    if viewModel.newProductNotes.isEmpty {
                                        Text("Why do you want this product?")
                                            .foregroundColor(.gray)
                                            .padding(.top, 12)
                                            .padding(.leading, 16)
                                    }
                                    
                                    TextEditor(text: $viewModel.newProductNotes)
                                        .padding(12)
                                        .background(Color.clear)
                                        .frame(minHeight: 100)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Add button
                        Button(action: {
                            viewModel.addWishlistItem()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                Text("Add to Wishlist")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .lushyButtonStyle(.primary, size: .large)
                        .disabled(viewModel.newProductName.isEmpty || viewModel.newProductURL.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct LushyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
                    )
            )
            .font(.body)
    }
}

// MARK: - Swipe Gesture Extension

extension View {
    func onSwipe(perform action: @escaping (SwipeDirection) -> Void) -> some View {
        self.gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        action(.trailing)
                    } else if value.translation.width < -threshold {
                        action(.leading)
                    }
                }
        )
    }
}

enum SwipeDirection {
    case leading, trailing
}

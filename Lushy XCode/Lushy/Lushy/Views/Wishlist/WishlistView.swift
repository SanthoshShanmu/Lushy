import Foundation
import SwiftUI

struct WishlistView: View {
    @StateObject private var viewModel = WishlistViewModel()
    @State private var showingAddItem = false
    @State private var showingLoginPrompt = false
    @State private var selectedProduct: AppWishlistItem?
    @State private var showProductDetail = false
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
                        Text("Your wishlist is empty 💖")
                            .lushyHeadline()
                            .glassCard()
                            .padding(20)
                    } else {
                        // Enhanced wishlist items display
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.wishlistItems) { item in
                                    WishlistItemRow(item: item)
                                        .onTapGesture {
                                            selectedProduct = item
                                            showProductDetail = true
                                        }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isAuthenticated {
                        Button(action: { showingAddItem = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                print("Login sheet dismissed, refreshing wishlist with token: \(AuthService.shared.token ?? "none")")
                                viewModel.fetchWishlist()
                            }
                        }
                    }
            }
            .sheet(isPresented: $showProductDetail) {
                if let product = selectedProduct {
                    WishlistProductDetailView(item: product)
                }
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
}

struct WishlistItemRow: View {
    let item: AppWishlistItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Product image placeholder with gradient
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.lushyPink.opacity(0.3), Color.lushyMint.opacity(0.2)]),
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
                
                if let url = URL(string: item.productURL) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "link.circle.fill")
                                .font(.caption)
                            Text("View Product")
                                .font(.caption)
                        }
                        .foregroundColor(.lushyPink)
                    }
                }
                
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

// MARK: - Wishlist Product Detail View

struct WishlistProductDetailView: View {
    let item: AppWishlistItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.08),
                        Color.lushyPurple.opacity(0.04),
                        Color.lushyCream.opacity(0.3),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Product Header
                        VStack(alignment: .leading, spacing: 16) {
                            // Product image placeholder
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.3), Color.lushyMint.opacity(0.2)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 60))
                                                .foregroundColor(.lushyPink)
                                            Text("Wishlist Item")
                                                .font(.caption)
                                                .foregroundColor(.lushyPink.opacity(0.8))
                                        }
                                    )
                                    .shadow(radius: 12)
                                Spacer()
                            }
                            
                            // Product Info
                            VStack(alignment: .leading, spacing: 12) {
                                Text(item.productName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                if !item.notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Your Notes")
                                            .font(.headline)
                                            .foregroundColor(.lushyPurple)
                                        
                                        Text(item.notes)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.lushyPink.opacity(0.1))
                                            )
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                        
                        // Actions Section
                        VStack(spacing: 16) {
                            Text("Actions")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.lushyPurple)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Visit Product URL
                            if let url = URL(string: item.productURL) {
                                Link(destination: url) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "link.circle.fill")
                                            .font(.title2)
                                        Text("Visit Product Page")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                            }
                            
                            // Note about adding to collection
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                    Text("Tip")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                Text("When you purchase this product, you can add it to your collection using the scanner or manual entry!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Wishlist Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                }
            }
        }
    }
}

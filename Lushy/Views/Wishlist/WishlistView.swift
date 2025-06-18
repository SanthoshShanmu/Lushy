import Foundation
import SwiftUI

struct WishlistView: View {
    @StateObject private var viewModel = WishlistViewModel()
    @State private var showingAddItem = false
    @State private var showingLoginPrompt = false
    @EnvironmentObject var authManager: AuthManager
    
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
                
                VStack {
                    if !authManager.isAuthenticated {
                        // Show login prompt if not authenticated
                        VStack(spacing: 24) {
                            // Sparkly heart animation
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.2), Color.lushyPurple.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("💕 Login Required 💕")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("Please log in to view your dreamy wishlist ✨")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .font(.subheadline)
                            }
                            
                            Button("Login") {
                                showingLoginPrompt = true
                            }
                            .lushyButtonStyle(.primary, size: .large)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    } else if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                .scaleEffect(1.2)
                            Text("Loading your wishlist... ✨")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(spacing: 8) {
                                Text("Oops! 😅")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.lushyPurple)
                                
                                Text(errorMessage)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .font(.subheadline)
                            }
                            
                            Button("Try Again") {
                                viewModel.fetchWishlist()
                            }
                            .lushyButtonStyle(.accent, size: .medium)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    } else if viewModel.wishlistItems.isEmpty {
                        // Enhanced empty state view
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink.opacity(0.2), Color.lushyMint.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyMint]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("💖 Your Wishlist is Empty 💖")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("Start adding your dream beauty products! ✨")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .font(.subheadline)
                            }
                            
                            Button("Add First Item") {
                                showingAddItem = true
                            }
                            .lushyButtonStyle(.primary, size: .large)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    } else {
                        // Enhanced wishlist items display
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.wishlistItems) { item in
                                    WishlistItemRow(item: item)
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
                
                if !item.notes.isEmpty {
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

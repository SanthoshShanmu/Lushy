import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isLoggedIn = false // Track authentication state
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var scannerViewModel = ScannerViewModel()
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    
    var body: some View {
        if isLoggedIn {
            // Main app content
            TabView(selection: $selectedTab) {
                HomeView(viewModel: homeViewModel)
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .tag(0)
                
                ScannerView(viewModel: scannerViewModel)
                    .tabItem {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scan")
                    }
                    .tag(1)
                
                WishlistView(viewModel: wishlistViewModel, isLoggedIn: $isLoggedIn)
                    .tabItem {
                        Image(systemName: "heart")
                        Text("Wishlist")
                    }
                    .tag(2)
                
                FavoritesView(viewModel: favoritesViewModel)
                    .tabItem {
                        Image(systemName: "star")
                        Text("Favorites")
                    }
                    .tag(3)
            }
            .onAppear {
                // Request notification permission when app starts
                NotificationService.shared.requestNotificationPermission()
                
                // Customize tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color.white)
                
                // Font settings for tab labels
                let normalIconAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                let selectedIconAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium)
                ]
                
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.gray)
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.lushyPink)
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalIconAttributes
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedIconAttributes
                
                // Apply the custom configuration to tab bar items
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
            .onReceive(NotificationService.shared.$lastOpenedProductId) { productId in
                if let id = productId, !id.isEmpty {
                    // Navigate to product detail if notification was tapped
                    homeViewModel.navigateToProduct(with: id)
                    selectedTab = 0  // Switch to home tab
                    NotificationService.shared.lastOpenedProductId = nil  // Reset
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedIn"))) { _ in
                // Force refresh auth state
                isLoggedIn = true
                print("ContentView detected login, refreshing auth state")
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset Auth") {
                        AuthService.shared.logout()
                        isLoggedIn = false
                    }
                }
            }
            #endif
        } else {
            // Authentication flow
            LoginView(isLoggedIn: $isLoggedIn)
        }
    }
    
    // Check for existing token on app start
    init() {
        _isLoggedIn = State(initialValue: AuthService.shared.isLoggedIn)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

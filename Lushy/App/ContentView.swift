import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var scannerViewModel = ScannerViewModel()
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Label("My Bag", systemImage: "bag.fill")
                }
                .tag(0)
            
            ScannerView(viewModel: scannerViewModel)
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(1)
            
            WishlistView(viewModel: wishlistViewModel)
                .tabItem {
                    Label("Wishlist", systemImage: "heart.fill")
                }
                .tag(2)
            
            FavoritesView(viewModel: favoritesViewModel)
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
                .tag(3)
        }
        .onAppear {
            // Request notification permission when app starts
            NotificationService.shared.requestNotificationPermission()
        }
        .onReceive(NotificationService.shared.$lastOpenedProductId) { productId in
            if let id = productId, !id.isEmpty {
                // Navigate to product detail if notification was tapped
                homeViewModel.navigateToProduct(with: id)
                selectedTab = 0  // Switch to home tab
                NotificationService.shared.lastOpenedProductId = nil  // Reset
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
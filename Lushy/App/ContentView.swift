import SwiftUI

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var scannerViewModel = ScannerViewModel()
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var statsViewModel = StatsViewModel()
    @EnvironmentObject var authManager: AuthManager
    @State private var showLoginPrompt = false
    
    // Tab items
    private enum Tab {
        case home, scan, wishlist, stats, settings
    }
    
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(Tab.home)
            
            ScannerView(viewModel: scannerViewModel)
                .tabItem {
                    Image(systemName: "barcode.viewfinder")
                    Text("Scan")
                }
                .tag(Tab.scan)
            
            WishlistView(viewModel: wishlistViewModel, isLoggedIn: $authManager.isAuthenticated)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Wishlist")
                }
                .tag(Tab.wishlist)
            
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(Tab.stats)
            
            NavigationView {
                AccountView(isLoggedIn: $authManager.isAuthenticated)
                    .environmentObject(authManager)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(Tab.settings)
        }
        .onAppear {
            // Any additional setup needed when the main content view appears
            // Token validation is already handled by AuthManager
        }
        // Handle opening product details from notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenProductDetail"))) { notification in
            if let barcode = notification.object as? String {
                selectedTab = .home
                homeViewModel.navigateToProduct(with: barcode)
            }
        }
        // Log out handler
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedOut"))) { _ in
            // This will trigger the app to show login screen again through LushyApp
            authManager.logout()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

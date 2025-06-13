import SwiftUI

// Move Tab enum outside ContentView for module-wide access
enum Tab {
    case home, scan, wishlist, stats, settings, favorites, bags, tags, feed, search
}

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var scannerViewModel = ScannerViewModel()
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var statsViewModel = StatsViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var userSearchViewModel = UserSearchViewModel()
    @State private var currentUserId: String = AuthService.shared.userId ?? ""
    @EnvironmentObject var authManager: AuthManager
    @State private var showLoginPrompt = false
    
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView(viewModel: feedViewModel, currentUserId: currentUserId)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Feed")
                }
                .tag(Tab.feed)
            
            UserSearchView(viewModel: userSearchViewModel, currentUserId: currentUserId)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(Tab.search)
            
            HomeView(viewModel: homeViewModel, selectedTab: $selectedTab)
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
            
            WishlistView()
                .environmentObject(authManager)
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
            
            NavigationView {
                FavoritesView(viewModel: favoritesViewModel)
            }
            .tabItem {
                Image(systemName: "star.fill")
                Text("Favorites")
            }
            .tag(Tab.favorites)
            
            NavigationView {
                BeautyBagsView()
            }
            .tabItem {
                Image(systemName: "bag.fill")
                Text("Bags")
            }
            .tag(Tab.bags)
            
            NavigationView {
                TagManagerView()
            }
            .tabItem {
                Image(systemName: "tag.fill")
                Text("Tags")
            }
            .tag(Tab.tags)
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

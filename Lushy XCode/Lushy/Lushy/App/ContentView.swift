import SwiftUI

// Move Tab enum outside ContentView for module-wide access
enum Tab {
    case home, scan, wishlist, stats, settings, favorites, bags, tags, feed, search
}

// Shared tab selection manager
final class TabSelection: ObservableObject { @Published var selected: Tab = .home }

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var scannerViewModel = ScannerViewModel()
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var statsViewModel = StatsViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var userSearchViewModel = UserSearchViewModel()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var tabSelection: TabSelection
    @State private var showLoginPrompt = false
    
    var body: some View {
        NavigationStack {
            TabView(selection: $tabSelection.selected) {
                FeedView(viewModel: feedViewModel, currentUserId: AuthService.shared.userId ?? "")
                    .tabItem { Image(systemName: "person.3.fill"); Text("Feed") }
                    .tag(Tab.feed)
                CombinedSearchView(currentUserId: AuthService.shared.userId ?? "")
                    .tabItem { Image(systemName: "magnifyingglass"); Text("Search") }
                    .tag(Tab.search)
                let uid = AuthService.shared.userId ?? ""
                UserProfileView(viewModel: UserProfileViewModel(currentUserId: uid, targetUserId: uid))
                    .environmentObject(authManager)
                    .id(uid)
                    .tabItem { Image(systemName: "house.fill"); Text("Home") }
                    .tag(Tab.home)
                ScannerView(viewModel: scannerViewModel)
                    .tabItem { Image(systemName: "barcode.viewfinder"); Text("Scan") }
                    .tag(Tab.scan)
                // Consolidated More tab that includes Wishlist, Stats, Favorites, and other settings
                MoreView()
                    .environmentObject(authManager)
                    .tabItem { Image(systemName: "ellipsis"); Text("More") }
                    .tag(Tab.settings)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenProductDetail"))) { notification in
                if let barcode = notification.object as? String {
                    tabSelection.selected = .home
                    homeViewModel.navigateToProduct(with: barcode)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedOut"))) { _ in
                authManager.logout()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToScanTab"))) { _ in
                tabSelection.selected = .scan
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
                // Navigate back to home tab after review submission
                tabSelection.selected = .home
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager.shared)
            .environmentObject(TabSelection())
    }
}

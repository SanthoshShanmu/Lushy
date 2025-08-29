import SwiftUI

struct MoreView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Beauty Features Section
                Section("Beauty Features") {
                    NavigationLink(destination: WishlistView().environmentObject(authManager)) {
                        Label("Wishlist", systemImage: "heart.text.square")
                            .foregroundColor(.lushyPink)
                    }
                    
                    NavigationLink(destination: StatsView()) {
                        Label("Beauty Stats", systemImage: "chart.bar.fill")
                            .foregroundColor(.lushyPurple)
                    }
                    
                    NavigationLink(destination: FavoritesView(viewModel: FavoritesViewModel())) {
                        Label("Favorites", systemImage: "star.fill")
                            .foregroundColor(.mossGreen)
                    }
                    
                    NavigationLink(destination: BeautyBagsView()) {
                        Label("Beauty Bags", systemImage: "bag.fill")
                            .foregroundColor(.lushyPeach)
                    }
                    
                    NavigationLink(destination: FinishedProductsView()) {
                        Label("Finished Products", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.mossGreen)
                    }
                }
                
                // Account Section
                Section("Account") {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gearshape.fill")
                            .foregroundColor(.lushyPurple)
                    }
                    
                    NavigationLink(destination: NotificationsSettingsView()) {
                        Label("Notifications", systemImage: "bell.fill")
                            .foregroundColor(.lushyPeach)
                    }
                    
                    if authManager.isAuthenticated {
                        Button(action: { showingLogoutAlert = true }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.lushyPink.opacity(0.8))
                        }
                    }
                }
                
                // App Info Section
                Section("About") {
                    NavigationLink(destination: AboutView()) {
                        Label("About Lushy", systemImage: "info.circle")
                            .foregroundColor(.lushyPurple)
                    }
                    
                    NavigationLink(destination: HelpView()) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                            .foregroundColor(.mossGreen)
                    }
                }
            }
            .navigationTitle("More")
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// Placeholder views for missing features
struct SettingsView: View {
    var body: some View {
        Text("Settings coming soon!")
            .navigationTitle("Settings")
    }
}

struct NotificationsSettingsView: View {
    var body: some View {
        Text("Notification settings coming soon!")
            .navigationTitle("Notifications")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.lushyPink)
            
            Text("Lushy")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your personal beauty companion")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("About")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Help & Support coming soon!")
            .navigationTitle("Help")
    }
}
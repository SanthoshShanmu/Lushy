import SwiftUI
import CoreData

@main
struct LushyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var tabSelection = TabSelection()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastBackgroundDate: Date?

    var body: some Scene {
        WindowGroup {
            if showSplash {
                // Use the UIKit wrapper for your original animation
                SplashUIKitWrapper {
                    withAnimation {
                        showSplash = false
                    }
                }
                .edgesIgnoringSafeArea(.all) // Important for full-screen display
                .environmentObject(authManager)
                .environmentObject(tabSelection)
            } else if !authManager.isAuthenticated {
                LoginView(isLoggedIn: .constant(false))
                    .environmentObject(authManager)
                    .environmentObject(tabSelection)
            } else {
                ContentView()
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .environmentObject(authManager)
                    .environmentObject(tabSelection)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                lastBackgroundDate = Date()
            case .active:
                if let backgroundDate = lastBackgroundDate {
                    let elapsed = Date().timeIntervalSince(backgroundDate)
                    // Only logout if inactive for more than 30 minutes
                    if elapsed > 1800 {
                        authManager.logout()
                    }
                }
                // Server-authoritative refresh on foreground
                SyncService.shared.refreshAllFromBackend()
            default:
                break
            }
        }
    }
}

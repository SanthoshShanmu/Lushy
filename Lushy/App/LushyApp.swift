import SwiftUI
import CoreData

@main
struct LushyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView(completion: {
                    // This will be called when splash animation completes
                    withAnimation {
                        showSplash = false
                    }
                })
                .environmentObject(authManager)
            } else if !authManager.isAuthenticated {
                LoginView(isLoggedIn: .constant(false))
                    .environmentObject(authManager)
            } else {
                ContentView()
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .environmentObject(authManager)
            }
        }
    }
}

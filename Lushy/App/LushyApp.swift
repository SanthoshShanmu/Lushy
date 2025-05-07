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
                // Use the UIKit wrapper for your original animation
                SplashUIKitWrapper {
                    withAnimation {
                        showSplash = false
                    }
                }
                .edgesIgnoringSafeArea(.all) // Important for full-screen display
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

import SwiftUI

struct AccountView: View {
    @State private var showingLogoutConfirm = false
    @State private var showingPasswordChange = false
    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showDebugInfo = false
    @Binding var isLoggedIn: Bool
    
    // Add this line to access AuthManager
    @EnvironmentObject var authManager: AuthManager
    
    // Add state for region picker
    @State private var selectedRegion = UserDefaults.standard.string(forKey: "userRegion") ?? "GLOBAL"
    
    // Add these state properties at the top of AccountView:
    @State private var showingOBFCredentialsSheet = false
    @State private var contributionCount = 0 // This would be loaded from local storage or API
    
    // Add state to track if profile has been fetched
    @State private var hasFetchedProfile = false
    
    var body: some View {
        ScrollView {
            Color.clear.pastelBackground()
            VStack(spacing: 16) {
                // Debug section for troubleshooting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Info").font(.headline)
                    Toggle("Show Debug Info", isOn: $showDebugInfo)
                    
                    if showDebugInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Auth Status: \(AuthService.shared.isAuthenticated ? "Logged In" : "Logged Out")")
                            Text("Token: \(AuthService.shared.token ?? "No token")")
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            if let errorMessage = errorMessage {
                                Text("Error: \(errorMessage)")
                                    .foregroundColor(.red)
                            }
                            
                            Button("Refresh Page") {
                                fetchUserProfile()
                            }
                            .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                }
                .glassCard(cornerRadius: 20)

                // Account Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Information").font(.headline)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if let profile = userProfile {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.lushyPink)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(profile.name.prefix(1).uppercased())
                                        .foregroundColor(.white)
                                        .font(.system(size: 20, weight: .semibold))
                                )
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Not logged in state
                        VStack(alignment: .leading) {
                            Text("Not logged in")
                                .font(.headline)
                            
                            Button(action: {
                                // Show login
                                NotificationCenter.default.post(name: NSNotification.Name("ShowLogin"), object: nil)
                            }) {
                                Text("Log in to sync your products")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .glassCard(cornerRadius: 20)

                if isLoggedIn {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Security").font(.headline)
                        
                        Button(action: {
                            showingPasswordChange = true
                            print("Password change button tapped")
                        }) {
                            Label("Change Password", systemImage: "lock.rotation")
                        }
                        
                        Button(action: {
                            showingLogoutConfirm = true
                            print("Logout button tapped")
                        }) {
                            Label("Log Out", systemImage: "arrow.right.square")
                                .foregroundColor(.red)
                        }
                    }
                    .glassCard(cornerRadius: 20)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Management").font(.headline)
                    
                    // Privacy settings
                    Button(action: { print("Privacy settings button tapped") }) {
                        Label("Privacy Settings", systemImage: "hand.raised")
                    }
                }
                .glassCard(cornerRadius: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("About").font(.headline)
                    
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        print("Terms of service button tapped")
                        if let url = URL(string: "https://example.com/terms") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    
                    Button(action: {
                        print("Privacy policy button tapped")
                        if let url = URL(string: "https://example.com/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Privacy Policy", systemImage: "shield.checkerboard")
                    }
                }
                .glassCard(cornerRadius: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Product Compliance").font(.headline)
                    
                    Picker("Region", selection: $selectedRegion) {
                        Text("Global").tag("GLOBAL")
                        Text("European Union").tag("EU")
                        Text("United States").tag("US")
                        Text("Japan").tag("JP")
                    }
                    // Replace deprecated onChange with the new version
                    #if compiler(>=5.9) && canImport(SwiftUI)
                    // Use new API for iOS 17+
                    .onChange(of: selectedRegion) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "userRegion")
                    }
                    #else
                    // Use old API for iOS 16 and earlier
                    .onChange(of: selectedRegion) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "userRegion")
                    }
                    #endif
                    
                    Text("Region setting affects product compliance information")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .glassCard(cornerRadius: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Open Beauty Facts").font(.headline)
                    
                    Toggle("Auto-contribute new products", isOn: Binding(
                        get: {
                            // Default to true if never set (first time users)
                            let hasSetPreference = UserDefaults.standard.object(forKey: "auto_contribute_to_obf") != nil
                            return hasSetPreference ?
                                UserDefaults.standard.bool(forKey: "auto_contribute_to_obf") :
                                true
                        },
                        set: { UserDefaults.standard.set($0, forKey: "auto_contribute_to_obf") }
                    ))
                    
                    Text("Automatically upload products not found in the database to Open Beauty Facts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("You've contributed \(contributionCount) products")
                        .font(.body)
                    
                    let contributions = UserDefaults.standard.stringArray(forKey: "obf_contributed_products") ?? []
                    if !contributions.isEmpty {
                        NavigationLink("View My Contributions (\(contributions.count))") {
                            List {
                                ForEach(contributions, id: \.self) { productId in
                                    Link(productId,
                                         destination: URL(string: "https://world.openbeautyfacts.org/product/\(productId)")!)
                                }
                            }
                            .navigationTitle("My Contributions")
                        }
                    }
                    
                    Link("View Open Beauty Facts", destination: URL(string: "https://world.openbeautyfacts.org/")!)
                        .foregroundColor(.blue)
                }
                .glassCard(cornerRadius: 20)
            }
            .padding()
        }
        .navigationTitle("Settings")
        .onAppear {
            print("AccountView appeared")
            if !hasFetchedProfile {
                hasFetchedProfile = true
                fetchUserProfile()
            }
        }
        .alert(isPresented: $showingLogoutConfirm) {
            Alert(
                title: Text("Log Out"),
                message: Text("Are you sure you want to log out? Your data will still be saved locally."),
                primaryButton: .destructive(Text("Log Out")) {
                    logout()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingPasswordChange) {
            ChangePasswordView()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.lushyPink.opacity(0.15), Color.lushyPurple.opacity(0.10)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)
                )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowLogin"))) { _ in
            isLoggedIn = false
            // Show login prompt via ContentView
            NotificationCenter.default.post(name: NSNotification.Name("ShowLoginPrompt"), object: nil)
        }
    }
    
    private func fetchUserProfile() {
        errorMessage = nil
        isLoading = true
        
        guard AuthService.shared.isAuthenticated else {
            isLoading = false
            userProfile = nil
            return
        }
        
        // Use the correct APIService method
        if let userId = AuthService.shared.userId {
            APIService.shared.fetchUserProfile(userId: userId) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let wrapper):
                        userProfile = wrapper.user
                    case .failure(let error):
                        errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            isLoading = false
            userProfile = nil
        }
    }
    
    private func logout() {
        print("Logging out user")
        // Post notification first so all interested parties can respond
        NotificationCenter.default.post(name: NSNotification.Name("UserLoggedOut"), object: nil)
        // Then perform the actual logout
        authManager.logout()
    }
}

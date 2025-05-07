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
    
    // Add state for sync button
    @State private var isSyncing = false
    
    // Add state for region picker
    @State private var selectedRegion = UserDefaults.standard.string(forKey: "userRegion") ?? "GLOBAL"
    
    var body: some View {
        List {
            // Debug section for troubleshooting
            Section(header: Text("Debug Info")) {
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

            Section(header: Text("Account Information")) {
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
            
            // Only show these sections if logged in
            if isLoggedIn {
                Section(header: Text("Security")) {
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
            }
            
            Section(header: Text("Data Management")) {
                Button(action: {
                    print("Sync data button tapped")
                    syncData()
                }) {
                    HStack {
                        Label("Sync Data Now", systemImage: "arrow.triangle.2.circlepath")
                        
                        if isSyncing {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                
                Button(action: {
                    print("Privacy settings button tapped")
                    // Show privacy settings (placeholder for now)
                }) {
                    Label("Privacy Settings", systemImage: "hand.raised")
                }
            }
            
            Section(header: Text("About")) {
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
            
            // Add this section to your settings view
            Section(header: Text("Product Compliance")) {
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
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
        .onAppear {
            print("AccountView appeared")
            fetchUserProfile()
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowLogin"))) { _ in
            isLoggedIn = false
            // Show login prompt via ContentView
            NotificationCenter.default.post(name: NSNotification.Name("ShowLoginPrompt"), object: nil)
        }
    }
    
    private func fetchUserProfile() {
        // Reset error message
        errorMessage = nil
        isLoading = true
        
        // Check if logged in first
        guard AuthService.shared.isAuthenticated else {
            isLoading = false
            userProfile = nil
            return
        }
        
        // For now, create a placeholder profile since the API might not be fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            
            // Check if still logged in after delay
            if AuthService.shared.isAuthenticated {
                userProfile = UserProfile(
                    name: "Demo User", 
                    email: "user@example.com",
                    id: AuthService.shared.userId ?? "unknown"
                )
            } else {
                userProfile = nil
            }
        }
        
        // Uncomment when API is fully implemented
        /*
        APIService.shared.fetchUserProfile()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    print("Error fetching profile: \(error)")
                    errorMessage = "Failed to load profile: \(error)"
                }
            }, receiveValue: { profile in
                self.userProfile = profile
            })
            .store(in: &AuthService.shared.cancellables)
        */
    }
    
    private func logout() {
        print("Logging out user")
        // Post notification first so all interested parties can respond
        NotificationCenter.default.post(name: NSNotification.Name("UserLoggedOut"), object: nil)
        // Then perform the actual logout
        authManager.logout()
    }
    
    private func syncData() {
        isSyncing = true
        print("Starting data sync")
        
        // Simulate sync process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSyncing = false
            print("Data sync complete")
        }
        
        // Uncomment when SyncService is fully implemented
        /*
        SyncService.shared.performInitialSync()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isSyncing = false
                
                if case .failure(let error) = completion {
                    print("Sync error: \(error)")
                    errorMessage = "Sync failed: \(error)"
                }
            }, receiveValue: { _ in
                print("Sync completed successfully")
            })
            .store(in: &AuthService.shared.cancellables)
        */
    }
}

// Model for the profile placeholder
struct UserProfile: Codable {
    let name: String
    let email: String
    let id: String
}
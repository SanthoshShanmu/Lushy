import SwiftUI

struct OBFCredentialsView: View {
    @Binding var isPresented: Bool
    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    // New state for connection testing and clearing feedback
    @State private var isTestingConnection = false
    @State private var showConnectionResult = false
    @State private var connectionOk = false
    @State private var showClearedAlert = false
    
    // Load existing credentials if available
    private func loadExistingCredentials() {
        if OBFContributionService.shared.hasCredentials {
            // Prefill only the user id (non-sensitive); leave password blank
            userId = OBFContributionService.shared.storedUserId() ?? ""
            password = ""
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                    .pastelBackground()
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        TextField("User ID", text: $userId)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    .glassCard()
                    
                    Button("Save Credentials") {
                        if !userId.isEmpty && !password.isEmpty {
                            OBFContributionService.shared.setCredentials(userId: userId, password: password)
                            showingSuccessAlert = true
                        } else {
                            showingErrorAlert = true
                        }
                    }
                    .neumorphicButtonStyle()
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(isTestingConnection ? "Testing..." : "Test Connection") {
                            guard !isTestingConnection else { return }
                            isTestingConnection = true
                            OBFContributionService.shared.testConnection { ok in
                                DispatchQueue.main.async {
                                    self.connectionOk = ok
                                    self.showConnectionResult = true
                                    self.isTestingConnection = false
                                }
                            }
                        }
                        .disabled(isTestingConnection)
                        .neumorphicButtonStyle()
                        
                        Button("Clear Credentials") {
                            OBFContributionService.shared.clearCredentials()
                            userId = ""
                            password = ""
                            showClearedAlert = true
                        }
                        .neumorphicButtonStyle()
                    }
                    .padding(.horizontal)
                    
                    Link("Create an OBF Account", destination: URL(string: "https://world.openbeautyfacts.org/cgi/user.pl")!)
                        .foregroundColor(LushyPalette.pink)
                }
                .padding()
             }
             .navigationTitle("OBF Credentials")
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .neumorphicButtonStyle()
                 }
             }
             .onAppear {
                 loadExistingCredentials()
             }
             .alert("Credentials Saved", isPresented: $showingSuccessAlert) {
                 Button("OK") {
                     isPresented = false
                 }
             } message: {
                 Text("Your Open Beauty Facts credentials have been saved.")
             }
             .alert("Invalid Credentials", isPresented: $showingErrorAlert) {
                 Button("OK", role: .cancel) { }
             } message: {
                 Text("Please enter both user ID and password.")
             }
             .alert(connectionOk ? "Connection OK" : "Connection Failed", isPresented: $showConnectionResult) {
                 Button("OK", role: .cancel) { }
             } message: {
                 Text(connectionOk ? "Successfully reached Open Beauty Facts API." : "Could not reach Open Beauty Facts. Check your internet connection and try again.")
             }
             .alert("Credentials Cleared", isPresented: $showClearedAlert) {
                 Button("OK", role: .cancel) { }
             } message: {
                 Text("Your stored credentials have been removed from the device.")
             }
        }
    }
}

import SwiftUI

struct OBFCredentialsView: View {
    @Binding var isPresented: Bool
    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    // Load existing credentials if available
    private func loadExistingCredentials() {
        if OBFContributionService.shared.hasCredentials {
            // This is just a placeholder since we don't have a getter for security reasons
            userId = UserDefaults.standard.string(forKey: "obf_user_id") ?? ""
            // We don't pre-fill the password for security
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
        }
    }
}

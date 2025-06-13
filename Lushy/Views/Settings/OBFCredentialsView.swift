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
            Form {
                Section(header: Text("Open Beauty Facts Account")) {
                    TextField("User ID", text: $userId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                }
                
                Section(footer: Text("Your credentials help expand the beauty product database. They're stored securely on your device only.")) {
                    Button("Save Credentials") {
                        if !userId.isEmpty && !password.isEmpty {
                            OBFContributionService.shared.setCredentials(userId: userId, password: password)
                            showingSuccessAlert = true
                        } else {
                            showingErrorAlert = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section {
                    Link("Create an OBF Account", destination: URL(string: "https://world.openbeautyfacts.org/cgi/user.pl")!)
                }
            }
            .navigationTitle("OBF Credentials")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
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

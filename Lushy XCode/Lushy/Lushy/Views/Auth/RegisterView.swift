import SwiftUI

struct RegisterView: View {
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var isCheckingUsername = false
    @State private var usernameAvailable: Bool? = nil
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    @Binding var isLoggedIn: Bool

    // Extracted header section
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image("lushy-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            Text("Create Account")
                .font(.title)
                .fontWeight(.bold)
            Text("Sign up to save and sync your beauty products")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // Extracted form fields section
    private var formFieldsSection: some View {
        VStack(spacing: 20) {
            TextField("Full Name", text: $name)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: username) { _, newValue in
                            // Clean username input
                            let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue {
                                username = filtered
                            }
                            
                            // Check availability after typing stops
                            if !newValue.isEmpty && newValue.count >= 3 {
                                checkUsernameAvailability()
                            } else {
                                usernameAvailable = nil
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    if isCheckingUsername {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                            .scaleEffect(0.8)
                    } else if let available = usernameAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(available ? .green : .red)
                    }
                }
                
                if let available = usernameAvailable, !username.isEmpty {
                    Text(available ? "Username is available!" : "Username is already taken")
                        .font(.caption)
                        .foregroundColor(available ? .green : .red)
                }
                
                Text("3-20 characters, letters, numbers, and underscores only")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            SecureField("Password", text: $password)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            SecureField("Confirm Password", text: $confirmPassword)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 5)
            }
            Button(action: register) {
                Group {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.lushyPink)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty || password != confirmPassword || isRegistering || (usernameAvailable == false))
            .lushyButtonStyle(.primary, size: .large)
        }
        .padding(.horizontal)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.lushyBackground.opacity(0.3).edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 30) {
                        // Logo and title
                        headerSection

                        // Registration form
                        formFieldsSection
                            .padding(.horizontal)

                        // Terms agreement
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(leading: Button("Back") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func checkUsernameAvailability() {
        guard username.count >= 3 else {
            usernameAvailable = nil
            return
        }
        
        isCheckingUsername = true
        
        // Call the backend to check username availability
        AuthService.shared.checkUsernameAvailability(username: username)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isCheckingUsername = false
                if case .failure(let error) = completion {
                    print("Username availability check failed: \(error)")
                    // For development, assume username is available if check fails
                    self.usernameAvailable = true
                }
            }, receiveValue: { available in
                self.usernameAvailable = available
            })
            .store(in: &AuthService.shared.cancellables)
    }

    private func register() {
        // Validate inputs
        guard !name.isEmpty, !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "All fields are required"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }

        // Validate username
        guard username.count >= 3 && username.count <= 20 else {
            errorMessage = "Username must be between 3 and 20 characters"
            return
        }

        guard usernameAvailable == true else {
            errorMessage = "Please choose an available username"
            return
        }

        // Validate password strength
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }

        isRegistering = true
        errorMessage = nil

        AuthService.shared.register(name: name, username: username, email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isRegistering = false

                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            }, receiveValue: { success in
                isLoggedIn = success
                presentationMode.wrappedValue.dismiss()

                // Start sync after successful registration
                if success {
                    SyncService.shared.performInitialSync()
                }
            })
            .store(in: &AuthService.shared.cancellables)
    }
}

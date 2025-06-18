import SwiftUI

struct RegisterView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
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
            .disabled(name.isEmpty || email.isEmpty || password.isEmpty || password != confirmPassword || isRegistering)
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

    private func register() {
        // Validate inputs
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
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

        // Validate password strength
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }

        isRegistering = true
        errorMessage = nil

        AuthService.shared.register(name: name, email: email, password: password)
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

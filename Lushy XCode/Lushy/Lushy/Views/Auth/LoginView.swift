import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showRegistration = false
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.lushyBackground.opacity(0.3).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // Logo and welcome text
                    VStack(spacing: 15) {
                        Image("AppIcon") // Use your existing AppIcon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        
                        Text("Welcome to Lushy")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Login to access your beauty products")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Login form
                    VStack(spacing: 20) {
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
                        
                        if let errorMessage = authManager.authError {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: login) {
                            Group {
                                if isLoggingIn {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .lushyButtonStyle(.primary, size: .large)
                        .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                    }
                    .padding(.horizontal)
                    
                    // Register option
                    VStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        
                        Button("Create Account") {
                            showRegistration = true
                        }
                        .foregroundColor(.lushyPink)
                        .fontWeight(.medium)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .sheet(isPresented: $showRegistration) {
                RegisterView(isLoggedIn: $isLoggedIn)
                    .environmentObject(authManager)
            }
        }
    }
    
    private func login() {
        isLoggingIn = true
        
        authManager.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoggingIn = false
                
                if case .failure(let error) = completion {
                    print("Login error: \(error)")
                }
            }, receiveValue: { success in
                isLoggingIn = false
                isLoggedIn = success
                
                if success {
                    // We don't need to do anything else here as AuthManager will set isAuthenticated
                    // which will cause LushyApp to show the ContentView
                    print("Login successful")
                }
            })
            .store(in: &AuthService.shared.cancellables)
    }
}

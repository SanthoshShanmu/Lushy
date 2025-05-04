import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.lushyCream, .lushyBackground]),
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .foregroundColor(.lushyPink)
                        .padding(.bottom, 10)
                    
                    Text("Welcome to Lushy")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Track your beauty products")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .textFieldStyle(LushyTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(LushyTextFieldStyle())
                    }
                    .padding(.horizontal, 30)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.top, 5)
                    }
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(LushyButtonStyle(isLarge: true))
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    .disabled(isLoading)
                    
                    NavigationLink(destination: RegisterView(isLoggedIn: $isLoggedIn)) {
                        Text("Don't have an account? Register")
                            .foregroundColor(.lushyPurple)
                            .underline()
                            .padding(.top, 10)
                            .font(.system(size: 16))
                    }
                    
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .navigationBarHidden(true)
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        
        AuthService.shared.login(email: email, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    isLoggedIn = true
                    print("Login successful, token should be set now")
                    // Force app-wide notification that user logged in
                    NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: nil)
                } else {
                    errorMessage = error ?? "Login failed"
                }
            }
        }
    }
}

struct LushyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
            )
    }
}

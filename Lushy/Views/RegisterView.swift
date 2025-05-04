import SwiftUI

struct RegisterView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Binding var isLoggedIn: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Create Account")
                .font(.largeTitle)
                .padding(.bottom, 30)
            
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.top, 10)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.top, 10)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.top, 10)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            Button(action: register) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Register")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(.lushyPurple)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 20)
            .disabled(isLoading)
        }
        .padding()
    }
    
    func register() {
        // Form validation
        if name.isEmpty || email.isEmpty || password.isEmpty {
            errorMessage = "All fields are required"
            return
        }
        
        if password != confirmPassword {
            errorMessage = "Passwords don't match"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        AuthService.shared.register(name: name, email: email, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    isLoggedIn = true
                } else {
                    errorMessage = error ?? "Registration failed"
                }
            }
        }
    }
}

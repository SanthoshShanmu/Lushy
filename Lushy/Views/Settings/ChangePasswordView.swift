import SwiftUI

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                }
                
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                    
                    if !newPassword.isEmpty {
                        PasswordStrengthView(password: newPassword)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let successMessage = successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: changePassword) {
                        Group {
                            if isChanging {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Change Password")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 10)
                        .background(buttonBackgroundColor)
                        .cornerRadius(8)
                    }
                    .disabled(isButtonDisabled)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }
            }
            .navigationBarTitle("Change Password", displayMode: .inline)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.lushyPink.opacity(0.10), Color.lushyPurple.opacity(0.08)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            )
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var isButtonDisabled: Bool {
        return currentPassword.isEmpty ||
               newPassword.isEmpty ||
               confirmPassword.isEmpty ||
               newPassword != confirmPassword ||
               isChanging
    }
    
    private var buttonBackgroundColor: Color {
        return isButtonDisabled ? Color.gray.opacity(0.5) : Color.lushyPink
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords don't match"
            return
        }
        
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters long"
            return
        }
        
        isChanging = true
        errorMessage = nil
        successMessage = nil
        
        APIService.shared.updatePassword(currentPassword: currentPassword,
                                         newPassword: newPassword,
                                         passwordConfirm: confirmPassword)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isChanging = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            }, receiveValue: { _ in
                successMessage = "Password changed successfully"
                
                // Reset fields
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                
                // Dismiss after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    presentationMode.wrappedValue.dismiss()
                }
            })
            .store(in: &AuthService.shared.cancellables)
    }
}

struct PasswordStrengthView: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Password strength:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(strengthText)
                    .font(.caption)
                    .bold()
                    .foregroundColor(strengthColor)
            }
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(height: 5)
                    .opacity(0.2)
                    .foregroundColor(Color(.systemGray5))
                
                Rectangle()
                    .frame(width: strengthBarWidth, height: 5)
                    .foregroundColor(strengthColor)
                    .animation(.spring(), value: password)
            }
            .cornerRadius(3)
        }
    }
    
    private var strength: Int {
        var score = 0
        
        // Length
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // Character sets
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: .punctuationCharacters) != nil { score += 1 }
        
        return min(score, 5)
    }
    
    private var strengthText: String {
        switch strength {
        case 0: return "Very Weak"
        case 1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        case 5: return "Very Strong"
        default: return ""
        }
    }
    
    private var strengthColor: Color {
        switch strength {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4...5: return .green
        default: return .gray
        }
    }
    
    private var strengthBarWidth: CGFloat {
        let percentage = CGFloat(strength) / 5.0
        return UIScreen.main.bounds.width * 0.7 * percentage
    }
}

import SwiftUI

struct ChangeEmailView: View {
    @State private var currentEmail = ""
    @State private var newEmail = ""
    @State private var confirmEmail = ""
    @State private var isChanging = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Email")) {
                    TextField("Enter current email", text: $currentEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("New Email")) {
                    TextField("Enter new email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Confirm new email", text: $confirmEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
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
                    Button(action: changeEmail) {
                        Group {
                            if isChanging {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Change Email")
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
            .navigationBarTitle("Change Email", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var isButtonDisabled: Bool {
        return currentEmail.isEmpty ||
               newEmail.isEmpty ||
               confirmEmail.isEmpty ||
               newEmail != confirmEmail ||
               isChanging
    }
    
    private var buttonBackgroundColor: Color {
        return isButtonDisabled ? Color.gray.opacity(0.5) : Color.lushyPink
    }
    
    private func changeEmail() {
        guard newEmail == confirmEmail else {
            errorMessage = "New emails don't match"
            return
        }
        
        guard newEmail.contains("@") && newEmail.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        guard let userId = AuthService.shared.userId else {
            errorMessage = "Not authenticated"
            return
        }
        
        isChanging = true
        errorMessage = nil
        successMessage = nil
        
        // Update email via profile update endpoint
        guard let url = URL(string: "\(APIService.shared.baseURL)/users/\(userId)/profile") else {
            errorMessage = "Invalid URL"
            isChanging = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["email": newEmail]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            errorMessage = "Failed to encode request"
            isChanging = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isChanging = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid response"
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    successMessage = "Email changed successfully"
                    
                    // Reset fields
                    currentEmail = ""
                    newEmail = ""
                    confirmEmail = ""
                    
                    // Dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    // Try to parse error message from response
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        errorMessage = message
                    } else {
                        errorMessage = "Failed to change email"
                    }
                }
            }
        }.resume()
    }
}
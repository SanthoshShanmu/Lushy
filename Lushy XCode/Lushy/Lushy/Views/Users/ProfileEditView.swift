import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: ProfileEditViewModel
    
    init(currentUser: UserProfile) {
        _viewModel = StateObject(wrappedValue: ProfileEditViewModel(currentUser: currentUser))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.05),
                        Color.lushyPurple.opacity(0.03),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Image Section
                        VStack(spacing: 16) {
                            Text("Profile Photo")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                viewModel.showingImagePicker = true
                            }) {
                                ZStack {
                                    if let selectedImage = viewModel.selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else if let profileImageUrl = viewModel.profileImageUrl,
                                              !profileImageUrl.isEmpty {
                                        AsyncImage(url: URL(string: "\(APIService.shared.staticBaseURL)\(profileImageUrl)")) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.lushyPink.opacity(0.3))
                                                .overlay(
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                )
                                        }
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                    } else {
                                        // Default avatar with initials
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.lushyPink.opacity(0.7),
                                                        Color.lushyPurple.opacity(0.5)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Text(viewModel.name.prefix(1).uppercased())
                                                    .font(.system(size: 36, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
                                    // Camera overlay
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Circle()
                                                .fill(Color.lushyPink)
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Image(systemName: "camera")
                                                        .foregroundColor(.white)
                                                        .font(.system(size: 16, weight: .medium))
                                                )
                                                .offset(x: -8, y: -8)
                                        }
                                    }
                                }
                            }
                            .shadow(color: Color.lushyPink.opacity(0.3), radius: 12, x: 0, y: 4)
                            
                            Text("Tap to change profile photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        
                        // Basic Info Section
                        VStack(spacing: 16) {
                            Text("Basic Information")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 12) {
                                // Name Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Display Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Your display name", text: $viewModel.name)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .background(Color.white)
                                        .cornerRadius(8)
                                }
                                
                                // Username Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Username")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        TextField("username", text: $viewModel.username)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .onChange(of: viewModel.username) { _, newValue in
                                                viewModel.validateUsername(newValue)
                                            }
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .background(Color.white)
                                            .cornerRadius(8)
                                        
                                        if viewModel.isCheckingUsername {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .lushyPink))
                                                .scaleEffect(0.8)
                                        } else if let available = viewModel.usernameAvailable {
                                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(available ? .green : .red)
                                        }
                                    }
                                    
                                    if let available = viewModel.usernameAvailable, !viewModel.username.isEmpty {
                                        Text(available ? "Username is available!" : "Username is already taken")
                                            .font(.caption)
                                            .foregroundColor(available ? .green : .red)
                                    }
                                }
                                
                                // Bio Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Bio")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $viewModel.bio)
                                            .frame(minHeight: 80)
                                            .padding(8)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        
                                        if viewModel.bio.isEmpty {
                                            Text("Tell us about yourself...")
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 16)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    
                                    Text("\(viewModel.bio.count)/200")
                                        .font(.caption)
                                        .foregroundColor(viewModel.bio.count > 200 ? .red : .secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        
                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    viewModel.saveProfile {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(viewModel.isSaving || !viewModel.canSave)
            )
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            PhotoPicker(selectedImage: $viewModel.selectedImage)
        }
    }
}

// Simple Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// ViewModel for Profile Edit
class ProfileEditViewModel: ObservableObject {
    @Published var name: String
    @Published var username: String
    @Published var bio: String
    @Published var selectedImage: UIImage?
    @Published var profileImageUrl: String?
    
    @Published var isCheckingUsername = false
    @Published var usernameAvailable: Bool?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showingImagePicker = false
    
    private let originalUsername: String
    private let userId: String
    private var cancellables = Set<AnyCancellable>()
    
    var canSave: Bool {
        !name.isEmpty && 
        !username.isEmpty && 
        username.count >= 3 && 
        username.count <= 20 &&
        bio.count <= 200 &&
        (username == originalUsername || usernameAvailable == true)
    }
    
    init(currentUser: UserProfile) {
        self.userId = currentUser.id
        self.name = currentUser.name
        self.username = currentUser.username
        self.originalUsername = currentUser.username
        self.bio = currentUser.bio ?? ""
        self.profileImageUrl = currentUser.profileImage
    }
    
    func validateUsername(_ newUsername: String) {
        let cleanedUsername = newUsername.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        if cleanedUsername != newUsername {
            DispatchQueue.main.async {
                self.username = cleanedUsername
            }
        }
        
        // Skip validation if username hasn't changed
        if cleanedUsername == originalUsername {
            usernameAvailable = true
            return
        }
        
        guard cleanedUsername.count >= 3 else {
            usernameAvailable = nil
            return
        }
        
        isCheckingUsername = true
        
        AuthService.shared.checkUsernameAvailability(username: cleanedUsername)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isCheckingUsername = false
                if case .failure = completion {
                    self.usernameAvailable = nil
                }
            }, receiveValue: { available in
                self.usernameAvailable = available
            })
            .store(in: &cancellables)
    }
    
    func saveProfile(completion: @escaping () -> Void) {
        guard canSave else { return }
        
        isSaving = true
        errorMessage = nil
        
        // Update basic profile info first
        updateBasicProfile { [weak self] success in
            if success {
                // Then upload image if one was selected
                if self?.selectedImage != nil {
                    self?.uploadProfileImage(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        self?.isSaving = false
                        completion()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isSaving = false
                }
            }
        }
    }
    
    private func updateBasicProfile(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(APIService.shared.baseURL)/users/\(userId)/profile") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
            }
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "name": name,
            "username": username,
            "bio": bio
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to encode data"
            }
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self.errorMessage = "Failed to update profile"
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }.resume()
    }
    
    private func uploadProfileImage(completion: @escaping () -> Void) {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async {
                self.isSaving = false
                completion()
            }
            return
        }
        
        guard let url = URL(string: "\(APIService.shared.baseURL)/users/\(userId)/profile/image") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
                self.isSaving = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSaving = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self.errorMessage = "Failed to upload image"
                    return
                }
                
                completion()
            }
        }.resume()
    }
}

import Combine
import SwiftUI
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var authError: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Start checking authentication silently in background
        // Don't set isCheckingAuth to true here to avoid UI conflicts with splash
        
        // Check if a token exists
        if let token = AuthService.shared.token {
            validateToken(token)
        } else {
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.isCheckingAuth = false
            }
        }
    }
    
    func checkExistingAuth() {
        isCheckingAuth = true
        authError = nil
        
        // Check if token exists and is valid
        if let token = AuthService.shared.token {
            print("Found existing token: \(String(describing: token.prefix(10)))...")
            
            // Validate token with backend
            validateToken(token)
        } else {
            print("No existing token found")
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.isCheckingAuth = false
            }
        }
    }
    
    private func validateToken(_ token: String) {
        APIService.shared.validateToken()
            .receive(on: DispatchQueue.main) // Ensure UI updates on main thread
            .sink { completion in
                self.isCheckingAuth = false
                
                if case .failure(let error) = completion {
                    print("Token validation failed: \(error)")
                    self.isAuthenticated = false
                    self.authError = "Session expired. Please login again."
                    
                    // Clear invalid token
                    AuthService.shared.logout()
                }
            } receiveValue: { isValid in
                self.isCheckingAuth = false
                self.isAuthenticated = isValid
                print("Token validation result: \(isValid)")
                
                if isValid {
                    // Sync data in background after successful authentication
                    SyncService.shared.performInitialSync()
                }
            }
            .store(in: &cancellables)
    }
    
    func login(email: String, password: String) -> AnyPublisher<Bool, Error> {
        DispatchQueue.main.async {
            self.isCheckingAuth = true
            self.authError = nil
        }
        
        return AuthService.shared.login(email: email, password: password)
            .receive(on: DispatchQueue.main) // Ensure UI updates happen on main thread
            .handleEvents(receiveOutput: { success in
                if success {
                    self.isAuthenticated = true
                    SyncService.shared.performInitialSync()
                }
                self.isCheckingAuth = false
            }, receiveCompletion: { completion in
                self.isCheckingAuth = false
                if case .failure(let error) = completion {
                    self.authError = error.localizedDescription
                }
            })
            .eraseToAnyPublisher()
    }
    
    func logout() {
        AuthService.shared.logout()
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
}

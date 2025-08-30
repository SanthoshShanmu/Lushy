import SwiftUI

struct MoreView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Beauty Features Section
                Section("Beauty Features") {
                    NavigationLink(destination: WishlistView().environmentObject(authManager)) {
                        Label("Wishlist", systemImage: "heart.text.square")
                            .foregroundColor(.lushyPink)
                    }
                    
                    NavigationLink(destination: StatsView()) {
                        Label("Beauty Stats", systemImage: "chart.bar.fill")
                            .foregroundColor(.lushyPurple)
                    }
                    
                    NavigationLink(destination: FavoritesView(viewModel: FavoritesViewModel())) {
                        Label("Favorites", systemImage: "star.fill")
                            .foregroundColor(.mossGreen)
                    }
                    
                    NavigationLink(destination: BeautyBagsView()) {
                        Label("Beauty Bags", systemImage: "bag.fill")
                            .foregroundColor(.lushyPeach)
                    }
                    
                    NavigationLink(destination: FinishedProductsView()) {
                        Label("Finished Products", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.mossGreen)
                    }
                }
                
                // Account Section
                Section("Account") {
                    NavigationLink(destination: SettingsView().environmentObject(authManager)) {
                        Label("Settings", systemImage: "gearshape.fill")
                            .foregroundColor(.lushyPurple)
                    }
                    
                    if authManager.isAuthenticated {
                        Button(action: { showingLogoutAlert = true }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.lushyPink.opacity(0.8))
                        }
                    }
                }
            }
            .navigationTitle("More")
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct SettingsView: View {
    @State private var showingPasswordChange = false
    @State private var showingEmailChange = false
    @State private var commentsAndLikes = false
    @State private var usageReminders = false
    @State private var newFollowers = false
    @State private var usageReminderDays = 7
    @State private var isLoadingPreferences = true
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        List {
            // Account Security Section
            Section("Account & Security") {
                Button(action: { showingPasswordChange = true }) {
                    HStack {
                        Label("Change Password", systemImage: "lock.rotation")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                
                Button(action: { showingEmailChange = true }) {
                    HStack {
                        Label("Change Email Address", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
            }
            
            // Notifications Section
            Section("Notifications") {
                if isLoadingPreferences {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                    .padding()
                } else {
                    Toggle(isOn: $commentsAndLikes) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Comments & Likes")
                                .font(.subheadline)
                            Text("Activity on your feed posts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: commentsAndLikes) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "notif_comments_likes")
                        syncNotificationPreferences()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $usageReminders) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Usage Journey Reminders")
                                    .font(.subheadline)
                                Text("Reminds you to use products")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: usageReminders) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "notif_usage_reminders")
                            handleUsageRemindersToggle(enabled: newValue)
                            syncNotificationPreferences()
                        }
                        
                        if usageReminders {
                            HStack {
                                Text("Remind after:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("Days", selection: $usageReminderDays) {
                                    Text("3 days").tag(3)
                                    Text("7 days").tag(7)
                                    Text("14 days").tag(14)
                                    Text("30 days").tag(30)
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: usageReminderDays) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "notif_usage_reminder_days")
                                    syncNotificationPreferences()
                                }
                            }
                            .padding(.leading, 32)
                        }
                    }
                    
                    Toggle(isOn: $newFollowers) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Followers")
                                .font(.subheadline)
                            Text("When someone follows you")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: newFollowers) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "notif_new_followers")
                        syncNotificationPreferences()
                    }
                }
            }
            
            // Legal Section
            Section("Legal") {
                Button(action: {
                    if let url = URL(string: "https://example.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
                
                Button(action: {
                    if let url = URL(string: "https://example.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Label("Privacy Policy", systemImage: "shield.checkerboard")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingPasswordChange) {
            ChangePasswordView()
        }
        .sheet(isPresented: $showingEmailChange) {
            ChangeEmailView()
        }
        .onAppear {
            // Request notification permissions when settings appear
            NotificationService.shared.requestNotificationPermission()
            // Fetch current preferences from backend
            fetchNotificationPreferences()
        }
    }
    
    private func handleUsageRemindersToggle(enabled: Bool) {
        if enabled {
            // Enable usage reminder notifications for all products
            let products = CoreDataManager.shared.fetchUserProducts()
            for product in products {
                if product.openDate != nil {
                    scheduleUsageReminder(for: product, afterDays: usageReminderDays)
                }
            }
        } else {
            // Cancel all usage reminder notifications
            cancelAllUsageReminders()
        }
    }
    
    private func scheduleUsageReminder(for product: UserProduct, afterDays days: Int) {
        guard let lastUsedDate = product.openDate else { return }
        let reminderDate = Calendar.current.date(byAdding: .day, value: days, to: lastUsedDate)
        
        guard let reminderDate = reminderDate, reminderDate > Date() else { return }
        
        let productName = product.productName ?? "Your product"
        let identifier = "usage_\(product.objectID.uriRepresentation().absoluteString)"
        
        NotificationService.shared.scheduleLocalNotification(
            identifier: identifier,
            title: "Time to use your product!",
            body: "It's been \(days) days since you used \(productName). Consider using it again!",
            date: reminderDate
        )
    }
    
    private func cancelAllUsageReminders() {
        let products = CoreDataManager.shared.fetchUserProducts()
        for product in products {
            let identifier = "usage_\(product.objectID.uriRepresentation().absoluteString)"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
    
    private func syncNotificationPreferences() {
        guard let userId = AuthService.shared.userId else { return }
        
        let preferences: [String: Any] = [
            "commentsAndLikes": commentsAndLikes,
            "usageReminders": usageReminders,
            "newFollowers": newFollowers,
            "usageReminderDays": usageReminderDays
        ]
        
        APIService.shared.updateNotificationPreferences(userId: userId, preferences: preferences) { result in
            switch result {
            case .success:
                print("Notification preferences synced to backend")
            case .failure(let error):
                print("Failed to sync notification preferences: \(error)")
            }
        }
    }
    
    private func fetchNotificationPreferences() {
        guard let userId = AuthService.shared.userId else {
            // If not authenticated, load from UserDefaults
            loadFromUserDefaults()
            return
        }
        
        isLoadingPreferences = true
        
        APIService.shared.getNotificationPreferences(userId: userId) { result in
            DispatchQueue.main.async {
                isLoadingPreferences = false
                
                switch result {
                case .success(let preferences):
                    // Update UI with backend values
                    commentsAndLikes = preferences["commentsAndLikes"] as? Bool ?? true
                    usageReminders = preferences["usageReminders"] as? Bool ?? false
                    newFollowers = preferences["newFollowers"] as? Bool ?? true
                    usageReminderDays = preferences["usageReminderDays"] as? Int ?? 7
                    
                    // Also update UserDefaults for consistency
                    UserDefaults.standard.set(commentsAndLikes, forKey: "notif_comments_likes")
                    UserDefaults.standard.set(usageReminders, forKey: "notif_usage_reminders")
                    UserDefaults.standard.set(newFollowers, forKey: "notif_new_followers")
                    UserDefaults.standard.set(usageReminderDays, forKey: "notif_usage_reminder_days")
                    
                case .failure(let error):
                    print("Failed to fetch notification preferences: \(error)")
                    // Fall back to UserDefaults
                    loadFromUserDefaults()
                }
            }
        }
    }
    
    private func loadFromUserDefaults() {
        commentsAndLikes = UserDefaults.standard.object(forKey: "notif_comments_likes") as? Bool ?? true
        usageReminders = UserDefaults.standard.object(forKey: "notif_usage_reminders") as? Bool ?? false
        newFollowers = UserDefaults.standard.object(forKey: "notif_new_followers") as? Bool ?? true
        usageReminderDays = UserDefaults.standard.object(forKey: "notif_usage_reminder_days") as? Int ?? 7
        isLoadingPreferences = false
    }
}
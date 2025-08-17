import SwiftUI

struct UsageTrackingView: View {
    @ObservedObject var usageViewModel: UsageTrackingViewModel
    @State private var showingCheckInSheet = false
    @State private var checkInContext: String = "morning_routine"
    @State private var checkInNotes: String = ""
    @State private var customCheckInDate: Date = Date()
    
    private let usageContexts = [
        ("morning_routine", "Morning Routine", "sun.max"),
        ("evening_routine", "Evening Routine", "moon"),
        ("special_occasion", "Special Occasion", "star"),
        ("work_day", "Work/Professional", "briefcase"),
        ("weekend", "Casual/Weekend", "house"),
        ("travel", "Travel", "airplane"),
        ("gym_sports", "Gym/Sports", "figure.walk"),
        ("date_night", "Date Night", "heart"),
        ("general", "General", "circle")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Usage Overview Section
            usageOverviewSection
            
            // Show finished message instead of tracking if product is finished
            if usageViewModel.isUsageTrackingDisabled {
                finishedSection
            } else {
                // Quick Check-in Section
                quickCheckInSection
            }
            
            // Recent Check-ins History
            recentCheckInsSection
        }
    }
    
    private var usageOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Usage Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Usage stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UsageStatCard(
                    icon: "calendar",
                    title: "Check-ins",
                    value: "\(usageViewModel.totalCheckIns)",
                    subtitle: "times used",
                    color: .lushyMint
                )
                
                UsageStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "This Week",
                    value: "\(usageViewModel.weeklyCheckIns)",
                    subtitle: "uses",
                    color: .lushyPeach
                )
                
                UsageStatCard(
                    icon: "clock",
                    title: "Days Since",
                    value: "\(usageViewModel.daysSinceLastUse)",
                    subtitle: "last use",
                    color: .lushyPurple
                )
            }
            
            // Usage frequency insight
            if !usageViewModel.usageFrequencyInsight.isEmpty {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.lushyPink)
                    Text(usageViewModel.usageFrequencyInsight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.lushyPink.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var quickCheckInSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Check-in")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Text("Did you use this product today?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    // Quick check-in for today
                    Button(action: {
                        usageViewModel.quickCheckIn(
                            context: "general",
                            notes: nil,
                            date: Date()
                        )
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Used Today")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.lushyMint, .lushyPeach],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    // Detailed check-in with custom date
                    Button(action: {
                        checkInContext = "morning_routine"
                        checkInNotes = ""
                        customCheckInDate = Date()
                        showingCheckInSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Detailed")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.lushyPink)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.lushyPink, lineWidth: 1.5)
                        )
                    }
                }
                
                // Finish product button (only show after significant usage)
                if usageViewModel.totalCheckIns >= 10 && !usageViewModel.isUsageTrackingDisabled {
                    Button(action: {
                        usageViewModel.isShowingFinishConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Finished")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingCheckInSheet) {
            DetailedCheckInSheet(
                context: $checkInContext,
                notes: $checkInNotes,
                date: $customCheckInDate,
                contexts: usageContexts,
                purchaseDate: usageViewModel.product.purchaseDate,
                onSave: { context, notes, date in
                    usageViewModel.quickCheckIn(
                        context: context,
                        notes: notes.isEmpty ? nil : notes,
                        date: date
                    )
                }
            )
        }
        .alert("Mark Product as Finished?", isPresented: $usageViewModel.isShowingFinishConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Finish", role: .destructive) {
                usageViewModel.finishProduct()
            }
        } message: {
            Text("This will mark the product as finished. You can still view your usage history.")
        }
    }
    
    private var finishedSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Product Finished!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                Spacer()
            }
            
            Text("This product has been marked as finished. View your complete usage history below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var recentCheckInsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if !usageViewModel.usageCheckIns.isEmpty {
                    NavigationLink("View All") {
                        UsageHistoryView(viewModel: usageViewModel)
                    }
                    .font(.caption)
                    .foregroundColor(.lushyPink)
                }
            }
            
            if usageViewModel.usageCheckIns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("No usage tracked yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Check in when you use this product to track your beauty routine")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(usageViewModel.usageCheckIns.prefix(3)), id: \.objectID) { checkIn in
                        UsageCheckInRow(checkIn: checkIn, contexts: usageContexts)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// Updated usage stat card
struct UsageStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// Usage check-in row
struct UsageCheckInRow: View {
    let checkIn: UsageEntryDisplay
    let contexts: [(String, String, String)]
    
    var body: some View {
        HStack(spacing: 12) {
            // Context icon
            let contextInfo = contexts.first { $0.0 == checkIn.context } ?? ("general", "General", "circle")
            Image(systemName: contextInfo.2)
                .font(.title3)
                .foregroundColor(.lushyMint)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contextInfo.1)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let notes = checkIn.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(formatDate(checkIn.date))
                    .font(.caption2)
                    .foregroundColor(.lushyPink)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// Detailed check-in sheet
struct DetailedCheckInSheet: View {
    @Binding var context: String
    @Binding var notes: String
    @Binding var date: Date
    let contexts: [(String, String, String)]
    let purchaseDate: Date?
    let onSave: (String, String, Date) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("When did you use this?")) {
                    DatePicker("Date", selection: $date, in: dateRange, displayedComponents: .date)
                }
                
                Section(header: Text("Context")) {
                    Picker("Usage Context", selection: $context) {
                        ForEach(contexts, id: \.0) { contextItem in
                            HStack {
                                Image(systemName: contextItem.2)
                                Text(contextItem.1)
                            }
                            .tag(contextItem.0)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("How did it work? Any observations?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(context, notes, date)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var dateRange: ClosedRange<Date> {
        let startDate = purchaseDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Date()
        return startDate...endDate
    }
}
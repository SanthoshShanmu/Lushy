import SwiftUI

struct UsageTrackingView: View {
    @ObservedObject var usageViewModel: UsageTrackingViewModel
    @State private var showingCheckInSheet = false
    @State private var checkInContext: String = "general"
    @State private var checkInNotes: String = ""
    @State private var customCheckInDate: Date = Date()
    @State private var reminderEnabled: Bool = false
    @State private var reminderDays: Int = 7
    @State private var dailyUseToggle: Bool = false
    
    private let usageContexts = [
        ("general", "General", "circle"),
        ("morning_routine", "Morning Routine", "sun.max"),
        ("evening_routine", "Evening Routine", "moon"),
        ("work", "Professional", "briefcase"),
        ("special_occasion", "Special Occasion", "star"),
        ("self_care", "Self-care", "heart"),
        ("sports", "Sports", "figure.walk"),
        ("travel", "Travel", "airplane")
    ]

    var body: some View {
        VStack(spacing: 16) {
            usageOverviewSection
            
            if usageViewModel.isUsageTrackingDisabled {
                finishedSection
            } else {
                checkInSection
                usageSettingsSection
            }
            
            // Only show insights section when there's actually an insight to display
            if usageViewModel.usagePatternInsight != nil && !(usageViewModel.usagePatternInsight?.isEmpty ?? true) {
                usageInsightsSection
            }
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
                    color: .mossGreen
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
            
            if !usageViewModel.usageFrequencyInsight.isEmpty {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.lushyPink)
                    Text(usageViewModel.usageFrequencyInsight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !usageViewModel.usageCheckIns.isEmpty {
                        Button("View All") {
                        }
                        .font(.caption)
                        .foregroundColor(.lushyPink)
                    }
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
    
    private var checkInSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Check-in")
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
                            Color.lushyPink
                        )
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        checkInContext = "general"
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
    
    private var usageSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Use Product")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("I use this product approximately every day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $dailyUseToggle)
                        .toggleStyle(SwitchToggleStyle(tint: .lushyPink))
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage Reminders")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Remind me when \(reminderDays) days have passed since last use")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $reminderEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .lushyPink))
                }
                
                if reminderEnabled {
                    HStack {
                        Text("Remind after:")
                        Spacer()
                        Picker("Days", selection: $reminderDays) {
                            ForEach([3, 7, 14, 30], id: \.self) { days in
                                Text("\(days) days").tag(days)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lushyPurple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lushyPurple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var usageInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let insight = usageViewModel.usagePatternInsight {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.mossGreen)
                        Text(insight)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.mossGreen.opacity(0.1))
                    )
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - DetailedCheckInSheet Component
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
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Add Usage Check-in")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Record when and how you used this product")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        DatePicker("Check-in Date", selection: $date, in: dateRange, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    // Context selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(contexts, id: \.0) { contextOption in
                                    let isSelected = context == contextOption.0
                                    Button(action: {
                                        context = contextOption.0
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: contextOption.2)
                                                .font(.caption)
                                            Text(contextOption.1)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(isSelected ? .white : Color.lushyPink)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(isSelected ? Color.lushyPink : Color.lushyPink.opacity(0.1))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        TextField("How did it work for you today?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Usage Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color.lushyPink)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(context, notes, date)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color.lushyPink)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var dateRange: ClosedRange<Date> {
        let endDate = Date()
        let startDate = purchaseDate ?? Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        return startDate...endDate
    }
}
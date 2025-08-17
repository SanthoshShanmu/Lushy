import SwiftUI

struct UsageJourneyView: View {
    @StateObject private var viewModel: UsageJourneyViewModel
    @Environment(\.presentationMode) var presentationMode
    
    init(product: UserProduct) {
        _viewModel = StateObject(wrappedValue: UsageJourneyViewModel(product: product))
    }
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.1),
                    Color.lushyPurple.opacity(0.05),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Timeline
                    if viewModel.events.isEmpty {
                        emptyStateView
                    } else {
                        timelineView
                    }
                    
                    // Add thought section
                    addThoughtSection
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Usage Journey")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.createInitialEvents()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.lushyPink)
                
                Text("Your Beauty Journey")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Track your experiences and thoughts about this product")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Journey stats
            HStack(spacing: 30) {
                StatCard(
                    icon: "calendar",
                    title: "Milestones",
                    value: "\(milestoneCount)",
                    color: .lushyMint
                )
                
                StatCard(
                    icon: "bubble.left.fill",
                    title: "Thoughts",
                    value: "\(thoughtCount)",
                    color: .lushyPeach
                )
                
                StatCard(
                    icon: "clock",
                    title: "Days",
                    value: "\(daysSincePurchase)",
                    color: .lushyPurple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.lushyPink.opacity(0.3))
            
            Text("Your journey starts here")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Add your first thought about this product to begin tracking your experience")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
    
    private var timelineView: some View {
        LazyVStack(spacing: 20) {
            ForEach(Array(viewModel.events.enumerated()), id: \.element.objectID) { index, event in
                TimelineEventView(
                    event: event,
                    isLast: index == viewModel.events.count - 1
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var addThoughtSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "plus.bubble.fill")
                    .font(.title3)
                    .foregroundColor(.lushyPink)
                
                Text("Add a Thought")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                TextField("What are you thinking about this product?", text: $viewModel.newThoughtText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.addThought()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add for Today")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            LinearGradient(
                                colors: [.lushyPink, .lushyPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.newThoughtText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button(action: {
                        viewModel.showingCustomDateSheet = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Custom Date")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.lushyPink)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.lushyPink, lineWidth: 1)
                        )
                    }
                    .disabled(viewModel.newThoughtText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 20)
        .sheet(isPresented: $viewModel.showingCustomDateSheet) {
            AddThoughtWithDateSheet(
                text: $viewModel.newThoughtText,
                date: $viewModel.customThoughtDate,
                purchaseDate: viewModel.product.purchaseDate,
                onSave: { text, date in
                    viewModel.addThought(withDate: date)
                }
            )
        }
    }
    
    // Computed properties for stats
    private var milestoneCount: Int {
        viewModel.events.filter { event in
            ["purchase", "open", "finished"].contains(event.eventType)
        }.count
    }
    
    private var thoughtCount: Int {
        viewModel.events.filter { $0.eventType == "thought" }.count
    }
    
    private var daysSincePurchase: Int {
        // Calculate days since purchase date if available
        guard let purchaseDate = viewModel.events.first(where: { $0.eventType == "purchase" })?.createdAt else {
            return 0
        }
        let days = Calendar.current.dateComponents([.day], from: purchaseDate, to: Date()).day ?? 0
        return max(0, days)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct TimelineEventView: View {
    let event: UsageJourneyEvent
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }
            
            // Event content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(eventTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(event.createdAt ?? Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let text = event.text, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(eventColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var eventColor: Color {
        switch event.eventType {
        case "purchase": return .lushyMint
        case "open": return .lushyPeach
        case "finished": return .green
        case "thought": return .lushyPink
        default: return .lushyPurple
        }
    }
    
    private var eventTitle: String {
        switch event.eventType {
        case "purchase": return "Purchased"
        case "open": return "First Use"
        case "finished": return "Finished"
        case "thought": return "Thought"
        default: return "Event"
        }
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

// Sheet for adding thoughts with custom dates
struct AddThoughtWithDateSheet: View {
    @Binding var text: String
    @Binding var date: Date
    let purchaseDate: Date?
    let onSave: (String, Date) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thought Details")) {
                    TextField("What are you thinking about this product?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                    
                    DatePicker("Date", selection: $date, in: dateRange, displayedComponents: .date)
                }
                
                Section {
                    HStack {
                        Spacer()
                        Text("This thought will be added to your journey for \(formatDate(date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Add Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(text, date)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var dateRange: ClosedRange<Date> {
        let startDate = purchaseDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Date()
        return startDate...endDate
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
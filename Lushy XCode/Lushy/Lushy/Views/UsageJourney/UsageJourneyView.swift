import SwiftUI

struct UsageJourneyView: View {
    @StateObject private var viewModel: UsageJourneyViewModel
    @ObservedObject var usageTrackingViewModel: UsageTrackingViewModel
    @State private var showingThoughtSheet = false
    @State private var showingProductDetailSheet = false
    @State private var showingUsageSheet = false
    @State private var refreshTrigger = false
    
    init(product: UserProduct, usageTrackingViewModel: UsageTrackingViewModel) {
        self._viewModel = StateObject(wrappedValue: UsageJourneyViewModel(product: product))
        self.usageTrackingViewModel = usageTrackingViewModel
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Product header
                    productHeader
                    
                    // Journey stats
                    journeyStats
                    
                    // Action buttons
                    actionButtons
                    
                    // Timeline
                    timelineSection
                }
                .padding()
            }
            .navigationTitle("Usage Journey")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.ensureInitialEventsExist() // Only call this one method
            }
            .sheet(isPresented: $showingThoughtSheet) {
                ThoughtEntrySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingProductDetailSheet) {
                ProductDetailView(viewModel: ProductDetailViewModel(product: viewModel.product))
            }
            .sheet(isPresented: $showingUsageSheet) {
                UsageEntrySheet(
                    product: viewModel.product,
                    usageTrackingViewModel: usageTrackingViewModel,
                    showingSheet: $showingUsageSheet
                )
            }
        }
    }
    
    private var productHeader: some View {
        VStack(spacing: 12) {
            HStack {
                AsyncImage(url: URL(string: viewModel.product.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.product.productName ?? "Product")
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    if let brand = viewModel.product.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(viewModel.product.isFinished ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.product.isFinished ? "Finished" : "In Use")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.product.isFinished ? .green : .orange)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var journeyStats: some View {
        HStack(spacing: 20) {
            JourneyStatCard(
                icon: "calendar",
                title: "Timeline Items",
                value: "\(viewModel.getTotalTimelineItems())",
                color: .lushyPink
            )
            
            JourneyStatCard(
                icon: "bubble.left.fill",
                title: "Thoughts",
                value: "\(viewModel.getThoughtCount())",
                color: .lushyPurple
            )
            
            JourneyStatCard(
                icon: "clock",
                title: "Days Owned",
                value: "\(daysSincePurchase)",
                color: .mossGreen
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    showingThoughtSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Thought")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.lushyPink)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showingUsageSheet = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Log Usage")
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
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Journey Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(timelineItems, id: \.id) { item in
                    TimelineItemView(item: item)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        
        // Add journey events
        for event in viewModel.events {
            items.append(TimelineItem(
                id: event.objectID.uriRepresentation().absoluteString,
                type: .journeyEvent,
                date: event.createdAt ?? Date(),
                title: event.eventType?.capitalized ?? "Event",
                subtitle: event.text,
                icon: iconForEventType(event.eventType ?? ""),
                color: colorForEventType(event.eventType ?? "")
            ))
        }
        
        // Add usage entries
        let usageEntries = CoreDataManager.shared.fetchUsageEntries(for: viewModel.product.objectID)
        for entry in usageEntries {
            let metadata = parseUsageMetadata(entry.notes)
            items.append(TimelineItem(
                id: entry.objectID.uriRepresentation().absoluteString,
                type: .usageEntry,
                date: entry.createdAt,
                title: "Used Product",
                subtitle: metadata.notes.isEmpty ? metadata.context.capitalized : metadata.notes,
                icon: "checkmark.circle.fill",
                color: .lushyPeach
            ))
        }
        
        return items.sorted { $0.date < $1.date }
    }
    
    private var daysSincePurchase: Int {
        guard let purchaseDate = viewModel.product.purchaseDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: purchaseDate, to: Date()).day ?? 0
    }
    
    private func iconForEventType(_ eventType: String) -> String {
        switch eventType {
        case "purchase": return "bag.fill"
        case "open": return "lock.open.fill"
        case "finished": return "checkmark.seal.fill"
        case "thought": return "bubble.left.fill"
        default: return "circle.fill"
        }
    }
    
    private func colorForEventType(_ eventType: String) -> Color {
        switch eventType {
        case "purchase": return .mossGreen
        case "open": return .lushyPurple
        case "finished": return .green
        case "thought": return .lushyPink
        default: return .gray
        }
    }
    
    private func parseUsageMetadata(_ notes: String?) -> (context: String, notes: String, rating: Int) {
        guard let notes = notes,
              let data = notes.data(using: .utf8),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("general", "", 0)
        }
        
        let context = metadata["context"] as? String ?? "general"
        let userNotes = metadata["notes"] as? String ?? ""
        let rating = metadata["rating"] as? Int ?? 0
        
        return (context, userNotes, rating)
    }
}

// MARK: - Supporting Views

struct JourneyStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct TimelineItem {
    let id: String
    let type: TimelineItemType
    let date: Date
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    enum TimelineItemType {
        case journeyEvent
        case usageEntry
    }
}

struct TimelineItemView: View {
    let item: TimelineItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Timeline dot
            Circle()
                .fill(item.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formatDate(item.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.color.opacity(0.05))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today, \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Sheet Views

struct ThoughtEntrySheet: View {
    @ObservedObject var viewModel: UsageJourneyViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextEditor(text: $viewModel.newThoughtText)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .frame(minHeight: 120)
                
                Spacer()
            }
            .padding()
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
                        viewModel.addThought()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(viewModel.newThoughtText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct UsageEntrySheet: View {
    let product: UserProduct
    @ObservedObject var usageTrackingViewModel: UsageTrackingViewModel
    @Binding var showingSheet: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Quick check-in for using this product")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    usageTrackingViewModel.quickCheckIn(
                        context: "general",
                        notes: nil,
                        date: Date()
                    )
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log Usage Now")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.lushyPink)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Log Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
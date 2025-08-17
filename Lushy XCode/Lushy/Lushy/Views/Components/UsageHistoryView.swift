import SwiftUI

struct UsageHistoryView: View {
    @ObservedObject var viewModel: UsageTrackingViewModel
    
    // Usage contexts for check-in display
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
        VStack(spacing: 0) {
            // Header with check-in stats
            headerSection
            
            // Usage check-ins list
            if viewModel.usageCheckIns.isEmpty {
                emptyStateView
            } else {
                checkInsList
            }
        }
        .navigationTitle("Usage History")
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Usage overview
            VStack(spacing: 8) {
                HStack {
                    Text("Usage Overview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(viewModel.totalCheckIns) check-ins")
                        .font(.subheadline)
                        .foregroundColor(.lushyPink)
                        .fontWeight(.medium)
                }
            }
            
            // Simple stats
            HStack(spacing: 20) {
                UsageStatCard(
                    icon: "calendar.badge.checkmark",
                    title: "Total Uses",
                    value: "\(viewModel.totalCheckIns)",
                    subtitle: "check-ins",
                    color: .lushyMint
                )
                
                UsageStatCard(
                    icon: "calendar.badge.clock",
                    title: "This Week",
                    value: "\(viewModel.weeklyCheckIns)",
                    subtitle: "uses",
                    color: .lushyPeach
                )
                
                UsageStatCard(
                    icon: "clock",
                    title: "Last Used",
                    value: viewModel.daysSinceLastUse == 0 ? "Today" : "\(viewModel.daysSinceLastUse)d ago",
                    subtitle: "days",
                    color: .lushyPurple
                )
            }
            
            // Usage insights
            if !viewModel.usageFrequencyInsight.isEmpty {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.lushyPink)
                    Text(viewModel.usageFrequencyInsight)
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
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var checkInsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedCheckIns, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date header
                        HStack {
                            Text(group.date)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(group.checkIns.count) use\(group.checkIns.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Check-ins for this date
                        ForEach(group.checkIns.indices, id: \.self) { index in
                            UsageCheckInRow(checkIn: group.checkIns[index], contexts: usageContexts)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var groupedCheckIns: [UsageCheckInGroup] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let grouped = Dictionary(grouping: viewModel.usageCheckIns) { checkIn in
            dateFormatter.string(from: checkIn.date)
        }
        
        return grouped.map { date, checkIns in
            UsageCheckInGroup(date: date, checkIns: checkIns.sorted { $0.date > $1.date })
        }.sorted { group1, group2 in
            // Sort by date, most recent first
            guard let date1 = dateFormatter.date(from: group1.date),
                  let date2 = dateFormatter.date(from: group2.date) else {
                return false
            }
            return date1 > date2
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Check-ins Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start checking in when you use this product to see your usage history here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// Row for individual usage entries
struct UsageEntryRow: View {
    let entry: UsageEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on rating
            Circle()
                .fill(ratingColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Entry details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Used product")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if parsedMetadata.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= parsedMetadata.rating ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Context and notes
                if !parsedMetadata.context.isEmpty && parsedMetadata.context != "general" {
                    Text(parsedMetadata.context.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.lushyPeach.opacity(0.2))
                        .foregroundColor(.lushyPeach)
                        .cornerRadius(4)
                }
                
                if !parsedMetadata.notes.isEmpty {
                    Text(parsedMetadata.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(formatTime(entry.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // Parse metadata from notes
    private var parsedMetadata: (rating: Int, context: String, notes: String) {
        guard let notes = entry.notes else { return (5, "general", "") }
        
        // Try to parse JSON first
        if let jsonData = notes.data(using: .utf8),
           let metadata = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let rating = metadata["rating"] as? Int ?? 5
            let context = metadata["context"] as? String ?? "general"
            let userNotes = metadata["notes"] as? String ?? ""
            return (rating, context, userNotes)
        }
        
        // Fallback parsing
        return (5, "general", notes)
    }
    
    private var ratingColor: Color {
        let rating = parsedMetadata.rating
        switch rating {
        case 5: return .green
        case 4: return .lushyMint
        case 3: return .orange
        case 2: return .lushyPeach
        case 1: return .red
        default: return .gray
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Data structure for grouping check-ins by date
struct UsageCheckInGroup {
    let date: String
    let checkIns: [UsageEntryDisplay]
}

// Data structure for grouping entries by date
struct UsageGroup {
    let date: String
    let entries: [UsageEntry]
}
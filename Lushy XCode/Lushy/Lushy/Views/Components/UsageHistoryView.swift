import SwiftUI

struct UsageHistoryView: View {
    @ObservedObject var viewModel: UsageTrackingViewModel
    @State private var showingStatsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            headerSection
            
            // Usage entries list
            if viewModel.usageEntries.isEmpty {
                emptyStateView
            } else {
                usageEntriesList
            }
        }
        .navigationTitle("Usage History")
        .navigationBarItems(trailing: 
            Button(action: { showingStatsSheet = true }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(.lushyPink)
            }
        )
        .sheet(isPresented: $showingStatsSheet) {
            UsageStatsSheet(viewModel: viewModel)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Progress overview
            VStack(spacing: 8) {
                HStack {
                    Text("Current Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(viewModel.currentAmount))% remaining")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: viewModel.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .lushyPink))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            
            // Quick stats
            HStack(spacing: 20) {
                StatBubble(
                    title: "Total Uses",
                    value: "\(viewModel.usageEntries.count)",
                    color: .lushyMint
                )
                
                StatBubble(
                    title: "This Week",
                    value: String(format: "%.1f%%", viewModel.averageUsagePerWeek),
                    color: .lushyPeach
                )
                
                if let finishDate = viewModel.predictedFinishDate {
                    StatBubble(
                        title: "Est. Finish",
                        value: formatShortDate(finishDate),
                        color: .lushyPurple
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
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var usageEntriesList: some View {
        List {
            ForEach(groupedEntries, id: \.date) { group in
                Section(header: Text(group.date).font(.subheadline).fontWeight(.medium)) {
                    ForEach(group.entries, id: \.objectID) { entry in
                        UsageHistoryRow(entry: entry)
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Usage History")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start tracking your product usage to see detailed insights and patterns here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    private var groupedEntries: [UsageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.usageEntries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
        
        return grouped.map { (date, entries) in
            UsageGroup(
                date: formatDateHeader(date),
                entries: entries.sorted { $0.createdAt > $1.createdAt }
            )
        }
        .sorted { first, second in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return (formatter.date(from: first.date) ?? Date()) > (formatter.date(from: second.date) ?? Date())
        }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct UsageGroup {
    let date: String
    let entries: [UsageEntry]
}

struct StatBubble: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct UsageHistoryRow: View {
    let entry: UsageEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Usage type icon
            Image(systemName: iconForUsageType(entry.usageType))
                .font(.title3)
                .foregroundColor(colorForUsageType(entry.usageType))
                .frame(width: 30)
            
            // Usage details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.usageType.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formatTime(entry.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Amount used
            VStack(alignment: .trailing, spacing: 2) {
                Text("-\(String(format: "%.1f", entry.usageAmount))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForUsageType(entry.usageType))
            }
        }
        .padding(.vertical, 8)
    }
    
    private func iconForUsageType(_ type: String) -> String {
        switch type {
        case "light": return "drop"
        case "medium": return "drop.fill"
        case "heavy": return "drop.triangle.fill"
        default: return "circle.fill"
        }
    }
    
    private func colorForUsageType(_ type: String) -> Color {
        switch type {
        case "light": return .lushyMint
        case "medium": return .lushyPeach
        case "heavy": return .lushyPink
        default: return .lushyPurple
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct UsageStatsSheet: View {
    @ObservedObject var viewModel: UsageTrackingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Usage pattern analysis
                    usagePatternSection
                    
                    // Weekly breakdown
                    weeklyBreakdownSection
                    
                    // Usage type distribution
                    usageTypeDistributionSection
                }
                .padding()
            }
            .navigationTitle("Usage Analytics")
            .navigationBarItems(trailing: 
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var usagePatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Pattern")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(usagePatternDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lushyMint.opacity(0.1))
        )
    }
    
    private var weeklyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Usage")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("Average per week:")
                Spacer()
                Text(String(format: "%.1f%%", viewModel.averageUsagePerWeek))
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPink)
            }
            
            if viewModel.averageUsagePerWeek > 0 && viewModel.currentAmount > 0 {
                let weeksRemaining = viewModel.currentAmount / viewModel.averageUsagePerWeek
                HStack {
                    Text("Estimated weeks remaining:")
                    Spacer()
                    Text(String(format: "%.1f weeks", weeksRemaining))
                        .fontWeight(.semibold)
                        .foregroundColor(.lushyPeach)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lushyPeach.opacity(0.1))
        )
    }
    
    private var usageTypeDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Type Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(usageTypeStats, id: \.type) { stat in
                HStack {
                    Image(systemName: iconForType(stat.type))
                        .foregroundColor(colorForType(stat.type))
                        .frame(width: 20)
                    
                    Text(stat.type.capitalized)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(stat.count)")
                        .fontWeight(.semibold)
                    
                    Text("(\(stat.percentage)%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lushyPurple.opacity(0.1))
        )
    }
    
    private var usagePatternDescription: String {
        let frequency = viewModel.usageFrequency.lowercased()
        if frequency.contains("daily") {
            return "You're using this product daily. This indicates it's likely part of your regular routine."
        } else if frequency.contains("frequently") {
            return "You use this product frequently throughout the week. Great consistency!"
        } else if frequency.contains("once") {
            return "You used this product once this week. Consider if this usage pattern meets your needs."
        } else {
            return "You haven't used this product recently. Consider if it's still relevant to your routine."
        }
    }
    
    private var usageTypeStats: [(type: String, count: Int, percentage: Int)] {
        let typeCounts = Dictionary(grouping: viewModel.usageEntries) { $0.usageType }
            .mapValues { $0.count }
        
        let total = viewModel.usageEntries.count
        
        return typeCounts.map { (type, count) in
            let percentage = total > 0 ? Int((Double(count) / Double(total)) * 100) : 0
            return (type: type, count: count, percentage: percentage)
        }
        .sorted { $0.count > $1.count }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "light": return "drop"
        case "medium": return "drop.fill"
        case "heavy": return "drop.triangle.fill"
        default: return "circle.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "light": return .lushyMint
        case "medium": return .lushyPeach
        case "heavy": return .lushyPink
        default: return .lushyPurple
        }
    }
}
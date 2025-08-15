import SwiftUI

struct UsageTrackingView: View {
    @ObservedObject var usageViewModel: UsageTrackingViewModel
    @State private var customAmount: String = ""
    @State private var showingCustomAmount = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Section
            progressSection
            
            // Usage Insights
            insightsSection
            
            // Show finished message instead of usage buttons if product is finished
            if usageViewModel.isUsageTrackingDisabled {
                finishedSection
            } else {
                // Quick Usage Buttons
                quickUsageSection
            }
            
            // Recent Usage History
            recentUsageSection
        }
        .sheet(isPresented: $usageViewModel.isShowingUsageSheet) {
            UsageEntrySheet(viewModel: usageViewModel, customAmount: $customAmount)
        }
        .alert("Finish Product Early?", isPresented: $usageViewModel.isShowingFinishConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Finish", role: .destructive) {
                usageViewModel.finishProductEarly()
            }
        } message: {
            Text("This will mark the product as finished and allow you to add a review. This action cannot be undone.")
        }
    }
    
    // Add finished section
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
            
            Text("This product has been marked as finished. No further usage tracking is available.")
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
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Product Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(usageViewModel.currentAmount))% left")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Visual Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // Progress
                    Rectangle()
                        .fill(LinearGradient(
                            colors: progressGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * usageViewModel.progressPercentage, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: usageViewModel.progressPercentage)
                }
            }
            .frame(height: 8)
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
    
    private var progressGradientColors: [Color] {
        let percentage = usageViewModel.progressPercentage
        if percentage > 0.5 {
            return [.lushyMint, .lushyPeach]
        } else if percentage > 0.2 {
            return [.orange, .yellow]
        } else {
            return [.red, .pink]
        }
    }
    
    private var insightsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Usage Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InsightCard(
                    title: "Frequency",
                    value: usageViewModel.usageFrequency,
                    icon: "clock",
                    color: .lushyPurple
                )
                
                if let finishDate = usageViewModel.predictedFinishDate {
                    InsightCard(
                        title: "Est. Finish",
                        value: formatDate(finishDate),
                        icon: "calendar",
                        color: .lushyMint
                    )
                } else {
                    InsightCard(
                        title: "Usage Rate",
                        value: usageViewModel.averageUsagePerWeek > 0 ? 
                               String(format: "%.1f%%/week", usageViewModel.averageUsagePerWeek) : "No data",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .lushyPeach
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
    
    private var quickUsageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Track Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(usageViewModel.usageTypes.keys.sorted()), id: \.self) { key in
                    if key != "custom" {
                        QuickUsageButton(
                            type: key,
                            description: usageViewModel.usageTypes[key]?.description ?? "",
                            amount: usageViewModel.usageTypes[key]?.amount ?? 0,
                            action: {
                                usageViewModel.addUsageEntry(type: key)
                            }
                        )
                    }
                }
            }
            
            // Custom usage button
            Button(action: {
                usageViewModel.selectedUsageType = "custom"
                usageViewModel.isShowingUsageSheet = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                    Text("Custom Amount")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.lushyPink, .lushyPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            // Finish Early button - only show if product can be finished early
            if usageViewModel.canFinishEarly {
                Button(action: {
                    usageViewModel.isShowingFinishConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Finish Product Early")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
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
    
    private var recentUsageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if !usageViewModel.usageEntries.isEmpty {
                    NavigationLink("View All") {
                        UsageHistoryView(viewModel: usageViewModel)
                    }
                    .font(.caption)
                    .foregroundColor(.lushyPink)
                }
            }
            
            if usageViewModel.usageEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("No usage tracked yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start tracking to see insights!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(usageViewModel.usageEntries.prefix(3)), id: \.objectID) { entry in
                        UsageEntryRow(entry: entry)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct QuickUsageButton: View {
    let type: String
    let description: String
    let amount: Double
    let action: () -> Void
    
    private var buttonColor: Color {
        switch type {
        case "light": return .lushyMint
        case "medium": return .lushyPeach
        case "heavy": return .lushyPink
        default: return .lushyPurple
        }
    }
    
    private var iconName: String {
        switch type {
        case "light": return "drop"
        case "medium": return "drop.fill"
        case "heavy": return "drop.triangle.fill"
        default: return "circle"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(buttonColor)
                
                Text(description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("-\(Int(amount))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(buttonColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UsageEntryRow: View {
    let entry: UsageEntry
    
    var body: some View {
        HStack {
            Image(systemName: iconForUsageType(entry.usageType))
                .foregroundColor(colorForUsageType(entry.usageType))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.usageType.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("-\(Int(entry.usageAmount))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(timeAgo(from: entry.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
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
    
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
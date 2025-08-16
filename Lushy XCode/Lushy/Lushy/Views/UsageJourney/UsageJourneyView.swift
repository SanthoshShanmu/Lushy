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
            // Journey progress indicator
            HStack {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundColor(.lushyPink)
                Text("Your Beauty Journey")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Journey stats
            HStack(spacing: 30) {
                StatBubble(
                    title: "Events",
                    value: "\(viewModel.events.count)",
                    color: .lushyMint
                )
                
                StatBubble(
                    title: "Thoughts",
                    value: "\(viewModel.events.filter { $0.eventType == UsageJourneyEvent.EventType.thought.rawValue }.count)",
                    color: .lushyPeach
                )
                
                StatBubble(
                    title: "Reviews",
                    value: "\(viewModel.events.filter { $0.eventType == UsageJourneyEvent.EventType.review.rawValue }.count)",
                    color: .lushyPink
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    private var timelineView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.events.enumerated()), id: \.element.objectID) { index, event in
                TimelineEventView(
                    event: event,
                    isFirst: index == 0,
                    isLast: index == viewModel.events.count - 1
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.lushyPink.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Start Your Journey")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Your product usage journey will appear here as you use and track your beauty products.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.vertical, 60)
    }
    
    private var addThoughtSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "plus.bubble.fill")
                        .font(.title3)
                        .foregroundColor(.lushyPink)
                    Text("Add Your Thoughts")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    TextField("Share your experience with this product...", text: $viewModel.newThoughtText, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    Button(action: {
                        viewModel.addThought()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: viewModel.newThoughtText.isEmpty ? [.gray] : [.lushyPink, .lushyPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .disabled(viewModel.newThoughtText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct TimelineEventView: View {
    let event: UsageJourneyEvent
    let isFirst: Bool
    let isLast: Bool
    
    private var eventType: UsageJourneyEvent.EventType {
        UsageJourneyEvent.EventType(rawValue: event.eventType ?? "") ?? .thought
    }
    
    private var eventColor: Color {
        switch eventType {
        case .purchase: return .lushyMint
        case .open: return .lushyPeach
        case .thought: return .lushyPink
        case .review: return .yellow
        case .halfEmpty: return .orange
        case .finished: return .green
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Top line
                if !isFirst {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
                
                // Event circle
                ZStack {
                    Circle()
                        .fill(eventColor)
                        .frame(width: 32, height: 32)
                        .shadow(color: eventColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: eventType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Bottom line
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }
            
            // Event content
            VStack(alignment: .leading, spacing: 8) {
                eventContentView
                
                // Timestamp
                Text(timeAgoString(from: event.createdAt ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var eventContentView: some View {
        switch eventType {
        case .purchase, .open, .finished, .halfEmpty:
            // Simple event
            simpleEventView
        case .thought:
            // Thought bubble
            thoughtEventView
        case .review:
            // Review card
            reviewEventView
        }
    }
    
    private var simpleEventView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eventType.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let text = event.text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var thoughtEventView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let text = event.text {
                Text(text)
                    .font(.subheadline)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.lushyPink.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.lushyPink.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    private var reviewEventView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Star rating
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= event.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                Spacer()
                Text("★ \(event.rating)/5")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            if let title = event.title, !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            if let text = event.text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
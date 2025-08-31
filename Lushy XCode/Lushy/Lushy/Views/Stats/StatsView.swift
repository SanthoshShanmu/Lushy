import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedTimeRange: TimeRange = .sixMonths
    @State private var selectedInsightTab: InsightTab = .overview
    
    enum TimeRange: String, CaseIterable {
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "1 Year"
        case allTime = "All Time"
    }
    
    enum InsightTab: String, CaseIterable {
        case overview = "Overview"
        case performance = "Performance"
        case goals = "Goals"
        case insights = "Insights"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with insights tab picker
                        headerSection
                        
                        // Content based on selected tab
                        tabContentView
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Beauty Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    timeRangeSection
                    Divider()
                    bagFilterSection
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.lushyPink)
                }
            }
        }
        .onAppear {
            viewModel.fetchAllData()
        }
    }
    
    // Break down complex expressions into separate computed properties
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.lushyPink.opacity(0.06),
                Color.lushyPurple.opacity(0.04),
                Color.lushyCream.opacity(0.2),
                Color.white
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var tabContentView: some View {
        Group {
            switch selectedInsightTab {
            case .overview:
                collectionOverviewSection
            case .performance:
                performanceSection
            case .goals:
                goalsSection
            case .insights:
                insightsSection
            }
        }
        .transition(.opacity.combined(with: .slide))
    }
    
    private var timeRangeSection: some View {
        ForEach(TimeRange.allCases, id: \.self) { range in
            Button(range.rawValue) {
                selectedTimeRange = range
            }
        }
    }
    
    private var bagFilterSection: some View {
        Menu {
            Button("All Bags", action: { viewModel.setBagFilter(nil) })
            ForEach(viewModel.allBags, id: \.self) { bag in
                Button(action: { viewModel.setBagFilter(bag) }) {
                    Label(bag.name ?? "Unnamed Bag", systemImage: bag.icon ?? "bag.fill")
                }
            }
        } label: {
            Label(viewModel.selectedBag?.name ?? "All Bags", systemImage: "bag")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Welcome message with personal touch
            welcomeMessageSection
            
            // Tab picker with beautiful design
            tabPickerSection
        }
    }
    
    private var welcomeMessageSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Beauty Journey ✨")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(beautyJourneyGradient)
                    
                    Text("Discover insights about your collection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var beautyJourneyGradient: LinearGradient {
        LinearGradient(
            colors: [.lushyPink, .lushyPurple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var tabPickerSection: some View {
        HStack(spacing: 0) {
            ForEach(InsightTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(tabPickerBackground)
        .padding(.horizontal, 24)
    }
    
    private func tabButton(for tab: InsightTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                selectedInsightTab = tab
            }
        }) {
            VStack(spacing: 6) {
                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(selectedInsightTab == tab ? .semibold : .medium)
                    .foregroundColor(selectedInsightTab == tab ? .white : .secondary)
                
                if selectedInsightTab == tab {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 20, height: 3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tabButtonBackground(for: tab))
        }
        .buttonStyle(.plain)
    }
    
    private func tabButtonBackground(for tab: InsightTab) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(selectedInsightTab == tab ? 
                  LinearGradient(colors: [.lushyPink, .lushyPurple], startPoint: .leading, endPoint: .trailing) : 
                  LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing))
    }
    
    private var tabPickerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.7))
            .shadow(color: .lushyPink.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Collection Overview Section
    private var collectionOverviewSection: some View {
        VStack(spacing: 20) {
            // Collection value cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                beautyStatCard(
                    title: "Collection Value",
                    value: formatCurrency(viewModel.totalCollectionValue),
                    subtitle: "Total investment",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    gradientColors: [.green.opacity(0.2), .green.opacity(0.1)]
                )
                
                beautyStatCard(
                    title: "Value Used",
                    value: formatCurrency(viewModel.valueUsedUp),
                    subtitle: "Products finished",
                    icon: "checkmark.circle.fill",
                    color: .lushyPink,
                    gradientColors: [.lushyPink.opacity(0.2), .lushyPink.opacity(0.1)]
                )
                
                beautyStatCard(
                    title: "Efficiency Rate",
                    value: "\(Int(viewModel.collectionEfficiencyRate))%",
                    subtitle: "Money well spent",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .lushyPurple,
                    gradientColors: [.lushyPurple.opacity(0.2), .lushyPurple.opacity(0.1)]
                )
                
                beautyStatCard(
                    title: "Avg. Product Value",
                    value: formatCurrency(viewModel.averageProductValue),
                    subtitle: "Per item",
                    icon: "tag.fill",
                    color: .mossGreen,
                    gradientColors: [.mossGreen.opacity(0.2), .mossGreen.opacity(0.1)]
                )
            }
            .padding(.horizontal, 24)
            
            // Collection health summary
            collectionHealthCard
            
            // Category breakdown
            categoryBreakdownCard
        }
    }
    
    // MARK: - Performance Section
    private var performanceSection: some View {
        VStack(spacing: 20) {
            // Top performers
            topPerformersCard
            
            // Best value products (cost per use)
            bestValueCard
            
            // Underperforming products
            underperformingCard
        }
    }
    
    // MARK: - Goals Section
    private var goalsSection: some View {
        VStack(spacing: 20) {
            // Waste reduction progress
            wasteReductionCard
            
            // Expiry alerts
            expiryAlertsCard
            
            // Unopened products
            unopenedProductsCard
        }
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(spacing: 20) {
            // Routine consistency
            routineConsistencyCard
            
            // Repurchase recommendations
            repurchaseRecommendationsCard
            
            // Seasonal patterns (if available)
            if !viewModel.seasonalUsagePatterns().isEmpty {
                seasonalPatternsCard
            }
        }
    }
    
    // MARK: - Collection Health Card
    private var collectionHealthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.lushyPink)
                Text("Collection Health")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(viewModel.allProducts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total Products")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(viewModel.finishedProducts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.lushyPink)
                    Text("Finished")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(viewModel.unopenedProducts().count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Unopened")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(viewModel.expiryAlerts().count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Expiring Soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .lushyPink.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Category Breakdown Card
    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundColor(.lushyPurple)
                Text("Collection Breakdown")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.categoryBalance(), id: \.category) { item in
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colorForCategory(item.category))
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(item.recommended)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(colorForCategory(item.category))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorForCategory(item.category).opacity(0.1))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .lushyPurple.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Top Performers Card
    private var topPerformersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("Top Performers")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let topProducts = viewModel.topPerformingProducts().prefix(3)
            
            if topProducts.isEmpty {
                Text("No rated products yet. Add reviews to see your top performers!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(topProducts.enumerated()), id: \.offset) { index, product in
                        HStack {
                            // Medal for top 3
                            Image(systemName: index == 0 ? "medal.fill" : index == 1 ? "medal" : "3.circle.fill")
                                .foregroundColor(index == 0 ? .yellow : index == 1 ? .gray : .orange)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.productName ?? "Unknown Product")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                if let brand = product.brand {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Rating stars
                            if let reviews = product.reviews as? Set<Review>,
                               let review = reviews.first {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .yellow.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Best Value Card
    private var bestValueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Best Value Products")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let costPerUseData = viewModel.costPerUse().prefix(3)
            
            if costPerUseData.isEmpty {
                Text("Finish some products with price data to see your best value items!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(costPerUseData.enumerated()), id: \.offset) { index, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.product.productName ?? "Unknown Product")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                if let brand = item.product.brand {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatCurrency(item.costPerUse))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("per use")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Underperforming Card
    private var underperformingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Needs Attention")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let underperforming = viewModel.underperformingProducts().prefix(3)
            
            if underperforming.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Great job! No products need attention right now.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(underperforming.enumerated()), id: \.offset) { index, product in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.productName ?? "Unknown Product")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(product.openDate == nil ? "Never opened" : "Low usage")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Waste Reduction Card
    private var wasteReductionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Waste Reduction Goal")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let wasteScore = viewModel.wasteReductionScore()
            
            VStack(spacing: 12) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: wasteScore / 100)
                        .stroke(
                            LinearGradient(colors: [.green, .mossGreen], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(wasteScore))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 4) {
                    Text("Products Finished")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(viewModel.finishedProducts.count) of \(viewModel.allProducts.count) products used up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Expiry Alerts Card
    private var expiryAlertsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            expiryAlertsHeader
            
            let expiringProducts = viewModel.expiryAlerts().prefix(3)
            
            if expiringProducts.isEmpty {
                expiryAlertsEmptyState
            } else {
                expiryAlertsContent(expiringProducts: Array(expiringProducts))
            }
        }
        .padding(20)
        .background(expiryAlertsBackground)
        .padding(.horizontal, 24)
    }
    
    private var expiryAlertsHeader: some View {
        HStack {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.title2)
                .foregroundColor(.red)
            Text("Expiry Alerts")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
    
    private var expiryAlertsEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundColor(.green)
            Text("All products are fresh! No expiry concerns.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    private func expiryAlertsContent(expiringProducts: [UserProduct]) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(expiringProducts.enumerated()), id: \.offset) { index, product in
                expiryAlertRow(product: product)
            }
        }
    }
    
    private func expiryAlertRow(product: UserProduct) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName ?? "Unknown Product")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let expireDate = product.expireDate {
                    let daysLeft = daysUntilExpiry(from: expireDate)
                    Text("\(daysLeft) days left")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(expiryAlertRowBackground)
    }
    
    private var expiryAlertsBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.9))
            .shadow(color: .red.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private var expiryAlertRowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.red.opacity(0.1))
    }
    
    private func daysUntilExpiry(from expiryDate: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }
    
    // MARK: - Unopened Products Card
    private var unopenedProductsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundColor(.lushyPurple)
                Text("Unopened Products")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let unopened = viewModel.unopenedProducts().prefix(3)
            
            if unopened.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Great! You're using your products well.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(unopened.enumerated()), id: \.offset) { index, product in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.productName ?? "Unknown Product")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                if let purchaseDate = product.purchaseDate {
                                    let monthsOld = Calendar.current.dateComponents([.month], from: purchaseDate, to: Date()).month ?? 0
                                    Text("Unopened for \(monthsOld) months")
                                        .font(.caption)
                                        .foregroundColor(.lushyPurple)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "gift")
                                .foregroundColor(.lushyPurple)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lushyPurple.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .lushyPurple.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Routine Consistency Card
    private var routineConsistencyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .font(.title2)
                    .foregroundColor(.mossGreen)
                Text("Routine Consistency")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let consistency = viewModel.routineConsistency()
            
            VStack(spacing: 12) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 16)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.mossGreen, .lushyPurple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * (consistency / 100), height: 16)
                    }
                }
                .frame(height: 16)
                
                HStack {
                    Text("\(Int(consistency))% of products in active use")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(consistency > 70 ? "Excellent!" : consistency > 50 ? "Good" : "Room for improvement")
                        .font(.caption)
                        .foregroundColor(consistency > 70 ? .green : consistency > 50 ? .orange : .red)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .mossGreen.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Repurchase Recommendations Card
    private var repurchaseRecommendationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.title2)
                    .foregroundColor(.lushyPink)
                Text("Repurchase Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let recommendations = viewModel.repurchaseRecommendations()
            
            if recommendations.isEmpty {
                Text("Finish and rate more products to get personalized recommendations!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, product in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.productName ?? "Unknown Product")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                if let brand = product.brand {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Rating stars
                            if let reviews = product.reviews as? Set<Review>,
                               let review = reviews.first {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.lushyPink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lushyPink.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .lushyPink.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Seasonal Patterns Card
    private var seasonalPatternsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.title2)
                    .foregroundColor(.lushyPeach)
                Text("Seasonal Patterns")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Simplified seasonal insights
            VStack(spacing: 8) {
                Text("Based on your usage history, you tend to finish more skincare in winter and makeup in summer.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .lushyPeach.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Views and Functions
    
    private func beautyStatCard(title: String, value: String, subtitle: String, icon: String, color: Color, gradientColors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "makeup": return .lushyPink
        case "skincare": return .mossGreen
        case "haircare": return .lushyPurple
        case "fragrance": return .lushyPeach
        default: return .gray
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}

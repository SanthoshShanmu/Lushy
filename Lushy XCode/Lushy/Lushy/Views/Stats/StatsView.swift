import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedTimeRange: TimeRange = .sixMonths
    @State private var selectedChart: ChartType = .usageTime
    
    enum TimeRange: String, CaseIterable {
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "1 Year"
        case allTime = "All Time"
    }
    
    enum ChartType: String, CaseIterable {
        case usageTime = "Usage Time"
        case byBrand = "By Brand"
        case byCategory = "By Category"
    }
    
    var body: some View {
        ZStack {
            Color.clear
                .pastelBackground()

            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Cards
                        summaryCardsView
                            .glassCard(cornerRadius: 22)
                        
                        // Chart Section
                        chartSectionView
                            .glassCard(cornerRadius: 22)
                        
                        // Finished Products Section
                        finishedProductsSection
                            .glassCard(cornerRadius: 22)
                    }
                    .padding(.top, 10)
                }
                .navigationTitle("Beauty Stats")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Button(range.rawValue) {
                                    selectedTimeRange = range
                                }
                            }
                            Divider()
                            // Bag filter
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
                            // Tag filter
                            Menu {
                                Button("All Tags", action: { viewModel.setTagFilter(nil) })
                                ForEach(viewModel.allTags, id: \.self) { tag in
                                    Button(action: { viewModel.setTagFilter(tag) }) {
                                        Label(tag.name ?? "Unnamed Tag", systemImage: "tag")
                                    }
                                }
                            } label: {
                                Label(viewModel.selectedTag?.name ?? "All Tags", systemImage: "tag")
                            }
                        } label: {
                            HStack {
                                Text(selectedTimeRange.rawValue)
                                Image(systemName: "chevron.down")
                            }
                            .foregroundColor(LushyPalette.purple)
                        }
                    }
                }
                .onAppear {
                    viewModel.fetchFinishedProducts()
                }
            }
        }
    }
    
    // Summary Cards
    private var summaryCardsView: some View {
        VStack(spacing: 10) {
            Text("Product Summary")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                statsCard(title: "Products Used",
                          value: "\(viewModel.finishedProducts.count)",
                          icon: "checkmark.circle.fill",
                          color: .lushyPink)
                
                statsCard(title: "Avg. Usage Time",
                          value: viewModel.averageUsageTime(),
                          icon: "clock.fill",
                          color: .lushyPurple)
                
                statsCard(title: "Most Used Brand",
                          value: viewModel.mostUsedBrand() ?? "N/A",
                          icon: "star.fill",
                          color: .yellow)
                
                statsCard(title: "Product Savings",
                          value: viewModel.calculateProductSavings(),
                          icon: "dollarsign.circle.fill",
                          color: .green)
                
                // New Shades Used card
                statsCard(title: "Shades Used",
                          value: "\(viewModel.uniqueShades())",
                          icon: "paintpalette.fill",
                          color: .lushyPeach)
            }
        }
        .padding()
        .background(
            BlurView(style: .systemUltraThinMaterial)
                .background(Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.lushyPink.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    // Individual Stat Card
    private func statsCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Chart Section
    private var chartSectionView: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Usage Analytics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Chart Type", selection: $selectedChart) {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            chartContent
                .frame(height: 250)
                .padding()
                .background(
                    BlurView(style: .systemUltraThinMaterial)
                        .background(Color.white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.lushyPurple.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .padding()
        .background(
            BlurView(style: .systemUltraThinMaterial)
                .background(Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.lushyPurple.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if #available(iOS 16.0, *) {
            Group {
                switch selectedChart {
                case .usageTime:
                    averageUsageTimeChart
                case .byBrand:
                    brandDistributionChart
                case .byCategory:
                    categoryUsageChart
                }
            }
        } else {
            // Fallback for iOS 15 and earlier
            legacyChartView
        }
    }
    
    // Finished Products Section
    private var finishedProductsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Finished Products")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.finishedProducts.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.finishedProducts.prefix(5)) { product in
                    finishedProductRow(product: product)
                }
                
                if viewModel.finishedProducts.count > 5 {
                    Button(action: {
                        // Show all finished products
                    }) {
                        Text("See All (\(viewModel.finishedProducts.count))")
                            .font(.subheadline)
                            .foregroundColor(.lushyPink)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.lushyPink.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(
            BlurView(style: .systemUltraThinMaterial)
                .background(Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.lushyPink.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    private func finishedProductRow(product: UserProduct) -> some View {
        HStack(spacing: 15) {
            // Product image
            productImageView(urlString: product.imageUrl)
                .frame(width: 60, height: 60)
                .background(Color.lushyCream)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName ?? "Unknown Product")
                    .font(.headline)
                    .lineLimit(1)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Bag and tag indicators
                HStack(spacing: 6) {
                    if let bags = product.bags as? Set<BeautyBag>, let bag = bags.first {
                        HStack(spacing: 3) {
                            Image(systemName: bag.icon ?? "bag.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                            Text(bag.name ?? "Bag")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(bag.color ?? "lushyPink").opacity(0.08))
                        .cornerRadius(8)
                    }
                    if let tags = product.tags as? Set<ProductTag>, !tags.isEmpty {
                        ForEach(Array(tags.prefix(2)), id: \.self) { tag in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 7, height: 7)
                                Text(tag.name ?? "")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(tag.color ?? "lushyPink").opacity(0.10))
                            .cornerRadius(8)
                        }
                    }
                }
                
                HStack {
                    Text(usageDurationText(product: product))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let openDate = product.openDate,
                       let finishDate = product.value(forKey: "finishDate") as? Date {
                        Spacer()
                        Text(formattedDateRange(from: openDate, to: finishDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Display rating if available
            if let reviews = product.reviews as? Set<Review>, let review = reviews.first {
                HStack {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= review.rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    private func productImageView(urlString: String?) -> some View {
        Group {
            if let imageUrlString = urlString, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func usageDurationText(product: UserProduct) -> String {
        guard let openDate = product.openDate,
              let finishDate = product.value(forKey: "finishDate") as? Date else {
            return "Duration unknown"
        }
        
        let days = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
        
        if days < 30 {
            return "\(days) days of use"
        } else {
            let months = Double(days) / 30.0
            return String(format: "%.1f months of use", months)
        }
    }
    
    private func formattedDateRange(from startDate: Date, to endDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(.lushyPink.opacity(0.6))
                .padding()
            
            Text("No Finished Products Yet")
                .font(.headline)
            
            Text("Track your beauty products usage by marking products as empty when you finish them.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // iOS 16+ Chart implementations
    @available(iOS 16.0, *)
    private var averageUsageTimeChart: some View {
        Chart {
            ForEach(viewModel.getMonthlyUsageData(), id: \.month) { data in
                BarMark(
                    x: .value("Month", data.month),
                    y: .value("Days", data.averageDays)
                )
                .foregroundStyle(Color.lushyPink.gradient)
                .cornerRadius(6)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var brandDistributionChart: some View {
        Chart {
            ForEach(viewModel.getBrandDistribution(), id: \.brand) { data in
                SectorMark(
                    angle: .value("Count", data.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(5)
                .foregroundStyle(by: .value("Brand", data.brand))
            }
        }
        .frame(height: 240)
    }
    
    @available(iOS 16.0, *)
    private var categoryUsageChart: some View {
        Chart {
            ForEach(viewModel.getCategoryData(), id: \.category) { data in
                BarMark(
                    x: .value("Count", data.count),
                    y: .value("Category", data.category)
                )
                .foregroundStyle(Color.lushyPurple.gradient)
                .cornerRadius(6)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
            }
        }
    }
    
    // Fallback for iOS 15 and earlier
    private var legacyChartView: some View {
        VStack(spacing: 10) {
            Text("Chart visualization available on iOS 16 and above")
                .font(.caption)
                .foregroundColor(.secondary)
            
            switch selectedChart {
            case .usageTime:
                simpleBarChartView(data: viewModel.getMonthlyUsageData())
            case .byBrand:
                simplePieChartView(data: viewModel.getBrandDistribution())
            case .byCategory:
                simpleHorizontalBarView(data: viewModel.getCategoryData())
            }
        }
    }
    
    private func simpleBarChartView(data: [(month: String, averageDays: Double)]) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.month) { item in
                    VStack {
                        Text("\(Int(item.averageDays))")
                            .font(.caption)
                            .foregroundColor(.lushyPink)
                        
                        Rectangle()
                            .fill(Color.lushyPink)
                            .frame(width: 30, height: max(20, item.averageDays * 2))
                            .cornerRadius(4)
                        
                        Text(item.month)
                            .font(.caption)
                            .frame(width: 30)
                    }
                }
            }
            .frame(height: 200)
            .padding(.top, 20)
        }
    }
    
    private func simplePieChartView(data: [(brand: String, count: Int)]) -> some View {
        VStack {
            HStack {
                ForEach(data.prefix(5), id: \.brand) { item in
                    Circle()
                        .fill(randomColor(for: item.brand))
                        .frame(width: 15, height: 15)
                    
                    Text(item.brand)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .frame(height: 20)
                }
            }
            .padding(.horizontal)
            
            ZStack {
                // Simple pie chart visualization
                GeometryReader { geo in
                    ForEach(data.enumerated().map({ i, item in
                        (index: i, item: item, color: randomColor(for: item.brand))
                    }), id: \.index) { item in
                        Path { path in
                            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                            let radius = min(geo.size.width, geo.size.height) / 2 * 0.8
                            
                            let totalValue = data.reduce(0) { $0 + $1.count }
                            let startAngle = item.index == 0 ? 0.0 :
                                data[0..<item.index].reduce(0.0) { $0 + (Double($1.count) / Double(totalValue)) * 2 * .pi }
                            let endAngle = startAngle + (Double(item.item.count) / Double(totalValue)) * 2 * .pi
                            
                            path.move(to: center)
                            path.addArc(center: center, radius: radius, startAngle: .radians(startAngle - .pi/2),
                                        endAngle: .radians(endAngle - .pi/2), clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(item.color)
                    }
                }
            }
            .frame(height: 120)
        }
    }
    
    private func simpleHorizontalBarView(data: [(category: String, count: Int)]) -> some View {
        VStack {
            ForEach(data, id: \.category) { item in
                HStack {
                    Text(item.category)
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    
                    GeometryReader { geo in
                        let maxCount = data.map { $0.count }.max() ?? 1
                        let width = (CGFloat(item.count) / CGFloat(maxCount)) * geo.size.width
                        
                        Rectangle()
                            .fill(Color.lushyPurple)
                            .frame(width: width)
                            .cornerRadius(4)
                    }
                    
                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
                .frame(height: 25)
            }
        }
    }
    
    private func randomColor(for string: String) -> Color {
        let colors: [Color] = [.lushyPink, .lushyPurple, .lushyMint, .lushyPeach, .lushyCream]
        var hash = 0
        for char in string.unicodeScalars {
            hash = Int(char.value) + ((hash << 5) - hash)
        }
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - StatsViewModel Extensions

extension StatsViewModel {
    // Additional methods for chart data
    
    func mostUsedBrand() -> String? {
        let brandCounts = getBrandDistribution()
        return brandCounts.max(by: { $0.count < $1.count })?.brand
    }
    
    func calculateProductSavings() -> String {
        let averageProductCost = 25.0 // Assumed average cost
        let savingsAmount = Double(finishedProducts.count) * averageProductCost
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: savingsAmount)) ?? "$0"
    }
    
    func getMonthlyUsageData() -> [(month: String, averageDays: Double)] {
        // Get data for the last 6 months
        let calendar = Calendar.current
        let today = Date()
        
        // Create month labels
        var data: [(month: String, averageDays: Double)] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        // Generate data for each of the last 6 months
        for i in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -i, to: today) {
                let monthString = dateFormatter.string(from: date)
                
                // Get average usage time for products finished in this month
                let monthData = finishedProducts.filter { product in
                    guard let finishDate = product.value(forKey: "finishDate") as? Date else { return false }
                    return calendar.isDate(finishDate, equalTo: date, toGranularity: .month)
                }
                
                let usageData = monthData.compactMap { product -> Double? in
                    guard let openDate = product.openDate,
                          let finishDate = product.value(forKey: "finishDate") as? Date else { return nil }
                    
                    let days = calendar.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
                    return Double(days)
                }
                
                let averageDays = usageData.isEmpty ? 0 : usageData.reduce(0, +) / Double(usageData.count)
                data.append((month: monthString, averageDays: averageDays))
            }
        }
        
        // Reverse to show oldest month first
        return data.reversed()
    }
    
    func getBrandDistribution() -> [(brand: String, count: Int)] {
        var brandCounts: [String: Int] = [:]
        
        for product in finishedProducts {
            let brand = product.brand ?? "Unknown"
            brandCounts[brand, default: 0] += 1
        }
        
        return brandCounts.map { (brand: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    func getCategoryData() -> [(category: String, count: Int)] {
        // This would ideally use product categories, but we'll simulate with product types
        var categories: [String: Int] = [
            "Skincare": 0,
            "Makeup": 0,
            "Hair": 0,
            "Body": 0,
            "Fragrance": 0,
            "Other": 0
        ]
        
        for product in finishedProducts {
            // Parse product name to guess category
            let name = product.productName?.lowercased() ?? ""
            
            if name.contains("cream") || name.contains("lotion") || name.contains("serum") || name.contains("face") {
                categories["Skincare", default: 0] += 1
            }
            else if name.contains("foundation") || name.contains("mascara") || name.contains("lipstick") {
                categories["Makeup", default: 0] += 1
            }
            else if name.contains("shampoo") || name.contains("conditioner") {
                categories["Hair", default: 0] += 1
            }
            else if name.contains("soap") || name.contains("shower") || name.contains("body") {
                categories["Body", default: 0] += 1
            }
            else if name.contains("perfume") || name.contains("cologne") || name.contains("fragrance") {
                categories["Fragrance", default: 0] += 1
            }
            else {
                categories["Other", default: 0] += 1
            }
        }
        
        return categories.map { (category: $0.key, count: $0.value) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}

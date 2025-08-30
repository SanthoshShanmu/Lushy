// Create a new view model for tracking usage statistics

import Foundation
import CoreData
import Combine

class StatsViewModel: ObservableObject {
    @Published var finishedProducts: [UserProduct] = []
    @Published var allProducts: [UserProduct] = []
    @Published var selectedBag: BeautyBag? = nil
    @Published var selectedTag: ProductTag? = nil
    @Published var allBags: [BeautyBag] = []
    @Published var allTags: [ProductTag] = []

    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchAllData()
        
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchAllData()
            }
            .store(in: &cancellables)
    }
    
    func fetchAllBagsAndTags() {
        allBags = CoreDataManager.shared.fetchBeautyBags()
        allTags = CoreDataManager.shared.fetchProductTags()
    }

    func setBagFilter(_ bag: BeautyBag?) {
        selectedBag = bag
        fetchAllData()
    }

    func setTagFilter(_ tag: ProductTag?) {
        selectedTag = tag
        fetchAllData()
    }

    func fetchAllData() {
        fetchAllBagsAndTags()
        
        // Fetch all products
        let allRequest: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        allRequest.sortDescriptors = [NSSortDescriptor(key: "purchaseDate", ascending: false)]
        
        do {
            allProducts = try managedObjectContext.fetch(allRequest)
            if let bag = selectedBag {
                allProducts = allProducts.filter { ($0.bags as? Set<BeautyBag>)?.contains(bag) == true }
            }
            if let tag = selectedTag {
                allProducts = allProducts.filter { ($0.tags as? Set<ProductTag>)?.contains(tag) == true }
            }
        } catch {
            print("Error fetching all products: \(error)")
        }
        
        // Fetch finished products
        let finishedRequest: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        finishedRequest.predicate = NSPredicate(format: "isFinished == YES")
        finishedRequest.sortDescriptors = [NSSortDescriptor(key: "finishDate", ascending: false)]
        
        do {
            var products = try managedObjectContext.fetch(finishedRequest)
            if let bag = selectedBag {
                products = products.filter { ($0.bags as? Set<BeautyBag>)?.contains(bag) == true }
            }
            if let tag = selectedTag {
                products = products.filter { ($0.tags as? Set<ProductTag>)?.contains(tag) == true }
            }
            finishedProducts = products
        } catch {
            print("Error fetching finished products: \(error)")
        }
    }
    
    // MARK: - Collection Overview Metrics
    
    var totalCollectionValue: Double {
        return allProducts.compactMap { $0.price }.reduce(0, +)
    }
    
    var valueUsedUp: Double {
        return finishedProducts.compactMap { $0.price }.reduce(0, +)
    }
    
    var collectionEfficiencyRate: Double {
        guard totalCollectionValue > 0 else { return 0 }
        return (valueUsedUp / totalCollectionValue) * 100
    }
    
    var averageProductValue: Double {
        let products = allProducts.filter { $0.price > 0 }
        guard !products.isEmpty else { return 0 }
        return products.compactMap { $0.price }.reduce(0, +) / Double(products.count)
    }
    
    // MARK: - Product Performance Metrics
    
    func topPerformingProducts() -> [UserProduct] {
        return finishedProducts
            .filter { product in
                // Products with high ratings and good usage time
                guard let reviews = product.reviews as? Set<Review>,
                      let review = reviews.first,
                      review.rating >= 4,
                      let openDate = product.openDate,
                      let finishDate = product.value(forKey: "finishDate") as? Date else {
                    return false
                }
                
                let daysUsed = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
                return daysUsed >= 30 // Used for at least a month
            }
            .sorted { first, second in
                guard let firstReviews = first.reviews as? Set<Review>,
                      let secondReviews = second.reviews as? Set<Review>,
                      let firstRating = firstReviews.first?.rating,
                      let secondRating = secondReviews.first?.rating else {
                    return false
                }
                return firstRating > secondRating
            }
    }
    
    func underperformingProducts() -> [UserProduct] {
        let currentDate = Date()
        
        return allProducts.filter { product in
            // Products opened but not used much or sitting unopened for too long
            if let openDate = product.openDate {
                // Opened products with low usage
                let monthsSinceOpen = Calendar.current.dateComponents([.month], from: openDate, to: currentDate).month ?? 0
                return monthsSinceOpen > 6 && !product.isFinished
            } else if let purchaseDate = product.purchaseDate {
                // Unopened products sitting too long
                let monthsSincePurchase = Calendar.current.dateComponents([.month], from: purchaseDate, to: currentDate).month ?? 0
                return monthsSincePurchase > 3
            }
            return false
        }
    }
    
    func costPerUse() -> [(product: UserProduct, costPerUse: Double)] {
        return finishedProducts.compactMap { product in
            guard product.price > 0,
                  let openDate = product.openDate,
                  let finishDate = product.value(forKey: "finishDate") as? Date else {
                return nil
            }
            
            let daysUsed = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 1
            let estimatedUses = max(daysUsed / 2, 1) // Estimate uses per day
            let costPerUse = product.price / Double(estimatedUses)
            
            return (product: product, costPerUse: costPerUse)
        }.sorted { $0.costPerUse < $1.costPerUse }
    }
    
    // MARK: - Usage Pattern Analysis
    
    func routineConsistency() -> Double {
        let last30Days = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentlyUsedProducts = allProducts.filter { product in
            guard let openDate = product.openDate else { return false }
            return openDate >= last30Days && !product.isFinished
        }
        
        guard !allProducts.isEmpty else { return 0 }
        return (Double(recentlyUsedProducts.count) / Double(allProducts.count)) * 100
    }
    
    func seasonalUsagePatterns() -> [(season: String, categoryUsage: [String: Int])] {
        let calendar = Calendar.current
        var seasonalData: [String: [String: Int]] = [
            "Spring": [:],
            "Summer": [:], 
            "Fall": [:],
            "Winter": [:]
        ]
        
        for product in finishedProducts {
            guard let finishDate = product.value(forKey: "finishDate") as? Date else { continue }
            
            let month = calendar.component(.month, from: finishDate)
            let season = getSeasonForMonth(month)
            let category = getCategoryForProduct(product)
            
            seasonalData[season]?[category, default: 0] += 1
        }
        
        return seasonalData.map { (season: $0.key, categoryUsage: $0.value) }
    }
    
    private func getSeasonForMonth(_ month: Int) -> String {
        switch month {
        case 3...5: return "Spring"
        case 6...8: return "Summer"
        case 9...11: return "Fall"
        default: return "Winter"
        }
    }
    
    private func getCategoryForProduct(_ product: UserProduct) -> String {
        let name = product.productName?.lowercased() ?? ""
        
        if name.contains("foundation") || name.contains("mascara") || name.contains("lipstick") || name.contains("eyeshadow") {
            return "Makeup"
        } else if name.contains("cream") || name.contains("serum") || name.contains("cleanser") || name.contains("moisturizer") {
            return "Skincare"
        } else if name.contains("shampoo") || name.contains("conditioner") || name.contains("hair") {
            return "Haircare"
        } else if name.contains("perfume") || name.contains("fragrance") {
            return "Fragrance"
        } else {
            return "Other"
        }
    }
    
    // MARK: - Goal Tracking Metrics
    
    func wasteReductionScore() -> Double {
        let totalProducts = allProducts.count
        let finishedCount = finishedProducts.count
        guard totalProducts > 0 else { return 0 }
        return (Double(finishedCount) / Double(totalProducts)) * 100
    }
    
    func expiryAlerts() -> [UserProduct] {
        let calendar = Calendar.current
        
        return allProducts.filter { product in
            guard !product.isFinished,
                  let expireDate = product.expireDate else { return false }
            
            let daysUntilExpiry = calendar.dateComponents([.day], from: Date(), to: expireDate).day ?? 0
            return daysUntilExpiry <= 30 && daysUntilExpiry >= 0
        }.sorted { first, second in
            guard let firstExpiry = first.expireDate,
                  let secondExpiry = second.expireDate else { return false }
            return firstExpiry < secondExpiry
        }
    }
    
    func unopenedProducts() -> [UserProduct] {
        return allProducts.filter { product in
            product.openDate == nil
        }
    }
    
    // MARK: - Repurchase Recommendations
    
    func repurchaseRecommendations() -> [UserProduct] {
        return topPerformingProducts().prefix(5).map { $0 }
    }
    
    func categoryBalance() -> [(category: String, count: Int, recommended: String)] {
        var categoryCount: [String: Int] = [:]
        
        for product in allProducts.filter({ !$0.isFinished }) {
            let category = getCategoryForProduct(product)
            categoryCount[category, default: 0] += 1
        }
        
        return categoryCount.map { category, count in
            let recommendation: String
            switch category {
            case "Skincare":
                recommendation = count < 5 ? "Consider adding more basics" : count > 15 ? "Well stocked!" : "Good balance"
            case "Makeup":
                recommendation = count < 3 ? "Room for essentials" : count > 20 ? "Large collection!" : "Nice variety"
            default:
                recommendation = count < 2 ? "Could add more" : "Good amount"
            }
            return (category: category, count: count, recommended: recommendation)
        }.sorted { $0.count > $1.count }
    }
    
    // MARK: - Legacy methods (for backward compatibility)
    
    func averageUsageTime() -> String {
        let products = finishedProducts.filter { $0.openDate != nil && $0.finishDate != nil }
        
        if products.isEmpty { return "N/A" }
        
        let totalDays = products.reduce(0) { result, product in
            guard let openDate = product.openDate,
                  let finishDate = product.value(forKey: "finishDate") as? Date else {
                return result
            }
            
            let days = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
            return result + days
        }
        
        let average = Double(totalDays) / Double(products.count)
        return String(format: "%.0f days", average)
    }
    
    func mostUsedBrand() -> String? {
        let brandCounts = getBrandDistribution()
        return brandCounts.max(by: { $0.count < $1.count })?.brand
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
        var categories: [String: Int] = [:]
        
        for product in finishedProducts {
            let category = getCategoryForProduct(product)
            categories[category, default: 0] += 1
        }
        
        return categories.map { (category: $0.key, count: $0.value) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }
    
    func getMonthlyUsageData() -> [(month: String, averageDays: Double)] {
        let calendar = Calendar.current
        let today = Date()
        
        var data: [(month: String, averageDays: Double)] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        for i in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -i, to: today) {
                let monthString = dateFormatter.string(from: date)
                
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
        
        return data.reversed()
    }
}

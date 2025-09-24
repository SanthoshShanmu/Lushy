import Foundation
import CoreData
import Combine
import UserNotifications

class UsageTrackingViewModel: ObservableObject {
    @Published var usageEntries: [UsageEntry] = []
    @Published var isShowingFinishConfirmation = false
    @Published var usagePatternInsight: String? = nil
    
    let product: UserProduct
    private var cancellables = Set<AnyCancellable>()
    private var isFinishingProduct = false
    
    init(product: UserProduct) {
        self.product = product
        loadUsageEntries()
        calculateUsagePatterns()
        
        // Subscribe to Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadUsageEntries()
                self?.calculateUsagePatterns()
            }
            .store(in: &cancellables)
    }
    
    private func loadUsageEntries() {
        // Force context refresh to get latest data
        CoreDataManager.shared.viewContext.refreshAllObjects()
        
        let request: NSFetchRequest<UsageEntry> = UsageEntry.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let fetchedEntries = try CoreDataManager.shared.viewContext.fetch(request)
            usageEntries = fetchedEntries
            print("📊 UsageTrackingViewModel loaded \(fetchedEntries.count) usage entries for product")
        } catch {
            print("❌ Error loading usage entries: \(error)")
            usageEntries = []
        }
    }
    
    // Add a new usage check-in using the existing UsageEntry model
    func quickCheckIn(context: String, notes: String?, date: Date) {
        // Validate date is not before purchase date
        if let purchaseDate = product.purchaseDate, date < purchaseDate {
            print("Cannot add check-in before purchase date")
            return
        }
        
        // Allow multiple uses per day
        CoreDataManager.shared.addUsageEntry(
            to: product.objectID,
            type: "check_in",
            amount: 1.0,
            notes: createNotesWithMetadata(notes: notes, context: context)
        )
        
        // FIXED Issue 2: Usage entries are stored and synced to backend
        // They do NOT create journey thoughts automatically
        // Usage tracking and journey thoughts are separate systems
        
        // Force immediate reload to ensure UI updates
        DispatchQueue.main.async {
            self.loadUsageEntries()
            self.calculateUsagePatterns()
            
            // Notify other views that usage data has changed
            NotificationCenter.default.post(name: NSNotification.Name("UsageDataChanged"), object: self.product.objectID)
        }
    }
    
    private func calculateUsagePatterns() {
        let recentEntries = usageEntries.filter { entry in
            entry.createdAt >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }
        
        guard !recentEntries.isEmpty else {
            usagePatternInsight = nil
            return
        }
        
        // Analyze usage patterns
        let usageFrequency = Double(recentEntries.count) / 30.0
        let weekendUse = recentEntries.filter { Calendar.current.isDateInWeekend($0.createdAt) }.count
        let weekdayUse = recentEntries.count - weekendUse
        
        if usageFrequency >= 0.8 { // Nearly daily use
            usagePatternInsight = "You're using this daily - perfect for maintaining consistency!"
        } else if weekendUse > weekdayUse {
            usagePatternInsight = "You prefer using this on weekends - great for self-care time!"
        } else if weekdayUse > weekendUse * 2 {
            usagePatternInsight = "This seems to be part of your work week routine"
        } else if usageFrequency < 0.2 {
            usagePatternInsight = "You use this occasionally - perfect for special moments"
        } else {
            usagePatternInsight = "You have a balanced usage pattern with this product"
        }
    }
    
    // Finish product
    func finishProduct() {
        guard !isFinishingProduct && !product.isFinished else { return }
        
        isFinishingProduct = true
        
        // Mark as finished
        product.isFinished = true
        product.finishDate = Date()
        
        // Cancel expiry notifications
        NotificationService.shared.cancelNotification(for: product)
        
        // Save changes
        do {
            try CoreDataManager.shared.viewContext.save()
            
            // Create journey event for finishing
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .finished,
                text: nil,
                title: nil,
                rating: 0,
                date: Date()
            )
        } catch {
            print("Error finishing product: \(error)")
        }
        
        // Reset flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isFinishingProduct = false
        }
    }
    
    // MARK: - Computed Properties adapted for UsageEntry
    
    var isUsageTrackingDisabled: Bool {
        return product.isFinished
    }
    
    var totalCheckIns: Int {
        return usageEntries.filter { $0.usageType == "check_in" }.count
    }
    
    var weeklyCheckIns: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return usageEntries.filter { $0.createdAt >= oneWeekAgo && $0.usageType == "check_in" }.count
    }
    
    var daysSinceLastUse: Int {
        let checkInEntries = usageEntries.filter { $0.usageType == "check_in" }
        guard let lastCheckIn = checkInEntries.first else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastCheckIn.createdAt, to: Date()).day ?? 0
    }
    
    var usageFrequencyInsight: String {
        let totalDays = daysSinceFirstUse
        guard totalDays > 0 && totalCheckIns > 0 else { return "" }
        
        let usagePerWeek = Double(totalCheckIns) / Double(totalDays) * 7.0
        
        if usagePerWeek >= 5 {
            // Simplified logic - just focus on usage patterns, not stock advice
            return "You use this daily - great consistency!"
        } else if usagePerWeek >= 3 {
            return "Regular use - great for your routine"
        } else if usagePerWeek >= 1 {
            return "Weekly use - perfect for special occasions"
        } else if daysSinceLastUse > 30 {
            return "Haven't used recently - consider decluttering?"
        } else {
            return "Occasional use product"
        }
    }
    
    private var daysSinceFirstUse: Int {
        let firstDate = product.openDate ?? product.purchaseDate ?? Date()
        return Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
    }
    
    // Get most common usage context
    var mostCommonContext: String {
        let checkInEntries = usageEntries.filter { $0.usageType == "check_in" }
        let contexts = checkInEntries.compactMap { entry -> String? in
            let metadata = parseMetadataFromNotes(entry.notes)
            return metadata.context
        }
        
        let contextCounts = contexts.reduce(into: [:]) { counts, context in
            counts[context, default: 0] += 1
        }
        return contextCounts.max(by: { $0.value < $1.value })?.key ?? ""
    }
    
    // Get usage entries formatted for display
    var usageCheckIns: [UsageEntryDisplay] {
        return usageEntries
            .filter { $0.usageType == "check_in" }
            .map { entry in
                let metadata = parseMetadataFromNotes(entry.notes)
                return UsageEntryDisplay(
                    objectID: entry.objectID,
                    date: entry.createdAt,
                    context: metadata.context,
                    notes: metadata.notes.isEmpty ? nil : metadata.notes
                )
            }
    }
    
    // Helper to create notes with metadata (no rating)
    private func createNotesWithMetadata(notes: String?, context: String) -> String? {
        let metadata: [String: Any] = [
            "context": context,
            "notes": notes ?? ""
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: metadata),
              let jsonString = String(data: data, encoding: .utf8) else {
            return notes
        }
        
        return jsonString
    }
    
    // Helper to parse metadata from notes
    private func parseMetadataFromNotes(_ notes: String?) -> (context: String, notes: String) {
        guard let notes = notes,
              let data = notes.data(using: .utf8),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (context: "general", notes: notes ?? "")
        }
        
        let context = metadata["context"] as? String ?? "general"
        let userNotes = metadata["notes"] as? String ?? ""
        
        return (context: context, notes: userNotes)
    }
}

// Helper struct to display usage entries (removed rating)
struct UsageEntryDisplay {
    let objectID: NSManagedObjectID
    let date: Date
    let context: String
    let notes: String?
}

// Helper function to extract months from PAO string
private func extractMonths(from periodString: String) -> Int? {
    let pattern = #"(\d+)\s*[Mm]"#
    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
       let match = regex.firstMatch(in: periodString, options: [], range: NSRange(location: 0, length: periodString.count)),
       let range = Range(match.range(at: 1), in: periodString) {
        return Int(periodString[range])
    }
    return nil
}
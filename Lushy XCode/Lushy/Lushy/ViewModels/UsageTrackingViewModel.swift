import Foundation
import CoreData
import Combine

class UsageTrackingViewModel: ObservableObject {
    @Published var usageEntries: [UsageEntry] = []
    @Published var isShowingFinishConfirmation = false
    
    let product: UserProduct  // Changed from private to public
    private var cancellables = Set<AnyCancellable>()
    private var isFinishingProduct = false
    
    init(product: UserProduct) {
        self.product = product
        loadUsageEntries()
        
        // Subscribe to Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadUsageEntries()
            }
            .store(in: &cancellables)
    }
    
    private func loadUsageEntries() {
        let request: NSFetchRequest<UsageEntry> = UsageEntry.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            usageEntries = try CoreDataManager.shared.viewContext.fetch(request)
        } catch {
            print("Error loading usage entries: \(error)")
        }
    }
    
    // Add a new usage check-in using the existing UsageEntry model
    func quickCheckIn(context: String, notes: String?, date: Date) {
        // Validate date is not before purchase date
        if let purchaseDate = product.purchaseDate, date < purchaseDate {
            print("Cannot add check-in before purchase date")
            return
        }
        
        // Check if already checked in today for this date
        let calendar = Calendar.current
        let existingEntry = usageEntries.first { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: date)
        }
        
        if existingEntry != nil {
            print("Already checked in for this date")
            return // Could show alert to user instead
        }
        
        let coreDataContext = CoreDataManager.shared.viewContext
        let entry = UsageEntry(context: coreDataContext)
        entry.userProduct = product
        entry.createdAt = date
        entry.usageAmount = 1.0 // Use 1.0 to represent a single usage
        entry.usageType = "check_in"
        entry.userId = AuthService.shared.userId ?? ""
        
        // Store context and notes in notes as JSON
        if let notesData = createNotesWithMetadata(notes: notes, context: context) {
            entry.notes = notesData
        }
        
        // Mark as opened if this is the first usage and not already opened
        if product.openDate == nil {
            product.openDate = date
            
            // Calculate expiry if we have PAO
            if let pao = product.periodsAfterOpening, let months = extractMonths(from: pao) {
                product.expireDate = Calendar.current.date(byAdding: .month, value: months, to: date)
                NotificationService.shared.scheduleExpiryNotification(for: product)
            }
        }
        
        do {
            try coreDataContext.save()
            loadUsageEntries()
            
            // Create journey event for usage
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .thought, // Use thought type since usage type doesn't exist
                text: "Used product - \(context)" + (notes?.isEmpty == false ? ": \(notes!)" : ""),
                title: nil,
                rating: 0,
                date: date
            )
        } catch {
            print("Error saving usage check-in: \(error)")
        }
    }
    
    // Helper to create notes with metadata (no rating)
    private func createNotesWithMetadata(notes: String?, context: String) -> String? {
        let metadata: [String: Any] = [
            "context": context,
            "notes": notes ?? ""
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        // Fallback to simple format
        return "Context: \(context)" + (notes?.isEmpty == false ? ", Notes: \(notes!)" : "")
    }
    
    // Helper to parse metadata from notes (no rating)
    private func parseMetadataFromNotes(_ notes: String?) -> (context: String, notes: String) {
        guard let notes = notes else { return ("general", "") }
        
        // Try to parse JSON first
        if let jsonData = notes.data(using: .utf8),
           let metadata = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let context = metadata["context"] as? String ?? "general"
            let userNotes = metadata["notes"] as? String ?? ""
            return (context, userNotes)
        }
        
        // Fallback parsing
        return ("general", notes)
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
            return "You use this daily - consider stocking up!"
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
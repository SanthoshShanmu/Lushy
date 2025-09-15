import Foundation
import CoreData
import Combine

class UsageJourneyViewModel: ObservableObject {
    @Published var events: [UsageJourneyEvent] = []
    @Published var newThoughtText = ""
    @Published var isLoading = false
    @Published var showingCustomDateSheet = false
    @Published var customThoughtDate = Date()
    
    let product: UserProduct  // Changed from private to public
    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init(product: UserProduct) {
        self.product = product
        loadEvents() // Use loadEvents() which doesn't return a value
        
        // Subscribe to Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadEvents() // Use loadEvents() which doesn't return a value
            }
            .store(in: &cancellables)
    }
    
    // FIXED: Separate methods - one for loading (side effect), one for fetching (return value)
    private func loadEvents() {
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            events = try managedObjectContext.fetch(request)
        } catch {
            print("Error fetching usage journey events: \(error)")
            events = []
        }
    }
    
    // FIXED: Separate method for when we need the return value
    private func fetchEventsArray() -> [UsageJourneyEvent] {
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try managedObjectContext.fetch(request)
        } catch {
            print("Error fetching usage journey events: \(error)")
            return []
        }
    }
    
    func addThought() {
        addThought(withDate: Date())
    }
    
    func addThought(withDate date: Date) {
        guard !newThoughtText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        createEvent(type: "thought", text: newThoughtText, date: date)
        newThoughtText = ""
    }
    
    private func createEvent(type: String, text: String?, date: Date) {
        let event = UsageJourneyEvent(context: managedObjectContext)
        event.userProduct = product
        event.eventType = type
        event.text = text
        event.createdAt = date
        
        do {
            try managedObjectContext.save()
            loadEvents() // Use loadEvents() which doesn't return a value
        } catch {
            print("Error saving usage journey event: \(error)")
        }
    }
    
    // FIXED: Enhanced initial events creation with better validation
    func createInitialEvents() {
        // Ensure we have the latest data
        managedObjectContext.refreshAllObjects()
        
        let existingEvents = fetchEventsArray() // Use fetchEventsArray() when we need the return value
        
        // Create purchase event if needed and purchase date exists
        if let purchaseDate = product.purchaseDate,
           !existingEvents.contains(where: { $0.eventType == "purchase" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .purchase,
                text: nil,
                title: nil,
                rating: 0,
                date: purchaseDate
            )
        }
        
        // Create open event if needed and open date exists
        if let openDate = product.openDate,
           !existingEvents.contains(where: { $0.eventType == "open" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .open,
                text: nil,
                title: nil,
                rating: 0,
                date: openDate
            )
        }
        
        // Create finished event if needed and product is finished
        if product.isFinished,
           !existingEvents.contains(where: { $0.eventType == "finished" }) {
            let finishDate = product.finishDate ?? Date()
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .finished,
                text: nil,
                title: nil,
                rating: 0,
                date: finishDate
            )
        }
        
        // Refresh events after creating initial ones
        loadEvents() // Use loadEvents() which doesn't return a value
    }
    
    // FIXED: Add method to get combined timeline count for accurate stats
    func getTotalTimelineItems() -> Int {
        // Force context refresh to ensure we have latest data
        managedObjectContext.refreshAllObjects()
        
        let journeyEvents = fetchEventsArray().count
        let usageEntries = CoreDataManager.shared.fetchUsageEntries(for: product.objectID)
        let usageCheckIns = usageEntries.filter { $0.usageType == "check_in" }.count
        
        return journeyEvents + usageCheckIns
    }
    
    // FIXED: Add method to get usage entries with notes for accurate thought count
    func getThoughtCount() -> Int {
        // Count journey thoughts
        let journeyThoughts = events.filter { $0.eventType == "thought" }.count
        
        // Count usage entries with meaningful notes (exclude basic check-ins)
        let usageEntries = CoreDataManager.shared.fetchUsageEntries(for: product.objectID)
        let usageWithNotes = usageEntries.filter { entry in
            guard let notes = entry.notes,
                  !notes.isEmpty,
                  let data = notes.data(using: .utf8),
                  let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let userNotes = metadata["notes"] as? String else {
                return false
            }
            // Only count entries with actual user-written notes (not just context)
            return !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        
        return journeyThoughts + usageWithNotes
    }
    
    // Enhanced event creation for better data persistence
    func ensureInitialEventsExist() {
        let existingEvents = fetchEventsArray() // Use fetchEventsArray() when we need the return value
        
        // Check if we need purchase event
        if let purchaseDate = product.purchaseDate,
           !existingEvents.contains(where: { $0.eventType == "purchase" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .purchase,
                text: nil,
                title: nil,
                rating: 0,
                date: purchaseDate
            )
        }
        
        // Check if we need open event (only if product is opened)
        if let openDate = product.openDate,
           !existingEvents.contains(where: { $0.eventType == "open" }) {
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .open,
                text: nil,
                title: nil,
                rating: 0,
                date: openDate
            )
        }
        
        // Check if we need finished event (only if product is finished)
        if product.isFinished,
           !existingEvents.contains(where: { $0.eventType == "finished" }) {
            let finishDate = product.finishDate ?? Date()
            CoreDataManager.shared.addUsageJourneyEventNew(
                to: product.objectID,
                type: .finished,
                text: nil,
                title: nil,
                rating: 0,
                date: finishDate
            )
        }
        
        // Refresh events after ensuring initial ones exist
        loadEvents() // Use loadEvents() which doesn't return a value
    }
}
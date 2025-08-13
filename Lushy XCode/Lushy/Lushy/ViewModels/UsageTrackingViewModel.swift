import Foundation
import CoreData
import Combine

class UsageTrackingViewModel: ObservableObject {
    @Published var usageEntries: [UsageEntry] = []
    @Published var currentAmount: Double = 100.0
    @Published var isShowingUsageSheet = false
    @Published var selectedUsageType = "light"
    @Published var usageNotes = ""
    @Published var predictedFinishDate: Date?
    @Published var averageUsagePerWeek: Double = 0
    @Published var isShowingFinishConfirmation = false
    
    private let product: UserProduct
    private var cancellables = Set<AnyCancellable>()
    private var isFinishingProduct = false // Add flag to prevent multiple finish operations
    
    let usageTypes = [
        "light": (amount: 2.0, description: "Light use"),
        "medium": (amount: 5.0, description: "Regular use"),
        "heavy": (amount: 10.0, description: "Heavy use"),
        "custom": (amount: 0.0, description: "Custom amount")
    ]
    
    init(product: UserProduct) {
        self.product = product
        self.currentAmount = product.currentAmount
        loadUsageEntries()
        calculateUsageInsights()
        
        // Subscribe to Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadUsageEntries()
                self?.calculateUsageInsights()
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
    
    func addUsageEntry(type: String, customAmount: Double? = nil) {
        let amount: Double
        if type == "custom", let customAmount = customAmount {
            amount = customAmount
        } else {
            amount = usageTypes[type]?.amount ?? 5.0
        }
        
        CoreDataManager.shared.addUsageEntry(
            to: product.objectID,
            type: type,
            amount: amount,
            notes: usageNotes.isEmpty ? nil : usageNotes
        )
        
        // Update current amount
        let newAmount = max(0, currentAmount - amount)
        currentAmount = newAmount
        product.currentAmount = newAmount
        
        // Only mark as finished if empty AND not already finished (prevent infinite loop)
        if newAmount <= 0 && !product.isFinished {
            CoreDataManager.shared.markProductAsFinished(id: product.objectID)
        } else {
            try? CoreDataManager.shared.viewContext.save()
        }
        
        // Clear form
        usageNotes = ""
        isShowingUsageSheet = false
    }
    
    // Add function to manually finish product early
    func finishProductEarly() {
        // Prevent multiple simultaneous finish operations
        guard !product.isFinished && !isFinishingProduct else { 
            print("Product already finished or finish operation in progress")
            return 
        }
        
        // Set flag to prevent re-entry
        isFinishingProduct = true
        
        // Set current amount to 0 and mark as finished
        currentAmount = 0
        product.currentAmount = 0
        
        // Use async dispatch to prevent UI conflicts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            CoreDataManager.shared.markProductAsFinished(id: self.product.objectID)
            self.isShowingFinishConfirmation = false
            
            // Reset flag after a delay to ensure operation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isFinishingProduct = false
            }
        }
    }
    
    // Check if product can be finished early (has some usage or is opened)
    var canFinishEarly: Bool {
        return !product.isFinished && (!usageEntries.isEmpty || product.openDate != nil)
    }
    
    private func calculateUsageInsights() {
        guard !usageEntries.isEmpty else { return }
        
        // Calculate average usage per week
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        
        let recentEntries = usageEntries.filter { $0.createdAt >= oneWeekAgo }
        let totalUsageThisWeek = recentEntries.reduce(0) { $0 + $1.usageAmount }
        averageUsagePerWeek = totalUsageThisWeek
        
        // Predict finish date based on usage pattern
        if averageUsagePerWeek > 0 && currentAmount > 0 {
            let weeksRemaining = currentAmount / averageUsagePerWeek
            predictedFinishDate = calendar.date(byAdding: .weekOfYear, value: Int(ceil(weeksRemaining)), to: now)
        }
    }
    
    var progressPercentage: Double {
        return currentAmount / 100.0
    }
    
    var usageFrequency: String {
        guard !usageEntries.isEmpty else { return "No usage yet" }
        
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        
        let entriesThisWeek = usageEntries.filter { $0.createdAt >= oneWeekAgo }.count
        
        switch entriesThisWeek {
        case 0: return "Not used this week"
        case 1: return "Used once this week"
        case 2...3: return "Used \(entriesThisWeek) times this week"
        case 4...6: return "Used frequently (\(entriesThisWeek)x)"
        default: return "Used daily+"
        }
    }
}
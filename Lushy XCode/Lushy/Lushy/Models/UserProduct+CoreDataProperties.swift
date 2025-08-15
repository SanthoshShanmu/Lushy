import Foundation
import CoreData


extension UserProduct {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProduct> {
        return NSFetchRequest<UserProduct>(entityName: "UserProduct")
    }

    @NSManaged public var barcode: String?
    @NSManaged public var brand: String?
    @NSManaged public var crueltyFree: Bool
    @NSManaged public var currentAmount: Double
    @NSManaged public var expireDate: Date?
    @NSManaged public var favorite: Bool
    @NSManaged public var finishDate: Date?
    @NSManaged public var imageUrl: String?
    @NSManaged public var inWishlist: Bool
    @NSManaged public var isFinished: Bool
    @NSManaged public var openDate: Date?
    @NSManaged public var periodsAfterOpening: String?
    @NSManaged public var productName: String?
    @NSManaged public var shade: String?
    @NSManaged public var sizeInMl: Double
    @NSManaged public var spf: Int16
    @NSManaged public var quantity: Int32
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var vegan: Bool
    @NSManaged public var comments: NSSet?
    @NSManaged public var reviews: NSSet?
    @NSManaged public var bags: NSSet?
    @NSManaged public var tags: NSSet?
    @NSManaged public var usageEntries: NSSet?
    @NSManaged public var userId: String
    @NSManaged public var backendId: String?
    @objc(timesUsed)
    @NSManaged public dynamic var timesUsed: Int32

}

// MARK: Generated accessors for comments
extension UserProduct {

    @objc(addCommentsObject:)
    @NSManaged public func addToComments(_ value: Comment)

    @objc(removeCommentsObject:)
    @NSManaged public func removeFromComments(_ value: Comment)

    @objc(addComments:)
    @NSManaged public func addToComments(_ values: NSSet)

    @objc(removeComments:)
    @NSManaged public func removeFromComments(_ values: NSSet)

}

// MARK: Generated accessors for reviews
extension UserProduct {

    @objc(addReviewsObject:)
    @NSManaged public func addToReviews(_ value: Review)

    @objc(removeReviewsObject:)
    @NSManaged public func removeFromReviews(_ value: Review)

    @objc(addReviews:)
    @NSManaged public func addToReviews(_ values: NSSet)

    @objc(removeReviews:)
    @NSManaged public func removeFromReviews(_ values: NSSet)

}

// MARK: Generated accessors for bags
extension UserProduct {

    @objc(addBagsObject:)
    @NSManaged public func addToBags(_ value: BeautyBag)

    @objc(removeBagsObject:)
    @NSManaged public func removeFromBags(_ value: BeautyBag)

    @objc(addBags:)
    @NSManaged public func addToBags(_ values: NSSet)

    @objc(removeBags:)
    @NSManaged public func removeFromBags(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension UserProduct {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: ProductTag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: ProductTag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

// MARK: Generated accessors for usageEntries
extension UserProduct {

    @objc(addUsageEntriesObject:)
    @NSManaged public func addToUsageEntries(_ value: UsageEntry)

    @objc(removeUsageEntriesObject:)
    @NSManaged public func removeFromUsageEntries(_ value: UsageEntry)

    @objc(addUsageEntries:)
    @NSManaged public func addToUsageEntries(_ values: NSSet)

    @objc(removeUsageEntries:)
    @NSManaged public func removeFromUsageEntries(_ values: NSSet)

}

extension UserProduct : Identifiable {

}

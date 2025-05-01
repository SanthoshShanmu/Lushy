//
//  UserProduct+CoreDataProperties.swift
//  Lushy
//
//  Created by Karoline Herleiksplass on 01/05/2025.
//
//

import Foundation
import CoreData


extension UserProduct {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProduct> {
        return NSFetchRequest<UserProduct>(entityName: "UserProduct")
    }

    @NSManaged public var barcode: String?
    @NSManaged public var brand: String?
    @NSManaged public var crueltyFree: Bool
    @NSManaged public var expireDate: Date?
    @NSManaged public var favorite: Bool
    @NSManaged public var imageUrl: String?
    @NSManaged public var inWishlist: Bool
    @NSManaged public var openDate: Date?
    @NSManaged public var periodsAfterOpening: String?
    @NSManaged public var productName: String?
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var vegan: Bool
    @NSManaged public var comments: NSSet?
    @NSManaged public var reviews: NSSet?

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

extension UserProduct : Identifiable {

}

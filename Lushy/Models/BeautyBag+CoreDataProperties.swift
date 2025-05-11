//
//  BeautyBag+CoreDataProperties.swift
//  Lushy
//
//  Created by Karoline Herleiksplass on 11/05/2025.
//
//

import Foundation
import CoreData


extension BeautyBag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BeautyBag> {
        return NSFetchRequest<BeautyBag>(entityName: "BeautyBag")
    }

    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var icon: String?
    @NSManaged public var name: String?
    @NSManaged public var products: NSSet?

}

// MARK: Generated accessors for products
extension BeautyBag {

    @objc(addProductsObject:)
    @NSManaged public func addToProducts(_ value: UserProduct)

    @objc(removeProductsObject:)
    @NSManaged public func removeFromProducts(_ value: UserProduct)

    @objc(addProducts:)
    @NSManaged public func addToProducts(_ values: NSSet)

    @objc(removeProducts:)
    @NSManaged public func removeFromProducts(_ values: NSSet)

}

extension BeautyBag : Identifiable {

}

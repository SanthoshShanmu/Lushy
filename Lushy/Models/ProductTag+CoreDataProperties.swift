//
//  ProductTag+CoreDataProperties.swift
//  Lushy
//
//  Created by Karoline Herleiksplass on 11/05/2025.
//
//

import Foundation
import CoreData


extension ProductTag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProductTag> {
        return NSFetchRequest<ProductTag>(entityName: "ProductTag")
    }

    @NSManaged public var color: String?
    @NSManaged public var name: String?
    @NSManaged public var products: NSSet?
    @NSManaged public var userId: String

}

// MARK: Generated accessors for products
extension ProductTag {

    @objc(addProductsObject:)
    @NSManaged public func addToProducts(_ value: UserProduct)

    @objc(removeProductsObject:)
    @NSManaged public func removeFromProducts(_ value: UserProduct)

    @objc(addProducts:)
    @NSManaged public func addToProducts(_ values: NSSet)

    @objc(removeProducts:)
    @NSManaged public func removeFromProducts(_ values: NSSet)

}

extension ProductTag : Identifiable {

}

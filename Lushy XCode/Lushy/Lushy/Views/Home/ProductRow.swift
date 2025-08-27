import SwiftUI
import CoreData

struct ProductRow: View {
    let product: UserProduct
    
    var body: some View {
        PrettyProductRow(product: product)
    }
}

#Preview {
    let context = CoreDataManager.shared.viewContext
    let sampleProduct = UserProduct(context: context)
    sampleProduct.productName = "Sample Product"
    sampleProduct.brand = "Sample Brand"
    sampleProduct.favorite = true
    
    return ProductRow(product: sampleProduct)
}

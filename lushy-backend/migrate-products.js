const mongoose = require('mongoose');
const Product = require('./src/models/product');
const UserProduct = require('./src/models/userProduct');
require('dotenv').config();

async function migrateToReferentialArchitecture() {
  try {
    console.log('🚀 Starting migration to referential architecture...');
    
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');
    
    // Get all existing UserProducts
    const existingUserProducts = await mongoose.connection.db.collection('userproducts').find({}).toArray();
    console.log(`📊 Found ${existingUserProducts.length} existing user products`);
    
    if (existingUserProducts.length === 0) {
      console.log('✅ No existing user products found. Migration complete.');
      process.exit(0);
    }
    
    let migratedCount = 0;
    let errorCount = 0;
    
    for (const userProduct of existingUserProducts) {
      try {
        console.log(`🔄 Processing user product: ${userProduct._id}`);
        
        // Extract product catalog data from user product
        const productCatalogData = {
          barcode: userProduct.barcode || `legacy_${userProduct._id}`,
          productName: userProduct.productName || 'Unknown Product',
          brand: userProduct.brand,
          imageUrl: userProduct.imageUrl,
          imageData: userProduct.imageData,
          imageMimeType: userProduct.imageMimeType,
          periodsAfterOpening: userProduct.periodsAfterOpening,
          vegan: userProduct.vegan || false,
          crueltyFree: userProduct.crueltyFree || false,
          category: 'legacy',
          contributedBy: [{
            source: 'migration',
            timestamp: new Date()
          }]
        };
        
        // Find or create product in catalog
        let catalogProduct = await Product.findOne({ barcode: productCatalogData.barcode });
        
        if (!catalogProduct) {
          catalogProduct = new Product(productCatalogData);
          await catalogProduct.save();
          console.log(`  ✅ Created catalog product: ${catalogProduct.productName}`);
        } else {
          console.log(`  ♻️  Using existing catalog product: ${catalogProduct.productName}`);
        }
        
        // Update user product to reference catalog product and remove duplicated fields
        const updateData = {
          product: catalogProduct._id,
          // Remove fields that are now in the catalog
          $unset: {
            productName: 1,
            brand: 1,
            barcode: 1,
            imageUrl: 1,
            imageData: 1,
            imageMimeType: 1,
            periodsAfterOpening: 1,
            vegan: 1,
            crueltyFree: 1
          }
        };
        
        await mongoose.connection.db.collection('userproducts').updateOne(
          { _id: userProduct._id },
          updateData
        );
        
        migratedCount++;
        console.log(`  ✅ Migrated user product ${userProduct._id}`);
        
      } catch (error) {
        console.error(`  ❌ Error migrating user product ${userProduct._id}:`, error);
        errorCount++;
      }
    }
    
    console.log('\n🎉 Migration Summary:');
    console.log(`✅ Successfully migrated: ${migratedCount} user products`);
    console.log(`❌ Errors: ${errorCount} user products`);
    
    // Update indexes
    console.log('\n🔧 Updating database indexes...');
    
    // Drop old indexes on UserProduct
    try {
      await mongoose.connection.db.collection('userproducts').dropIndex('user_1_productName_1_brand_1');
    } catch (e) {
      console.log('  ⚠️  Index user_1_productName_1_brand_1 not found (ok)');
    }
    
    try {
      await mongoose.connection.db.collection('userproducts').dropIndex('user_1_barcode_1');
    } catch (e) {
      console.log('  ⚠️  Index user_1_barcode_1 not found (ok)');
    }
    
    // Create new indexes
    await mongoose.connection.db.collection('userproducts').createIndex({ user: 1, product: 1 }, { unique: true });
    await mongoose.connection.db.collection('userproducts').createIndex({ user: 1 });
    await mongoose.connection.db.collection('userproducts').createIndex({ product: 1 });
    await mongoose.connection.db.collection('userproducts').createIndex({ user: 1, isFinished: 1 });
    await mongoose.connection.db.collection('userproducts').createIndex({ user: 1, favorite: 1 });
    
    console.log('✅ Updated database indexes');
    
    console.log('\n🎉 Migration completed successfully!');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

// Run migration if called directly
if (require.main === module) {
  migrateToReferentialArchitecture()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = { migrateToReferentialArchitecture };
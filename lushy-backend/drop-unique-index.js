const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

async function dropUniqueIndex() {
  console.log('🚀 Starting index drop operation...');
  
  try {
    // Use the same connection string as your backend
    const mongoUri = process.env.MONGODB_URI;
    
    if (!mongoUri) {
      console.error('❌ MONGODB_URI environment variable is not set');
      console.log('Please check your .env file or set the MONGODB_URI environment variable');
      process.exit(1);
    }
    
    console.log(`Connecting to database...`);
    
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB');
    
    const db = mongoose.connection.db;
    const collection = db.collection('userproducts');
    
    console.log('📋 Current indexes:');
    const indexes = await collection.indexes();
    indexes.forEach(index => {
      console.log(`  - ${index.name}: ${JSON.stringify(index.key)} ${index.unique ? '(UNIQUE)' : ''}`);
    });
    
    // Try to drop the unique index on user + product
    console.log('\n🔧 Attempting to drop unique index...');
    try {
      // Try dropping by index name first
      await collection.dropIndex('user_1_product_1');
      console.log('✅ Successfully dropped unique index user_1_product_1');
    } catch (error) {
      if (error.codeName === 'IndexNotFound' || error.code === 27) {
        console.log('ℹ️  Index user_1_product_1 was already dropped or does not exist');
      } else {
        console.log('❌ Error dropping index by name:', error.message);
        // Try alternative method with key specification
        try {
          await collection.dropIndex({ user: 1, product: 1 });
          console.log('✅ Successfully dropped unique index using key specification');
        } catch (altError) {
          console.log('❌ Alternative method also failed:', altError.message);
          throw altError;
        }
      }
    }
    
    console.log('\n📋 Indexes after operation:');
    const newIndexes = await collection.indexes();
    newIndexes.forEach(index => {
      console.log(`  - ${index.name}: ${JSON.stringify(index.key)} ${index.unique ? '(UNIQUE)' : ''}`);
    });
    
    // Verify the problematic index is gone
    const hasUniqueIndex = newIndexes.some(index => 
      index.name === 'user_1_product_1' || 
      (JSON.stringify(index.key) === '{"user":1,"product":1}' && index.unique)
    );
    
    if (hasUniqueIndex) {
      console.log('❌ Unique index still exists! Manual intervention may be required.');
    } else {
      console.log('🎉 Success! Users can now add multiple instances of the same product.');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    await mongoose.connection.close();
    console.log('📤 Database connection closed.');
    process.exit(0);
  }
}

dropUniqueIndex();
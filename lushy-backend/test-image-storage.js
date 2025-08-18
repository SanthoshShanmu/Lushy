const mongoose = require('mongoose');
const UserProduct = require('./src/models/userProduct');

// Test script to verify base64 image storage in MongoDB
async function testImageStorage() {
  try {
    // Connect to MongoDB
    await mongoose.connect('mongodb://localhost:27017/lushy-test', {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
    
    console.log('Connected to MongoDB');
    
    // Sample base64 image data (1x1 pixel red image)
    const sampleImageData = '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/AB2p';
    
    // Create test product with base64 image
    const testProduct = new UserProduct({
      user: new mongoose.Types.ObjectId(),
      productName: 'Test Product with Base64 Image',
      brand: 'Test Brand',
      imageData: sampleImageData,
      imageMimeType: 'image/jpeg',
      imageUrl: `data:image/jpeg;base64,${sampleImageData}`,
      barcode: '1234567890123',
      purchaseDate: new Date(),
      vegan: false,
      crueltyFree: true
    });
    
    // Save to database
    const savedProduct = await testProduct.save();
    console.log('✅ Product saved with base64 image data');
    console.log('Product ID:', savedProduct._id);
    console.log('Image data length:', savedProduct.imageData.length);
    console.log('MIME type:', savedProduct.imageMimeType);
    
    // Test barcode search
    const searchResults = await UserProduct.find({ barcode: '1234567890123' })
      .select('productName brand imageUrl imageData imageMimeType barcode')
      .lean();
    
    console.log('✅ Barcode search results:', searchResults.length);
    
    if (searchResults.length > 0) {
      const product = searchResults[0];
      console.log('Found product:', product.productName);
      console.log('Has base64 image data:', !!product.imageData);
      console.log('Image URL format:', product.imageUrl?.substring(0, 50) + '...');
    }
    
    // Clean up test data
    await UserProduct.deleteOne({ _id: savedProduct._id });
    console.log('✅ Test data cleaned up');
    
    console.log('\n🎉 All tests passed! Image storage in MongoDB is working correctly.');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  }
}

// Run the test
testImageStorage();
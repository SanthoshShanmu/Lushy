const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Product catalog schema - stores general product information for barcode lookups
const ProductSchema = new Schema({
  barcode: {
    type: String,
    required: true,
    unique: true
  },
  productName: {
    type: String,
    required: true
  },
  brand: String,
  imageUrl: String, // Keep for backward compatibility
  imageData: String, // Base64 image data stored in MongoDB
  imageMimeType: String, // MIME type for proper display
  periodsAfterOpening: String, // PAO information like "12M"
  // Ethics information
  vegan: {
    type: Boolean,
    default: false
  },
  crueltyFree: {
    type: Boolean,
    default: false
  },
  // Product-specific attributes (different values = different barcodes/products)
  shade: String, // e.g., "Light", "Medium", "Dark" for foundations/concealers
  sizeInMl: Number, // e.g., 30, 50, 100 for different size variants
  spf: Number, // e.g., 15, 30, 50 for different SPF levels
  // Additional metadata
  category: String, // e.g., "skincare", "makeup", "haircare"
  // Contribution tracking
  contributedBy: [{
    source: String, // "user_submission", "manual_entry", etc.
    timestamp: {
      type: Date,
      default: Date.now
    }
  }],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Update the updatedAt field on save
ProductSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Static method to find or create product by barcode with better race condition handling
ProductSchema.statics.findOrCreateByBarcode = async function(barcodeData) {
  const session = await mongoose.startSession();
  
  try {
    return await session.withTransaction(async () => {
      // Try to find existing product first
      let product = await this.findOne({ barcode: barcodeData.barcode }).session(session);
      
      if (!product) {
        // Create new product entry
        const productDoc = new this({
          barcode: barcodeData.barcode,
          productName: barcodeData.productName || 'Unknown Product',
          brand: barcodeData.brand,
          imageData: barcodeData.imageData,
          imageMimeType: barcodeData.imageMimeType,
          imageUrl: barcodeData.imageUrl,
          periodsAfterOpening: barcodeData.periodsAfterOpening,
          vegan: barcodeData.vegan || false,
          crueltyFree: barcodeData.crueltyFree || false,
          category: barcodeData.category || 'beauty',
          contributedBy: [{
            source: barcodeData.source || 'user_submission',
            timestamp: new Date()
          }]
        });
        
        try {
          product = await productDoc.save({ session });
          console.log(`Created new product in catalog: ${product.productName} (${product.barcode})`);
        } catch (error) {
          if (error.code === 11000) {
            // Duplicate key error - another process created it, fetch the existing one
            product = await this.findOne({ barcode: barcodeData.barcode }).session(session);
            console.log(`Product already exists in catalog: ${product.productName} (${product.barcode})`);
          } else {
            throw error;
          }
        }
      }
      
      return product;
    });
  } finally {
    await session.endSession();
  }
};

// Static method for manual product creation (without barcode)
ProductSchema.statics.findOrCreateManualProduct = async function(productData, userId) {
  const session = await mongoose.startSession();
  
  try {
    return await session.withTransaction(async () => {
      // For manual entries, create a unique identifier
      const uniqueKey = `manual_${userId}_${productData.productName}_${productData.brand || ''}`;
      
      let product = await this.findOne({ barcode: uniqueKey }).session(session);
      
      if (!product) {
        const productDoc = new this({
          ...productData,
          barcode: uniqueKey,
          contributedBy: [{
            source: 'manual_entry',
            timestamp: new Date()
          }]
        });
        
        try {
          product = await productDoc.save({ session });
          console.log(`Created new manual product: ${product.productName}`);
        } catch (error) {
          if (error.code === 11000) {
            product = await this.findOne({ barcode: uniqueKey }).session(session);
          } else {
            throw error;
          }
        }
      }
      
      return product;
    });
  } finally {
    await session.endSession();
  }
};

// Index for efficient lookups (barcode index auto-created by unique constraint)
ProductSchema.index({ productName: 'text', brand: 'text' });

module.exports = mongoose.model('Product', ProductSchema);
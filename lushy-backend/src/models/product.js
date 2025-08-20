const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Product catalog schema - stores general product information for barcode lookups
const ProductSchema = new Schema({
  barcode: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  productName: {
    type: String,
    required: true
  },
  brand: String,
  imageUrl: String, // Keep for backward compatibility
  imageData: String, // Base64 image data stored in MongoDB
  imageMimeType: String, // MIME type for proper display
  ingredients: [String], // Array of ingredients
  periodsAfterOpening: String, // PAO information like "12M"
  periodsAfterOpeningTags: [String], // Alternative PAO formats
  batchCode: String,
  manufactureDate: Date,
  complianceAdvisory: String,
  regionSpecificGuidelines: {
    type: Map,
    of: String
  },
  // Ethics information
  vegan: {
    type: Boolean,
    default: false
  },
  crueltyFree: {
    type: Boolean,
    default: false
  },
  // Additional metadata
  category: String, // e.g., "skincare", "makeup", "haircare"
  subcategory: String,
  // Contribution tracking
  contributedBy: [{
    source: String, // "user_submission", "manual_entry", etc.
    timestamp: {
      type: Date,
      default: Date.now
    }
  }],
  verified: {
    type: Boolean,
    default: false
  },
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

// Static method to find or create product by barcode
ProductSchema.statics.findOrCreateByBarcode = async function(barcodeData) {
  try {
    let product = await this.findOne({ barcode: barcodeData.barcode });
    
    if (!product) {
      // Create new product entry
      product = new this({
        barcode: barcodeData.barcode,
        productName: barcodeData.productName || 'Unknown Product',
        brand: barcodeData.brand,
        imageData: barcodeData.imageData,
        imageMimeType: barcodeData.imageMimeType,
        imageUrl: barcodeData.imageUrl,
        ingredientsTextWithAllergens: barcodeData.ingredients,
        periodsAfterOpening: barcodeData.periodsAfterOpening,
        vegan: barcodeData.vegan || false,
        crueltyFree: barcodeData.crueltyFree || false,
        category: barcodeData.category || 'beauty',
        contributedBy: [{
          source: 'user_submission',
          timestamp: new Date()
        }]
      });
      
      await product.save();
      console.log(`Created new product in catalog: ${product.productName} (${product.barcode})`);
    }
    
    return product;
  } catch (error) {
    console.error('Error in findOrCreateByBarcode:', error);
    throw error;
  }
};

// Index for efficient barcode lookups
ProductSchema.index({ barcode: 1 });
ProductSchema.index({ productName: 'text', brand: 'text' });

module.exports = mongoose.model('Product', ProductSchema);
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Usage Entry schema for detailed usage tracking
const UsageEntrySchema = new Schema({
  usageType: {
    type: String,
    required: true,
    enum: ['light', 'medium', 'heavy', 'custom']
  },
  usageAmount: {
    type: Number,
    required: true,
    min: 0,
    max: 100
  },
  notes: {
    type: String,
    required: false
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Comment schema
const CommentSchema = new Schema({
  text: {
    type: String,
    required: true
  },
  date: {
    type: Date,
    default: Date.now
  }
});

// Review schema
const ReviewSchema = new Schema({
  rating: {
    type: Number,
    required: true,
    min: 1,
    max: 5
  },
  title: {
    type: String,
    required: true
  },
  text: {
    type: String,
    required: true
  },
  date: {
    type: Date,
    default: Date.now
  }
});

// UserProduct schema
const UserProductSchema = new Schema({
  user: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  barcode: {
    type: String,
    required: false // made optional to allow manual products without barcode
  },
  productName: {
    type: String,
    required: true
  },
  brand: String,
  imageUrl: String, // Keep for backward compatibility
  imageData: String, // New field for base64 image data
  imageMimeType: String, // Store MIME type for proper display (e.g., 'image/jpeg')
  purchaseDate: {
    type: Date,
    required: true
  },
  openDate: Date,
  expireDate: Date,
  periodsAfterOpening: String,
  vegan: {
    type: Boolean,
    default: false
  },
  crueltyFree: {
    type: Boolean,
    default: false
  },
  favorite: {
    type: Boolean,
    default: false
  },
  // Enhanced usage tracking
  currentAmount: {
    type: Number,
    default: 100.0,
    min: 0,
    max: 100
  },
  timesUsed: {
    type: Number,
    default: 0
  },
  isFinished: {
    type: Boolean,
    default: false
  },
  finishDate: Date,
  // Usage entries for detailed tracking
  usageEntries: [UsageEntrySchema],
  // New optional metadata fields
  shade: { type: String },
  sizeInMl: { type: Number },
  spf: { type: Number },
  // Quantity field to track similar products
  quantity: {
    type: Number,
    default: 1,
    min: 0
  },
  inWishlist: {
    type: Boolean,
    default: false
  },
  // Associations to user tags and beauty bags
  tags: [{ type: Schema.Types.ObjectId, ref: 'ProductTag' }],
  bags: [{ type: Schema.Types.ObjectId, ref: 'BeautyBag' }],
  comments: [CommentSchema],
  reviews: [ReviewSchema],
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
UserProductSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Calculate expireDate from openDate and periodsAfterOpening
UserProductSchema.pre('save', function(next) {
  if (this.openDate && this.periodsAfterOpening) {
    const months = extractMonths(this.periodsAfterOpening);
    if (months) {
      const openDate = new Date(this.openDate);
      this.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
    }
  }
  next();
});

// Helper function to extract months from period string
function extractMonths(periodString) {
  const match = periodString.match(/(\d+)\s*[Mm]/);
  return match ? parseInt(match[1]) : null;
}

// Helper function to find similar products
UserProductSchema.statics.findSimilarProducts = async function(userId, productName, brand, sizeInMl) {
  const query = {
    user: userId,
    productName: productName,
    brand: brand
  };
  
  // Include sizeInMl in comparison if it's specified
  if (sizeInMl && sizeInMl > 0) {
    query.sizeInMl = sizeInMl;
  }
  
  return await this.find(query);
};

// Helper function to update quantity for similar products
UserProductSchema.statics.updateSimilarProductsQuantity = async function(userId, productName, brand, sizeInMl, increment = true) {
  try {
    // Find all similar products for this user
    const query = {
      user: userId,
      productName: { $regex: new RegExp(`^${productName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
      brand: { $regex: new RegExp(`^${brand.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') }
    };
    
    // If size is specified, also match by size (within 10ml tolerance)
    if (sizeInMl && sizeInMl > 0) {
      query.sizeInMl = { $gte: sizeInMl - 10, $lte: sizeInMl + 10 };
    }
    
    const similarProducts = await this.find(query);
    
    // Calculate new quantity
    let totalQuantity = similarProducts.length;
    if (!increment && totalQuantity > 0) {
      totalQuantity = Math.max(0, totalQuantity - 1);
    }
    
    // Update all similar products with the new quantity
    await this.updateMany(query, { quantity: totalQuantity });
    
    console.log(`Updated quantity to ${totalQuantity} for ${similarProducts.length} similar products: ${productName} by ${brand}`);
    
    return totalQuantity;
  } catch (error) {
    console.error('Error updating similar products quantity:', error);
    throw error;
  }
};

// Index for efficient similarity queries
UserProductSchema.index({ user: 1, productName: 1, brand: 1 });
UserProductSchema.index({ user: 1, barcode: 1 });

module.exports = mongoose.model('UserProduct', UserProductSchema);
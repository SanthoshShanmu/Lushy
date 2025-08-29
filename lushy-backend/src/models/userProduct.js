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

// UserProduct schema - now references Product catalog
const UserProductSchema = new Schema({
  user: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  // Reference to the Product catalog (single source of truth)
  product: {
    type: Schema.Types.ObjectId,
    ref: 'Product',
    required: true
  },
  // User-specific product data only
  purchaseDate: {
    type: Date,
    required: true
  },
  // Add price field for user-specific pricing
  price: {
    type: Number,
    required: false,
    min: 0
  },
  currency: {
    type: String,
    required: false,
    default: 'USD',
    maxlength: 3
  },
  openDate: Date,
  expireDate: Date,
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

// Calculate expireDate from openDate and product's periodsAfterOpening
UserProductSchema.pre('save', async function(next) {
  if (this.openDate && this.isModified('openDate')) {
    try {
      // Get the product to access periodsAfterOpening
      const Product = mongoose.model('Product');
      const product = await Product.findById(this.product);
      
      if (product && product.periodsAfterOpening) {
        const months = extractMonths(product.periodsAfterOpening);
        if (months) {
          const openDate = new Date(this.openDate);
          this.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
        }
      }
    } catch (error) {
      console.error('Error calculating expiry date:', error);
    }
  }
  next();
});

// Helper function to extract months from period string
function extractMonths(periodString) {
  const match = periodString.match(/(\d+)\s*[Mm]/);
  return match ? parseInt(match[1]) : null;
}

// Static method to create user product with proper product reference
UserProductSchema.statics.createWithProduct = async function(userData, productData) {
  const session = await mongoose.startSession();
  
  try {
    return await session.withTransaction(async () => {
      const Product = mongoose.model('Product');
      
      // Find or create the product in catalog using atomic operation
      let product;
      if (productData.barcode) {
        // Try to find existing product by barcode
        product = await Product.findOne({ barcode: productData.barcode }).session(session);
        
        if (!product) {
          // Create new product with upsert to handle race conditions
          const productDoc = new Product(productData);
          try {
            product = await productDoc.save({ session });
          } catch (error) {
            if (error.code === 11000) {
              // Duplicate key error - another process created it
              product = await Product.findOne({ barcode: productData.barcode }).session(session);
            } else {
              throw error;
            }
          }
        }
      } else {
        // For manual entries without barcode, create a unique product entry
        // Use a combination of name + brand + user to create unique products for manual entries
        const uniqueKey = `${userData.user}_${productData.productName}_${productData.brand || ''}`;
        product = await Product.findOne({ 
          barcode: uniqueKey,
          productName: productData.productName,
          brand: productData.brand || ''
        }).session(session);
        
        if (!product) {
          const productDoc = new Product({
            ...productData,
            barcode: uniqueKey // Use unique key as barcode for manual entries
          });
          try {
            product = await productDoc.save({ session });
          } catch (error) {
            if (error.code === 11000) {
              product = await Product.findOne({ barcode: uniqueKey }).session(session);
            } else {
              throw error;
            }
          }
        }
      }
      
      // Create the user product entry
      const userProduct = new this({
        ...userData,
        product: product._id
      });
      
      await userProduct.save({ session });
      return await userProduct.populate('product');
    });
  } finally {
    await session.endSession();
  }
};

// Helper function to find similar products for a user
UserProductSchema.statics.findSimilarProducts = async function(userId, productId) {
  return await this.find({
    user: userId,
    product: productId
  }).populate('product');
};

// Helper function to update quantity for similar products
UserProductSchema.statics.updateSimilarProductsQuantity = async function(userId, productId, increment = true) {
  try {
    const similarProducts = await this.find({
      user: userId,
      product: productId
    });
    
    // Calculate new quantity
    let totalQuantity = similarProducts.length;
    if (!increment && totalQuantity > 0) {
      totalQuantity = Math.max(0, totalQuantity - 1);
    }
    
    // Update all similar products with the new quantity
    await this.updateMany({
      user: userId,
      product: productId
    }, { quantity: totalQuantity });
    
    console.log(`Updated quantity to ${totalQuantity} for ${similarProducts.length} similar products`);
    
    return totalQuantity;
  } catch (error) {
    console.error('Error updating similar products quantity:', error);
    throw error;
  }
};

// Indexes for efficient queries
UserProductSchema.index({ user: 1 });
UserProductSchema.index({ product: 1 });
UserProductSchema.index({ user: 1, isFinished: 1 });

module.exports = mongoose.model('UserProduct', UserProductSchema);
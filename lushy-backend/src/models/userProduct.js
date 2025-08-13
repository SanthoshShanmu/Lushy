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
  imageUrl: String,
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

module.exports = mongoose.model('UserProduct', UserProductSchema);
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Global Product Rating schema - tracks community ratings for products
const GlobalProductRatingSchema = new Schema({
  productKey: {
    type: String,
    required: true,
    index: true // Index for fast lookups
  },
  user: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Create a compound index to ensure one rating per user per product
GlobalProductRatingSchema.index({ productKey: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('GlobalProductRating', GlobalProductRatingSchema);
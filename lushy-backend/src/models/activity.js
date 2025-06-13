const mongoose = require('mongoose');

const ActivitySchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, required: true }, // e.g., 'bag_update', 'review', 'product_added'
  targetId: { type: mongoose.Schema.Types.ObjectId }, // ID of the bag/product/review
  targetType: { type: String }, // e.g., 'BeautyBag', 'Review', 'UserProduct'
  description: { type: String },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Activity', ActivitySchema);
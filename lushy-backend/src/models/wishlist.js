const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const WishlistItemSchema = new Schema({
  user: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  productName: {
    type: String,
    required: true
  },
  productURL: {
    type: String,
    required: true
  },
  notes: String,
  imageURL: String,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('WishlistItem', WishlistItemSchema);
const mongoose = require('mongoose');

const BeautyBagSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  color: { type: String, default: 'lushyPink' },
  icon: { type: String, default: 'bag.fill' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('BeautyBag', BeautyBagSchema);
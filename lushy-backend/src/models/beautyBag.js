const mongoose = require('mongoose');

const BeautyBagSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  description: { type: String, default: '' }, // New: bag bio/description
  color: { type: String, default: 'lushyPink' },
  icon: { type: String, default: 'bag.fill' },
  image: { type: String }, // New: custom image path
  isPrivate: { type: Boolean, default: false }, // New: privacy setting
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('BeautyBag', BeautyBagSchema);
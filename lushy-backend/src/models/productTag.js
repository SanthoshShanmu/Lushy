const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Model for user-defined product tags
const ProductTagSchema = new Schema({
  user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  color: { type: String, required: true }
}, { timestamps: true });

module.exports = mongoose.model('ProductTag', ProductTagSchema);
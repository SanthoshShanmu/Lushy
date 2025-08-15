const User = require('../models/user');
const mongoose = require('mongoose');

// Follow a user
exports.followUser = async (req, res) => {
  try {
    const currentUserId = req.body.currentUserId; // The user who is following
    const targetUserId = req.params.userId; // The user to be followed
    if (currentUserId === targetUserId) {
      return res.status(400).json({ message: 'You cannot follow yourself.' });
    }
    const currentUser = await User.findById(currentUserId);
    const targetUser = await User.findById(targetUserId);
    if (!currentUser || !targetUser) {
      return res.status(404).json({ message: 'User not found.' });
    }
    if (currentUser.following.map(id => id.toString()).includes(targetUserId)) {
      return res.status(400).json({ message: 'Already following this user.' });
    }
    currentUser.following.push(targetUserId);
    targetUser.followers.push(currentUserId);
    await currentUser.save();
    await targetUser.save();

    // DO NOT create activity for follow action - this shouldn't appear in feed

    res.json({ message: 'User followed successfully.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Unfollow a user
exports.unfollowUser = async (req, res) => {
  try {
    const currentUserId = req.body.currentUserId;
    const targetUserId = req.params.userId;
    if (currentUserId === targetUserId) {
      return res.status(400).json({ message: 'You cannot unfollow yourself.' });
    }
    const currentUser = await User.findById(currentUserId);
    const targetUser = await User.findById(targetUserId);
    if (!currentUser || !targetUser) {
      return res.status(404).json({ message: 'User not found.' });
    }
    currentUser.following = currentUser.following.filter(id => id.toString() !== targetUserId);
    targetUser.followers = targetUser.followers.filter(id => id.toString() !== currentUserId);
    await currentUser.save();
    await targetUser.save();

    // DO NOT create activity for unfollow action - this shouldn't appear in feed

    res.json({ message: 'User unfollowed successfully.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Get user profile (with bags and products)
exports.getUserProfile = async (req, res) => {
  try {
    const userId = req.params.userId;
    let user = await User.findById(userId)
      .select('-password')
      .populate('followers', 'name email')
      .populate('following', 'name email');
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }
    // Fetch bags and products if models exist
    let bags = [];
    let products = [];
    try {
      const BeautyBag = require('../models/beautyBag');
      bags = await BeautyBag.find({ user: userId }).select('name');
      // Remove duplicate bag entries by name
      bags = bags.filter((bag, idx) => bags.findIndex(b => b.name === bag.name) === idx);
    } catch (e) {}
    try {
      const UserProduct = require('../models/userProduct');
      // Fetch products for user with populated tags and bags
      products = await UserProduct.find({ user: userId })
        .select('productName brand favorite tags bags barcode imageUrl purchaseDate openDate periodsAfterOpening vegan crueltyFree isFinished')
        .populate('tags', 'name color')
        .populate('bags', 'name');
    } catch (e) {}
    // Attach bags and products to user object
    user = user.toObject();
    user.bags = bags;
    user.products = products;
    res.json({ user });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Search users
exports.searchUsers = async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) {
      return res.status(400).json({ message: 'Query required.' });
    }
    const users = await User.find({
      $or: [
        { name: { $regex: q, $options: 'i' } },
        { email: { $regex: q, $options: 'i' } }
      ]
    }).select('name email');
    res.json({ users });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Create a new beauty bag
exports.createBag = async (req, res) => {
  try {
    const userId = req.params.userId;
    const { name } = req.body;
    const BeautyBag = require('../models/beautyBag');
    // Prevent duplicate bag names per user
    const existing = await BeautyBag.findOne({ user: userId, name });
    if (existing) {
      return res.status(200).json({ bag: existing });
    }
    const newBag = await BeautyBag.create({ user: userId, name });
    res.status(201).json({ bag: newBag });
  } catch (err) {
    res.status(500).json({ message: 'Failed to create bag.', error: err.message });
  }
};

// Get all beauty bags for a user
exports.getUserBags = async (req, res) => {
  try {
    const userId = req.params.userId;
    const BeautyBag = require('../models/beautyBag');
    const bags = await BeautyBag.find({ user: userId }).select('name');
    res.json({ bags });
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch bags.', error: err.message });
  }
};

// Delete a beauty bag
exports.deleteBag = async (req, res) => {
  try {
    const { userId, bagId } = req.params;
    const BeautyBag = require('../models/beautyBag');
    const deleted = await BeautyBag.findOneAndDelete({ _id: bagId, user: userId });
    if (!deleted) {
      return res.status(404).json({ message: 'Bag not found.' });
    }
    res.json({ message: 'Bag deleted successfully.' });
  } catch (err) {
    res.status(500).json({ message: 'Failed to delete bag.', error: err.message });
  }
};

// Get product tags for a user
exports.getUserTags = async (req, res) => {
  console.log('getUserTags called with userId=', req.params.userId);
  try {
    const userId = req.params.userId;
    const ProductTag = require('../models/productTag');
    console.log('ProductTag model loaded:', typeof ProductTag);
    const tags = await ProductTag.find({ user: new mongoose.Types.ObjectId(userId) }).select('name color');
    console.log(`Fetched ${tags.length} tags`);
    res.json({ tags });
  } catch (err) {
    console.error('Error in getUserTags:', err);
    res.status(500).json({ message: 'Failed to fetch tags.', error: err.message });
  }
};

// Create a new product tag for a user
exports.createTag = async (req, res) => {
  try {
    const userId = req.params.userId;
    const { name, color } = req.body;
    const ProductTag = require('../models/productTag');
    // Prevent duplicate tag names per user
    let existing = await ProductTag.findOne({ user: userId, name });
    if (existing) {
      return res.status(200).json({ tag: existing });
    }
    const newTag = await ProductTag.create({ user: userId, name, color });
    res.status(201).json({ tag: newTag });
  } catch (err) {
    res.status(500).json({ message: 'Failed to create tag.', error: err.message });
  }
};

// Get user settings (region, auto-contribute, OBF counters)
exports.getUserSettings = async (req, res) => {
  try {
    const userId = req.params.userId;
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user id.' });
    }
    const user = await User.findById(userId).select('region settings.obf settings.autoContributeToOBF obfContributionCount obfContributedProducts');
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({
      settings: {
        region: user.region || 'GLOBAL',
        autoContributeToOBF: user.settings?.autoContributeToOBF ?? true
      },
      obf: {
        contributionCount: user.obfContributionCount || 0,
        contributedProducts: user.obfContributedProducts || []
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Update user settings (only owner can update)
exports.updateUserSettings = async (req, res) => {
  try {
    const userId = req.params.userId;
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user id.' });
    }

    // Authorization: only the authenticated user can update their settings
    if (!req.user || req.user._id.toString() !== userId) {
      return res.status(403).json({ message: 'Not authorized to update these settings.' });
    }

    const updates = {};
    const allowedRegions = ['GLOBAL', 'EU', 'US', 'JP'];

    if (typeof req.body.region === 'string') {
      const region = req.body.region.toUpperCase();
      if (!allowedRegions.includes(region)) {
        return res.status(400).json({ message: 'Invalid region.' });
      }
      updates.region = region;
    }

    if (typeof req.body.autoContributeToOBF === 'boolean') {
      updates['settings.autoContributeToOBF'] = req.body.autoContributeToOBF;
    }

    const user = await User.findByIdAndUpdate(userId, { $set: updates }, { new: true });
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({
      settings: {
        region: user.region || 'GLOBAL',
        autoContributeToOBF: user.settings?.autoContributeToOBF ?? true
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Increment OBF contribution count and optionally record a product id
exports.addObfContribution = async (req, res) => {
  try {
    const userId = req.params.userId;
    const { productId } = req.body || {};

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user id.' });
    }

    // Only owner can modify their counters
    if (!req.user || req.user._id.toString() !== userId) {
      return res.status(403).json({ message: 'Not authorized.' });
    }

    const update = { $inc: { obfContributionCount: 1 } };
    if (productId && typeof productId === 'string' && productId.trim()) {
      update.$addToSet = { obfContributedProducts: productId.trim() };
    }

    const user = await User.findByIdAndUpdate(userId, update, { new: true, upsert: false });
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.status(201).json({
      obf: {
        contributionCount: user.obfContributionCount || 0,
        contributedProducts: user.obfContributedProducts || []
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Get OBF contribution summary
exports.getObfContributions = async (req, res) => {
  try {
    const userId = req.params.userId;
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user id.' });
    }

    // Owner or public read? Keep it authenticated owner-only for now
    if (!req.user || req.user._id.toString() !== userId) {
      return res.status(403).json({ message: 'Not authorized.' });
    }

    const user = await User.findById(userId).select('obfContributionCount obfContributedProducts');
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({
      obf: {
        contributionCount: user.obfContributionCount || 0,
        contributedProducts: user.obfContributedProducts || []
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

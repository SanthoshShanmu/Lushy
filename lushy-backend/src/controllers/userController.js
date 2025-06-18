const User = require('../models/user');

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
      .populate('followers', 'name')
      .populate('following', 'name');
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
      products = await UserProduct.find({ user: userId }).select('productName brand favorite');
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

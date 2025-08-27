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
      .populate('followers', 'name username profileImage')
      .populate('following', 'name username profileImage');
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }
    // Fetch bags and products if models exist
    let bags = [];
    let products = [];
    try {
      const BeautyBag = require('../models/beautyBag');
      bags = await BeautyBag.find({ user: userId }).select('name color icon');
      // Remove duplicate bag entries by name
      bags = bags.filter((bag, idx) => bags.findIndex(b => b.name === bag.name) === idx);
    } catch (e) {
      console.error('Error fetching bags:', e);
    }
    try {
      const UserProduct = require('../models/userProduct');
      // Fetch products for user with populated product catalog and relationships
      const userProducts = await UserProduct.find({ user: userId })
        .populate('product') // Populate the product catalog reference
        .populate('tags', 'name color')
        .populate('bags', 'name')
        .lean();

      // Transform to match expected structure for profile
      products = userProducts.map(userProduct => ({
        _id: userProduct._id,
        // Use product catalog fields
        productName: userProduct.product?.productName || 'Unknown Product',
        brand: userProduct.product?.brand,
        barcode: userProduct.product?.barcode,
        imageUrl: userProduct.product?.imageData && userProduct.product?.imageMimeType 
          ? `data:${userProduct.product.imageMimeType};base64,${userProduct.product.imageData}`
          : userProduct.product?.imageUrl || '/uploads/defaults/default-placeholder.jpg',
        periodsAfterOpening: userProduct.product?.periodsAfterOpening,
        vegan: userProduct.product?.vegan || false,
        crueltyFree: userProduct.product?.crueltyFree || false,
        // User-specific fields
        favorite: userProduct.favorite || false,
        isFinished: userProduct.isFinished || false,
        purchaseDate: userProduct.purchaseDate,
        openDate: userProduct.openDate,
        tags: userProduct.tags || [],
        bags: userProduct.bags || []
      }));
    } catch (e) {
      console.error('Error fetching products:', e);
    }
    // Attach bags and products to user object
    user = user.toObject();
    user.bags = bags;
    user.products = products;
    res.json({ user });
  } catch (err) {
    console.error('getUserProfile error:', err);
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
        { username: { $regex: q, $options: 'i' } }
      ]
    }).select('name username profileImage');
    res.json({ users });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Create a new beauty bag
exports.createBag = async (req, res) => {
  try {
    const userId = req.params.userId;
    const { name, description = '', color = 'lushyPink', icon = 'bag.fill', image, isPrivate = false } = req.body;
    
    // Validate that userId is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user ID format.' });
    }
    
    const BeautyBag = require('../models/beautyBag');
    
    // Convert userId string to ObjectId for querying
    const userObjectId = new mongoose.Types.ObjectId(userId);
    
    // Prevent duplicate bag names per user
    const existing = await BeautyBag.findOne({ user: userObjectId, name });
    if (existing) {
      return res.status(200).json({ bag: existing });
    }
    
    // Create new bag with proper ObjectId
    const newBag = await BeautyBag.create({ 
      user: userObjectId, 
      name, 
      description,
      color, 
      icon,
      image,
      isPrivate
    });
    
    console.log(`✅ Created beauty bag: ${name} for user ${userId}`);
    res.status(201).json({ bag: newBag });
  } catch (err) {
    console.error('❌ Error creating bag:', err);
    res.status(500).json({ message: 'Failed to create bag.', error: err.message });
  }
};

// Get all beauty bags for a user
exports.getUserBags = async (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Validate that userId is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user ID format.' });
    }
    
    const BeautyBag = require('../models/beautyBag');
    
    // Convert userId string to ObjectId for querying
    const userObjectId = new mongoose.Types.ObjectId(userId);
    
    // Check if this is the owner or another user viewing
    const isOwner = req.user && req.user._id.toString() === userId;
    
    // If not the owner, only return public bags
    const query = { user: userObjectId };
    if (!isOwner) {
      query.isPrivate = { $ne: true };
    }
    
    const bags = await BeautyBag.find(query).select('name description color icon image isPrivate');
    res.json({ bags });
  } catch (err) {
    console.error('❌ Error fetching bags:', err);
    res.status(500).json({ message: 'Failed to fetch bags.', error: err.message });
  }
};

// Update a beauty bag
exports.updateBag = async (req, res) => {
  try {
    const { userId, bagId } = req.params;
    const { name, description, color, icon, image, isPrivate } = req.body;
    
    // Validate that userId and bagId are valid ObjectIds
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user ID format.' });
    }
    if (!mongoose.Types.ObjectId.isValid(bagId)) {
      return res.status(400).json({ message: 'Invalid bag ID format.' });
    }
    
    const BeautyBag = require('../models/beautyBag');
    
    // Convert userId string to ObjectId for querying
    const userObjectId = new mongoose.Types.ObjectId(userId);
    const bagObjectId = new mongoose.Types.ObjectId(bagId);
    
    // Build update object with only provided fields
    const updateFields = {};
    if (name !== undefined) updateFields.name = name;
    if (description !== undefined) updateFields.description = description;
    if (color !== undefined) updateFields.color = color;
    if (icon !== undefined) updateFields.icon = icon;
    if (image !== undefined) updateFields.image = image;
    if (isPrivate !== undefined) updateFields.isPrivate = isPrivate;
    
    const updatedBag = await BeautyBag.findOneAndUpdate(
      { _id: bagObjectId, user: userObjectId },
      updateFields,
      { new: true }
    );
    
    if (!updatedBag) {
      return res.status(404).json({ message: 'Bag not found.' });
    }
    
    console.log(`✅ Updated beauty bag: ${name || updatedBag.name} for user ${userId}`);
    res.json({ message: 'Bag updated successfully.', bag: updatedBag });
  } catch (err) {
    console.error('❌ Error updating bag:', err);
    res.status(500).json({ message: 'Failed to update bag.', error: err.message });
  }
};

// Delete a beauty bag
exports.deleteBag = async (req, res) => {
  try {
    const { userId, bagId } = req.params;
    
    // Validate that userId and bagId are valid ObjectIds
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user ID format.' });
    }
    if (!mongoose.Types.ObjectId.isValid(bagId)) {
      return res.status(400).json({ message: 'Invalid bag ID format.' });
    }
    
    const BeautyBag = require('../models/beautyBag');
    
    // Convert strings to ObjectIds for querying
    const userObjectId = new mongoose.Types.ObjectId(userId);
    const bagObjectId = new mongoose.Types.ObjectId(bagId);
    
    const deleted = await BeautyBag.findOneAndDelete({ _id: bagObjectId, user: userObjectId });
    if (!deleted) {
      return res.status(404).json({ message: 'Bag not found.' });
    }
    
    console.log(`✅ Deleted beauty bag: ${deleted.name} for user ${userId}`);
    res.json({ message: 'Bag deleted successfully.' });
  } catch (err) {
    console.error('❌ Error deleting bag:', err);
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

// Get user settings (region only)
exports.getUserSettings = async (req, res) => {
  try {
    const userId = req.params.userId;
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user id.' });
    }
    const user = await User.findById(userId).select('region');
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({
      settings: {
        region: user.region || 'GLOBAL'
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

    const user = await User.findByIdAndUpdate(userId, { $set: updates }, { new: true });
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({
      settings: {
        region: user.region || 'GLOBAL'
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Update user profile (name, bio, username)
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Authorization: only the authenticated user can update their profile
    if (!req.user || req.user._id.toString() !== userId) {
      return res.status(403).json({ message: 'Not authorized to update this profile.' });
    }

    const { name, bio, username } = req.body;
    const updates = {};

    if (name && name.trim()) {
      updates.name = name.trim();
    }

    if (typeof bio === 'string') {
      updates.bio = bio.trim();
    }

    if (username && username.trim()) {
      const usernameToCheck = username.trim().toLowerCase();
      // Check if username is already taken by another user
      const existingUser = await User.findOne({ 
        username: usernameToCheck, 
        _id: { $ne: userId } 
      });
      if (existingUser) {
        return res.status(400).json({ message: 'Username already taken.' });
      }
      updates.username = usernameToCheck;
    }

    const updatedUser = await User.findByIdAndUpdate(
      userId, 
      { $set: updates }, 
      { new: true, runValidators: true }
    ).select('-password');

    if (!updatedUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    res.json({ 
      message: 'Profile updated successfully.',
      user: updatedUser 
    });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(400).json({ message: 'Username already taken.' });
    }
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Update profile image
exports.updateProfileImage = async (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Authorization: only the authenticated user can update their profile image
    if (!req.user || req.user._id.toString() !== userId) {
      return res.status(403).json({ message: 'Not authorized to update this profile.' });
    }

    if (!req.file) {
      return res.status(400).json({ message: 'No image file provided.' });
    }

    // The upload middleware should handle file storage and provide the file path
    const imageUrl = `/uploads/profiles/${req.file.filename}`;

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { profileImage: imageUrl },
      { new: true }
    ).select('-password');

    if (!updatedUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    res.json({
      message: 'Profile image updated successfully.',
      profileImage: imageUrl,
      user: updatedUser
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Check username availability
exports.checkUsername = async (req, res) => {
  try {
    const { username } = req.params;
    const usernameToCheck = username.toLowerCase().trim();

    if (!usernameToCheck || usernameToCheck.length < 3) {
      return res.status(400).json({ 
        available: false, 
        message: 'Username must be at least 3 characters long.' 
      });
    }

    const existingUser = await User.findOne({ username: usernameToCheck });
    const available = !existingUser;

    res.json({ 
      available,
      message: available ? 'Username is available.' : 'Username is already taken.'
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

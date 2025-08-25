const WishlistItem = require('../models/wishlist');

// Get all wishlist items for a user
exports.getWishlistItems = async (req, res) => {
  try {
    const wishlistItems = await WishlistItem.find({ user: req.params.userId });
    res.status(200).json({
      status: 'success',
      results: wishlistItems.length,
      data: { wishlistItems }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Get a single wishlist item
exports.getWishlistItem = async (req, res) => {
  try {
    const wishlistItem = await WishlistItem.findOne({
      _id: req.params.id,
      user: req.params.userId
    });

    if (!wishlistItem) {
      return res.status(404).json({
        status: 'fail',
        message: 'Wishlist item not found'
      });
    }

    res.status(200).json({
      status: 'success',
      data: { wishlistItem }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Create a new wishlist item
exports.createWishlistItem = async (req, res) => {
  try {
    // Add user ID to wishlist data
    const wishlistItemData = {
      ...req.body,
      user: req.params.userId
    };

    // Validate URL format
    if (wishlistItemData.productURL) {
      try {
        new URL(wishlistItemData.productURL);
      } catch (e) {
        return res.status(400).json({
          status: 'fail',
          message: 'Invalid URL format'
        });
      }
    }

    const newWishlistItem = await WishlistItem.create(wishlistItemData);

    res.status(201).json({
      status: 'success',
      data: { wishlistItem: newWishlistItem }
    });
  } catch (error) {
    res.status(400).json({
      status: 'fail',
      message: error.message
    });
  }
};

// Update a wishlist item
exports.updateWishlistItem = async (req, res) => {
  try {
    // Protect against updating userId
    if (req.body.user) {
      delete req.body.user;
    }

    // Validate URL format if present
    if (req.body.productURL) {
      try {
        new URL(req.body.productURL);
      } catch (e) {
        return res.status(400).json({
          status: 'fail',
          message: 'Invalid URL format'
        });
      }
    }

    const wishlistItem = await WishlistItem.findOneAndUpdate(
      { _id: req.params.id, user: req.params.userId },
      req.body,
      { new: true, runValidators: true }
    );

    if (!wishlistItem) {
      return res.status(404).json({
        status: 'fail',
        message: 'Wishlist item not found'
      });
    }

    res.status(200).json({
      status: 'success',
      data: { wishlistItem }
    });
  } catch (error) {
    res.status(400).json({
      status: 'fail',
      message: error.message
    });
  }
};

// Delete a wishlist item
exports.deleteWishlistItem = async (req, res) => {
  try {
    const mongoose = require('mongoose');
    
    // Validate that the ID is a valid MongoDB ObjectId
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        status: 'fail',
        message: 'Invalid wishlist item ID format'
      });
    }

    const wishlistItem = await WishlistItem.findOneAndDelete({
      _id: req.params.id,
      user: req.params.userId
    });

    if (!wishlistItem) {
      return res.status(404).json({
        status: 'fail',
        message: 'Wishlist item not found'
      });
    }

    res.status(204).json({
      status: 'success',
      data: null
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};
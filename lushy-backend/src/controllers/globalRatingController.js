const GlobalProductRating = require('../models/globalProductRating');

// Add a global rating for a product
exports.addGlobalRating = async (req, res) => {
  try {
    const { userId, productKey } = req.params;
    
    // Validate that the user is the authenticated user
    if (req.user.id !== userId) {
      return res.status(403).json({
        status: 'fail',
        message: 'You can only rate products for yourself'
      });
    }

    // Create the rating (the unique index will prevent duplicates)
    await GlobalProductRating.create({
      productKey: productKey,
      user: userId
    });

    // Get the updated count
    const totalCount = await GlobalProductRating.countDocuments({ productKey: productKey });

    res.status(201).json({
      status: 'success',
      data: {
        totalCount: totalCount
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      // Duplicate key error - user already rated this product
      const totalCount = await GlobalProductRating.countDocuments({ productKey: req.params.productKey });
      return res.status(200).json({
        status: 'success',
        data: {
          totalCount: totalCount
        }
      });
    }
    
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Remove a global rating for a product
exports.removeGlobalRating = async (req, res) => {
  try {
    const { userId, productKey } = req.params;
    
    // Validate that the user is the authenticated user
    if (req.user.id !== userId) {
      return res.status(403).json({
        status: 'fail',
        message: 'You can only remove ratings for yourself'
      });
    }

    // Remove the rating
    await GlobalProductRating.findOneAndDelete({
      productKey: productKey,
      user: userId
    });

    // Get the updated count
    const totalCount = await GlobalProductRating.countDocuments({ productKey: productKey });

    res.status(200).json({
      status: 'success',
      data: {
        totalCount: totalCount
      }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Get global rating info for a product
exports.getGlobalRating = async (req, res) => {
  try {
    const { userId, productKey } = req.params;
    
    // Validate that the user is the authenticated user
    if (req.user.id !== userId) {
      return res.status(403).json({
        status: 'fail',
        message: 'Access denied'
      });
    }

    // Check if the user has rated this product
    const userRating = await GlobalProductRating.findOne({
      productKey: productKey,
      user: userId
    });

    // Get the total count
    const totalCount = await GlobalProductRating.countDocuments({ productKey: productKey });

    res.status(200).json({
      status: 'success',
      data: {
        hasUserRated: !!userRating,
        totalCount: totalCount
      }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};
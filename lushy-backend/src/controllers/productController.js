const UserProduct = require('../models/userProduct');
const Product = require('../models/product');
const User = require('../models/user');
const mongoose = require('mongoose');

// Search products by name across catalog only (since UserProduct no longer stores product data directly)
exports.searchProducts = async (req, res) => {
  try {
    const query = req.query.q || '';
    const regex = new RegExp(query, 'i');
    
    // Check if query looks like a barcode (8-13 digits)
    const isBarcode = /^\d{8,13}$/.test(query.trim());
    
    let searchCriteria;
    if (isBarcode) {
      // If it's a barcode, search by exact barcode match
      searchCriteria = { barcode: query.trim() };
    } else {
      // Otherwise search by name and brand
      searchCriteria = {
        $or: [
          { productName: regex },
          { brand: regex }
        ]
      };
    }
    
    // Search only in product catalog (since UserProduct now references Product)
    const catalogProducts = await Product.find(searchCriteria)
      .limit(25)
      .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree periodsAfterOpening category shade size spf ingredients')
      .lean();

    // Format the results with all detailed information
    const formattedProducts = catalogProducts.map(product => ({
      _id: product._id,
      productName: product.productName,
      brand: product.brand,
      barcode: product.barcode,
      vegan: product.vegan || false,
      crueltyFree: product.crueltyFree || false,
      periodsAfterOpening: product.periodsAfterOpening,
      category: product.category,
      shade: product.shade,
      size: product.size,
      spf: product.spf,
      ingredients: product.ingredients,
      imageUrl: product.imageData && product.imageMimeType 
        ? `data:${product.imageMimeType};base64,${product.imageData}`
        : product.imageUrl || '/uploads/defaults/default-placeholder.jpg'
    }));

    res.status(200).json({ 
      status: 'success', 
      results: formattedProducts.length, 
      data: { products: formattedProducts } 
    });
  } catch (error) {
    console.error('Product search error:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
};

// Get product by barcode - only check catalog since UserProduct no longer stores product data
exports.getProductByBarcode = async (req, res) => {
  try {
    const { barcode } = req.params;
    
    // Check product catalog only
    const product = await Product.findOne({ barcode })
      .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree periodsAfterOpening ingredients size')
      .lean();
    
    if (!product) {
      return res.status(404).json({ 
        status: 'fail', 
        message: 'Product not found' 
      });
    }

    // Format response
    const formattedProduct = {
      _id: product._id,
      productName: product.productName,
      brand: product.brand,
      barcode: product.barcode,
      vegan: product.vegan,
      crueltyFree: product.crueltyFree,
      periodsAfterOpening: product.periodsAfterOpening,
      ingredients: product.ingredients,
      size: product.size,
      imageUrl: product.imageData && product.imageMimeType 
        ? `data:${product.imageMimeType};base64,${product.imageData}`
        : product.imageUrl || '/uploads/defaults/default-placeholder.jpg'
    };

    res.status(200).json({ 
      status: 'success', 
      data: { product: formattedProduct } 
    });
  } catch (error) {
    console.error('Product barcode lookup error:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
};

// Get user product detail by ID (now properly populates product reference)
exports.getProductDetail = async (req, res) => {
  try {
    const id = req.params.productId;
    const userProduct = await UserProduct.findById(id)
      .select('-user -createdAt -updatedAt')
      .populate('product') // Populate the product catalog reference
      .populate('tags', 'name color')
      .populate('bags', 'name')
      .lean();
      
    if (!userProduct) {
      return res.status(404).json({ status: 'fail', message: 'Product not found' });
    }
    
    res.status(200).json({ status: 'success', data: { product: userProduct } });
  } catch (error) {
    console.error('Product detail error:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
};

// Get users who own a specific product by barcode
exports.getUsersWhoOwnProduct = async (req, res) => {
  try {
    const { barcode } = req.params;
    const currentUserId = req.query.currentUserId;
    
    // First, find the product in the catalog
    const product = await Product.findOne({ barcode });
    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }

    // Find all user products that reference this product
    const userProducts = await UserProduct.find({ product: product._id })
      .populate('user', 'name username profileImage')
      .lean();

    // Get unique users and filter out the current user
    const usersMap = new Map();
    userProducts.forEach(userProduct => {
      if (userProduct.user && userProduct.user._id.toString() !== currentUserId) {
        const userId = userProduct.user._id.toString();
        if (!usersMap.has(userId)) {
          usersMap.set(userId, {
            id: userProduct.user._id,
            name: userProduct.user.name,
            username: userProduct.user.username,
            profileImage: userProduct.user.profileImage
          });
        }
      }
    });

    const users = Array.from(usersMap.values());

    // If current user is provided, filter to only show users they follow
    if (currentUserId) {
      try {
        const currentUser = await User.findById(currentUserId).populate('following', '_id');
        if (currentUser) {
          const followingIds = currentUser.following.map(f => f._id.toString());
          const followedUsers = users.filter(user => followingIds.includes(user.id.toString()));
          
          res.status(200).json({
            status: 'success',
            data: {
              product: {
                barcode: product.barcode,
                productName: product.productName,
                brand: product.brand,
                imageUrl: product.imageData && product.imageMimeType 
                  ? `data:${product.imageMimeType};base64,${product.imageData}`
                  : product.imageUrl
              },
              users: followedUsers
            }
          });
          return;
        }
      } catch (err) {
        console.error('Error filtering by following:', err);
      }
    }

    res.status(200).json({
      status: 'success',
      data: {
        product: {
          barcode: product.barcode,
          productName: product.productName,
          brand: product.brand,
          imageUrl: product.imageData && product.imageMimeType 
            ? `data:${product.imageMimeType};base64,${product.imageData}`
            : product.imageUrl
        },
        users: users
      }
    });
  } catch (error) {
    console.error('Get users who own product error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// NEW: Toggle favorite status for a product
exports.toggleProductFavorite = async (req, res) => {
  try {
    const { barcode } = req.params;
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({
        status: 'fail',
        message: 'User ID is required'
      });
    }

    // Find the product by barcode
    const product = await Product.findOne({ barcode });
    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }

    // Toggle favorite status
    const isFavorited = product.toggleFavorite(userId);
    await product.save();

    res.status(200).json({
      status: 'success',
      data: {
        product: {
          barcode: product.barcode,
          productName: product.productName,
          brand: product.brand,
          isFavorited: isFavorited,
          favoriteCount: product.getFavoriteCount()
        }
      }
    });
  } catch (error) {
    console.error('Toggle product favorite error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// NEW: Get favorite status for a product
exports.getProductFavoriteStatus = async (req, res) => {
  try {
    const { barcode } = req.params;
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({
        status: 'fail',
        message: 'User ID is required'
      });
    }

    // Find the product by barcode
    const product = await Product.findOne({ barcode });
    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }

    const isFavorited = product.isFavoritedBy(userId);
    const favoriteCount = product.getFavoriteCount();

    res.status(200).json({
      status: 'success',
      data: {
        barcode: product.barcode,
        isFavorited: isFavorited,
        favoriteCount: favoriteCount
      }
    });
  } catch (error) {
    console.error('Get product favorite status error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// NEW: Get all favorited products for a user
exports.getUserFavoriteProducts = async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({
        status: 'fail',
        message: 'Valid User ID is required'
      });
    }

    // Find all products favorited by this user
    const favoriteProducts = await Product.find({
      favoritedBy: new mongoose.Types.ObjectId(userId)
    }).lean();

    // For each favorited product, find the user's instances
    const userFavoriteProducts = [];
    
    for (const product of favoriteProducts) {
      const userProducts = await UserProduct.find({
        user: new mongoose.Types.ObjectId(userId),
        product: product._id
      }).populate('tags', 'name color').populate('bags', 'name').lean();

      // Take the first instance for display (since all instances share the same favorite status)
      if (userProducts.length > 0) {
        const userProduct = userProducts[0];
        userFavoriteProducts.push({
          _id: userProduct._id,
          product: {
            _id: product._id,
            barcode: product.barcode,
            productName: product.productName,
            brand: product.brand,
            imageUrl: product.imageData && product.imageMimeType 
              ? `data:${product.imageMimeType};base64,${product.imageData}`
              : product.imageUrl || '/uploads/defaults/default-placeholder.jpg',
            vegan: product.vegan,
            crueltyFree: product.crueltyFree,
            favoriteCount: product.favoritedBy.length
          },
          purchaseDate: userProduct.purchaseDate,
          openDate: userProduct.openDate,
          isFinished: userProduct.isFinished,
          tags: userProduct.tags,
          bags: userProduct.bags,
          totalInstances: userProducts.length
        });
      }
    }

    res.status(200).json({
      status: 'success',
      results: userFavoriteProducts.length,
      data: {
        favorites: userFavoriteProducts
      }
    });
  } catch (error) {
    console.error('Get user favorite products error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};
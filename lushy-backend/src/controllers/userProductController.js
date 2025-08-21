const UserProduct = require('../models/userProduct');
const ProductTag = require('../models/productTag');
const BeautyBag = require('../models/beautyBag');
const mongoose = require('mongoose');

// Add PAO taxonomy data directly in the backend
const PAO_TAXONOMY = {
  "3M": "3 months",
  "6M": "6 months", 
  "9M": "9 months",
  "12M": "12 months",
  "18M": "18 months",
  "24M": "24 months",
  "36M": "36 months"
};

// Add function to get region-specific compliance advisories
function getExpiryGuideline(region) {
  const rules = {
    'EU': 'PAO mandatory after opening',
    'US': 'Manufacture date required',
    'JP': 'Both expiry and PAO required'
  };
  return rules[region] || 'Use within 36 months of manufacture';
}

// Helper function to extract months from period string like "12 months"
function extractMonths(periodString) {
  const pattern = /(\d+)\s*[Mm]/;
  const match = periodString.match(pattern);
  
  if (match && match[1]) {
    return parseInt(match[1], 10);
  }
  return null;
}

// Helper function to determine product category from name
function getFallbackCategory(productName) {
  if (!productName) return 'default';
  
  const name = productName.toLowerCase();
  if (name.includes('cream') || name.includes('serum') || name.includes('moistur')) {
    return 'skincare';
  } else if (name.includes('lipstick') || name.includes('foundation') || name.includes('mascara')) {
    return 'makeup';
  } else if (name.includes('shampoo') || name.includes('conditioner') || name.includes('hair')) {
    return 'haircare';
  } else if (name.includes('perfume') || name.includes('fragrance') || name.includes('cologne')) {
    return 'fragrance';
  }
  return 'default';
}

// Helper function to generate a simple placeholder image as base64
function generatePlaceholderImage(category) {
  // Simple 1x1 pixel colored images as base64 for different categories
  const placeholders = {
    'skincare': '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/AB2p',
    'makeup': '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/AB2p',
    'haircare': '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/AB2p',
    'fragrance': '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/AB2p',
    'default': '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/AB2p'
  };
  
  return placeholders[category] || placeholders['default'];
}

// Get all products for a user
exports.getUserProducts = async (req, res) => {
  try {
    const products = await UserProduct.find({ user: new mongoose.Types.ObjectId(req.params.userId) })
       .populate('product') // Populate the product catalog reference
       .populate('tags', 'name color')
       .populate('bags', 'name')
       .lean(); // Use lean for better performance

    // Ensure all fields are present in the response for each product
    const responseProducts = products.map(product => ({
      _id: product._id,
      product: product.product,
      purchaseDate: product.purchaseDate,
      openDate: product.openDate,
      expireDate: product.expireDate,
      favorite: product.favorite || false,
      isFinished: product.isFinished || false,
      finishDate: product.finishDate,
      currentAmount: product.currentAmount || 100.0,
      timesUsed: product.timesUsed || 0,
      tags: product.tags || [],
      bags: product.bags || [],
      quantity: product.quantity || 1,
      comments: product.comments || [],
      reviews: product.reviews || [],
      usageEntries: product.usageEntries || []
    }));

    res.status(200).json({
      status: 'success',
      results: responseProducts.length,
      data: { products: responseProducts }
    });
  } catch (error) {
    console.error('getUserProducts error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Enhance getUserProduct to include compliance info
exports.getUserProduct = async (req, res) => {
  try {
    const product = await UserProduct.findOne({
      _id: req.params.id,
      user: new mongoose.Types.ObjectId(req.params.userId)
    })
      .populate('product') // Populate the product catalog reference
      .populate('tags', 'name color')
      .populate('bags', 'name')
      .lean(); // Use lean for better performance

    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }

    // Format the response to match the iOS app's expected BackendUserProduct structure
    const responseProduct = {
      _id: product._id,
      // Nested product catalog structure that matches BackendProductCatalog
      product: {
        _id: product.product._id,
        barcode: product.product.barcode,
        productName: product.product.productName,
        brand: product.product.brand || null,
        imageUrl: product.product.imageData && product.product.imageMimeType 
          ? `data:${product.product.imageMimeType};base64,${product.product.imageData}`
          : product.product.imageUrl || '/uploads/defaults/default-placeholder.jpg',
        imageData: product.product.imageData || null,
        imageMimeType: product.product.imageMimeType || null,
        periodsAfterOpening: product.product.periodsAfterOpening || null,
        vegan: product.product.vegan || false,
        crueltyFree: product.product.crueltyFree || false,
        category: product.product.category || null,
        shade: product.product.shade || null,
        sizeInMl: product.product.sizeInMl || null,
        spf: product.product.spf || null
      },
      // User-specific fields with proper date formatting
      purchaseDate: product.purchaseDate ? product.purchaseDate.toISOString() : new Date().toISOString(),
      openDate: product.openDate ? product.openDate.toISOString() : null,
      expireDate: product.expireDate ? product.expireDate.toISOString() : null,
      favorite: product.favorite || false,
      isFinished: product.isFinished || false,
      finishDate: product.finishDate ? product.finishDate.toISOString() : null,
      currentAmount: product.currentAmount || 100.0,
      timesUsed: product.timesUsed || 0,
      tags: product.tags || [],
      bags: product.bags || [],
      quantity: product.quantity || 1,
      comments: product.comments || [],
      reviews: product.reviews || [],
      usageEntries: product.usageEntries || []
    };

    res.status(200).json({
      status: 'success',
      data: { 
        product: responseProduct
      }
    });
  } catch (error) {
    console.error('getUserProduct error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Create a new product using the new referential architecture
exports.createUserProduct = async (req, res) => {
  try {
    console.log('Creating product for user:', req.params.userId);
    const rawBody = req.body || {};
    
    // Coerce primitive types from multipart form-data strings
    const coerceNumber = v => (v === undefined || v === null || v === '' ? undefined : (isNaN(v) ? undefined : Number(v)));
    if (rawBody.purchaseDate && /^(\d+)$/.test(rawBody.purchaseDate)) rawBody.purchaseDate = new Date(Number(rawBody.purchaseDate));
    if (rawBody.openDate && /^(\d+)$/.test(rawBody.openDate)) rawBody.openDate = new Date(Number(rawBody.openDate));
    if (rawBody.sizeInMl) rawBody.sizeInMl = coerceNumber(rawBody.sizeInMl);
    if (rawBody.spf) rawBody.spf = coerceNumber(rawBody.spf);
    
    // Separate product catalog data from user-specific data
    const productCatalogData = {
      barcode: rawBody.barcode,
      productName: rawBody.productName,
      brand: rawBody.brand,
      periodsAfterOpening: rawBody.periodsAfterOpening,
      vegan: rawBody.vegan || false,
      crueltyFree: rawBody.crueltyFree || false,
      // Product-specific attributes (different values = different barcodes)
      shade: rawBody.shade,
      sizeInMl: rawBody.sizeInMl,
      spf: rawBody.spf,
      category: rawBody.category || getFallbackCategory(rawBody.productName)
    };
    
    const userProductData = {
      user: new mongoose.Types.ObjectId(req.params.userId),
      purchaseDate: rawBody.purchaseDate || new Date(),
      openDate: rawBody.openDate,
      favorite: rawBody.favorite || false,
      tags: rawBody.tags || [],
      bags: rawBody.bags || []
    };
    
    // Handle image upload - convert to base64 and store in product catalog
    if (req.file) {
      productCatalogData.imageData = req.file.buffer.toString('base64');
      productCatalogData.imageMimeType = req.file.mimetype;
      productCatalogData.imageUrl = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;
    }
    
    // Add fallback image if no image is provided
    if (!productCatalogData.imageData) {
      const fallbackCategory = getFallbackCategory(productCatalogData.productName);
      const placeholderBase64 = generatePlaceholderImage(fallbackCategory);
      productCatalogData.imageData = placeholderBase64;
      productCatalogData.imageMimeType = 'image/jpeg';
      productCatalogData.imageUrl = `data:image/jpeg;base64,${placeholderBase64}`;
    }
    
    console.log('🆕 Creating product with new referential architecture');
    
    // Use the new createWithProduct method that handles product catalog creation and user product linking
    const Product = require('../models/product');
    let newUserProduct;
    
    if (productCatalogData.barcode) {
      // For products with barcodes, use the atomic findOrCreateByBarcode method
      newUserProduct = await UserProduct.createWithProduct(userProductData, productCatalogData);
    } else {
      // For manual entries without barcode, create unique product per user
      const uniqueProductData = {
        ...productCatalogData,
        barcode: `manual_${userProductData.user}_${productCatalogData.productName}_${productCatalogData.brand || ''}`
      };
      newUserProduct = await UserProduct.createWithProduct(userProductData, uniqueProductData);
    }
    
    // Update quantity for similar products (products with same product reference)
    await UserProduct.updateSimilarProductsQuantity(
      newUserProduct.user,
      newUserProduct.product,
      true // increment
    );
    
    // Activity: Product added
    try {
      const Activity = require('../models/activity');
      const User = require('../models/user');
      const user = await User.findById(req.params.userId);
      if (user) {
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'product_added',
          targetId: newUserProduct._id,
          targetType: 'UserProduct',
          description: `Added ${newUserProduct.product.productName} to their collection`,
          imageUrl: newUserProduct.product.imageUrl,
          createdAt: new Date()
        });
      }
    } catch (err) { 
      console.error('Product added activity error:', err); 
    }

    // Handle initial tag and bag associations if provided
    if (rawBody.tags && Array.isArray(rawBody.tags) && rawBody.tags.length) {
      await UserProduct.findByIdAndUpdate(newUserProduct._id, { $addToSet: { tags: { $each: rawBody.tags } } });
    }
    if (rawBody.bags && Array.isArray(rawBody.bags) && rawBody.bags.length) {
      await UserProduct.findByIdAndUpdate(newUserProduct._id, { $addToSet: { bags: { $each: rawBody.bags } } });
    }

    console.log('Product created successfully:', newUserProduct._id);
    
    // Return the newly created product with populated product reference
    const populatedNewProduct = await UserProduct.findById(newUserProduct._id)
      .populate('product')
      .populate('tags', 'name color')
      .populate('bags', 'name');
      
    res.status(201).json({
      status: 'success',
      data: { 
        product: populatedNewProduct,
        action: 'new_product',
        message: 'New product added to your collection.'
      }
    });
  } catch (error) {
    console.error('Product creation error:', error);
    res.status(400).json({
      status: 'fail',
      message: error.message
    });
  }
};

// Update a product
exports.updateUserProduct = async (req, res) => {
  try {
    if (req.body.userId) delete req.body.userId;
    if (req.body.purchaseDate && /^(\d+)$/.test(req.body.purchaseDate)) req.body.purchaseDate = new Date(Number(req.body.purchaseDate));
    if (req.body.openDate && /^(\d+)$/.test(req.body.openDate)) req.body.openDate = new Date(Number(req.body.openDate));
    
    // Get the existing user product first
    const existingUserProduct = await UserProduct.findOne({
      _id: req.params.id,
      user: new mongoose.Types.ObjectId(req.params.userId)
    }).populate('product');

    if (!existingUserProduct) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }
    
    // Handle updates to product-specific fields (shade, sizeInMl, spf)
    const productUpdates = {};
    if (req.body.sizeInMl && /^(\d+\.?\d*)$/.test(req.body.sizeInMl)) {
      productUpdates.sizeInMl = Number(req.body.sizeInMl);
      delete req.body.sizeInMl; // Remove from user product updates
    }
    if (req.body.spf && /^(\d+)$/.test(req.body.spf)) {
      productUpdates.spf = Number(req.body.spf);
      delete req.body.spf; // Remove from user product updates
    }
    if (req.body.shade) {
      productUpdates.shade = req.body.shade;
      delete req.body.shade; // Remove from user product updates
    }
    
    // Update product catalog if there are product-specific field changes
    if (Object.keys(productUpdates).length > 0) {
      const Product = require('../models/product');
      await Product.findByIdAndUpdate(existingUserProduct.product._id, productUpdates);
    }
    
    // Handle image upload - update the product catalog if new image provided
    if (req.file) {
      const Product = require('../models/product');
      await Product.findByIdAndUpdate(existingUserProduct.product._id, {
        imageData: req.file.buffer.toString('base64'),
        imageMimeType: req.file.mimetype,
        imageUrl: `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`
      });
    }

    // Calculate expiry date if openDate is being updated
    if (req.body.openDate) {
      const periodsAfterOpening = existingUserProduct.product.periodsAfterOpening;
      if (periodsAfterOpening) {
        const months = extractMonths(periodsAfterOpening);
        if (months) {
          const openDate = new Date(req.body.openDate);
          req.body.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
        }
      }
    }

    // Handle finish date - update quantity for similar products
    if (req.body.finishDate || req.body.isFinished) {
      if (!existingUserProduct.isFinished) {
        // Update quantity for similar products when a product is finished
        await UserProduct.updateSimilarProductsQuantity(
          existingUserProduct.user,
          existingUserProduct.product,
          false // decrement
        );
      }
    }

    // Handle comment addition
    if (req.body.newComment) {
      const comment = {
        text: req.body.newComment,
        date: new Date()
      };
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $push: { comments: comment } }
      );
      delete req.body.newComment;
    }

    // Handle review addition
    if (req.body.newReview) {
      const { rating, title, text } = req.body.newReview;
      if (typeof rating !== 'number' || !title || !text) {
        return res.status(400).json({ status: 'fail', message: 'Missing review fields' });
      }
      
      const review = {
        rating,
        title,
        text,
        date: new Date()
      };
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $push: { reviews: review } }
      );
      
      // Activity: Review added
      try {
        const Activity = require('../models/activity');
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'review_added',
          targetId: new mongoose.Types.ObjectId(req.params.id),
          targetType: 'UserProduct',
          description: text,
          rating: rating,
          imageUrl: existingUserProduct.product.imageUrl,
          reviewData: {
            title: title,
            text: text,
            rating: rating,
            productName: existingUserProduct.product.productName,
            brand: existingUserProduct.product.brand
          },
          createdAt: new Date()
        });
        console.log('Activity created: review_added for user', req.params.userId);
      } catch (e) {
        console.error('Review activity creation error:', e);
      }
      delete req.body.newReview;
    }

    // Handle bag associations
    if (req.body.addToBagId) {
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $addToSet: { bags: req.body.addToBagId } }
      );
      delete req.body.addToBagId;
    }

    if (req.body.removeFromBagId) {
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $pull: { bags: req.body.removeFromBagId } }
      );
      delete req.body.removeFromBagId;
    }

    // Handle tag associations
    if (req.body.addTagId) {
      const tagId = req.body.addTagId;
      console.log(`Received addTagId ${tagId} for product ${req.params.id}`);
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $addToSet: { tags: tagId } }
      );
      delete req.body.addTagId;
    }
    
    if (req.body.removeTagId) {
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $pull: { tags: req.body.removeTagId } }
      );
      delete req.body.removeTagId;
    }

    // Update and return the product with populated references
    const product = await UserProduct.findOneAndUpdate(
      { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
      req.body,
      { new: true, runValidators: true }
    )
      .populate('product')
      .populate('tags', 'name color')
      .populate('bags', 'name');

    res.status(200).json({
      status: 'success',
      data: { product }
    });
  } catch (error) {
    res.status(400).json({
      status: 'fail',
      message: error.message
    });
  }
};

// Delete a product
exports.deleteUserProduct = async (req, res) => {
  try {
    const product = await UserProduct.findOneAndDelete({
      _id: req.params.id,
      user: new mongoose.Types.ObjectId(req.params.userId)
    });

    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }

    // Cascade delete ALL activities related to this product
    try {
      const Activity = require('../models/activity');
      
      // Delete activities that directly target this product
      const directResult = await Activity.deleteMany({
        user: new mongoose.Types.ObjectId(req.params.userId),
        targetType: 'UserProduct',
        targetId: product._id
      });
      
      // Also delete activities that might reference this product indirectly
      // (like bag activities where the product was mentioned in description)
      const indirectResult = await Activity.deleteMany({
        user: new mongoose.Types.ObjectId(req.params.userId),
        $or: [
          // Activities where targetId matches the product ID regardless of targetType
          { targetId: product._id },
          // Activities that mention the product name in description
          { description: { $regex: product.productName, $options: 'i' } }
        ]
      });
      
      const totalDeleted = directResult.deletedCount + indirectResult.deletedCount;
      console.log(`Deleted product ${product._id} and ${totalDeleted} related activities (${directResult.deletedCount} direct, ${indirectResult.deletedCount} indirect).`);
    } catch (e) {
      console.error('Failed to cascade delete activities for product', product._id, e);
    }

    return res.status(204).json({
      status: 'success',
      data: null
    });
  } catch (error) {
    return res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Add a new endpoint to access the taxonomy
exports.getPAOTaxonomy = async (req, res) => {
  try {
    const taxonomy = PAO_TAXONOMY;
    
    res.status(200).json({
      status: 'success',
      data: { taxonomy }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};
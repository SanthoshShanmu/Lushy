const UserProduct = require('../models/userProduct');
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
       .populate('tags', 'name color')
       .populate('bags', 'name');

    res.status(200).json({
      status: 'success',
      results: products.length,
      data: { products }
    });
  } catch (error) {
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
      .populate('tags', 'name color')
      .populate('bags', 'name');

    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }
    
    // Get user's region from request or user profile
    const userRegion = req.query.region || req.user?.region || 'GLOBAL';
    
    // Add compliance advisory
    const complianceInfo = {
      advisory: getExpiryGuideline(userRegion),
      region: userRegion
    };

    res.status(200).json({
      status: 'success',
      data: { 
        product,
        compliance: complianceInfo
      }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Create a new product
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
    const productData = {
      ...rawBody,
      user: new mongoose.Types.ObjectId(req.params.userId)
    };
    
    // Handle image upload - convert to base64 and store in MongoDB
    if (req.file) {
      productData.imageData = req.file.buffer.toString('base64');
      productData.imageMimeType = req.file.mimetype;
      // Keep imageUrl for backward compatibility but make it a data URL
      productData.imageUrl = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;
    }
    
    console.log('🆕 Creating new product instance');

    // Add fallback image if no image is provided - store as base64
    if (!productData.imageData) {
      // Generate a simple placeholder as base64
      const fallbackCategory = getFallbackCategory(productData.productName);
      const placeholderBase64 = generatePlaceholderImage(fallbackCategory);
      productData.imageData = placeholderBase64;
      productData.imageMimeType = 'image/jpeg';
      productData.imageUrl = `data:image/jpeg;base64,${placeholderBase64}`;
    }

    // Calculate expiry date if open date and periods_after_opening are set
    if (productData.openDate && productData.periodsAfterOpening) {
      const months = extractMonths(productData.periodsAfterOpening);
      if (months) {
        const openDate = new Date(productData.openDate);
        productData.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
      }
    }

    console.log('Product data prepared:', {
      productName: productData.productName,
      user: productData.user
    });

    const newProduct = await UserProduct.create(productData);
    
    // Update quantity for similar products (including the new one)
    if (newProduct.productName && newProduct.brand) {
      await UserProduct.updateSimilarProductsQuantity(
        newProduct.user,
        newProduct.productName,
        newProduct.brand,
        newProduct.sizeInMl,
        true // increment
      );
    }
    
    // Activity: Product added
    try {
      const Activity = require('../models/activity');
      const User = require('../models/user');
      const user = await User.findById(req.params.userId);
      if (user) {
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'product_added',
          targetId: newProduct._id,
          targetType: 'UserProduct',
          description: `Added ${newProduct.productName} to their collection`,
          imageUrl: newProduct.imageUrl, // Include product image for feed display
          createdAt: new Date()
        });
      }
    } catch (err) { console.error('Product added activity error:', err); }

    // Handle initial tag and bag associations if provided
    if (req.body.tags && Array.isArray(req.body.tags) && req.body.tags.length) {
         await UserProduct.findByIdAndUpdate(newProduct._id, { $addToSet: { tags: { $each: req.body.tags } } });
         const Activity = require('../models/activity');
         for (const tagId of req.body.tags) {
             // Create add_tag activity with tag name
             const tag = await require('../models/productTag').findById(tagId);
             await Activity.create({
                 user: new mongoose.Types.ObjectId(req.params.userId),
                 type: 'add_tag',
                 targetId: newProduct._id,
                 targetType: 'UserProduct',
                 description: `Added tag ${tag?.name || tagId} to product ${newProduct.productName}`,
                 createdAt: new Date()
             });
         }
     }
     if (req.body.bags && Array.isArray(req.body.bags) && req.body.bags.length) {
         await UserProduct.findByIdAndUpdate(newProduct._id, { $addToSet: { bags: { $each: req.body.bags } } });
         const Activity = require('../models/activity');
         for (const bagId of req.body.bags) {
            // Create add_to_bag activity with bag name
            const BeautyBag = require('../models/beautyBag');
            const bag = await BeautyBag.findById(bagId);
            await Activity.create({
                user: new mongoose.Types.ObjectId(req.params.userId),
                type: 'add_to_bag',
                targetId: new mongoose.Types.ObjectId(bagId),
                targetType: 'BeautyBag',
                description: `Added product ${newProduct.productName} to bag ${bag?.name || bagId}`,
                createdAt: new Date()
            });
         }
     }

    console.log('Product created successfully:', newProduct._id);
    
    // After associations, return the newly created product
     const populatedNewProduct = await UserProduct.findById(newProduct._id)
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
    if (req.body.sizeInMl && /^(\d+\.?\d*)$/.test(req.body.sizeInMl)) req.body.sizeInMl = Number(req.body.sizeInMl);
    if (req.body.spf && /^(\d+)$/.test(req.body.spf)) req.body.spf = Number(req.body.spf);
    
    // Handle image upload - convert to base64 and store in MongoDB
    if (req.file) {
      req.body.imageData = req.file.buffer.toString('base64');
      req.body.imageMimeType = req.file.mimetype;
      req.body.imageUrl = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;
    }

    // Calculate expiry date if openDate is being updated
    if (req.body.openDate && req.body.periodsAfterOpening) {
      const months = extractMonths(req.body.periodsAfterOpening);
      if (months) {
        const openDate = new Date(req.body.openDate);
        req.body.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
      }
    } else if (req.body.openDate) {
      // Fetch existing product to get periodsAfterOpening
      const existingProduct = await UserProduct.findOne({
        _id: req.params.id,
        user: new mongoose.Types.ObjectId(req.params.userId)
      });
      
      if (existingProduct && existingProduct.periodsAfterOpening) {
        const months = extractMonths(existingProduct.periodsAfterOpening);
        if (months) {
          const openDate = new Date(req.body.openDate);
          req.body.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
        }
      }
    }

    // Toggle favorite status
    if (typeof req.body.favorite === 'boolean') {
      // Find the product
      const product = await UserProduct.findOne({ _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) });
      if (product) {
        // Only create activity if favorite status is actually changing
        if (product.favorite !== req.body.favorite) {
          const Activity = require('../models/activity');
          await Activity.create({
            user: new mongoose.Types.ObjectId(req.params.userId),
            type: req.body.favorite ? 'favorite_product' : 'unfavorite_product',
            targetId: product._id, // already ObjectId
            targetType: 'UserProduct',
            description: `${req.body.favorite ? 'Favorited' : 'Unfavorited'} product: ${product.productName}`,
            createdAt: new Date()
          });
        }
      }
    }

    // Handle openDate activity
    if (req.body.openDate) {
      const product = await UserProduct.findOne({ _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) });
      if (product && (!product.openDate || product.openDate.getTime() !== new Date(req.body.openDate).getTime())) {
        try {
          const Activity = require('../models/activity');
          await Activity.create({
            user: new mongoose.Types.ObjectId(req.params.userId),
            type: 'opened_product',
            targetId: product._id,
            targetType: 'UserProduct',
            description: `Opened product: ${product.productName}`,
            createdAt: new Date()
          });
        } catch (e) {}
      }
    }

    // Handle finish date activity
    if (req.body.finishDate || req.body.isFinished) {
      const product = await UserProduct.findOne({ _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) });
      if (product && !product.isFinished) {
        try {
          const Activity = require('../models/activity');
          await Activity.create({
            user: new mongoose.Types.ObjectId(req.params.userId),
            type: 'finished_product',
            targetId: product._id,
            targetType: 'UserProduct',
            description: `Finished using ${product.productName}`,
            createdAt: new Date()
          });
          console.log('Activity created: finished_product for user', req.params.userId, 'product:', product.productName);
          
          // Update quantity for similar products when a product is finished
          if (product.productName && product.brand) {
            await UserProduct.updateSimilarProductsQuantity(
              product.user,
              product.productName,
              product.brand,
              product.sizeInMl,
              false // decrement
            );
          }
        } catch (e) {
          console.error('Finished product activity creation error:', e);
        }
      }
    }

    // Handle comment or review addition
    if (req.body.newComment) {
      const comment = {
        text: req.body.newComment,
        date: new Date()
      };
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $push: { comments: comment } }
      );
      // Activity: Comment added
      try {
        const Activity = require('../models/activity');
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'comment',
          targetId: new mongoose.Types.ObjectId(req.params.id), // ensure ObjectId
          targetType: 'UserProduct',
          description: `Commented on product`,
          createdAt: new Date()
        });
      } catch (e) {}
      delete req.body.newComment;
    }

    if (req.body.newReview) {
      const { rating, title, text } = req.body.newReview;
      if (typeof rating !== 'number' || !title || !text) {
        return res.status(400).json({ status: 'fail', message: 'Missing review fields' });
      }
      
      // Get the product first for the activity description
      const product = await UserProduct.findOne({ _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) });
      
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
          targetId: new mongoose.Types.ObjectId(req.params.id), // ensure ObjectId
          targetType: 'UserProduct',
          description: text, // Use the actual review text as description
          rating: rating,
          imageUrl: product.imageUrl, // Include product image for feed display
          // Store additional review data in a reviewData field for the frontend to access
          reviewData: {
            title: title,
            text: text,
            rating: rating,
            productName: product.productName,
            brand: product.brand
          },
          createdAt: new Date()
        });
        console.log('Activity created: review_added for user', req.params.userId);
      } catch (e) {
        console.error('Review activity creation error:', e);
      }
      delete req.body.newReview;
    }

    // Handle adding a product to a beauty bag
    if (req.body.addToBagId) {
      // Persist bag association
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $addToSet: { bags: req.body.addToBagId } }
      );
      // Create activity for adding to bag
      try {
        const Activity = require('../models/activity');
        const product = await UserProduct.findById(req.params.id);
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'add_to_bag',
          targetId: new mongoose.Types.ObjectId(req.body.addToBagId),
          targetType: 'BeautyBag',
          description: `Added ${product.productName} to their beauty bag`,
          createdAt: new Date()
        });
        console.log('Activity created: add_to_bag for user', req.params.userId);
      } catch (e) {
        console.error('Add to bag activity creation error:', e);
      }
      delete req.body.addToBagId;
    }

    // Handle removing a product from a beauty bag
    if (req.body.removeFromBagId) {
      const bagId = req.body.removeFromBagId;
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $pull: { bags: bagId } }
      );
      try {
        const Activity = require('../models/activity');
        const BeautyBag = require('../models/beautyBag');
        const product = await UserProduct.findById(req.params.id);
        const bag = await BeautyBag.findById(bagId);
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'remove_from_bag',
          targetId: new mongoose.Types.ObjectId(bagId),
          targetType: 'BeautyBag',
          description: `Removed ${product.productName} from bag ${bag?.name || ''}`.trim(),
          createdAt: new Date()
        });
        console.log('Activity created: remove_from_bag for user', req.params.userId);
      } catch (e) {
        console.error('Remove from bag activity creation error:', e);
      }
      delete req.body.removeFromBagId;
    }

    // Handle tag addition
    if (req.body.addTagId) {
      const tagId = req.body.addTagId;
      console.log(`Received addTagId ${tagId} for product ${req.params.id}`);
      const result = await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $addToSet: { tags: tagId } },
        { new: true }
      );
      console.log(`Post-update tags for product ${req.params.id}:`, result.tags);
       try {
         const Activity = require('../models/activity');
         await Activity.create({
           user: new mongoose.Types.ObjectId(req.params.userId),
           type: 'add_tag',
           targetId: req.params.id,
           targetType: 'UserProduct',
           description: `Added a tag to product`,
           createdAt: new Date()
         });
       } catch (e) {}
      delete req.body.addTagId;
    }
    // Handle tag removal
    if (req.body.removeTagId) {
      const tagId = req.body.removeTagId;
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
        { $pull: { tags: tagId } }
      );
      try {
        const Activity = require('../models/activity');
        await Activity.create({
          user: new mongoose.Types.ObjectId(req.params.userId),
          type: 'remove_tag',
          targetId: req.params.id,
          targetType: 'UserProduct',
          description: `Removed a tag from product`,
          createdAt: new Date()
        });
      } catch (e) {}
      delete req.body.removeTagId;
    }

    // Update and return the product with populated tags and bags
    const product = await UserProduct.findOneAndUpdate(
      { _id: req.params.id, user: new mongoose.Types.ObjectId(req.params.userId) },
      req.body,
      { new: true, runValidators: true }
    )
      .populate('tags', 'name color')
      .populate('bags', 'name');

    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found'
      });
    }

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
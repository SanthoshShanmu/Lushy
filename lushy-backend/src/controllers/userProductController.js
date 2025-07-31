const UserProduct = require('../models/userProduct');
const axios = require('axios');
const mongoose = require('mongoose');

// Helper function to proxy external API calls
async function fetchProductDetails(barcode) {
  try {
    const response = await axios.get(
      `https://world.openbeautyfacts.org/api/v2/product/${barcode}?fields=code,product_name,brands,image_url,image_small_url,periods_after_opening,periods_after_opening_tags,batch_code,manufacturing_date`
    );
    return response.data;
  } catch (error) {
    console.error('Error fetching product from Open Beauty Facts:', error);
    return null;
  }
}

// Helper function to proxy ethics information
async function fetchEthicsInfo(brand) {
  try {
    // Replace with your actual ethics API endpoint
    const response = await axios.get(`https://api.example.com/ethics/${encodeURIComponent(brand)}`);
    return {
      vegan: response.data.vegan || false,
      crueltyFree: response.data.cruelty_free || false
    };
  } catch (error) {
    console.error('Error fetching ethics information:', error);
    return { vegan: false, crueltyFree: false };
  }
}

// Add this new function
async function fetchPAOTaxonomy() {
  try {
    const response = await axios.get(`https://world.openbeautyfacts.org/periods-after-opening.json`);
    return response.data.tags;
  } catch (error) {
    console.error('Error fetching PAO taxonomy:', error);
    return [];
  }
}

// Add this function for batch code decoding
function decodeBatchCode(code) {
  if (!code) return null;
  
  // Common pattern: Year+Julian date (e.g., 2024-180)
  let match = code.match(/(\d{4})[-/]?(\d{3})/);
  if (match) {
    const year = parseInt(match[1]);
    const day = parseInt(match[2]);
    
    // Create date from Julian day
    const date = new Date(year, 0);
    date.setDate(day);
    return { manufactureDate: date };
  }
  
  // Month/year formats (e.g., 0324 for March 2024)
  match = code.match(/^(\d{2})(\d{2})$/);
  if (match) {
    const month = parseInt(match[1]) - 1; // 0-based month
    const year = 2000 + parseInt(match[2]);
    return { manufactureDate: new Date(year, month, 1) };
  }
  
  return null;
}

// Add function to get region-specific compliance advisories
function getExpiryGuideline(region) {
  const rules = {
    'EU': 'PAO mandatory after opening',
    'US': 'Manufacture date required',
    'JP': 'Both expiry and PAO required'
  };
  return rules[region] || 'Use within 36 months of manufacture';
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
    
    // Add user ID to product data
    const productData = {
      ...req.body,
      user: new mongoose.Types.ObjectId(req.params.userId) // Fixed: added 'new'
    };

    // If barcode is provided but no product details, fetch from Open Beauty Facts
    if (productData.barcode && (!productData.productName || !productData.imageUrl)) {
      const externalData = await fetchProductDetails(productData.barcode);
      
      if (externalData && externalData.product) {
        const product = externalData.product;
        
        if (!productData.productName && product.product_name) {
          productData.productName = product.product_name;
        }
        
        if (!productData.imageUrl && product.image_url) {
          productData.imageUrl = product.image_url;
        }
        
        if (!productData.brand && product.brands) {
          productData.brand = product.brands;
        }
        
        if (!productData.periodsAfterOpening && product.periods_after_opening) {
          productData.periodsAfterOpening = product.periods_after_opening;
        }

        // If we have a brand, fetch ethics info
        if (productData.brand && (!productData.hasOwnProperty('vegan') || !productData.hasOwnProperty('crueltyFree'))) {
          const ethicsInfo = await fetchEthicsInfo(productData.brand);
          productData.vegan = ethicsInfo.vegan;
          productData.crueltyFree = ethicsInfo.crueltyFree;
        }
      }
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
    
    // Activity: Product added should be first
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
       data: { product: populatedNewProduct }
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
    // Protect against updating userId
    if (req.body.userId) {
      delete req.body.userId;
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
          description: `Reviewed ${product.productName} and gave it ${rating} stars`,
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

// Add a new endpoint to access the taxonomy
exports.getPAOTaxonomy = async (req, res) => {
  try {
    const taxonomy = await fetchPAOTaxonomy();
    
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

// Helper function to extract months from period string like "12 months"
function extractMonths(periodString) {
  const pattern = /(\\d+)\\s*[Mm]/;
  const match = periodString.match(pattern);
  
  if (match && match[1]) {
    return parseInt(match[1], 10);
  }
  return null;
}
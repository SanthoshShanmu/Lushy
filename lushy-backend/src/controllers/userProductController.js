const UserProduct = require('../models/userProduct');
const axios = require('axios');

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
    const products = await UserProduct.find({ userId: req.params.userId });
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
      userId: req.params.userId
    });

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
    // Add user ID to product data
    const productData = {
      ...req.body,
      userId: req.params.userId
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

    // If no PAO but batch code is available, use fallback
    if (!productData.periodsAfterOpening && externalData?.product?.batch_code) {
      const batchInfo = decodeBatchCode(externalData.product.batch_code);
      if (batchInfo && batchInfo.manufactureDate) {
        // Default to 36 months if no PAO specified
        productData.manufactureDate = batchInfo.manufactureDate;
        
        // Set a generic PAO of 36 months as fallback
        productData.periodsAfterOpening = "36 months";
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

    const newProduct = await UserProduct.create(productData);

    res.status(201).json({
      status: 'success',
      data: { product: newProduct }
    });
  } catch (error) {
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
        userId: req.params.userId
      });
      
      if (existingProduct && existingProduct.periodsAfterOpening) {
        const months = extractMonths(existingProduct.periodsAfterOpening);
        if (months) {
          const openDate = new Date(req.body.openDate);
          req.body.expireDate = new Date(openDate.setMonth(openDate.getMonth() + months));
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
        { _id: req.params.id, userId: req.params.userId },
        { $push: { comments: comment } }
      );
      
      delete req.body.newComment;
    }

    if (req.body.newReview) {
      const review = {
        ...req.body.newReview,
        date: new Date()
      };
      
      await UserProduct.findOneAndUpdate(
        { _id: req.params.id, userId: req.params.userId },
        { $push: { reviews: review } }
      );
      
      delete req.body.newReview;
    }

    const product = await UserProduct.findOneAndUpdate(
      { _id: req.params.id, userId: req.params.userId },
      req.body,
      { new: true, runValidators: true }
    );

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
      userId: req.params.userId
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
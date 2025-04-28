const UserProduct = require('../models/userProduct');
const axios = require('axios');

// Helper function to proxy external API calls
async function fetchProductDetails(barcode) {
  try {
    const response = await axios.get(`https://world.openbeautyfacts.org/api/v2/product/${barcode}.json`);
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

// Get a single product
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

    res.status(200).json({
      status: 'success',
      data: { product }
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

// Helper function to extract months from period string like "12 months"
function extractMonths(periodString) {
  const pattern = /(\\d+)\\s*[Mm]/;
  const match = periodString.match(pattern);
  
  if (match && match[1]) {
    return parseInt(match[1], 10);
  }
  return null;
}
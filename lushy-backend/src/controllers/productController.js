const UserProduct = require('../models/userProduct');
const Product = require('../models/product');
const User = require('../models/user');

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
      .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree')
      .lean();

    // Format the results
    const formattedProducts = catalogProducts.map(product => ({
      _id: product._id,
      productName: product.productName,
      brand: product.brand,
      barcode: product.barcode,
      vegan: product.vegan,
      crueltyFree: product.crueltyFree,
      imageUrl: product.imageData && product.imageMimeType 
        ? `data:${product.imageMimeType};base64,${product.imageData}`
        : product.imageUrl || null
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
      .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree periodsAfterOpening ingredients')
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
      imageUrl: product.imageData && product.imageMimeType 
        ? `data:${product.imageMimeType};base64,${product.imageData}`
        : product.imageUrl || null
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
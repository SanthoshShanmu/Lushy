const UserProduct = require('../models/userProduct');
const Product = require('../models/product');
const User = require('../models/user');

// Search products by name across catalog and user products
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
    
    // Search in both product catalog and user products
    const [catalogProducts, userProducts] = await Promise.all([
      Product.find(searchCriteria)
        .limit(25)
        .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree')
        .lean(),
      UserProduct.find(searchCriteria)
        .limit(25)
        .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree')
        .lean()
    ]);

    // Combine and deduplicate results (prefer catalog over user products)
    const seenBarcodes = new Set();
    const combinedProducts = [];

    // Add catalog products first
    for (const product of catalogProducts) {
      if (product.barcode && !seenBarcodes.has(product.barcode)) {
        seenBarcodes.add(product.barcode);
        combinedProducts.push({
          _id: product._id,
          productName: product.productName,
          brand: product.brand,
          barcode: product.barcode,
          vegan: product.vegan,
          crueltyFree: product.crueltyFree,
          imageUrl: product.imageData && product.imageMimeType 
            ? `data:${product.imageMimeType};base64,${product.imageData}`
            : product.imageUrl || null
        });
      }
    }

    // Add user products that aren't already in catalog
    for (const product of userProducts) {
      if (!product.barcode || !seenBarcodes.has(product.barcode)) {
        if (product.barcode) seenBarcodes.add(product.barcode);
        combinedProducts.push({
          _id: product._id,
          productName: product.productName,
          brand: product.brand,
          barcode: product.barcode,
          vegan: product.vegan,
          crueltyFree: product.crueltyFree,
          imageUrl: product.imageData && product.imageMimeType 
            ? `data:${product.imageMimeType};base64,${product.imageData}`
            : product.imageUrl || null
        });
      }
    }

    res.status(200).json({ 
      status: 'success', 
      results: combinedProducts.length, 
      data: { products: combinedProducts } 
    });
  } catch (error) {
    console.error('Product search error:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
};

// Get product by barcode - prioritize catalog, fallback to user products
exports.getProductByBarcode = async (req, res) => {
  try {
    const { barcode } = req.params;
    
    // First check product catalog
    let product = await Product.findOne({ barcode })
      .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree periodsAfterOpening ingredients')
      .lean();
    
    // If not found in catalog, check user products
    if (!product) {
      product = await UserProduct.findOne({ barcode })
        .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree periodsAfterOpening')
        .lean();
    }
    
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

// Get general product detail by ID
exports.getProductDetail = async (req, res) => {
  try {
    const id = req.params.productId;
    const product = await UserProduct.findById(id)
      .select('-user -createdAt -updatedAt')
      .populate('tags', 'name color')
      .populate('bags', 'name')
      .lean();
    if (!product) {
      return res.status(404).json({ status: 'fail', message: 'Product not found' });
    }
    res.status(200).json({ status: 'success', data: { product } });
  } catch (error) {
    console.error('Product detail error:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
};
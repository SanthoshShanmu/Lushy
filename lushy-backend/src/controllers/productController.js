const UserProduct = require('../models/userProduct');
const User = require('../models/user');

// Search products by name across all users
exports.searchProducts = async (req, res) => {
  try {
    const query = req.query.q || '';
    const regex = new RegExp(query, 'i');
    
    // Check if query looks like a barcode (8-13 digits)
    const isBarcode = /^\d{8,13}$/.test(query.trim());
    
    let searchCriteria;
    if (isBarcode) {
      // If it's a barcode, search by exact barcode match first
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
    
    let products = await UserProduct.find(searchCriteria)
      .limit(50)
      .select('productName brand imageUrl imageData imageMimeType barcode vegan crueltyFree')
      .lean();

    // Convert products to include proper image format
    products = products.map(product => ({
      ...product,
      // If we have base64 image data, create data URL, otherwise use existing imageUrl
      imageUrl: product.imageData && product.imageMimeType 
        ? `data:${product.imageMimeType};base64,${product.imageData}`
        : product.imageUrl || null
    }));

    // Return results from MongoDB only
    res.status(200).json({ status: 'success', results: products.length, data: { products } });
  } catch (error) {
    console.error('Product search error:', error);
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
const UserProduct = require('../models/userProduct');
const axios = require('axios');

// Search products by name across all users
exports.searchProducts = async (req, res) => {
  try {
    const query = req.query.q || '';
    const regex = new RegExp(query, 'i');
    let products = await UserProduct.find({
      $or: [
        { productName: regex },
        { brand: regex }
      ]
    })
      .limit(50)
      .select('productName brand imageUrl barcode')
      .lean();

    if (products.length === 0) {
      // Fallback to OpenBeautyFacts search
      const obUrl = `https://world.openbeautyfacts.org/cgi/search.pl`;
      const obResponse = await axios.get(obUrl, {
          params: {
              search_terms: query,
              search_simple: 1,
              action: 'process',    // ensure JSON output
              json: 1,
              fields: 'code,product_name,brands,image_url,image_small_url',
              page_size: 20
          }
      });
      const obProducts = (obResponse.data.products || []).map(p => ({
        _id: p.code,
        barcode: p.code,
        productName: p.product_name,
        brand: p.brands,
        imageUrl: p.image_small_url || p.image_url
      }));
      return res.status(200).json({ status: 'success', results: obProducts.length, data: { products: obProducts } });
    }

    // Return user products match
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
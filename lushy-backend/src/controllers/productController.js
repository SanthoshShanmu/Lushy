const UserProduct = require('../models/userProduct');
const User = require('../models/user');
const axios = require('axios');

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

// Add OBF contribution endpoint
exports.contributeToOBF = async (req, res) => {
    try {
        const { barcode, productName, brand, category, periodsAfterOpening } = req.body;
        
        // Validate required fields
        if (!productName || !brand) {
            return res.status(400).json({
                status: 'error',
                message: 'Product name and brand are required'
            });
        }
        
        // Get OBF credentials from environment variables
        const obfUserId = process.env.OBF_SYSTEM_USER_ID;
        const obfPassword = process.env.OBF_SYSTEM_PASSWORD;
        
        if (!obfUserId || !obfPassword) {
            return res.status(500).json({
                status: 'error',
                message: 'OBF credentials not configured'
            });
        }
        
        // Prepare OBF contribution data
        const formData = new URLSearchParams({
            user_id: obfUserId,
            password: obfPassword,
            product_name: productName,
            brands: brand,
            categories: category || 'en:beauty',
            periods_after_opening: periodsAfterOpening || '',
            lang: 'en',
            action: 'process'
        });
        
        if (barcode) {
            formData.append('code', barcode);
        }
        
        // Submit to Open Beauty Facts using the correct endpoint
        const obfResponse = await fetch('https://world.openbeautyfacts.org/cgi/product_jqm2.pl', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'Lushy/1.0 (Beauty product tracker; contact: your-email@example.com)'
            },
            body: formData
        });
        
        const responseText = await obfResponse.text();
        console.log('OBF Response Status:', obfResponse.status);
        console.log('OBF Response Headers:', Object.fromEntries(obfResponse.headers.entries()));
        console.log('OBF Response Text:', responseText);
        
        // Check if the response contains success indicators
        const isSuccess = obfResponse.ok && (
            responseText.includes('Product saved') ||
            responseText.includes('Product updated') ||
            responseText.includes('saved successfully') ||
            responseText.includes('"status":1') ||
            responseText.includes('status_verbose":"product saved')
        );
        
        if (isSuccess) {
            // Track successful contribution
            if (req.user) {
                await User.findByIdAndUpdate(req.user.id, {
                    $inc: { 'obf.contributionCount': 1 },
                    $addToSet: { 'obf.contributedProducts': barcode || `generated-${Date.now()}` }
                });
            }
            
            res.json({
                status: 'success',
                message: 'Product contributed to Open Beauty Facts',
                productId: barcode || `generated-${Date.now()}`,
                obfResponse: responseText // Include raw response for debugging
            });
        } else {
            console.log('❌ OBF contribution failed - response does not indicate success');
            res.status(500).json({
                status: 'error',
                message: 'Failed to contribute to Open Beauty Facts - response does not indicate success',
                details: responseText,
                httpStatus: obfResponse.status
            });
        }
        
    } catch (error) {
        console.error('OBF contribution error:', error);
        res.status(500).json({
            status: 'error',
            message: 'Internal server error during OBF contribution'
        });
    }
};
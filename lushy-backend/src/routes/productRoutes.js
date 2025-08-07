const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');

// Search products by name
router.get('/search', productController.searchProducts);

// Get general product detail
router.get('/:productId', productController.getProductDetail);

module.exports = router;
const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');
const auth = require('../middleware/auth');

// Search products by name
router.get('/search', productController.searchProducts);

// Get general product detail
router.get('/:productId', productController.getProductDetail);

// Contribute to Open Beauty Facts (protected route)
router.post('/contribute-obf', auth.authenticate, productController.contributeToOBF);

module.exports = router;
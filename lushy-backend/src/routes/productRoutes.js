const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');

// Search products by name
router.get('/search', productController.searchProducts);

// Get product by barcode
router.get('/barcode/:barcode', productController.getProductByBarcode);

// Get users who own a specific product by barcode
router.get('/barcode/:barcode/users', productController.getUsersWhoOwnProduct);

// Get general product detail
router.get('/:productId', productController.getProductDetail);

module.exports = router;
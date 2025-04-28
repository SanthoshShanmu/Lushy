const express = require('express');
const router = express.Router({ mergeParams: true });
const wishlistController = require('../controllers/wishlistController');
const authMiddleware = require('../middleware/auth');

// Apply authentication middleware to all routes
router.use(authMiddleware.authenticate);

router
  .route('/')
  .get(wishlistController.getWishlistItems)
  .post(wishlistController.createWishlistItem);

router
  .route('/:id')
  .get(wishlistController.getWishlistItem)
  .put(wishlistController.updateWishlistItem)
  .delete(wishlistController.deleteWishlistItem);

module.exports = router;
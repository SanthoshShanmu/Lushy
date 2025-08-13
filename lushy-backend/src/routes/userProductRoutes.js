const express = require('express');
const router = express.Router({ mergeParams: true });
const userProductController = require('../controllers/userProductController');
const authMiddleware = require('../middleware/auth');
const upload = require('../middleware/upload');

// Apply authentication middleware to all routes
router.use(authMiddleware.authenticate);

router
  .route('/')
  .get(userProductController.getUserProducts)
  .post(upload.single('image'), userProductController.createUserProduct);

router
  .route('/:id')
  .get(userProductController.getUserProduct)
  .put(upload.single('image'), userProductController.updateUserProduct)
  .delete(userProductController.deleteUserProduct);

module.exports = router;
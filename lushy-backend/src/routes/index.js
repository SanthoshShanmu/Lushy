const express = require('express');
const userRoutes = require('./userRoutes');
const productRoutes = require('./productRoutes');
const userProductRoutes = require('./userProductRoutes');
const authRoutes = require('./authRoutes');
const activityRoutes = require('./activityRoutes');
const wishlistRoutes = require('./wishlistRoutes');
const notificationRoutes = require('./notificationRoutes');

const router = express.Router();

// Mount all route modules
router.use('/users', userRoutes);
router.use('/users/:userId/products', userProductRoutes); // Add this line to mount user product routes
router.use('/users/:userId/wishlist', wishlistRoutes); // Mount wishlist routes under users path
router.use('/products', productRoutes);
router.use('/auth', authRoutes);
router.use('/activities', activityRoutes);
router.use('/notifications', notificationRoutes);

module.exports = router;
const express = require('express');
const router = express.Router();
const authRoutes = require('./authRoutes');
const userProductRoutes = require('./userProductRoutes');
const wishlistRoutes = require('./wishlistRoutes');
const notificationRoutes = require('./notificationRoutes');
const userRoutes = require('./userRoutes');
const activityRoutes = require('./activityRoutes');
const productRoutes = require('./productRoutes');

// Auth routes (no userId required)
router.use('/auth', authRoutes);

// User-specific routes (nested routes with userId)
router.use('/users/:userId/products', userProductRoutes);
router.use('/users/:userId/wishlist', wishlistRoutes);

// Notification routes
router.use('/notifications', notificationRoutes);

// Activity routes (likes & comments)
router.use('/activities', activityRoutes);

// User routes
router.use('/users', userRoutes);

// Public product endpoints
router.use('/products', productRoutes);

module.exports = router;
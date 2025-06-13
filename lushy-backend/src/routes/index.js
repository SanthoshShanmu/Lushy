const express = require('express');
const router = express.Router();
const authRoutes = require('./authRoutes');
const userProductRoutes = require('./userProductRoutes');
const wishlistRoutes = require('./wishlistRoutes');
const notificationRoutes = require('./notificationRoutes');
const userRoutes = require('./userRoutes');

// Auth routes (no userId required)
router.use('/auth', authRoutes);

// User-specific routes (nested routes with userId)
router.use('/users/:userId/products', userProductRoutes);
router.use('/users/:userId/wishlist', wishlistRoutes);

// User routes
router.use('/users', userRoutes);

// Notification routes
router.use('/notifications', notificationRoutes);

module.exports = router;
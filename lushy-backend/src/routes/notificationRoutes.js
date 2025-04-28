const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const authMiddleware = require('../middleware/auth');

// Apply authentication middleware to all routes
router.use(authMiddleware.authenticate);

router.post('/schedule', notificationController.scheduleNotification);
router.get('/user/:userId', notificationController.getUserNotifications);
router.delete('/:notificationId', notificationController.cancelNotification);

// API proxies - no authentication required for these routes
router.get('/proxy/product/:barcode', notificationController.proxyProductInfo);
router.get('/proxy/ethics/:brand', notificationController.proxyEthicsInfo);

module.exports = router;
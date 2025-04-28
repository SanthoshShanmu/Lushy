const UserProduct = require('../models/userProduct');
const axios = require('axios');
const { schedulePushNotification } = require('../utils/notifications');

// Schedule a notification for product expiry
exports.scheduleNotification = async (req, res) => {
  try {
    const { productId, userId, title, message, scheduledFor } = req.body;

    if (!productId || !userId || !scheduledFor) {
      return res.status(400).json({
        status: 'fail',
        message: 'Missing required fields: productId, userId, scheduledFor'
      });
    }

    // Verify the product exists and belongs to the user
    const product = await UserProduct.findOne({
      _id: productId,
      userId: userId
    });

    if (!product) {
      return res.status(404).json({
        status: 'fail',
        message: 'Product not found or does not belong to user'
      });
    }

    // Default notification values if not provided
    const notificationTitle = title || `${product.productName} is expiring soon!`;
    const notificationMessage = message || 'Your product will expire soon. Consider a replacement.';
    
    // Schedule the push notification
    const notificationId = await schedulePushNotification({
      userId,
      productId,
      title: notificationTitle,
      message: notificationMessage,
      scheduledFor: new Date(scheduledFor)
    });

    res.status(200).json({
      status: 'success',
      data: {
        notificationId,
        scheduled: true,
        scheduledFor
      }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Get all upcoming notifications for a user
exports.getUserNotifications = async (req, res) => {
  try {
    const userId = req.params.userId;

    // Find products with expiry dates in the future
    const expiringProducts = await UserProduct.find({
      userId,
      expireDate: { $exists: true, $ne: null, $gt: new Date() }
    }).sort({ expireDate: 1 });

    // Format the notification data
    const notifications = expiringProducts.map(product => {
      const notificationDate = new Date(product.expireDate);
      notificationDate.setDate(notificationDate.getDate() - 7); // 7 days before expiry
      
      return {
        productId: product._id,
        productName: product.productName,
        expireDate: product.expireDate,
        notificationDate,
        message: `${product.productName} will expire in 7 days`
      };
    });

    res.status(200).json({
      status: 'success',
      results: notifications.length,
      data: { notifications }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// Cancel a scheduled notification
exports.cancelNotification = async (req, res) => {
  try {
    const { notificationId } = req.params;
    
    // Logic to cancel a notification would go here
    // This would depend on your notification implementation (e.g. Firebase, custom solution)
    
    res.status(200).json({
      status: 'success',
      message: 'Notification canceled successfully'
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};

// External API proxy for fetching product info by barcode
exports.proxyProductInfo = async (req, res) => {
  try {
    const { barcode } = req.params;
    
    const response = await axios.get(`https://world.openbeautyfacts.org/api/v2/product/${barcode}.json`);
    
    res.status(200).json(response.data);
  } catch (error) {
    res.status(error.response?.status || 500).json({
      status: 'error',
      message: error.message
    });
  }
};

// External API proxy for ethics info
exports.proxyEthicsInfo = async (req, res) => {
  try {
    const { brand } = req.params;
    
    // This would be replaced with your actual ethics API endpoint
    // For now returning mock data as example
    
    // Mock data for demonstration purposes
    const brandLower = brand.toLowerCase();
    const mockData = {
      vegan: ['lush', 'fenty', 'rare beauty', 'milk makeup'].includes(brandLower),
      cruelty_free: ['lush', 'fenty', 'rare beauty', 'milk makeup', 'glossier'].includes(brandLower)
    };
    
    res.status(200).json(mockData);
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
};
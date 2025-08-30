const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const activityController = require('../controllers/activityController');
const authMiddleware = require('../middleware/auth');
const multer = require('multer');
const path = require('path');

// Configure multer for profile image uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/profiles/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, req.params.userId + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

// Follow a user
router.post('/:userId/follow', userController.followUser);
// Unfollow a user
router.post('/:userId/unfollow', userController.unfollowUser);
// Get user profile (with bags and products)
router.get('/:userId/profile', userController.getUserProfile);
// Update user profile (name, bio, username)
router.patch('/:userId/profile', authMiddleware.authenticate, userController.updateProfile);
// Update profile image
router.post('/:userId/profile/image', authMiddleware.authenticate, upload.single('profileImage'), userController.updateProfileImage);
// Check username availability
router.get('/username/:username/availability', userController.checkUsername);
// Get all beauty bags for a user
router.get('/:userId/bags', userController.getUserBags);
// Create a new beauty bag for the user
router.post('/:userId/bags', userController.createBag);
// Update a beauty bag for the user
router.put('/:userId/bags/:bagId', userController.updateBag);
// Delete a beauty bag for the user
router.delete('/:userId/bags/:bagId', userController.deleteBag);
// Search users
router.get('/search', userController.searchUsers);
// Create activity
router.post('/:userId/activities', activityController.createActivity);
// Get product tags
router.get('/:userId/tags', userController.getUserTags);
// Create a new product tag
router.post('/:userId/tags', userController.createTag);

// User settings endpoints (region only, removed OBF settings)
router.get('/:userId/settings', authMiddleware.authenticate, userController.getUserSettings);
router.patch('/:userId/settings', authMiddleware.authenticate, userController.updateUserSettings);

// Notification preferences endpoints
router.get('/:userId/notification-preferences', authMiddleware.authenticate, require('../controllers/notificationController').getNotificationPreferences);
router.patch('/:userId/notification-preferences', authMiddleware.authenticate, require('../controllers/notificationController').updateNotificationPreferences);

module.exports = router;
const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const activityController = require('../controllers/activityController');
const authMiddleware = require('../middleware/auth');

// Follow a user
router.post('/:userId/follow', userController.followUser);
// Unfollow a user
router.post('/:userId/unfollow', userController.unfollowUser);
// Get user profile (with bags and products)
router.get('/:userId/profile', userController.getUserProfile);
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

module.exports = router;
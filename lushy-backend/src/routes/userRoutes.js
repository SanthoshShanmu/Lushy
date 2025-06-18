const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const activityController = require('../controllers/activityController');

// Follow a user
router.post('/:userId/follow', userController.followUser);
// Unfollow a user
router.post('/:userId/unfollow', userController.unfollowUser);
// Get user profile (with bags and products)
router.get('/:userId/profile', userController.getUserProfile);
// Create a new beauty bag for the user
router.post('/:userId/bags', userController.createBag);
// Delete a beauty bag for the user
router.delete('/:userId/bags/:bagId', userController.deleteBag);
// Search users
router.get('/search', userController.searchUsers);
// Get activity feed for a user
router.get('/:userId/feed', activityController.getUserFeed);
// Create activity
router.post('/:userId/activities', activityController.createActivity);

module.exports = router;
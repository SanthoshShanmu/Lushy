const express = require('express');
const router = express.Router();
const activityController = require('../controllers/activityController');
const authMiddleware = require('../middleware/auth');

// Require authentication for activity interactions
router.use(authMiddleware.authenticate);

// Get activity feed for the authenticated user
router.get('/feed', activityController.getFeed);

// Like an activity
router.post('/:activityId/like', activityController.likeActivity);

// Comment on an activity
router.post('/:activityId/comment', activityController.commentOnActivity);

module.exports = router;
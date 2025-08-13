const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const globalRatingController = require('../controllers/globalRatingController');

// Add a global rating
router.post('/users/:userId/global-ratings/:productKey', auth, globalRatingController.addGlobalRating);

// Remove a global rating
router.delete('/users/:userId/global-ratings/:productKey', auth, globalRatingController.removeGlobalRating);

// Get global rating info
router.get('/users/:userId/global-ratings/:productKey', auth, globalRatingController.getGlobalRating);

module.exports = router;
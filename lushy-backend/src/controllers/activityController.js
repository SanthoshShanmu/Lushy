const Activity = require('../models/activity');
const mongoose = require('mongoose');

// Get activity feed for a user
exports.getUserFeed = async (req, res) => {
  try {
    const userId = req.params.userId;
    console.log('Fetching feed for user:', userId);
    
    const User = require('../models/user');
    const user = await User.findById(userId);
    if (!user) {
      console.log('User not found:', userId);
      return res.status(404).json({ message: 'User not found.' });
    }
    
    console.log('User found:', user.name, 'Following:', user.following?.length || 0);
    
    // Ensure all IDs are ObjectIds
    const feedUserIds = [userId, ...(user.following || [])].map(id => {
      if (typeof id === 'string') return new mongoose.Types.ObjectId(id);
      if (id instanceof mongoose.Types.ObjectId) return id;
      if (id && id._id) return new mongoose.Types.ObjectId(id._id);
      return id;
    });
    
    console.log('Feed user IDs:', feedUserIds);
    
    // Only fetch relevant activity types for the feed
    const relevantActivityTypes = [
      'product_added',
      'review_added',
      'favorite_product',
      'unfavorite_product', 
      'opened_product',
      'finished_product',
      'add_to_bag',
      'bag_created'
    ];
    
    console.log('Searching for activity types:', relevantActivityTypes);
    
    // First, let's check all activities in the database
    const allActivities = await Activity.find({});
    console.log('Total activities in database:', allActivities.length);
    allActivities.forEach(activity => {
      console.log('Activity:', {
        id: activity._id,
        user: activity.user,
        type: activity.type,
        description: activity.description,
        createdAt: activity.createdAt
      });
    });
    
    const activities = await Activity.find({ 
      user: { $in: feedUserIds },
      type: { $in: relevantActivityTypes }
    })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate('user', 'name email');
      
    console.log('Found matching activities:', activities.length);
    activities.forEach(activity => {
      console.log('Matching activity:', {
        id: activity._id,
        user: activity.user?.name,
        type: activity.type,
        description: activity.description
      });
    });
    
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');
    res.set('Surrogate-Control', 'no-store');
    res.json({ feed: activities || [] });
  } catch (err) {
    console.error('Feed error:', err);
    res.status(500).json({ message: 'Server error', error: err.message, stack: err.stack });
  }
};

// Create a new activity
exports.createActivity = async (req, res) => {
  try {
    const userId = req.params.userId;
    const { type, targetId, targetType, description } = req.body;

    // Validate required fields
    if (!type) {
      return res.status(400).json({ message: 'Activity type is required.' });
    }

    // Create the activity
    const activity = await Activity.create({
      user: userId,
      type,
      targetId: targetId || null,
      targetType: targetType || null,
      description: description || null
    });

    // Populate user info before returning
    const populatedActivity = await Activity.findById(activity._id)
      .populate('user', 'name email');

    res.status(201).json({
      status: 'success',
      activity: populatedActivity
    });
  } catch (err) {
    console.error('Create activity error:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

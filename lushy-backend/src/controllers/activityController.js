const Activity = require('../models/activity');
const User = require('../models/user');
const mongoose = require('mongoose');

// Get activity feed for a user
exports.getFeed = async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('Getting feed for user:', userId);
    
    // Get user's following list
    const user = await User.findById(userId).populate('following', '_id');
    if (!user) {
      return res.status(404).json({ status: 'fail', message: 'User not found' });
    }
    
    const followingIds = user.following.map(u => u._id);
    const feedUserIds = [new mongoose.Types.ObjectId(userId), ...followingIds];
    console.log('Feed user IDs:', feedUserIds.map(id => id.toString()));
    
    // Only fetch product_added and review_added activities for the feed
    const relevantActivityTypes = [
      'product_added',
      'review_added'
    ];
    
    console.log('Searching for activity types:', relevantActivityTypes);
    
    const activities = await Activity.find({ 
      user: { $in: feedUserIds },
      type: { $in: relevantActivityTypes }
    })
      .sort({ createdAt: -1 })
      .limit(200) // Fetch more to allow for proper bundling
      .populate('user', 'name email')
      .populate('comments.user', 'name');
      
    console.log('Found matching activities:', activities.length);
    
    // Bundle product_added activities by user and time window (1 hour)
    const bundledActivities = [];
    const processedActivityIds = new Set();
    
    for (const activity of activities) {
      // Skip if already processed
      if (processedActivityIds.has(activity._id.toString())) {
        continue;
      }
      
      if (activity.type === 'product_added') {
        // Find other product_added activities from the same user within 1 hour
        const activityTime = new Date(activity.createdAt);
        const oneHourBefore = new Date(activityTime.getTime() - 60 * 60 * 1000);
        const oneHourAfter = new Date(activityTime.getTime() + 60 * 60 * 1000);
        
        const relatedActivities = activities.filter(a => 
          a.type === 'product_added' &&
          a.user._id.toString() === activity.user._id.toString() &&
          new Date(a.createdAt) >= oneHourBefore &&
          new Date(a.createdAt) <= oneHourAfter &&
          !processedActivityIds.has(a._id.toString())
        );
        
        // Mark all related activities as processed
        relatedActivities.forEach(a => processedActivityIds.add(a._id.toString()));
        
        if (relatedActivities.length > 1) {
          // Create bundled activity
          const bundledActivity = {
            _id: `bundled_${activity._id}`,
            type: 'bundled_product_added',
            user: activity.user,
            description: `Added ${relatedActivities.length} products to their collection`,
            createdAt: activity.createdAt,
            bundledActivities: relatedActivities.map(a => ({
              _id: a._id,
              description: a.description,
              targetId: a.targetId,
              targetType: a.targetType,
              createdAt: a.createdAt,
              imageUrl: a.imageUrl // Include image URL for bundled items
            })),
            liked: false, // Will be computed below
            likes: 0,
            comments: []
          };
          bundledActivities.push(bundledActivity);
        } else {
          // Single activity, add as is
          bundledActivities.push(activity);
        }
      } else {
        // Review activities - add as is
        bundledActivities.push(activity);
        processedActivityIds.add(activity._id.toString());
      }
    }
    
    // Sort bundled activities by creation time and limit to 100
    bundledActivities.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const finalActivities = bundledActivities.slice(0, 100);
    
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');
    res.set('Surrogate-Control', 'no-store');
    
    // Compute liked flag for each activity
    const currentUserId = req.user.id;
    const feedWithLiked = finalActivities.map(act => {
      if (act.type === 'bundled_product_added') {
        // For bundled activities, liked flag is always false for now
        return { ...act, liked: false };
      } else {
        const obj = act.toObject();
        obj.liked = (act.likedBy || []).some(id => id.toString() === currentUserId);
        
        // Also compute liked state for each comment
        if (obj.comments && obj.comments.length > 0) {
          obj.comments = obj.comments.map(comment => ({
            ...comment,
            liked: (comment.likedBy || []).some(id => id.toString() === currentUserId)
          }));
        }
        
        return obj;
      }
    });
    
    // Return response in the format expected by iOS frontend
    res.json({ 
      status: 'success',
      results: feedWithLiked.length,
      data: {
        activities: feedWithLiked || []
      }
    });
  } catch (err) {
    console.error('Feed error:', err);
    res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
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

// Like an activity
exports.likeActivity = async (req, res) => {
  try {
    const activityId = req.params.activityId;
    const userId = req.user.id;
    const activity = await Activity.findById(activityId);
    if (!activity) return res.status(404).json({ message: 'Activity not found' });
    // Toggle like
    const idx = activity.likedBy.findIndex(id => id.toString() === userId);
    let liked;
    if (idx !== -1) {
      activity.likedBy.splice(idx, 1);
      activity.likes = Math.max(0, activity.likes - 1);
      liked = false;
    } else {
      activity.likedBy.push(userId);
      activity.likes = (activity.likes || 0) + 1;
      liked = true;
    }
    await activity.save();
    res.json({ likes: activity.likes, liked });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Add a comment to an activity
exports.commentOnActivity = async (req, res) => {
  try {
    const activityId = req.params.activityId;
    const { text } = req.body;
    if (!text) return res.status(400).json({ message: 'Comment text required' });
    const comment = { user: req.user.id, text, createdAt: new Date() };
    const activity = await Activity.findByIdAndUpdate(
      activityId,
      { $push: { comments: comment } },
      { new: true }
    ).populate('comments.user', 'name');
    if (!activity) return res.status(404).json({ message: 'Activity not found' });
    
    // Compute liked state for each comment for the current user
    const currentUserId = req.user.id;
    const commentsWithLikedState = activity.comments.map(comment => {
      const commentObj = comment.toObject();
      commentObj.liked = (comment.likedBy || []).some(id => id.toString() === currentUserId);
      return commentObj;
    });
    
    res.json({ comments: commentsWithLikedState });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// Like a comment on an activity
exports.likeComment = async (req, res) => {
  try {
    const { activityId, commentId } = req.params;
    const userId = req.user.id;
    
    const activity = await Activity.findById(activityId);
    if (!activity) return res.status(404).json({ message: 'Activity not found' });
    
    const comment = activity.comments.id(commentId);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    
    // Toggle like
    const likedIndex = comment.likedBy.findIndex(id => id.toString() === userId);
    let liked;
    
    if (likedIndex !== -1) {
      // Unlike the comment
      comment.likedBy.splice(likedIndex, 1);
      comment.likes = Math.max(0, comment.likes - 1);
      liked = false;
    } else {
      // Like the comment
      comment.likedBy.push(userId);
      comment.likes = (comment.likes || 0) + 1;
      liked = true;
    }
    
    await activity.save();
    res.json({ likes: comment.likes, liked });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

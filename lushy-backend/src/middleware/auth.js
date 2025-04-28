const jwt = require('jsonwebtoken');
const { promisify } = require('util');
const User = require('../models/user');
const config = require('../config/config');

// Authentication middleware
exports.authenticate = async (req, res, next) => {
  try {
    // 1) Check if token exists in the header
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({
        status: 'fail',
        message: 'Authentication required. Please log in.'
      });
    }

    // 2) Verify the token
    const decoded = await promisify(jwt.verify)(token, config.jwtSecret);

    // 3) Check if user still exists
    const currentUser = await User.findById(decoded.id);
    if (!currentUser) {
      return res.status(401).json({
        status: 'fail',
        message: 'The user for this token no longer exists.'
      });
    }

    // 4) Add user info to request
    req.user = currentUser;
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({
        status: 'fail',
        message: 'Invalid token. Please log in again.'
      });
    } else if (err.name === 'TokenExpiredError') {
      return res.status(401).json({
        status: 'fail',
        message: 'Your session has expired. Please log in again.'
      });
    }

    return res.status(500).json({
      status: 'error',
      message: 'Internal server error'
    });
  }
};

// Authorization middleware - for role-based access
exports.restrictTo = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        status: 'fail',
        message: 'You do not have permission to perform this action'
      });
    }
    next();
  };
};
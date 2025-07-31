const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Initialize express app
const app = express();
const PORT = process.env.PORT || 5000;

// Check if db.js exists and import it correctly
try {
  const { connectDB } = require('./src/config/db');
  connectDB();
} catch (error) {
  console.error("Error connecting to database:", error.message);
  // Continue without database for now
}

// Middleware
app.use(cors());
app.use(helmet());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(morgan('dev'));

// Disable ETag to prevent 304 Not Modified responses
app.disable('etag');

// Rate limiting only on auth routes to avoid 429 on standard API usage
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs on auth
  message: 'Too many requests on auth routes from this IP, please try again after 15 minutes'
});
app.use('/api/auth', authLimiter);

// Health check route
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

// API routes
try {
  const routes = require('./src/routes');
  app.use('/api', routes);
} catch (error) {
  console.error("Error loading routes:", error.message);
  // Add a fallback route
  app.get('/api', (req, res) => {
    res.status(503).json({ status: 'error', message: 'API routes not available' });
  });
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';
  
  res.status(statusCode).json({
    status: 'error',
    message,
    stack: process.env.NODE_ENV === 'production' ? '🥞' : err.stack
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  console.log('UNHANDLED REJECTION! 💥 Shutting down...');
  console.log(err.name, err.message);
  process.exit(1);
});

module.exports = app;
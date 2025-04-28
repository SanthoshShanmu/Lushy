const dotenv = require('dotenv');

dotenv.config();

module.exports = {
  jwtSecret: process.env.JWT_SECRET || 'lushy-super-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  openBeautyFactsApiUrl: 'https://world.openbeautyfacts.org/api/v2',
  crueltyFreeApiUrl: process.env.CRUELTY_FREE_API_URL || 'https://cruelty-free-api.herokuapp.com/api/v1',
  makeupApiUrl: 'http://makeup-api.herokuapp.com/api/v1'
};
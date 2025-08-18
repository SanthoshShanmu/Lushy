const multer = require('multer');
const path = require('path');

// Use memory storage instead of disk storage for base64 conversion
const storage = multer.memoryStorage();

function fileFilter(req, file, cb) {
  if (/^image\//.test(file.mimetype)) cb(null, true); else cb(new Error('Only image uploads allowed'));
}

const upload = multer({ 
  storage, 
  fileFilter, 
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

module.exports = upload;
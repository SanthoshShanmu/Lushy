const { createCanvas } = require('canvas');
const fs = require('fs');
const path = require('path');

const categories = {
  'skincare': { color: '#FFB6C1', icon: '🧴', label: 'Skincare' },
  'makeup': { color: '#DDA0DD', icon: '💄', label: 'Makeup' },
  'haircare': { color: '#98FB98', icon: '🧴', label: 'Hair Care' },
  'fragrance': { color: '#F0E68C', icon: '🌸', label: 'Fragrance' },
  'default': { color: '#E6E6FA', icon: '✨', label: 'Beauty Product' }
};

const canvas = createCanvas(300, 300);
const ctx = canvas.getContext('2d');

Object.entries(categories).forEach(([category, config]) => {
  // Clear canvas
  ctx.clearRect(0, 0, 300, 300);
  
  // Background gradient
  const gradient = ctx.createLinearGradient(0, 0, 300, 300);
  gradient.addColorStop(0, config.color);
  gradient.addColorStop(1, '#FFFFFF');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 300, 300);
  
  // Add soft border
  ctx.strokeStyle = '#CCCCCC';
  ctx.lineWidth = 2;
  ctx.strokeRect(1, 1, 298, 298);
  
  // Add icon (emoji)
  ctx.font = 'bold 80px Arial';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#666666';
  ctx.fillText(config.icon, 150, 140);
  
  // Add label
  ctx.font = 'bold 24px Arial';
  ctx.fillStyle = '#555555';
  ctx.fillText(config.label, 150, 200);
  
  // Add "Lushy" watermark
  ctx.font = '16px Arial';
  ctx.fillStyle = '#999999';
  ctx.fillText('Lushy', 150, 280);
  
  // Save image
  const buffer = canvas.toBuffer('image/jpeg', { quality: 0.8 });
  const filename = `${category}-placeholder.jpg`;
  const filepath = path.join(__dirname, 'uploads', 'defaults', filename);
  
  fs.writeFileSync(filepath, buffer);
  console.log(`Created ${filename}`);
});

console.log('All placeholder images created successfully!');
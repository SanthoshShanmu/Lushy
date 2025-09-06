const XLSX = require('xlsx');
const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config();

// Import the updated Product model (we'll update it first)
const Product = require('./src/models/product');

// Database connection
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/lushy', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('MongoDB connected successfully');
  } catch (error) {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  }
};

// Function to read Excel file
const readExcelFile = (filePath) => {
  try {
    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0]; // Get first sheet
    const worksheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(worksheet);
    
    console.log(`Successfully read ${data.length} rows from Excel file`);
    return data;
  } catch (error) {
    console.error('Error reading Excel file:', error);
    throw error;
  }
};

// Function to clean and validate data
const cleanExcelData = (rawData) => {
  return rawData.map((row, index) => {
    try {
      // Map Excel columns to our schema
      const product = {
        imageUrl: row['Image'] || '',
        brand: row['Brand'] || '',
        barcode: String(row['EAN'] || ''), // Convert to string
        productName: row['Name'] || '',
        size: row['Size'] || '', // This will be our new size field (was sizeInMl)
        shade: row['Shade'] || '',
        spf: row['SPF'] || '', // This will be string now
        category: 'beauty', // Default category
        contributedBy: [{
          source: 'excel_import',
          timestamp: new Date()
        }]
      };

      // Validate required fields
      if (!product.barcode || !product.productName) {
        console.warn(`Row ${index + 1}: Missing required fields (barcode or productName)`);
        return null;
      }

      // Clean barcode - ensure it's a valid string
      if (product.barcode && product.barcode !== 'undefined' && product.barcode !== 'null') {
        product.barcode = String(product.barcode).trim();
      } else {
        console.warn(`Row ${index + 1}: Invalid barcode, skipping`);
        return null;
      }

      return product;
    } catch (error) {
      console.error(`Error processing row ${index + 1}:`, error);
      return null;
    }
  }).filter(product => product !== null);
};

// Function to insert products into database
const insertProducts = async (products) => {
  let successCount = 0;
  let duplicateCount = 0;
  let errorCount = 0;

  console.log(`Starting to insert ${products.length} products...`);

  for (const productData of products) {
    try {
      // Check if product already exists
      const existingProduct = await Product.findOne({ barcode: productData.barcode });
      
      if (existingProduct) {
        console.log(`Product with barcode ${productData.barcode} already exists, skipping...`);
        duplicateCount++;
        continue;
      }

      // Create new product
      const product = new Product(productData);
      await product.save();
      
      successCount++;
      if (successCount % 50 === 0) {
        console.log(`Inserted ${successCount} products so far...`);
      }
    } catch (error) {
      console.error(`Error inserting product ${productData.productName}:`, error.message);
      errorCount++;
    }
  }

  console.log('\n--- Migration Summary ---');
  console.log(`Successfully inserted: ${successCount} products`);
  console.log(`Duplicates skipped: ${duplicateCount} products`);
  console.log(`Errors encountered: ${errorCount} products`);
  console.log(`Total processed: ${products.length} products`);
};

// Main migration function
const runMigration = async () => {
  try {
    console.log('Starting Excel data migration...\n');

    // Connect to database
    await connectDB();

    // Read Excel file - updated path to match actual location
    const excelFilePath = path.join(__dirname, '..', 'data', 'Lushy_data.xlsx');
    console.log(`Reading Excel file from: ${excelFilePath}`);
    
    const rawData = readExcelFile(excelFilePath);
    console.log(`Raw data contains ${rawData.length} rows`);

    // Clean and validate data
    const cleanedProducts = cleanExcelData(rawData);
    console.log(`Cleaned data contains ${cleanedProducts.length} valid products\n`);

    // Show sample of first product for verification
    if (cleanedProducts.length > 0) {
      console.log('Sample product data:');
      console.log(JSON.stringify(cleanedProducts[0], null, 2));
      console.log('\n');
    }

    // Insert products into database
    await insertProducts(cleanedProducts);

    console.log('\nMigration completed successfully!');
    
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await mongoose.connection.close();
    console.log('Database connection closed.');
  }
};

// Run migration if this file is executed directly
if (require.main === module) {
  runMigration();
}

module.exports = { runMigration, readExcelFile, cleanExcelData, insertProducts };
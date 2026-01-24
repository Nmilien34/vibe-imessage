require('dotenv').config();
const mongoose = require('mongoose');
const { ListBucketsCommand } = require('@aws-sdk/client-s3');
const s3Client = require('./src/config/s3');
const connectDB = require('./src/config/db');

async function testConnections() {
    console.log('🚀 Starting connection tests...');

    // 1. Test MongoDB
    console.log('\n--- Testing MongoDB ---');
    try {
        console.log('Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ MongoDB connection successful!');
        console.log(`Connected to host: ${mongoose.connection.host}`);
        await mongoose.disconnect();
    } catch (error) {
        console.error('❌ MongoDB connection failed:');
        console.error(error.message);
    }

    // 2. Test S3
    console.log('\n--- Testing AWS S3 ---');
    try {
        console.log('Fetching S3 buckets...');
        const command = new ListBucketsCommand({});
        const response = await s3Client.send(command);
        console.log('✅ S3 connection successful!');
        console.log('Available buckets:');
        response.Buckets.forEach(bucket => {
            console.log(` - ${bucket.Name}`);
        });
    } catch (error) {
        console.error('❌ S3 connection failed:');
        console.error(error.message);
    }

    console.log('\n--- Tests Complete ---');
    process.exit(0);
}

testConnections();

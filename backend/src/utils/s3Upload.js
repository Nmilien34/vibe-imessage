const { PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { v4: uuidv4 } = require('uuid');
const s3Client = require('../config/s3');

const BUCKET = process.env.AWS_S3_BUCKET;

// Generate a presigned URL for client-side upload
const getUploadUrl = async (fileType, folder = 'vibes') => {
  const key = `${folder}/${uuidv4()}.${fileType}`;

  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ContentType: getContentType(fileType),
  });

  const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
  const publicUrl = `https://${BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

  return { uploadUrl, publicUrl, key };
};

// Delete a file from S3
const deleteFile = async (key) => {
  const command = new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: key,
  });

  await s3Client.send(command);
};

// Helper to get content type
const getContentType = (fileType) => {
  const types = {
    mp4: 'video/mp4',
    mov: 'video/quicktime',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
  };
  return types[fileType.toLowerCase()] || 'application/octet-stream';
};

module.exports = { getUploadUrl, deleteFile };

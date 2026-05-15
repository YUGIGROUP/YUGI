const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const s3Client = new S3Client({
  region: process.env.AWS_S3_REGION,
  credentials: {
    accessKeyId: process.env.AWS_S3_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_S3_SECRET_ACCESS_KEY,
  },
});

const BUCKET = process.env.AWS_S3_BUCKET;

/**
 * Upload a document buffer to S3.
 * Returns { s3Key } on success.
 */
async function uploadDocument({ userId, documentType, fileBuffer, mimeType, originalFileName }) {
  if (!BUCKET) {
    throw new Error('AWS_S3_BUCKET not configured');
  }

  const extension = path.extname(originalFileName) || '';
  const s3Key = `providers/${userId}/${documentType}/${uuidv4()}${extension}`;

  await s3Client.send(new PutObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
    Body: fileBuffer,
    ContentType: mimeType,
    ServerSideEncryption: 'AES256',
  }));

  return { s3Key };
}

/**
 * Generate a time-limited signed URL for admin to view a document.
 * Defaults to 15 minutes — short enough to be safe, long enough to review.
 */
async function getSignedViewUrl(s3Key, expiresInSeconds = 900) {
  if (!BUCKET) {
    throw new Error('AWS_S3_BUCKET not configured');
  }

  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
  });

  return getSignedUrl(s3Client, command, { expiresIn: expiresInSeconds });
}

/**
 * Delete a document from S3 (used when provider deletes pending upload).
 */
async function deleteDocument(s3Key) {
  if (!BUCKET) {
    throw new Error('AWS_S3_BUCKET not configured');
  }

  await s3Client.send(new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
  }));
}

module.exports = {
  uploadDocument,
  getSignedViewUrl,
  deleteDocument,
};

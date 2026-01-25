#!/usr/bin/env node

/**
 * S3 Lifecycle Policy Setup Script
 *
 * This script applies a lifecycle policy to your S3 bucket that automatically
 * deletes media files after 15 days. This serves as a backup to the cleanup job.
 *
 * Run: node scripts/setup-s3-lifecycle.js
 *
 * Requirements:
 * - AWS credentials with s3:PutLifecycleConfiguration permission
 * - AWS_S3_BUCKET, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY env vars
 */

const { S3Client, PutBucketLifecycleConfigurationCommand, GetBucketLifecycleConfigurationCommand } = require('@aws-sdk/client-s3');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const BUCKET = process.env.AWS_S3_BUCKET;
const REGION = process.env.AWS_REGION;

if (!BUCKET || !REGION) {
  console.error('Error: AWS_S3_BUCKET and AWS_REGION environment variables are required');
  process.exit(1);
}

const s3Client = new S3Client({
  region: REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

async function getCurrentPolicy() {
  try {
    const command = new GetBucketLifecycleConfigurationCommand({ Bucket: BUCKET });
    const response = await s3Client.send(command);
    return response.Rules || [];
  } catch (error) {
    if (error.name === 'NoSuchLifecycleConfiguration') {
      return [];
    }
    throw error;
  }
}

async function applyLifecyclePolicy() {
  console.log(`\nSetting up S3 lifecycle policy for bucket: ${BUCKET}\n`);

  // Load policy from JSON file
  const policyPath = path.join(__dirname, '..', 'src', 'config', 's3-lifecycle-policy.json');
  const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));

  // Show current policy
  console.log('Current lifecycle rules:');
  const currentRules = await getCurrentPolicy();
  if (currentRules.length === 0) {
    console.log('  (none)\n');
  } else {
    currentRules.forEach(rule => {
      console.log(`  - ${rule.ID}: ${rule.Status}`);
    });
    console.log('');
  }

  // Apply new policy
  console.log('Applying new lifecycle rules:');
  policy.Rules.forEach(rule => {
    const expiration = rule.Expiration?.Days
      ? `expires after ${rule.Expiration.Days} days`
      : rule.AbortIncompleteMultipartUpload
        ? `abort incomplete uploads after ${rule.AbortIncompleteMultipartUpload.DaysAfterInitiation} day(s)`
        : 'unknown';
    console.log(`  - ${rule.ID} (${rule.Filter.Prefix || 'all'}): ${expiration}`);
  });

  const command = new PutBucketLifecycleConfigurationCommand({
    Bucket: BUCKET,
    LifecycleConfiguration: policy,
  });

  await s3Client.send(command);

  console.log('\n✅ Lifecycle policy applied successfully!\n');
  console.log('Media files will now be automatically deleted by S3 after 15 days.');
  console.log('This is a backup to the cleanup job (src/jobs/cleanupVibes.js).\n');
}

// Run
applyLifecyclePolicy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error applying lifecycle policy:', error.message);
    process.exit(1);
  });

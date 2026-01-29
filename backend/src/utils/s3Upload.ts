import { PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import s3Client from '../config/s3';
import { UploadResult, S3UploadResult } from '../types';

const BUCKET = process.env.AWS_S3_BUCKET || '';

const contentTypes: Record<string, string> = {
  mp4: 'video/mp4',
  mov: 'video/quicktime',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  gif: 'image/gif',
};

export const getContentType = (fileType: string): string => {
  return contentTypes[fileType.toLowerCase()] || 'application/octet-stream';
};

export const getUploadUrl = async (fileType: string, folder: string = 'vibes'): Promise<UploadResult> => {
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

export const deleteFile = async (key: string): Promise<void> => {
  const command = new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: key,
  });

  await s3Client.send(command);
};

export const uploadToS3 = async (
  buffer: Buffer,
  fileType: string,
  folder: string = 'vibes'
): Promise<S3UploadResult> => {
  const key = `${folder}/${uuidv4()}.${fileType}`;
  const contentType = getContentType(fileType);

  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    Body: buffer,
    ContentType: contentType,
  });

  await s3Client.send(command);
  const publicUrl = `https://${BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;

  return { publicUrl, key };
};

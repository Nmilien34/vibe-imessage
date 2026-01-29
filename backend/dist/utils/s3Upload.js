"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.uploadToS3 = exports.deleteFile = exports.getUploadUrl = exports.getContentType = void 0;
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const uuid_1 = require("uuid");
const s3_1 = __importDefault(require("../config/s3"));
const BUCKET = process.env.AWS_S3_BUCKET || '';
const contentTypes = {
    mp4: 'video/mp4',
    mov: 'video/quicktime',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
};
const getContentType = (fileType) => {
    return contentTypes[fileType.toLowerCase()] || 'application/octet-stream';
};
exports.getContentType = getContentType;
const getUploadUrl = async (fileType, folder = 'vibes') => {
    const key = `${folder}/${(0, uuid_1.v4)()}.${fileType}`;
    const command = new client_s3_1.PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        ContentType: (0, exports.getContentType)(fileType),
    });
    const uploadUrl = await (0, s3_request_presigner_1.getSignedUrl)(s3_1.default, command, { expiresIn: 3600 });
    const publicUrl = `https://${BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;
    return { uploadUrl, publicUrl, key };
};
exports.getUploadUrl = getUploadUrl;
const deleteFile = async (key) => {
    const command = new client_s3_1.DeleteObjectCommand({
        Bucket: BUCKET,
        Key: key,
    });
    await s3_1.default.send(command);
};
exports.deleteFile = deleteFile;
const uploadToS3 = async (buffer, fileType, folder = 'vibes') => {
    const key = `${folder}/${(0, uuid_1.v4)()}.${fileType}`;
    const contentType = (0, exports.getContentType)(fileType);
    const command = new client_s3_1.PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        Body: buffer,
        ContentType: contentType,
    });
    await s3_1.default.send(command);
    const publicUrl = `https://${BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;
    return { publicUrl, key };
};
exports.uploadToS3 = uploadToS3;
//# sourceMappingURL=s3Upload.js.map
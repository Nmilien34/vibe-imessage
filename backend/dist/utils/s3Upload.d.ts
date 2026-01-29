import { UploadResult, S3UploadResult } from '../types';
export declare const getContentType: (fileType: string) => string;
export declare const getUploadUrl: (fileType: string, folder?: string) => Promise<UploadResult>;
export declare const deleteFile: (key: string) => Promise<void>;
export declare const uploadToS3: (buffer: Buffer, fileType: string, folder?: string) => Promise<S3UploadResult>;
//# sourceMappingURL=s3Upload.d.ts.map
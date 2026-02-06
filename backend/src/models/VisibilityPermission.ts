import mongoose, { Schema, Model } from 'mongoose';
import { IVisibilityPermission, VisibilitySource } from '../types';

const sources: VisibilitySource[] = ['past_chat', 'contact', 'manual'];

const visibilityPermissionSchema = new Schema<IVisibilityPermission>({
  permissionId: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  visibleToUserId: { type: String, required: true, index: true },
  source: {
    type: String,
    enum: sources,
    required: true,
  },
  grantedAt: { type: Date, default: Date.now },
  revokedAt: { type: Date },
});

// One permission per directed pair
visibilityPermissionSchema.index({ userId: 1, visibleToUserId: 1 }, { unique: true });

const VisibilityPermission: Model<IVisibilityPermission> = mongoose.model<IVisibilityPermission>('VisibilityPermission', visibilityPermissionSchema);

export default VisibilityPermission;

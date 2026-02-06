import mongoose, { Schema, Model } from 'mongoose';
import { IChatMember, MembershipType, MemberRole } from '../types';

const membershipTypes: MembershipType[] = ['full', 'virtual'];
const memberRoles: MemberRole[] = ['admin', 'member'];

const chatMemberSchema = new Schema<IChatMember>({
  memberId: { type: String, required: true, unique: true },
  chatId: { type: String, required: true, index: true },
  userId: { type: String, required: true, index: true },
  membershipType: {
    type: String,
    enum: membershipTypes,
    default: 'full',
  },
  role: {
    type: String,
    enum: memberRoles,
    default: 'member',
  },
  joinedAt: { type: Date, default: Date.now },
});

// One membership record per user per chat
chatMemberSchema.index({ chatId: 1, userId: 1 }, { unique: true });

const ChatMember: Model<IChatMember> = mongoose.model<IChatMember>('ChatMember', chatMemberSchema);

export default ChatMember;

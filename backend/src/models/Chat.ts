import mongoose, { Schema, Model, HydratedDocument } from 'mongoose';
import { IChatDocument, ChatType, ChatSourceType } from '../types';

interface IChatMethods {
  addMember(userId: string): Promise<HydratedDocument<IChatDocument, IChatMethods>>;
  isMember(userId: string): boolean;
  touch(vibeId?: string): Promise<HydratedDocument<IChatDocument, IChatMethods>>;
}

type ChatModel = Model<IChatDocument, {}, IChatMethods>;

const chatTypes: ChatType[] = ['individual', 'group'];
const chatSourceTypes: ChatSourceType[] = ['imessage', 'virtual'];

const chatSchema = new Schema<IChatDocument, ChatModel, IChatMethods>(
  {
    _id: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      default: null,
    },
    members: [
      {
        type: String,
        ref: 'User',
      },
    ],
    lastVibeId: {
      type: String,
      ref: 'Vibe',
      default: null,
    },
    lastActivityAt: {
      type: Date,
      default: Date.now,
    },
    type: {
      type: String,
      enum: chatTypes,
      default: 'group',
    },
    chatType: {
      type: String,
      enum: chatSourceTypes,
      default: 'imessage',
    },
    createdBy: {
      type: String,
      ref: 'User',
    },
  },
  {
    timestamps: true,
    _id: false,
  }
);

chatSchema.index({ members: 1 });
chatSchema.index({ lastActivityAt: -1 });

chatSchema.methods.addMember = async function (userId: string) {
  if (!this.members.includes(userId)) {
    this.members.push(userId);
    await this.save();
  }
  return this;
};

chatSchema.methods.isMember = function (userId: string): boolean {
  return this.members.includes(userId);
};

chatSchema.methods.touch = async function (vibeId?: string) {
  this.lastActivityAt = new Date();
  if (vibeId) {
    this.lastVibeId = vibeId;
  }
  await this.save();
  return this;
};

const Chat = mongoose.model<IChatDocument, ChatModel>('Chat', chatSchema);

export default Chat;

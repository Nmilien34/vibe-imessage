import mongoose, { Schema, Model, HydratedDocument } from 'mongoose';
import { IUserDocument } from '../types';

interface IUserMethods {
  joinChat(chatId: string): Promise<HydratedDocument<IUserDocument, IUserMethods>>;
  leaveChat(chatId: string): Promise<HydratedDocument<IUserDocument, IUserMethods>>;
}

type UserModel = Model<IUserDocument, {}, IUserMethods>;

const userSchema = new Schema<IUserDocument, UserModel, IUserMethods>(
  {
    _id: {
      type: String,
      default: () => `user_${new mongoose.Types.ObjectId().toString()}`,
    },
    appleId: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    appleUUID: {
      type: String,
      index: true,
      sparse: true,
    },
    firstName: { type: String },
    lastName: { type: String },
    email: {
      type: String,
      lowercase: true,
    },
    profilePicture: { type: String },
    birthday: {
      month: { type: Number },
      day: { type: Number },
    },
    joinedChatIds: [
      {
        type: String,
        ref: 'Chat',
      },
    ],
    pushToken: { type: String },
    lastSeen: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
    _id: false,
  }
);

userSchema.index({ joinedChatIds: 1 });

userSchema.methods.joinChat = async function (chatId: string) {
  if (!this.joinedChatIds.includes(chatId)) {
    this.joinedChatIds.push(chatId);
    await this.save();
  }
  return this;
};

userSchema.methods.leaveChat = async function (chatId: string) {
  this.joinedChatIds = this.joinedChatIds.filter((id: string) => id !== chatId);
  await this.save();
  return this;
};

const User = mongoose.model<IUserDocument, UserModel>('User', userSchema);

export default User;

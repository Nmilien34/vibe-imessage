import { v4 as uuidv4 } from 'uuid';
import Chat from '../models/Chat';
import ChatMember from '../models/ChatMember';
import User from '../models/User';
import { MemberRole, MembershipType } from '../types';

interface EnsureChatMembershipParams {
  chatId: string;
  userId: string;
  membershipType?: MembershipType;
  role?: MemberRole;
}

function deriveRole(chatCreatedBy: string | undefined, userId: string, explicitRole?: MemberRole): MemberRole {
  if (explicitRole) return explicitRole;
  return chatCreatedBy === userId ? 'admin' : 'member';
}

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: number }).code === 11000
  );
}

/**
 * Guarantees ChatMember + Chat.members + User.joinedChatIds are in sync.
 * Idempotent and safe to call repeatedly.
 */
export async function ensureChatMembership(params: EnsureChatMembershipParams): Promise<boolean> {
  const { chatId, userId, membershipType = 'full', role } = params;

  const [chat, user] = await Promise.all([
    Chat.findById(chatId),
    User.findById(userId),
  ]);

  if (!chat || !user) {
    return false;
  }

  let chatChanged = false;
  if (!chat.members.includes(userId)) {
    chat.members.push(userId);
    chatChanged = true;
  }

  let userChanged = false;
  if (!user.joinedChatIds.includes(chatId)) {
    user.joinedChatIds.push(chatId);
    userChanged = true;
  }

  const desiredRole = deriveRole(chat.createdBy, userId, role);
  let membership = await ChatMember.findOne({ chatId, userId });

  if (!membership) {
    try {
      await ChatMember.create({
        memberId: `member_${uuidv4()}`,
        chatId,
        userId,
        membershipType,
        role: desiredRole,
        joinedAt: new Date(),
      });
    } catch (error) {
      // Concurrent join/resolve can race on unique(chatId,userId).
      if (!isDuplicateKeyError(error)) {
        throw error;
      }
    }
    membership = await ChatMember.findOne({ chatId, userId });
  } else {
    let membershipChanged = false;

    // Only upgrade, never downgrade (full > virtual, admin > member)
    if (membershipType === 'full' && membership.membershipType !== 'full') {
      membership.membershipType = 'full';
      membershipChanged = true;
    }
    if (desiredRole === 'admin' && membership.role !== 'admin') {
      membership.role = 'admin';
      membershipChanged = true;
    }

    if (membershipChanged) {
      await membership.save();
    }
  }

  await Promise.all([
    chatChanged ? chat.save() : Promise.resolve(),
    userChanged ? user.save() : Promise.resolve(),
  ]);

  return true;
}

/**
 * Repairs membership only when existing data indicates the user already belongs
 * to the chat (via Chat.members or User.joinedChatIds). Returns false if not.
 */
export async function ensureChatMembershipIfKnown(chatId: string, userId: string): Promise<boolean> {
  const existing = await ChatMember.findOne({ chatId, userId });
  if (existing) {
    return true;
  }

  const [chat, user] = await Promise.all([
    Chat.findById(chatId).select('members createdBy'),
    User.findById(userId).select('joinedChatIds'),
  ]);

  if (!chat || !user) {
    return false;
  }

  const hasSignal = chat.members.includes(userId) || user.joinedChatIds.includes(chatId);
  if (!hasSignal) {
    return false;
  }

  return ensureChatMembership({ chatId, userId, membershipType: 'full' });
}

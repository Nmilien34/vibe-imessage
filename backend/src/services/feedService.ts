/**
 * Feed Service - Discovery & Feed Generation
 *
 * Generates personalized feeds based on:
 * 1. Bets from chats user is IN (full access)
 * 2. Bets from past connections (view-only)
 * 3. Bets from approved contacts (view-only)
 */

import Bet from '../models/Bet';
import User from '../models/User';
import ChatMember from '../models/ChatMember';
import UserConnection from '../models/UserConnection';
import VisibilityPermission from '../models/VisibilityPermission';
import { getBetTotals, getBetParticipants } from './betService';

interface FeedBet {
  bet: any;
  accessLevel: 'full' | 'view_only';
  source: 'chat_member' | 'past_connection' | 'contact';
  canBet: boolean;
  totals: any;
  participantCount: number;
}

/**
 * Generate personalized feed for a user
 */
export async function generateFeed(params: {
  userId: string;
  limit?: number;
  offset?: number;
  status?: 'active' | 'completed' | 'expired' | 'ducked';
}): Promise<{
  bets: FeedBet[];
  total: number;
  hasMore: boolean;
}> {
  const { userId, limit = 20, offset = 0, status = 'active' } = params;

  // Get all chat IDs where user is a member (full access)
  const memberships = await ChatMember.find({ userId });
  const memberChatIds = memberships.map(m => m.chatId);

  // Get past connections (users who shared chats with this user)
  const connections = await UserConnection.find({
    $or: [{ userId1: userId }, { userId2: userId }]
  });
  const connectedUserIds = connections.map(c =>
    c.userId1 === userId ? c.userId2 : c.userId1
  );

  // Get contacts who user has granted visibility to (and vice versa)
  const visibilityGrants = await VisibilityPermission.find({
    $or: [
      { userId: userId, revokedAt: null },
      { visibleToUserId: userId, revokedAt: null }
    ]
  });

  // Build set of users who can see this user's bets
  const contactUserIds: string[] = [];
  for (const grant of visibilityGrants) {
    if (grant.userId === userId) {
      // User granted visibility to someone
      contactUserIds.push(grant.visibleToUserId);
    } else {
      // Someone granted visibility to user
      contactUserIds.push(grant.userId);
    }
  }

  // Deduplicate
  const allVisibleUserIds = [...new Set([...connectedUserIds, ...contactUserIds])];

  // Query 1: Bets from chats user is in (full access)
  const memberBets = await Bet.find({
    chatId: { $in: memberChatIds },
    status
  }).sort({ createdAt: -1 });

  // Query 2: Bets from connected/contact users (view only)
  // Only include bets NOT already in member chats
  const viewOnlyBets = await Bet.find({
    creatorId: { $in: allVisibleUserIds },
    chatId: { $nin: memberChatIds },
    status
  }).sort({ createdAt: -1 });

  // Combine and sort by urgency/freshness
  const allBets: FeedBet[] = [];

  // Add member bets (full access)
  for (const bet of memberBets) {
    const totals = await getBetTotals(bet.betId);
    const participants = await getBetParticipants(bet.betId);

    allBets.push({
      bet: {
        betId: bet.betId,
        chatId: bet.chatId,
        creatorId: bet.creatorId,
        betType: bet.betType,
        description: bet.description,
        deadline: bet.deadline,
        targetUserId: bet.targetUserId,
        status: bet.status,
        createdAt: bet.createdAt
      },
      accessLevel: 'full',
      source: 'chat_member',
      canBet: true,
      totals,
      participantCount: participants.length
    });
  }

  // Add view-only bets
  for (const bet of viewOnlyBets) {
    const totals = await getBetTotals(bet.betId);
    const participants = await getBetParticipants(bet.betId);

    // Determine source
    const source = connectedUserIds.includes(bet.creatorId)
      ? 'past_connection'
      : 'contact';

    allBets.push({
      bet: {
        betId: bet.betId,
        chatId: bet.chatId,
        creatorId: bet.creatorId,
        betType: bet.betType,
        description: bet.description,
        deadline: bet.deadline,
        targetUserId: bet.targetUserId,
        status: bet.status,
        createdAt: bet.createdAt
      },
      accessLevel: 'view_only',
      source,
      canBet: false, // Must join chat to bet
      totals,
      participantCount: participants.length
    });
  }

  // Sort by:
  // 1. Urgency (bets ending soon first for active bets)
  // 2. Stakes (high Aura pots)
  // 3. Freshness (recent first)
  allBets.sort((a, b) => {
    // Active bets: sort by deadline (soonest first)
    if (status === 'active') {
      const aDeadline = new Date(a.bet.deadline).getTime();
      const bDeadline = new Date(b.bet.deadline).getTime();

      // Prioritize bets ending within 24 hours
      const now = Date.now();
      const aUrgent = aDeadline - now < 24 * 60 * 60 * 1000;
      const bUrgent = bDeadline - now < 24 * 60 * 60 * 1000;

      if (aUrgent && !bUrgent) return -1;
      if (!aUrgent && bUrgent) return 1;

      // Then by pot size
      if (a.totals.totalPot !== b.totals.totalPot) {
        return b.totals.totalPot - a.totals.totalPot;
      }

      // Then by deadline
      return aDeadline - bDeadline;
    }

    // Completed/expired: sort by creation date (newest first)
    return new Date(b.bet.createdAt).getTime() - new Date(a.bet.createdAt).getTime();
  });

  // Apply pagination
  const total = allBets.length;
  const paginatedBets = allBets.slice(offset, offset + limit);
  const hasMore = offset + limit < total;

  return {
    bets: paginatedBets,
    total,
    hasMore
  };
}

/**
 * Get visibility settings for a user
 */
export async function getVisibilitySettings(userId: string): Promise<{
  pastConnections: Array<{ userId: string; chatId: string; visible: boolean }>;
  contacts: Array<{ userId: string; visible: boolean }>;
}> {
  // Get past connections
  const connections = await UserConnection.find({
    $or: [{ userId1: userId }, { userId2: userId }]
  });

  const pastConnectionSettings = await Promise.all(
    connections.map(async (conn) => {
      const connectedUserId = conn.userId1 === userId ? conn.userId2 : conn.userId1;

      // Check if visibility is granted
      const permission = await VisibilityPermission.findOne({
        userId: userId,
        visibleToUserId: connectedUserId,
        source: 'past_connection',
        revokedAt: null
      });

      return {
        userId: connectedUserId,
        chatId: conn.sourceChatId,
        visible: !!permission
      };
    })
  );

  // Get contact-based permissions
  const contactPermissions = await VisibilityPermission.find({
    userId: userId,
    source: 'contact',
    revokedAt: null
  });

  const contactSettings = contactPermissions.map(p => ({
    userId: p.visibleToUserId,
    visible: true
  }));

  return {
    pastConnections: pastConnectionSettings,
    contacts: contactSettings
  };
}

/**
 * Grant visibility to a user
 */
export async function grantVisibility(params: {
  userId: string;
  visibleToUserId: string;
  source: 'past_connection' | 'contact';
}): Promise<void> {
  const { userId, visibleToUserId, source } = params;

  // Check if already granted
  const existing = await VisibilityPermission.findOne({
    userId,
    visibleToUserId,
    revokedAt: null
  });

  if (existing) {
    // Already granted
    return;
  }

  // Check if was previously revoked
  const revoked = await VisibilityPermission.findOne({
    userId,
    visibleToUserId,
    revokedAt: { $ne: null }
  });

  if (revoked) {
    // Re-grant
    revoked.revokedAt = undefined;
    revoked.grantedAt = new Date();
    await revoked.save();
    return;
  }

  // Create new permission
  const permissionId = `perm_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  await VisibilityPermission.create({
    permissionId,
    userId,
    visibleToUserId,
    source
  });
}

/**
 * Revoke visibility from a user
 */
export async function revokeVisibility(params: {
  userId: string;
  visibleToUserId: string;
}): Promise<void> {
  const { userId, visibleToUserId } = params;

  await VisibilityPermission.updateOne(
    { userId, visibleToUserId, revokedAt: null },
    { $set: { revokedAt: new Date() } }
  );
}

/**
 * Create user connection from shared chat
 */
export async function createConnection(params: {
  userId1: string;
  userId2: string;
  sourceChatId: string;
}): Promise<void> {
  const { userId1, userId2, sourceChatId } = params;

  // Normalize order
  const [user1, user2] = [userId1, userId2].sort();

  // Check if exists
  const existing = await UserConnection.findOne({
    userId1: user1,
    userId2: user2
  });

  if (existing) {
    // Update last interaction
    existing.lastInteraction = new Date();
    await existing.save();
    return;
  }

  // Create new connection
  const connectionId = `conn_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  await UserConnection.create({
    connectionId,
    userId1: user1,
    userId2: user2,
    sourceChatId
  });

  // Auto-grant visibility for past connections
  await grantVisibility({
    userId: user1,
    visibleToUserId: user2,
    source: 'past_connection'
  });

  await grantVisibility({
    userId: user2,
    visibleToUserId: user1,
    source: 'past_connection'
  });
}

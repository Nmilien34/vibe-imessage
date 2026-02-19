import crypto from 'crypto';
import ChatMember from '../models/ChatMember';
import User from '../models/User';
import UserConnection from '../models/UserConnection';
import UserIdentifier from '../models/UserIdentifier';
import VisibilityPermission from '../models/VisibilityPermission';
import { ContactIdentifierKind } from '../types';

const CONTACT_HASH_PATTERN = /^(e|p):[a-f0-9]{64}$/;
const MAX_CONTACT_HASHES = 5000;

interface ParsedContactHash {
  kind: ContactIdentifierKind;
  hash: string;
}

function sha256(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function normalizePhone(phone: string): string {
  const trimmed = phone.trim();
  const digits = trimmed.replace(/[^\d]/g, '');
  if (!digits) return '';
  return trimmed.startsWith('+') ? `+${digits}` : digits;
}

function toContactHash(kind: ContactIdentifierKind, normalizedValue: string): string {
  const prefix = kind === 'email' ? 'e' : 'p';
  return `${prefix}:${sha256(`${kind}:${normalizedValue}`)}`;
}

function parseContactHash(raw: string): ParsedContactHash | null {
  const normalized = raw.trim().toLowerCase();
  if (!CONTACT_HASH_PATTERN.test(normalized)) {
    return null;
  }

  const [prefix, hash] = normalized.split(':');
  if (!prefix || !hash) {
    return null;
  }

  return {
    kind: prefix === 'e' ? 'email' : 'phone',
    hash,
  };
}

async function ensureContactVisibilityGrant(params: {
  userId: string;
  visibleToUserId: string;
}): Promise<'created' | 'restored' | 'existing'> {
  const { userId, visibleToUserId } = params;

  const existing = await VisibilityPermission.findOne({ userId, visibleToUserId });
  if (!existing) {
    await VisibilityPermission.create({
      permissionId: `perm_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
      userId,
      visibleToUserId,
      source: 'contact',
    });
    return 'created';
  }

  if (!existing.revokedAt) {
    return 'existing';
  }

  existing.revokedAt = undefined;
  existing.grantedAt = new Date();
  existing.source = 'contact';
  await existing.save();
  return 'restored';
}

export function hashEmailContact(email: string): string | null {
  const normalized = normalizeEmail(email);
  if (!normalized) return null;
  return toContactHash('email', normalized);
}

export function hashPhoneContact(phone: string): string | null {
  const normalized = normalizePhone(phone);
  if (!normalized) return null;
  return toContactHash('phone', normalized);
}

export async function registerVerifiedEmailIdentifier(params: {
  userId: string;
  email?: string | null;
}): Promise<void> {
  const { userId, email } = params;
  if (!email) {
    return;
  }

  const contactHash = hashEmailContact(email);
  if (!contactHash) {
    return;
  }

  const parsed = parseContactHash(contactHash);
  if (!parsed) {
    return;
  }

  const existing = await UserIdentifier.findOne({
    kind: parsed.kind,
    hash: parsed.hash,
  }).select('userId');

  // Do not overwrite an identifier already claimed by another account.
  if (existing && existing.userId !== userId) {
    return;
  }

  await UserIdentifier.updateOne(
    { userId, kind: parsed.kind, hash: parsed.hash },
    {
      $set: { verifiedAt: new Date() },
      $setOnInsert: {
        userId,
        kind: parsed.kind,
        hash: parsed.hash,
      },
    },
    { upsert: true }
  );
}

export async function getAudienceGraph(params: { userId: string }): Promise<{
  groupUserIds: string[];
  contactUserIds: string[];
  mergedUserIds: string[];
}> {
  const { userId } = params;

  const memberships = await ChatMember.find({ userId }).select('chatId');
  const memberChatIds = memberships.map(m => m.chatId);

  const sharedChatUserIds: string[] = memberChatIds.length > 0
    ? [
      ...new Set(
        (await ChatMember.find({
          chatId: { $in: memberChatIds },
          userId: { $ne: userId },
        }).select('userId')).map(m => m.userId)
      )
    ]
    : [];

  const explicitConnections = await UserConnection.find({
    $or: [{ userId1: userId }, { userId2: userId }]
  }).select('userId1 userId2');

  const connectionUserIds = explicitConnections.map(c =>
    c.userId1 === userId ? c.userId2 : c.userId1
  );

  const groupUserIds = [...new Set([...sharedChatUserIds, ...connectionUserIds])];

  const contactPermissions = await VisibilityPermission.find({
    source: 'contact',
    revokedAt: null,
    $or: [
      { userId },
      { visibleToUserId: userId },
    ],
  }).select('userId visibleToUserId');

  const contactSet = new Set<string>();
  for (const permission of contactPermissions) {
    if (permission.userId === userId) {
      contactSet.add(permission.visibleToUserId);
    } else if (permission.visibleToUserId === userId) {
      contactSet.add(permission.userId);
    }
  }

  contactSet.delete(userId);

  const contactUserIds = [...contactSet];
  const mergedUserIds = [...new Set([...groupUserIds, ...contactUserIds])];

  return {
    groupUserIds,
    contactUserIds,
    mergedUserIds,
  };
}

export async function syncContactNetwork(params: {
  userId: string;
  contactHashes: string[];
  replace?: boolean;
  enableDiscovery?: boolean;
}): Promise<{
  processed: number;
  invalid: number;
  matchedUsers: number;
  grantsCreated: number;
  grantsRestored: number;
  reciprocalGrantsCreated: number;
  reciprocalGrantsRestored: number;
  grantsRevoked: number;
  audienceSize: number;
}> {
  const {
    userId,
    contactHashes,
    replace = true,
    enableDiscovery = true,
  } = params;

  if (contactHashes.length > MAX_CONTACT_HASHES) {
    throw new Error(`Too many contact hashes (max ${MAX_CONTACT_HASHES})`);
  }

  const rawTokens = [...new Set(contactHashes.map(v => v.trim().toLowerCase()).filter(Boolean))];
  const parsedTokens: ParsedContactHash[] = [];
  let invalid = 0;

  for (const token of rawTokens) {
    const parsed = parseContactHash(token);
    if (!parsed) {
      invalid += 1;
      continue;
    }
    parsedTokens.push(parsed);
  }

  await User.updateOne(
    { _id: userId },
    { $set: { contactDiscoveryEnabled: enableDiscovery } }
  );

  if (!enableDiscovery) {
    const revokeResult = await VisibilityPermission.updateMany(
      { userId, source: 'contact', revokedAt: null },
      { $set: { revokedAt: new Date() } }
    );

    const audience = await getAudienceGraph({ userId });
    return {
      processed: parsedTokens.length,
      invalid,
      matchedUsers: 0,
      grantsCreated: 0,
      grantsRestored: 0,
      reciprocalGrantsCreated: 0,
      reciprocalGrantsRestored: 0,
      grantsRevoked: revokeResult.modifiedCount,
      audienceSize: audience.mergedUserIds.length,
    };
  }

  const matchClauses = parsedTokens.map(token => ({ kind: token.kind, hash: token.hash }));
  const matchedIdentifiers = matchClauses.length > 0
    ? await UserIdentifier.find({ $or: matchClauses }).select('userId')
    : [];

  const matchedUserIds = [...new Set(matchedIdentifiers.map(identifier => identifier.userId))]
    .filter(id => id !== userId);

  const matchedUsers = await User.find({ _id: { $in: matchedUserIds } })
    .select('_id contactDiscoveryEnabled');
  const discoverableUsers = new Set(
    matchedUsers
      .filter(user => user.contactDiscoveryEnabled)
      .map(user => user._id as string)
  );

  let grantsCreated = 0;
  let grantsRestored = 0;
  let reciprocalGrantsCreated = 0;
  let reciprocalGrantsRestored = 0;

  for (const matchedUserId of matchedUserIds) {
    const result = await ensureContactVisibilityGrant({
      userId,
      visibleToUserId: matchedUserId,
    });

    if (result === 'created') grantsCreated += 1;
    if (result === 'restored') grantsRestored += 1;

    if (!discoverableUsers.has(matchedUserId)) {
      continue;
    }

    const reciprocalResult = await ensureContactVisibilityGrant({
      userId: matchedUserId,
      visibleToUserId: userId,
    });

    if (reciprocalResult === 'created') reciprocalGrantsCreated += 1;
    if (reciprocalResult === 'restored') reciprocalGrantsRestored += 1;
  }

  let grantsRevoked = 0;
  if (replace) {
    const revokeResult = await VisibilityPermission.updateMany(
      {
        userId,
        source: 'contact',
        revokedAt: null,
        visibleToUserId: { $nin: matchedUserIds },
      },
      { $set: { revokedAt: new Date() } }
    );
    grantsRevoked = revokeResult.modifiedCount;
  }

  const audience = await getAudienceGraph({ userId });

  return {
    processed: parsedTokens.length,
    invalid,
    matchedUsers: matchedUserIds.length,
    grantsCreated,
    grantsRestored,
    reciprocalGrantsCreated,
    reciprocalGrantsRestored,
    grantsRevoked,
    audienceSize: audience.mergedUserIds.length,
  };
}

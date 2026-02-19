"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashEmailContact = hashEmailContact;
exports.hashPhoneContact = hashPhoneContact;
exports.registerVerifiedEmailIdentifier = registerVerifiedEmailIdentifier;
exports.getAudienceGraph = getAudienceGraph;
exports.syncContactNetwork = syncContactNetwork;
const crypto_1 = __importDefault(require("crypto"));
const ChatMember_1 = __importDefault(require("../models/ChatMember"));
const User_1 = __importDefault(require("../models/User"));
const UserConnection_1 = __importDefault(require("../models/UserConnection"));
const UserIdentifier_1 = __importDefault(require("../models/UserIdentifier"));
const VisibilityPermission_1 = __importDefault(require("../models/VisibilityPermission"));
const CONTACT_HASH_PATTERN = /^(e|p):[a-f0-9]{64}$/;
const MAX_CONTACT_HASHES = 5000;
function sha256(value) {
    return crypto_1.default.createHash('sha256').update(value).digest('hex');
}
function normalizeEmail(email) {
    return email.trim().toLowerCase();
}
function normalizePhone(phone) {
    const trimmed = phone.trim();
    const digits = trimmed.replace(/[^\d]/g, '');
    if (!digits)
        return '';
    return trimmed.startsWith('+') ? `+${digits}` : digits;
}
function toContactHash(kind, normalizedValue) {
    const prefix = kind === 'email' ? 'e' : 'p';
    return `${prefix}:${sha256(`${kind}:${normalizedValue}`)}`;
}
function parseContactHash(raw) {
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
async function ensureContactVisibilityGrant(params) {
    const { userId, visibleToUserId } = params;
    const existing = await VisibilityPermission_1.default.findOne({ userId, visibleToUserId });
    if (!existing) {
        await VisibilityPermission_1.default.create({
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
function hashEmailContact(email) {
    const normalized = normalizeEmail(email);
    if (!normalized)
        return null;
    return toContactHash('email', normalized);
}
function hashPhoneContact(phone) {
    const normalized = normalizePhone(phone);
    if (!normalized)
        return null;
    return toContactHash('phone', normalized);
}
async function registerVerifiedEmailIdentifier(params) {
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
    const existing = await UserIdentifier_1.default.findOne({
        kind: parsed.kind,
        hash: parsed.hash,
    }).select('userId');
    // Do not overwrite an identifier already claimed by another account.
    if (existing && existing.userId !== userId) {
        return;
    }
    await UserIdentifier_1.default.updateOne({ userId, kind: parsed.kind, hash: parsed.hash }, {
        $set: { verifiedAt: new Date() },
        $setOnInsert: {
            userId,
            kind: parsed.kind,
            hash: parsed.hash,
        },
    }, { upsert: true });
}
async function getAudienceGraph(params) {
    const { userId } = params;
    const memberships = await ChatMember_1.default.find({ userId }).select('chatId');
    const memberChatIds = memberships.map(m => m.chatId);
    const sharedChatUserIds = memberChatIds.length > 0
        ? [
            ...new Set((await ChatMember_1.default.find({
                chatId: { $in: memberChatIds },
                userId: { $ne: userId },
            }).select('userId')).map(m => m.userId))
        ]
        : [];
    const explicitConnections = await UserConnection_1.default.find({
        $or: [{ userId1: userId }, { userId2: userId }]
    }).select('userId1 userId2');
    const connectionUserIds = explicitConnections.map(c => c.userId1 === userId ? c.userId2 : c.userId1);
    const groupUserIds = [...new Set([...sharedChatUserIds, ...connectionUserIds])];
    const contactPermissions = await VisibilityPermission_1.default.find({
        source: 'contact',
        revokedAt: null,
        $or: [
            { userId },
            { visibleToUserId: userId },
        ],
    }).select('userId visibleToUserId');
    const contactSet = new Set();
    for (const permission of contactPermissions) {
        if (permission.userId === userId) {
            contactSet.add(permission.visibleToUserId);
        }
        else if (permission.visibleToUserId === userId) {
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
async function syncContactNetwork(params) {
    const { userId, contactHashes, replace = true, enableDiscovery = true, } = params;
    if (contactHashes.length > MAX_CONTACT_HASHES) {
        throw new Error(`Too many contact hashes (max ${MAX_CONTACT_HASHES})`);
    }
    const rawTokens = [...new Set(contactHashes.map(v => v.trim().toLowerCase()).filter(Boolean))];
    const parsedTokens = [];
    let invalid = 0;
    for (const token of rawTokens) {
        const parsed = parseContactHash(token);
        if (!parsed) {
            invalid += 1;
            continue;
        }
        parsedTokens.push(parsed);
    }
    await User_1.default.updateOne({ _id: userId }, { $set: { contactDiscoveryEnabled: enableDiscovery } });
    if (!enableDiscovery) {
        const revokeResult = await VisibilityPermission_1.default.updateMany({ userId, source: 'contact', revokedAt: null }, { $set: { revokedAt: new Date() } });
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
        ? await UserIdentifier_1.default.find({ $or: matchClauses }).select('userId')
        : [];
    const matchedUserIds = [...new Set(matchedIdentifiers.map(identifier => identifier.userId))]
        .filter(id => id !== userId);
    const matchedUsers = await User_1.default.find({ _id: { $in: matchedUserIds } })
        .select('_id contactDiscoveryEnabled');
    const discoverableUsers = new Set(matchedUsers
        .filter(user => user.contactDiscoveryEnabled)
        .map(user => user._id));
    let grantsCreated = 0;
    let grantsRestored = 0;
    let reciprocalGrantsCreated = 0;
    let reciprocalGrantsRestored = 0;
    for (const matchedUserId of matchedUserIds) {
        const result = await ensureContactVisibilityGrant({
            userId,
            visibleToUserId: matchedUserId,
        });
        if (result === 'created')
            grantsCreated += 1;
        if (result === 'restored')
            grantsRestored += 1;
        if (!discoverableUsers.has(matchedUserId)) {
            continue;
        }
        const reciprocalResult = await ensureContactVisibilityGrant({
            userId: matchedUserId,
            visibleToUserId: userId,
        });
        if (reciprocalResult === 'created')
            reciprocalGrantsCreated += 1;
        if (reciprocalResult === 'restored')
            reciprocalGrantsRestored += 1;
    }
    let grantsRevoked = 0;
    if (replace) {
        const revokeResult = await VisibilityPermission_1.default.updateMany({
            userId,
            source: 'contact',
            revokedAt: null,
            visibleToUserId: { $nin: matchedUserIds },
        }, { $set: { revokedAt: new Date() } });
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
//# sourceMappingURL=contactNetworkService.js.map
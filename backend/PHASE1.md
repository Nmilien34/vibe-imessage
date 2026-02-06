# Phase 1: Database Schema Extension — Complete

## What was locked (zero changes made)

| File | Why |
|---|---|
| `routes/vibe.ts` / `vibes.ts` | Vibe posting, S3 upload, reactions, polls |
| `routes/feed.ts` | Feed aggregation + stories |
| `routes/group.ts` | Streak read/write |
| `routes/upload.ts` / `reminders.ts` / `vibewire.ts` | Unchanged surface |
| `config/*` / `utils/*` / `jobs/*` | DB, S3, scheduler, cleanup |
| `server.ts` | Route mounting (no new routes added yet) |
| `scripts/seed.ts` | Test data — untouched |

Note: `routes/chat.ts` was originally locked but was later modified to fix the identity split (see [Identity Split Fix](#identity-split-fix) below).

---

## Step 1.1 — Extend `users` Collection

### `models/User.ts` — 10 new schema fields

**Aura Economy:**
| Field | Type | Default | Purpose |
|---|---|---|---|
| `auraBalance` | Number | 1000 | Current spendable balance |
| `lifetimeAuraEarned` | Number | 0 | Running total of all Aura ever received |
| `lifetimeAuraSpent` | Number | 0 | Running total of all Aura ever spent |
| `lastDailyBonus` | Date | null | Timestamp of last +50 daily claim |

**Reputation:**
| Field | Type | Default | Purpose |
|---|---|---|---|
| `vibeScore` | Number | 100 | Reputation — computed from bet stats |
| `betsCreated` | Number | 0 | How many bets this user has started |
| `betsCompleted` | Number | 0 | Bets followed through on |
| `betsFailed` | Number | 0 | Bets ducked/missed |
| `calloutsReceived` | Number | 0 | Times others called this user out |
| `calloutsIgnored` | Number | 0 | Callouts this user ignored |

All fields are optional with schema-level defaults. Mongoose populates them automatically on `new User().save()` — no application code needs to set them explicitly.

### `types/index.ts` — `IUserDocument` extended
All 10 fields added as optional properties, matching the schema defaults.

### `scripts/migrate-add-aura.ts`
Backfills existing users missing the new fields. Uses `updateMany` with a single `$exists: false` filter — one round trip regardless of user count. Idempotent: safe to run repeatedly.

---

## Step 1.2 — New Collections (Betting System)

Seven new models. All follow the project's established pattern: interface in `types/index.ts`, schema + model in the model file, exported from `models/index.ts`.

### `Bet.ts`
The core bet document.

| Field | Notes |
|---|---|
| `betId` | `bet_` + UUID. Application-level ID. |
| `chatId` | Which chat the bet lives in |
| `creatorId` | User who created the bet |
| `betType` | `'self'` / `'callout'` / `'dare'` |
| `description` | "I'm going to the gym today" |
| `deadline` | When the bet expires |
| `status` | `'active'` / `'completed'` / `'expired'` / `'ducked'` |
| `targetUserId` | Only set for callouts/dares |
| `creationCost` | Aura burned to create (default 10) |

### `BetParticipant.ts`
Who is in a bet and on which side.

| Field | Notes |
|---|---|
| `participantId` | `participant_` + UUID |
| `betId` | FK → Bet |
| `userId` | FK → User |
| `side` | `'yes'` or `'no'` |
| `amount` | Aura staked (min 10) |

Compound unique index: `(betId, userId)` — one entry per user per bet.

### `BetProof.ts`
Media evidence that a bet was completed. Reuses the existing S3 upload flow.

| Field | Notes |
|---|---|
| `proofId` | `proof_` + UUID |
| `betId` | FK → Bet |
| `userId` | Who posted the proof |
| `mediaType` | `'photo'` or `'video'` |
| `mediaUrl` / `mediaKey` | S3 location |
| `thumbnailUrl` / `thumbnailKey` | S3 thumbnail |
| `caption` | Optional |

### `BetResolution.ts`
How a bet ended. One resolution per bet (unique on `betId`).

| Field | Notes |
|---|---|
| `resolutionId` | `resolution_` + UUID |
| `betId` | FK → Bet (unique) |
| `outcome` | `'yes'` / `'no'` / `'expired'` / `'ducked'` |
| `resolvedBy` | userId or `'system'` |
| `resolvedAt` | When it was resolved |
| `notes` | Optional context |

No `timestamps` on this schema — `resolvedAt` is the only date field.

### `AuraTransaction.ts`
Append-only ledger. Every Aura movement in or out gets a row here.

| Field | Notes |
|---|---|
| `transactionId` | `txn_` + UUID |
| `userId` | FK → User |
| `amount` | Positive = earned, negative = spent |
| `balanceAfter` | Snapshot of balance after this transaction |
| `transactionType` | `string` — no enum constraint (see design decisions) |
| `referenceId` | betId or teaId if applicable |
| `description` | Human-readable label |

### `TeaSpill.ts`
The "Someone in this chat..." guessing game.

| Field | Notes |
|---|---|
| `teaId` | `tea_` + UUID |
| `chatId` | Which chat |
| `creatorId` | Who made it |
| `mysteryText` | The clue shown to guessers |
| `answer` | Revealed when status → `'revealed'` |
| `options` | Array of names to guess from |
| `deadline` | Auto-expires if not revealed |
| `status` | `'active'` / `'revealed'` / `'expired'` |
| `creationCost` | Aura burned to create (default 10) |
| `creatorBonusPercent` | Creator's cut of the pot (default 10%) |

### `TeaGuess.ts`
One guess per user per tea spill.

| Field | Notes |
|---|---|
| `guessId` | `guess_` + UUID |
| `teaId` | FK → TeaSpill |
| `userId` | FK → User |
| `guess` | Which option they picked |
| `amount` | Aura staked (min 10) |

Compound unique index: `(teaId, userId)`.

---

## Step 1.3 — Extend `chats` Collection + ChatMember

### `models/Chat.ts` — 1 new field
`chatType: 'imessage' | 'virtual'` (default `'imessage'`).

This is orthogonal to the existing `type` field:
- `type` = group structure (`'individual'` / `'group'`)
- `chatType` = how the chat was sourced (`'imessage'` / `'virtual'`)

Two fields the spec listed as new already existed:
- `name` → already `title`
- `createdBy` → already present

### `models/ChatMember.ts` (new)
Granular membership tracking. Replaces relying solely on the `chat.members` string array.

| Field | Notes |
|---|---|
| `memberId` | `member_` + UUID |
| `chatId` | FK → Chat |
| `userId` | FK → User |
| `membershipType` | `'full'` (in iMessage) / `'virtual'` (backend only) |
| `role` | `'admin'` / `'member'` |
| `joinedAt` | When they entered |

Compound unique index: `(chatId, userId)`.

### `scripts/migrate-chat-members.ts`
Reads every User, iterates `user.joinedChatIds`, creates a ChatMember doc for each. Loads Chat docs in a separate pass to build a `chatId → createdBy` map — creator gets `role: 'admin'`, everyone else `'member'`. Idempotent via compound unique index `(chatId, userId)` + code 11000 skip.

**Why `joinedChatIds`, not `chat.members`:** Membership in this codebase is tracked user → chat (`user.joinedChatIds`), not chat → users (`chat.members`). The `chat.members` array exists on the schema but is not the populated side of the relationship in production data. The original migration iterated `chat.members` and produced 0 records against 22 chats — this was the bug.

---

## Step 1.4 — Discovery System Collections

### `models/UserConnection.ts`
The friendship/connection graph. Every pair of users who share a chat gets one record.

| Field | Notes |
|---|---|
| `connectionId` | `conn_` + UUID |
| `userId1` | Always the lexicographically smaller ID |
| `userId2` | Always the larger ID |
| `sourceChatId` | Which chat created this connection |
| `establishedAt` | When they first shared a chat |
| `lastInteraction` | Updated on future shared activity |

Compound unique index: `(userId1, userId2)`. The sort-order enforcement on IDs prevents duplicate pairs (A↔B stored once, not twice).

### `models/VisibilityPermission.ts`
Controls who can see whose vibes in discovery/feed contexts. Directional — each direction is a separate record. This allows asymmetric revocation (A can see B, but B can't see A).

| Field | Notes |
|---|---|
| `permissionId` | `perm_` + UUID |
| `userId` | Whose vibes are visible |
| `visibleToUserId` | Who can see them |
| `source` | `'past_chat'` / `'contact'` / `'manual'` |
| `grantedAt` | When permission was created |
| `revokedAt` | Set when revoked (soft delete) |

Compound unique index: `(userId, visibleToUserId)`.

### `models/JoinRequest.ts`
A user requests access to a chat they're not in.

| Field | Notes |
|---|---|
| `requestId` | `request_` + UUID |
| `chatId` | Target chat |
| `userId` | Who's requesting |
| `reason` | Optional message |
| `contextBetId` | If they're joining specifically to bet |
| `status` | `'pending'` / `'approved'` / `'denied'` / `'expired'` |
| `resolvedAt` | When a decision was made |

Has `timestamps` (createdAt/updatedAt).

### `models/JoinRequestVote.ts`
Existing chat members vote on a join request.

| Field | Notes |
|---|---|
| `voteId` | `vote_` + UUID |
| `requestId` | FK → JoinRequest |
| `voterId` | Which member voted |
| `decision` | `'approve'` / `'deny'` |
| `votedAt` | When they voted |

Compound unique index: `(requestId, voterId)` — one vote per member per request.

### Migration scripts
- `build-connection-graph.ts` — Groups ChatMembers by chat, generates all user pairs, writes UserConnections
- `init-visibility.ts` — For every UserConnection, writes two VisibilityPermissions (one each direction)

Both are idempotent via compound unique indexes + code 11000 skip.

---

## Checkpoint 1 — Master Migration Runner

### `scripts/run-all-migrations.ts`
Runs all 4 migrations in dependency order against a single MongoDB connection:

```
Phase 1: migrate-add-aura        (users ← new fields)
Phase 2: migrate-chat-members    (users.joinedChatIds → ChatMember docs)
Phase 3: build-connection-graph  (ChatMember pairs → UserConnection)
Phase 4: init-visibility         (UserConnection → VisibilityPermission)
```

Each individual script remains standalone-executable. The pattern used: export the core logic function, gate the self-connecting standalone block on `require.main === module`. Same pattern already used by `cleanupVibes.ts` in this repo.

### Migration run results (first run — against empty DB)
| Phase | Result | Reason |
|---|---|---|
| Users | 0 migrated | DB had 0 User documents |
| Chat Members | 22 chats, 0 memberships | Script was reading `chat.members` (empty). **Fixed** — now reads `user.joinedChatIds`. |
| Connections | 0 | Downstream of Chat Members |
| Visibility | 0 | Downstream of Connections |

**Pending re-run.** Seed the DB first (`npx ts-node src/scripts/seed.ts`), then run migrations (`npx ts-node src/scripts/run-all-migrations.ts`) to populate ChatMember → UserConnection → VisibilityPermission.

---

## Auth Flow — New User Creation + Response

### `routes/auth.ts` changes (both `/apple` and `/dev-login`)

**Before:** Response was identical for new vs returning users. Only returned `id`, `firstName`, `lastName`, `email`. Client had no way to trigger onboarding or know economy state. New users were created with an auto-generated `_id` (`user_<ObjectId>`) that the iMessage extension could not resolve — see [Identity Split Fix](#identity-split-fix).

**After:**
```
POST /api/auth/apple  →  {
  token: string,
  isNewUser: boolean,          // NEW — gates onboarding flow
  dailyBonusClaimed: boolean,  // NEW — triggers +50 notification
  user: {
    id, firstName, lastName, email,
    profilePicture,            // NEW
    auraBalance,               // NEW — current balance after any bonus
    vibeScore,                 // NEW — freshly recalculated
  }
}
```

`user.id` is now the Apple `sub` claim (see Identity Split Fix). The economy fields on new users come from Mongoose schema defaults — `auraBalance: 1000`, `vibeScore: 100`. No explicit setting in the creation code. The defaults are the single source of truth.

---

## Daily Bonus + VibeScore — `services/auraService.ts`

### `processLoginUpdates(userId)`
Called on every login. Single function, two jobs:

**1. Daily Aura Bonus (+50)**
- Checks `lastDailyBonus` on the user doc
- If null (never claimed) or 24h+ ago → awards +50
- Writes an `AuraTransaction` record (type: `daily_bonus`)
- Updates `lifetimeAuraEarned`
- Sets `lastDailyBonus` to now
- New users get the bonus on their very first login (lastDailyBonus is null) → they start at 1050

**2. VibeScore Recalculation**
Not time-based. Recomputed from current stats every login:
```
vibeScore = 100 + (betsCompleted × 10) − (betsFailed × 20) − (calloutsIgnored × 10)
```
Floors at 0. A fresh user with no bets stays at 100. The score only moves when bets resolve — the login recalc ensures the stored value is always current when viewed.

---

## Full File Inventory — Current State

### New files (19)
```
models/
  Bet.ts
  BetParticipant.ts
  BetProof.ts
  BetResolution.ts
  AuraTransaction.ts
  TeaSpill.ts
  TeaGuess.ts
  ChatMember.ts
  UserConnection.ts
  VisibilityPermission.ts
  JoinRequest.ts
  JoinRequestVote.ts

services/
  auraService.ts

scripts/
  migrate-add-aura.ts          (refactored — now exports)
  migrate-chat-members.ts      (refactored — now exports)
  build-connection-graph.ts    (refactored — now exports)
  init-visibility.ts           (refactored — now exports)
  run-all-migrations.ts        (new — master runner)
```

### Modified files (6)
```
models/User.ts          — +10 schema fields (Aura + Reputation)
models/Chat.ts          — +1 field (chatType), +import (ChatSourceType)
models/index.ts         — exports for all 12 new models
types/index.ts          — 12 new type aliases, 12 new interfaces
routes/auth.ts          — isNewUser, dailyBonusClaimed, economy fields, _id: appleId, auraService
routes/chat.ts          — identity split fallback chain on /resolve, /create, /join
```

### MongoDB collections — full list (19 total)
```
Existing (7):  users, vibes, chats, streaks, reminders, archivedvibes, newsitems
New (12):      bets, betparticipants, betproofs, betresolutions, auratransactions,
               teaspills, teaguesses, chatmembers, userconnections,
               visibilitypermissions, joinrequests, joinrequestvotes
```

---

## Identity Split Fix

### The problem
Two code paths created User documents independently, producing two docs for the same person:

| Path | `_id` | Has name/email | Has `joinedChatIds` |
|---|---|---|---|
| `auth.ts /apple` | `user_<ObjectId>` (schema default) | Yes | No |
| `chat.ts /resolve` | Whatever `userId` the client sent | No | Yes |

The iMessage extension sends the Apple `sub` claim as `userId`. Auth created the user with a different `_id`. `findById` in the chat routes missed. Second doc created. Name, email, and chats lived on separate records.

### The fix — two parts

**1. `auth.ts` — `_id` set to `appleId`**
The `sub` claim from Apple's verified identity token is now the document's primary key. Apple explicitly documents `sub` as the stable, unique user identifier — using it as `_id` is the intended pattern. It does not change for the life of the account (unless the user revokes app access — see Known Items).

**2. `chat.ts` — fallback lookup chain on all three user-touching routes**
After `findById(userId)` misses, each route runs additional lookups before falling back to creating a new doc:

| Route | Fallback chain |
|---|---|
| `/resolve` | `findById` → `findOne({ appleId: userId })` → `findOne({ appleUUID })` → create |
| `/create` | `findById` → `findOne({ appleId: userId })` → create |
| `/join` | `findById` → `findOne({ appleId: userId })` → create |

`/resolve` gets the extra `appleUUID` step because it is the only route the iMessage extension hits directly, and the only one that receives `localParticipantIdentifier`. The fallbacks only fire if there is stale data from before the `_id` fix — on a clean DB, `findById` hits on the first try every time.

---

## Design Decisions — Why

| Decision | Rationale |
|---|---|
| Interfaces in `types/index.ts`, not inline `extends Document` | 6 of 7 existing models use this pattern. `NewsItem.ts` is the outlier. |
| `updateMany` in aura migration, not loop + save | Single round trip. The loop pattern was in the original spec but would fire N individual writes. |
| Daily bonus on login (lazy), not cron | User gets the bonus when they actually open the app. No wasted cron runs for inactive users. |
| `vibeScore` computed on login, not on a timer | Always reflects current stats. No race condition between stat change and score update. |
| `transactionType` is `string`, no enum in schema | Left intentionally flexible. New transaction types will come as the economy builds out. TypeScript doesn't constrain it at compile time either — this is a conscious tradeoff for extensibility. |
| `userId1 < userId2` enforced in UserConnection | Prevents storing the same pair twice (A→B and B→A). One canonical direction. |
| VisibilityPermission is directional, not symmetric | Allows revoking A→B without touching B→A. Each direction is an independent permission. |
| `chatType` orthogonal to existing `type` | `type` = group structure (individual/group). `chatType` = source (imessage/virtual). Different axes. |
| Migration scripts export + `require.main` gate | Master runner imports the exported functions. Each script still works standalone. Same pattern as `cleanupVibes.ts`. |
| `_id: appleId` on User, not `user_<ObjectId>` | Apple `sub` is the stable canonical identifier. iMessage extension sends it as `userId`. Using it as `_id` means `findById` resolves on first try — no split possible. |
| ChatMember migration reads `user.joinedChatIds`, not `chat.members` | `joinedChatIds` is the populated side of the relationship. `chat.members` is empty in production data. |

---

## Known Items Heading Into Phase 2

1. **Duplicate streak logic** — `updateStreak()` is copy-pasted in both `routes/vibes.ts` and `routes/group.ts`. Will diverge if either is touched. Extract before extending.
2. **No auth middleware** — All routes trust `userId` from the request body. No JWT verification anywhere. Betting and Aura economy routes are high-value targets — this needs addressing before those routes go live.
3. **`conversationId` vs `chatId` split** — `ArchivedVibe` and legacy `vibe.ts` route query by `conversationId`. Everything new uses `chatId`. Be explicit about which one you're querying.
4. **Apple `sub` revocation** — If a user revokes app access in Apple ID settings and re-signs in, they get a new `sub` value. Apple sends a server-to-server notification (`revocation` event) when this happens. No handler exists yet. Low urgency — only fires if user actively revokes.
5. **`vibewire` route** — Mounted in `server.ts` but not exported from `routes/index.ts`. Minor inconsistency.
6. **Migrations pending re-run** — `migrate-chat-members.ts` was fixed (reads `joinedChatIds` now). Seed first, then run `run-all-migrations.ts` to populate ChatMember → UserConnection → VisibilityPermission.

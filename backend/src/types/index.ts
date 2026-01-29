import { Types } from 'mongoose';

// ============================================================================
// Vibe Types
// ============================================================================

export type VibeType =
  | 'video'
  | 'photo'
  | 'song'
  | 'battery'
  | 'mood'
  | 'poll'
  | 'dailyDrop'
  | 'tea'
  | 'leak'
  | 'sketch'
  | 'eta'
  | 'parlay';

export type ParlayStatus = 'pending' | 'accepted' | 'declined' | 'settled' | 'active' | 'resolved' | 'cancelled';

export type ReminderType = 'birthday' | 'hangout' | 'event' | 'custom';

export type ChatType = 'individual' | 'group';

// ============================================================================
// Subdocument Interfaces
// ============================================================================

export interface ISongData {
  title?: string;
  artist?: string;
  albumArt?: string;
  previewUrl?: string;
  spotifyId?: string;
  spotifyUrl?: string;
  appleMusicUrl?: string;
}

export interface IMood {
  emoji?: string;
  text?: string;
}

export interface IPollVote {
  userId: string;
  optionIndex: number;
}

export interface IPoll {
  question?: string;
  options?: string[];
  votes: IPollVote[];
}

export interface IParlay {
  // Core fields
  title?: string;
  question?: string;
  options?: string[];
  // Bet fields
  amount?: string;
  wager?: string;
  // Opponent fields
  opponentId?: string;
  opponentName?: string;
  // Status and timing
  status?: ParlayStatus;
  expiresAt?: Date;
  // Voting/results
  votes?: { oderId: string; optionIndex: number }[];
  winnersReceived?: string[];
}

export interface IReaction {
  userId: string;
  emoji: string;
  createdAt?: Date;
}

export interface IBirthday {
  month?: number;
  day?: number;
}

export interface IMetrics {
  viewCount: number;
  reactionCount: number;
  unlockCount: number;
}

// ============================================================================
// Document Interfaces
// ============================================================================

// For documents with string _id (User, Chat)
export interface IUserDocument {
  _id: string;
  appleId?: string;
  appleUUID?: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  profilePicture?: string;
  birthday?: IBirthday;
  joinedChatIds: string[];
  pushToken?: string;
  lastSeen: Date;
  createdAt: Date;
  updatedAt: Date;
}

// Alias for backwards compatibility
export type IUser = IUserDocument;

export interface IVibe {
  _id: Types.ObjectId;
  userId: string;
  chatId: string;
  conversationId?: string;
  oderId?: string;
  type: VibeType;
  mediaUrl?: string;
  mediaKey?: string;
  thumbnailUrl?: string;
  thumbnailKey?: string;
  songData?: ISongData;
  batteryLevel?: number;
  mood?: IMood;
  poll?: IPoll;
  parlay?: IParlay;
  textStatus?: string;
  styleName?: string;
  etaStatus?: string;
  isLocked: boolean;
  unlockedBy: string[];
  reactions: IReaction[];
  viewedBy: string[];
  expiresAt: Date;
  permanentDeleteAt: Date;
  mediaDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface IChatDocument {
  _id: string;
  title?: string;
  members: string[];
  lastVibeId?: string;
  lastActivityAt: Date;
  type: ChatType;
  createdBy?: string;
  createdAt: Date;
  updatedAt: Date;
}

// Alias for backwards compatibility
export type IChat = IChatDocument;

export interface IStreak {
  _id?: Types.ObjectId;
  conversationId: string;
  currentStreak: number;
  longestStreak: number;
  lastPostDate?: Date;
  todayPosters: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface IReminder {
  _id: Types.ObjectId;
  chatId: string;
  userId: string;
  type: ReminderType;
  emoji: string;
  title: string;
  date: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface IArchivedVibe {
  _id?: Types.ObjectId;
  originalVibeId: string;
  userId: string;
  conversationId: string;
  type: VibeType;
  wasLocked: boolean;
  metrics: IMetrics;
  originalCreatedAt: Date;
  archivedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

// ============================================================================
// Request/Response Types
// ============================================================================

export interface CreateVibeRequest {
  userId: string;
  chatId?: string;
  conversationId?: string;
  type: VibeType;
  mediaUrl?: string;
  mediaKey?: string;
  thumbnailUrl?: string;
  thumbnailKey?: string;
  songData?: ISongData;
  batteryLevel?: number;
  mood?: IMood;
  poll?: { question: string; options: string[] };
  parlay?: IParlay;
  textStatus?: string;
  styleName?: string;
  etaStatus?: string;
  oderId?: string;
  isLocked?: boolean;
}

export interface UploadResult {
  uploadUrl: string;
  publicUrl: string;
  key: string;
}

export interface S3UploadResult {
  publicUrl: string;
  key: string;
}

// ============================================================================
// Feed Response Types
// ============================================================================

export interface IVibeWithBlur extends IVibe {
  isBlurred?: boolean;
}

export interface IVibeWithExpiry extends IVibe {
  isExpiredFromFeed?: boolean;
}

export interface FeedResponse {
  vibes: IVibeWithBlur[];
  hasMore: boolean;
}

export interface FeedStatsResponse {
  totalChats: number;
  totalVibes: number;
  unviewedCount: number;
}

// ============================================================================
// Stories Response Types (Grouped by User)
// ============================================================================

export interface IUserStory {
  userId: string;
  userName?: string;
  profilePicture?: string;
  vibes: IVibeWithBlur[];
  latestVibeAt: Date;
  hasUnviewed: boolean;
}

export interface StoriesFeedResponse {
  stories: IUserStory[];
  hasMore: boolean;
}

export interface StoriesByChatResponse {
  chatId: string;
  stories: IUserStory[];
}

// ============================================================================
// Chat Response Types (for ConversationManager)
// ============================================================================

export interface CreateChatResponse {
  chatId: string;
  chat: IChatDocument;
  isNew: boolean;
}

export interface JoinChatResponse {
  success: boolean;
  chat: IChatDocument;
  isNewMember: boolean;
}

export interface ResolveChatRequest {
  userId: string;
  chatId?: string;           // If known (from URL parameter)
  appleUUID?: string;        // localParticipantIdentifier
  title?: string;            // Optional title for new chats
}

export interface ResolveChatResponse {
  chatId: string;
  chat: IChatDocument;
  isNew: boolean;            // Was this chat just created?
  isNewMember: boolean;      // Did user just join this chat?
}

export interface UserChatsResponse {
  chats: IChatDocument[];
}

export interface ChatMembersResponse {
  members: IUserDocument[];
}

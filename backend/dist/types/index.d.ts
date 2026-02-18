import { Types } from 'mongoose';
export type VibeType = 'video' | 'photo' | 'song' | 'battery' | 'mood' | 'poll' | 'dailyDrop' | 'tea' | 'leak' | 'sketch' | 'eta' | 'parlay';
export type ParlayStatus = 'pending' | 'accepted' | 'declined' | 'settled' | 'active' | 'resolved' | 'cancelled';
export type ReminderType = 'birthday' | 'hangout' | 'event' | 'custom';
export type ChatType = 'individual' | 'group';
export type BetType = 'self' | 'callout' | 'dare';
export type BetStatus = 'active' | 'completed' | 'expired' | 'ducked';
export type BetSide = 'yes' | 'no';
export type BetOutcome = 'yes' | 'no' | 'expired' | 'ducked';
export type ProofMediaType = 'photo' | 'video';
export type TeaSpillStatus = 'active' | 'revealed' | 'expired';
export type ChatSourceType = 'imessage' | 'virtual';
export type MembershipType = 'full' | 'virtual';
export type MemberRole = 'admin' | 'member';
export type VisibilitySource = 'past_chat' | 'past_connection' | 'contact' | 'manual';
export type JoinRequestStatus = 'pending' | 'approved' | 'denied' | 'expired';
export type JoinDecision = 'approve' | 'deny';
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
    title?: string;
    question?: string;
    options?: string[];
    betId?: string;
    amount?: string;
    wager?: string;
    opponentId?: string;
    opponentName?: string;
    status?: ParlayStatus;
    expiresAt?: Date;
    votes?: {
        oderId: string;
        optionIndex: number;
    }[];
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
    auraBalance?: number;
    lifetimeAuraEarned?: number;
    lifetimeAuraSpent?: number;
    lastDailyBonus?: Date;
    vibeScore?: number;
    betsCreated?: number;
    betsCompleted?: number;
    betsFailed?: number;
    calloutsReceived?: number;
    calloutsIgnored?: number;
    createdAt: Date;
    updatedAt: Date;
}
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
    chatType?: ChatSourceType;
    createdBy?: string;
    createdAt: Date;
    updatedAt: Date;
}
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
export interface IBet {
    _id: Types.ObjectId;
    betId: string;
    chatId: string;
    creatorId: string;
    betType: BetType;
    description: string;
    deadline: Date;
    status: BetStatus;
    targetUserId?: string;
    creationCost: number;
    createdAt: Date;
    updatedAt: Date;
}
export interface IBetParticipant {
    _id: Types.ObjectId;
    participantId: string;
    betId: string;
    userId: string;
    side: BetSide;
    amount: number;
    createdAt: Date;
    updatedAt: Date;
}
export interface IBetProof {
    _id: Types.ObjectId;
    proofId: string;
    betId: string;
    userId: string;
    mediaType: ProofMediaType;
    mediaUrl: string;
    mediaKey: string;
    thumbnailUrl?: string;
    thumbnailKey?: string;
    caption?: string;
    createdAt: Date;
    updatedAt: Date;
}
export interface IBetResolution {
    _id: Types.ObjectId;
    resolutionId: string;
    betId: string;
    outcome: BetOutcome;
    resolvedBy: string;
    resolvedAt: Date;
    notes?: string;
}
export interface IAuraTransaction {
    _id: Types.ObjectId;
    transactionId: string;
    userId: string;
    amount: number;
    balanceAfter: number;
    transactionType: string;
    referenceId?: string;
    description?: string;
    createdAt: Date;
    updatedAt: Date;
}
export interface ITeaSpill {
    _id: Types.ObjectId;
    teaId: string;
    chatId: string;
    creatorId: string;
    mysteryText: string;
    answer?: string;
    options: string[];
    deadline: Date;
    status: TeaSpillStatus;
    creationCost: number;
    creatorBonusPercent?: number;
    revealedAt?: Date;
    createdAt: Date;
    updatedAt: Date;
}
export interface ITeaGuess {
    _id: Types.ObjectId;
    guessId: string;
    teaId: string;
    userId: string;
    guess: string;
    amount: number;
    createdAt: Date;
    updatedAt: Date;
}
export interface IChatMember {
    _id: Types.ObjectId;
    memberId: string;
    chatId: string;
    userId: string;
    membershipType: MembershipType;
    role: MemberRole;
    joinedAt: Date;
}
export interface IUserConnection {
    _id: Types.ObjectId;
    connectionId: string;
    userId1: string;
    userId2: string;
    sourceChatId: string;
    establishedAt: Date;
    lastInteraction: Date;
}
export interface IVisibilityPermission {
    _id: Types.ObjectId;
    permissionId: string;
    userId: string;
    visibleToUserId: string;
    source: VisibilitySource;
    grantedAt: Date;
    revokedAt?: Date;
}
export interface IJoinRequest {
    _id: Types.ObjectId;
    requestId: string;
    chatId: string;
    userId: string;
    reason?: string;
    contextBetId?: string;
    status: JoinRequestStatus;
    resolvedAt?: Date;
    createdAt: Date;
    updatedAt: Date;
}
export interface IJoinRequestVote {
    _id: Types.ObjectId;
    voteId: string;
    requestId: string;
    voterId: string;
    decision: JoinDecision;
    votedAt: Date;
}
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
    poll?: {
        question: string;
        options: string[];
    };
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
    chatId?: string;
    appleUUID?: string;
    title?: string;
}
export interface ResolveChatResponse {
    chatId: string;
    chat: IChatDocument;
    isNew: boolean;
    isNewMember: boolean;
}
export interface UserChatsResponse {
    chats: IChatDocument[];
}
export interface ChatMembersResponse {
    members: IUserDocument[];
}
//# sourceMappingURL=index.d.ts.map
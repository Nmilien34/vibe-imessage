export declare function hashEmailContact(email: string): string | null;
export declare function hashPhoneContact(phone: string): string | null;
export declare function registerVerifiedEmailIdentifier(params: {
    userId: string;
    email?: string | null;
}): Promise<void>;
export declare function getAudienceGraph(params: {
    userId: string;
}): Promise<{
    groupUserIds: string[];
    contactUserIds: string[];
    mergedUserIds: string[];
}>;
export declare function syncContactNetwork(params: {
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
}>;
//# sourceMappingURL=contactNetworkService.d.ts.map
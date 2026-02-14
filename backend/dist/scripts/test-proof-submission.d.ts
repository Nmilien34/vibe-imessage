/**
 * Proof Submission Test Suite
 *
 * Requires server running on localhost:3000
 *
 * Tests:
 *   1. Get presigned URL for upload
 *   2. Submit proof (happy path)
 *   3. Get bet proofs
 *   4. Submit second proof (multiple proofs allowed)
 *   5. Authorization: Non-creator cannot submit proof for self bet
 *   6. Delete own proof
 *   7. Cannot delete others' proofs
 *   8. Missing fields rejection
 *   9. Invalid mediaType rejection
 *
 * Run: npx ts-node src/scripts/test-proof-submission.ts
 */
export {};
//# sourceMappingURL=test-proof-submission.d.ts.map
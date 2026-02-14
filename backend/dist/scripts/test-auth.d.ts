/**
 * Auth Middleware Test Suite
 *
 * Requires the server to be running on localhost:3000.
 * Starts automatically if not already running.
 *
 * Tests:
 *   1. Dev login returns a real JWT (3-part structure)
 *   2. Valid token is accepted on GET /api/user/me
 *   3. No token  → 401
 *   4. Fake token → 401
 *   5. Missing "Bearer " prefix → 401
 *
 * Run: npx ts-node src/scripts/test-auth.ts
 */
export {};
//# sourceMappingURL=test-auth.d.ts.map
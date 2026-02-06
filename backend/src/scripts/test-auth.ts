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

import axios from 'axios';

const API = 'http://localhost:3000/api';

let passed = 0;
let failed = 0;

function ok(label: string, detail?: string) {
  passed++;
  console.log(`  PASS  ${label}`);
  if (detail) console.log(`        ${detail}`);
}

function fail(label: string, detail?: string) {
  failed++;
  console.log(`  FAIL  ${label}`);
  if (detail) console.log(`        ${detail}`);
}

async function run() {
  console.log('AUTH MIDDLEWARE TEST SUITE\n');

  // ── 1. Login & token format ─────────────────────────────
  console.log('1. Dev login → real JWT');
  let token: string;
  try {
    const { data } = await axios.post<{ token: string }>(`${API}/auth/dev-login`, { userId: 'test_user_me' });
    token = data.token;
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error(`token has ${parts.length} parts, expected 3`);
    ok('Login returned 3-part JWT', `${token.substring(0, 40)}...`);
  } catch (err: any) {
    fail('Login', err.response?.data?.error ?? err.message);
    console.log('\nCannot continue without a valid token.');
    process.exit(1);
  }

  // ── 2. Valid token on protected route ───────────────────
  console.log('\n2. Valid token → GET /user/me');
  try {
    const { data } = await axios.get<{ user: { id: string } }>(`${API}/user/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    ok('200 returned', `user.id = ${data.user?.id}`);
  } catch (err: any) {
    fail('Valid token rejected', `${err.response?.status} — ${err.response?.data?.error}`);
  }

  // ── 3. No token ─────────────────────────────────────────
  console.log('\n3. No token → 401');
  try {
    await axios.get(`${API}/user/me`);
    fail('No token was accepted');
  } catch (err: any) {
    if (err.response?.status === 401) ok('Rejected with 401', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── 4. Fake token ───────────────────────────────────────
  console.log('\n4. Fake token → 401');
  try {
    await axios.get(`${API}/user/me`, {
      headers: { Authorization: 'Bearer totally.fake.token' },
    });
    fail('Fake token was accepted');
  } catch (err: any) {
    if (err.response?.status === 401) ok('Rejected with 401', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── 5. Missing Bearer prefix ────────────────────────────
  console.log('\n5. Missing "Bearer " prefix → 401');
  try {
    await axios.get(`${API}/user/me`, {
      headers: { Authorization: token }, // raw token, no prefix
    });
    fail('Malformed header was accepted');
  } catch (err: any) {
    if (err.response?.status === 401) ok('Rejected with 401', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── Summary ─────────────────────────────────────────────
  console.log('\n' + '─'.repeat(40));
  console.log(`Results: ${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
}

run().catch((err) => {
  console.error('Test suite crashed:', err.message);
  process.exit(1);
});

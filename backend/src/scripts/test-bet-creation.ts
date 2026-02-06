/**
 * Bet Creation Test Suite
 *
 * Requires server running on localhost:3000
 *
 * Tests:
 *   1. Self bet (happy path)
 *   2. Missing fields → 400
 *   3. Invalid betType → 400
 *   4. Past deadline → 400
 *   5. Empty description → 400
 *   6. Description too long → 400
 *
 * Run: npx ts-node src/scripts/test-bet-creation.ts
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
  console.log('BET CREATION TEST SUITE\n');

  // ── Setup ───────────────────────────────────────────────
  console.log('Setup: Login');
  let token: string;
  let chatId = 'test_chat_main';

  try {
    const { data } = await axios.post<{ token: string; user: { id: string; auraBalance: number } }>(
      `${API}/auth/dev-login`,
      { userId: 'test_user_me' }
    );
    token = data.token;
    ok('Logged in', `Aura: ${data.user.auraBalance}`);
  } catch (err: any) {
    fail('Login', err.response?.data?.error ?? err.message);
    process.exit(1);
  }

  // ── 1. Self bet (happy path) ────────────────────────────
  console.log('\n1. Create self bet');
  try {
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    const { data } = await axios.post<{ success: boolean; bet: { betId: string } }>(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'I will go to the gym today',
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    if (data.success && data.bet?.betId) {
      ok('Self bet created', `ID: ${data.bet.betId}`);
    } else {
      fail('Self bet created', 'Missing betId in response');
    }
  } catch (err: any) {
    fail('Self bet', err.response?.data?.error ?? err.message);
  }

  // ── 2. Missing fields ───────────────────────────────────
  console.log('\n2. Missing fields → 400');
  try {
    await axios.post(
      `${API}/bets/create`,
      { chatId, betType: 'self' }, // missing description & deadline
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should reject missing fields');
  } catch (err: any) {
    if (err.response?.status === 400) ok('Rejected (400)', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── 3. Invalid betType ──────────────────────────────────
  console.log('\n3. Invalid betType → 400');
  try {
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    await axios.post(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'invalid_type',
        description: 'Test',
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should reject invalid betType');
  } catch (err: any) {
    if (err.response?.status === 400) ok('Rejected (400)', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── 4. Past deadline ────────────────────────────────────
  console.log('\n4. Past deadline → 400');
  try {
    const pastDeadline = new Date();
    pastDeadline.setHours(pastDeadline.getHours() - 1);

    await axios.post(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'Test with past deadline',
        deadline: pastDeadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should reject past deadline');
  } catch (err: any) {
    if (err.response?.status === 400) ok('Rejected (400)', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── 5. Empty description ────────────────────────────────
  console.log('\n5. Empty description → 400');
  try {
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    await axios.post(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: '   ', // whitespace
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should reject empty description');
  } catch (err: any) {
    if (err.response?.status === 400) ok('Rejected (400)', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── 6. Description too long ─────────────────────────────
  console.log('\n6. Description too long → 400');
  try {
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    await axios.post(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'A'.repeat(501), // 501 chars
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should reject long description');
  } catch (err: any) {
    if (err.response?.status === 400) ok('Rejected (400)', err.response.data.error);
    else fail('Wrong status', `got ${err.response?.status}`);
  }

  // ── Summary ─────────────────────────────────────────────
  console.log('\n' + '─'.repeat(40));
  console.log(`Results: ${passed} passed, ${failed} failed`);

  if (failed === 0) {
    console.log('\nRoutes compiled and HTTP validation works.');
    console.log('Tests fail at service layer (expected - stubs throw).\n');
  }

  process.exit(failed === 0 ? 0 : 1);
}

run().catch((err) => {
  console.error('Test suite crashed:', err.message);
  process.exit(1);
});

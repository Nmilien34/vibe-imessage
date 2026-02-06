/**
 * Staking Test Suite
 *
 * Requires server running on localhost:3000
 *
 * Tests:
 *   1. Place stake (happy path)
 *   2. Duplicate stake rejection → 409
 *   3. Minimum stake enforcement → 400
 *   4. Invalid side rejection → 400
 *   5. Get participants endpoint
 *   6. Get user's own stake
 *
 * Run: npx ts-node src/scripts/test-staking.ts
 */

import axios from 'axios';

const API = 'http://localhost:3000/api';

let passed = 0;
let failed = 0;

function pass(detail: string) {
  passed++;
  console.log(`✅ ${detail}`);
}

function fail(detail: string) {
  failed++;
  console.log(`❌ ${detail}`);
}

function section(title: string) {
  console.log(`\n📝 ${title}`);
  console.log('─'.repeat(70));
}

async function run() {
  console.log('\n🧪 STAKING TEST SUITE\n');
  console.log(`Testing against: ${API}\n`);
  console.log('═'.repeat(70));

  // ── Setup ───────────────────────────────────────────────
  console.log('\n🔐 SETUP: Logging in and creating test bet...');
  console.log('─'.repeat(70));

  let token: string;
  let betId: string;
  let userName: string;
  let userBalance: number;
  const chatId = 'test_chat_main';

  try {
    const { data } = await axios.post<{
      token: string;
      user: { id: string; firstName: string; auraBalance: number }
    }>(
      `${API}/auth/dev-login`,
      { userId: 'test_user_me' }
    );
    token = data.token;
    userName = data.user.firstName;
    userBalance = data.user.auraBalance;
    pass(`Logged in as: ${userName}`);
    console.log(`   Aura Balance: ${userBalance}`);
  } catch (err: any) {
    fail('Login failed: ' + (err.response?.data?.error ?? err.message));
    process.exit(1);
  }

  // Create a bet to stake on
  try {
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    const { data } = await axios.post<{ success: boolean; bet: { betId: string } }>(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'Test bet for staking',
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    betId = data.bet.betId;
    pass(`Created test bet: ${betId}`);
  } catch (err: any) {
    fail('Failed to create bet: ' + (err.response?.data?.error ?? err.message));
    process.exit(1);
  }

  // ── TEST 1: Place stake ─────────────────────────────────
  section('TEST 1: Place Stake on Bet');

  let participantId: string;

  try {
    const { data } = await axios.post<{
      success: boolean;
      participant: { participantId: string; side: string; amount: number };
    }>(
      `${API}/bets/${betId}/stake`,
      { side: 'yes', amount: 50 },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    participantId = data.participant.participantId;
    pass('Stake placed successfully');
    console.log(`   Participant ID: ${participantId}`);
    console.log(`   Side: ${data.participant.side}`);
    console.log(`   Amount: ${data.participant.amount}`);

    // Get totals
    const totalsRes = await axios.get<{
      totals: { totalYes: number; totalNo: number };
    }>(
      `${API}/bets/${betId}/participants`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    console.log(`   Totals: YES=${totalsRes.data.totals.totalYes}, NO=${totalsRes.data.totals.totalNo}`);
  } catch (err: any) {
    fail('Failed to place stake: ' + (err.response?.data?.error ?? err.message));
  }

  // ── TEST 2: Duplicate stake ─────────────────────────────
  section('TEST 2: Cannot Stake Twice on Same Bet');

  try {
    await axios.post(
      `${API}/bets/${betId}/stake`,
      { side: 'no', amount: 30 },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should have rejected duplicate stake');
  } catch (err: any) {
    if (err.response?.status === 409) {
      pass('Correctly rejected duplicate stake (409)');
      console.log(`   Error: "${err.response.data.error}"`);
    } else {
      fail(`Wrong status code: ${err.response?.status}`);
    }
  }

  // ── TEST 3: Minimum stake ───────────────────────────────
  section('TEST 3: Reject Stake Below Minimum');

  // Create another bet for this test
  let betId2: string;
  try {
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    const { data } = await axios.post<{ bet: { betId: string } }>(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'Second test bet',
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    betId2 = data.bet.betId;
  } catch (err: any) {
    fail('Failed to create second bet');
    process.exit(1);
  }

  try {
    await axios.post(
      `${API}/bets/${betId2}/stake`,
      { side: 'yes', amount: 5 },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should have rejected low stake');
  } catch (err: any) {
    if (err.response?.status === 400 && err.response.data.error.includes('Minimum stake')) {
      pass('Correctly rejected low stake (400)');
      console.log(`   Error: "${err.response.data.error}"`);
    } else {
      fail(`Wrong response: ${err.response?.status}`);
    }
  }

  // ── TEST 4: Invalid side ────────────────────────────────
  section('TEST 4: Reject Invalid Side');

  try {
    await axios.post(
      `${API}/bets/${betId2}/stake`,
      { side: 'maybe', amount: 20 },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    fail('Should have rejected invalid side');
  } catch (err: any) {
    if (err.response?.status === 400) {
      pass('Correctly rejected invalid side (400)');
      console.log(`   Error: "${err.response.data.error}"`);
    } else {
      fail(`Wrong status code: ${err.response?.status}`);
    }
  }

  // ── TEST 5: Get participants ────────────────────────────
  section('TEST 5: Get Bet Participants');

  try {
    const { data } = await axios.get<{
      participants: Array<{ userId: string; side: string; amount: number }>;
      totals: { totalYes: number; totalNo: number; totalPot: number; yesCount: number; noCount: number };
    }>(
      `${API}/bets/${betId}/participants`,
      { headers: { Authorization: `Bearer ${token}` } }
    );

    pass('Fetched participants');
    console.log(`   Count: ${data.participants.length}`);
    console.log(`   Total Pot: ${data.totals.totalPot} Aura`);
    console.log(`   YES: ${data.totals.totalYes} (${data.totals.yesCount} bettors)`);
    console.log(`   NO: ${data.totals.totalNo} (${data.totals.noCount} bettors)`);
  } catch (err: any) {
    fail('Failed to get participants: ' + (err.response?.data?.error ?? err.message));
  }

  // ── TEST 6: Get user's stake ────────────────────────────
  section('TEST 6: Get User\'s Own Stake');

  try {
    const { data } = await axios.get<{
      hasStake: boolean;
      stake: { side: string; amount: number } | null;
    }>(
      `${API}/bets/${betId}/my-stake`,
      { headers: { Authorization: `Bearer ${token}` } }
    );

    if (data.hasStake && data.stake) {
      pass('User has stake');
      console.log(`   Side: ${data.stake.side}`);
      console.log(`   Amount: ${data.stake.amount}`);
    } else {
      fail('Expected user to have stake');
    }
  } catch (err: any) {
    fail('Failed to get user stake: ' + (err.response?.data?.error ?? err.message));
  }

  // ── Summary ─────────────────────────────────────────────
  console.log('\n' + '═'.repeat(70));
  console.log('📊 TEST SUMMARY');
  console.log('═'.repeat(70));
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);

  if (failed === 0) {
    console.log('\n🎉 ALL TESTS PASSED!');
    console.log('   Staking system is working correctly.\n');
  } else {
    console.log(`\n❌ ${failed} test(s) failed.\n`);
  }

  process.exit(failed === 0 ? 0 : 1);
}

run().catch((err) => {
  console.error('❌ Test suite crashed:', err.message);
  process.exit(1);
});

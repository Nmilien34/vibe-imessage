/**
 * Resolution & Payout Test Suite
 *
 * Tests complete betting flow end-to-end:
 * 1. Create bet
 * 2. Multiple users stake
 * 3. Resolve bet
 * 4. Verify payouts distributed correctly
 * 5. Verify stats updated correctly
 *
 * Scenarios:
 * A. YES wins (pari-mutuel payout)
 * B. Authorization enforcement
 * C. Get resolution details
 *
 * Run: npx ts-node src/scripts/test-resolution.ts
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
  console.log('\n🧪 RESOLUTION & PAYOUT TEST SUITE\n');
  console.log(`Testing against: ${API}\n`);
  console.log('═'.repeat(70));

  // ── Setup: Login multiple users ─────────────────────────
  console.log('\n🔐 SETUP: Logging in 3 users...');
  console.log('─'.repeat(70));

  let user1Token: string, user1Id: string, user1BalanceBefore: number;
  let user2Token: string, user2Id: string, user2BalanceBefore: number;
  let user3Token: string, user3Id: string, user3BalanceBefore: number;
  const chatId = 'test_chat_main';

  try {
    // User 1 (creator)
    const login1 = await axios.post<{
      token: string;
      user: { id: string; firstName: string; auraBalance: number };
    }>(
      `${API}/auth/dev-login`,
      { userId: 'test_user_me' }
    );
    user1Token = login1.data.token;
    user1Id = login1.data.user.id;
    user1BalanceBefore = login1.data.user.auraBalance;

    // User 2 (bettor on YES)
    const login2 = await axios.post<{
      token: string;
      user: { id: string; firstName: string; auraBalance: number };
    }>(
      `${API}/auth/dev-login`,
      { userId: 'test_user_friend1' }
    );
    user2Token = login2.data.token;
    user2Id = login2.data.user.id;
    user2BalanceBefore = login2.data.user.auraBalance;

    // User 3 (bettor on NO)
    const login3 = await axios.post<{
      token: string;
      user: { id: string; firstName: string; auraBalance: number };
    }>(
      `${API}/auth/dev-login`,
      { userId: 'test_user_friend2' }
    );
    user3Token = login3.data.token;
    user3Id = login3.data.user.id;
    user3BalanceBefore = login3.data.user.auraBalance;

    console.log('✅ 3 users logged in');
    console.log(`   User 1: ${user1Id} (Balance: ${user1BalanceBefore})`);
    console.log(`   User 2: ${user2Id} (Balance: ${user2BalanceBefore})`);
    console.log(`   User 3: ${user3Id} (Balance: ${user3BalanceBefore})`);

  } catch (error: any) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  }

  // ── SCENARIO A: YES WINS (Pari-Mutuel Payout) ──────────
  section('SCENARIO A: YES Wins (Pari-Mutuel Payout)');

  let betId: string = '';

  try {
    // Step 1: User 1 creates bet
    console.log('Step 1: Creating bet...');
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    const betRes = await axios.post<{
      success: boolean;
      bet: { betId: string };
    }>(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'Test pari-mutuel payouts',
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${user1Token}` } }
    );

    betId = betRes.data.bet.betId;
    pass(`Bet created: ${betId}`);

    // Step 2: Users stake
    console.log('\nStep 2: Users placing stakes...');

    // User 1 stakes 60 on YES
    await axios.post(
      `${API}/bets/${betId}/stake`,
      { side: 'yes', amount: 60 },
      { headers: { Authorization: `Bearer ${user1Token}` } }
    );
    pass('User 1: 60 Aura on YES');

    // User 2 stakes 40 on YES
    await axios.post(
      `${API}/bets/${betId}/stake`,
      { side: 'yes', amount: 40 },
      { headers: { Authorization: `Bearer ${user2Token}` } }
    );
    pass('User 2: 40 Aura on YES');

    // User 3 stakes 100 on NO
    await axios.post(
      `${API}/bets/${betId}/stake`,
      { side: 'no', amount: 100 },
      { headers: { Authorization: `Bearer ${user3Token}` } }
    );
    pass('User 3: 100 Aura on NO');

    console.log('\n💰 Pot breakdown:');
    console.log('   Team YES: 100 Aura (User1: 60, User2: 40)');
    console.log('   Team NO:  100 Aura (User3: 100)');
    console.log('   Total:    200 Aura');

    // Step 3: Resolve as YES wins
    console.log('\nStep 3: Resolving bet as YES wins...');

    const resolveRes = await axios.post<{
      success: boolean;
      resolution: { resolutionId: string; outcome: string };
      message: string;
    }>(
      `${API}/bets/${betId}/resolve`,
      { outcome: 'yes' },
      { headers: { Authorization: `Bearer ${user1Token}` } }
    );

    pass('Bet resolved successfully');

    // Step 4: Verify payouts
    console.log('\nStep 4: Verifying payouts...');

    // User 1 should get: (60/100) × 200 = 120 (net +60)
    const user1After = await axios.get<{
      user: { auraBalance: number };
    }>(
      `${API}/user/me`,
      { headers: { Authorization: `Bearer ${user1Token}` } }
    );
    const user1Payout = user1After.data.user.auraBalance - (user1BalanceBefore - 10 - 60);
    console.log(`   User 1: Expected 120, Got ${user1Payout}`);

    // User 2 should get: (40/100) × 200 = 80 (net +40)
    const user2After = await axios.get<{
      user: { auraBalance: number };
    }>(
      `${API}/user/me`,
      { headers: { Authorization: `Bearer ${user2Token}` } }
    );
    const user2Payout = user2After.data.user.auraBalance - (user2BalanceBefore - 40);
    console.log(`   User 2: Expected 80, Got ${user2Payout}`);

    // User 3 should get: 0 (lost 100)
    const user3After = await axios.get<{
      user: { auraBalance: number };
    }>(
      `${API}/user/me`,
      { headers: { Authorization: `Bearer ${user3Token}` } }
    );
    const user3Loss = user3BalanceBefore - user3After.data.user.auraBalance;
    console.log(`   User 3: Expected loss 100, Lost ${user3Loss}`);

    // Verify math
    if (user1Payout === 120 && user2Payout === 80 && user3Loss === 100) {
      pass('Pari-mutuel payouts correct!');
    } else {
      fail('Payout math incorrect');
    }

    // Step 5: Verify stats updated
    console.log('\nStep 5: Verifying stats...');

    const user1Stats = user1After.data.user as any;
    console.log(`   User 1 betsCompleted: ${user1Stats.stats?.betsCompleted ?? user1Stats.betsCompleted ?? 0}`);
    console.log(`   User 1 vibeScore: ${user1Stats.vibeScore}`);

    if ((user1Stats.stats?.betsCompleted ?? user1Stats.betsCompleted ?? 0) > 0) {
      pass('Stats updated correctly');
    } else {
      fail('Stats not updated');
    }

  } catch (error: any) {
    fail('Scenario A failed: ' + (error.response?.data?.error ?? error.message));
  }

  // ── SCENARIO B: Authorization Test ─────────────────────
  section('SCENARIO B: Authorization (Only Creator Can Resolve)');

  try {
    // Create new bet
    const deadline = new Date();
    deadline.setHours(deadline.getHours() + 6);

    const betRes = await axios.post<{
      bet: { betId: string };
    }>(
      `${API}/bets/create`,
      {
        chatId,
        betType: 'self',
        description: 'Authorization test bet',
        deadline: deadline.toISOString()
      },
      { headers: { Authorization: `Bearer ${user1Token}` } }
    );

    const testBetId = betRes.data.bet.betId;

    // Try to resolve as User 2 (not creator - should fail)
    try {
      await axios.post(
        `${API}/bets/${testBetId}/resolve`,
        { outcome: 'yes' },
        { headers: { Authorization: `Bearer ${user2Token}` } }
      );

      fail('Should have failed but didn\'t');

    } catch (error: any) {
      if (error.response?.status === 403) {
        pass('Correctly rejected unauthorized resolution (403)');
        console.log(`   Error: "${error.response.data.error}"`);
      } else {
        fail('Wrong error code: ' + error.response?.status);
      }
    }

  } catch (error: any) {
    fail('Scenario B setup failed: ' + (error.response?.data?.error ?? error.message));
  }

  // ── SCENARIO C: Get Resolution Details ─────────────────
  section('SCENARIO C: Get Resolution Details');

  if (betId) {
    try {
      const res = await axios.get<{
        resolution: {
          resolutionId: string;
          outcome: string;
          resolvedBy: string;
          resolvedAt: string;
        } | null;
      }>(
        `${API}/bets/${betId}/resolution`,
        { headers: { Authorization: `Bearer ${user1Token}` } }
      );

      if (res.data.resolution && res.data.resolution.outcome === 'yes') {
        pass('Resolution details fetched');
        console.log(`   Outcome: ${res.data.resolution.outcome}`);
        console.log(`   Resolved by: ${res.data.resolution.resolvedBy}`);
        console.log(`   Resolved at: ${new Date(res.data.resolution.resolvedAt).toLocaleString()}`);
      } else {
        fail('Resolution not found or incorrect');
      }

    } catch (error: any) {
      fail('Failed to fetch resolution: ' + (error.response?.data?.error ?? error.message));
    }
  } else {
    fail('No betId from Scenario A');
  }

  // ── Summary ─────────────────────────────────────────────
  console.log('\n' + '═'.repeat(70));
  console.log('📊 TEST SUMMARY');
  console.log('═'.repeat(70));
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);

  if (failed === 0) {
    console.log('\n🎉 ALL TESTS PASSED!');
    console.log('   Resolution & payout system is working correctly.');
    console.log('   Pari-mutuel math verified.');
    console.log('   Stats tracking verified.\n');
    process.exit(0);
  } else {
    console.log('\n⚠️  SOME TESTS FAILED');
    console.log('   Review failures above and fix before proceeding.\n');
    process.exit(1);
  }
}

run().catch(error => {
  console.error('\n❌ Test suite crashed:', error.message);
  process.exit(1);
});

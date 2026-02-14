"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const axios_1 = __importDefault(require("axios"));
const API = 'http://localhost:3000/api';
let passed = 0;
let failed = 0;
function pass(detail) {
    passed++;
    console.log(`✅ ${detail}`);
}
function fail(detail) {
    failed++;
    console.log(`❌ ${detail}`);
}
function section(title) {
    console.log(`\n📝 ${title}`);
    console.log('─'.repeat(70));
}
async function run() {
    console.log('\n🧪 PROOF SUBMISSION TEST SUITE\n');
    console.log(`Testing against: ${API}\n`);
    console.log('═'.repeat(70));
    // ── Setup ───────────────────────────────────────────────
    console.log('\n🔐 SETUP: Login and create bet...');
    console.log('─'.repeat(70));
    let token;
    let token2;
    let betId;
    let userName;
    const chatId = 'test_chat_main';
    // Login user 1 (bet creator)
    try {
        const { data } = await axios_1.default.post(`${API}/auth/dev-login`, { userId: 'test_user_me' });
        token = data.token;
        userName = data.user.firstName;
        pass(`Logged in as: ${userName}`);
        console.log(`   User ID: test_user_me`);
    }
    catch (err) {
        fail('Login failed: ' + (err.response?.data?.error ?? err.message));
        process.exit(1);
    }
    // Login user 2 (for authorization tests)
    try {
        const { data } = await axios_1.default.post(`${API}/auth/dev-login`, { userId: 'test_user_alice' });
        token2 = data.token;
        pass(`Logged in second user: ${data.user.firstName}`);
    }
    catch (err) {
        fail('Second login failed');
        process.exit(1);
    }
    // Create a self bet
    try {
        const deadline = new Date();
        deadline.setHours(deadline.getHours() + 6);
        const { data } = await axios_1.default.post(`${API}/bets/create`, {
            chatId,
            betType: 'self',
            description: 'I will go to the gym today',
            deadline: deadline.toISOString()
        }, { headers: { Authorization: `Bearer ${token}` } });
        betId = data.bet.betId;
        pass(`Created self bet: ${betId}`);
    }
    catch (err) {
        fail('Failed to create bet: ' + (err.response?.data?.error ?? err.message));
        process.exit(1);
    }
    // ── TEST 1: Get presigned URL ───────────────────────────
    section('TEST 1: Get Presigned URL for Upload');
    let uploadUrl;
    let publicUrl;
    let mediaKey;
    try {
        const { data } = await axios_1.default.post(`${API}/upload/presigned-url`, { fileType: 'jpg', folder: 'bet-proofs' });
        uploadUrl = data.uploadUrl;
        publicUrl = data.publicUrl;
        mediaKey = data.key;
        pass('Presigned URL generated');
        console.log(`   Key: ${mediaKey}`);
        console.log(`   Public URL: ${publicUrl.substring(0, 60)}...`);
    }
    catch (err) {
        fail('Failed to get presigned URL: ' + (err.response?.data?.error ?? err.message));
        process.exit(1);
    }
    // ── TEST 2: Submit proof (happy path) ───────────────────
    section('TEST 2: Submit Proof for Bet');
    let proofId = '';
    try {
        const { data } = await axios_1.default.post(`${API}/bets/${betId}/proof`, {
            mediaType: 'photo',
            mediaUrl: publicUrl,
            mediaKey: mediaKey,
            caption: 'Here I am at the gym!'
        }, { headers: { Authorization: `Bearer ${token}` } });
        proofId = data.proof.proofId;
        pass('Proof submitted successfully');
        console.log(`   Proof ID: ${proofId}`);
        console.log(`   Caption: "${data.proof.caption}"`);
    }
    catch (err) {
        fail('Failed to submit proof: ' + (err.response?.data?.error ?? err.message));
    }
    // ── TEST 3: Get bet proofs ──────────────────────────────
    section('TEST 3: Get All Proofs for Bet');
    try {
        const { data } = await axios_1.default.get(`${API}/bets/${betId}/proofs`, { headers: { Authorization: `Bearer ${token}` } });
        if (data.count === 1 && data.proofs[0].proofId === proofId) {
            pass('Fetched proofs successfully');
            console.log(`   Count: ${data.count}`);
            console.log(`   First proof: ${data.proofs[0].mediaType}`);
        }
        else {
            fail(`Expected 1 proof, got ${data.count}`);
        }
    }
    catch (err) {
        fail('Failed to get proofs: ' + (err.response?.data?.error ?? err.message));
    }
    // ── TEST 4: Submit second proof ─────────────────────────
    section('TEST 4: Submit Second Proof (Multiple Allowed)');
    try {
        // Get another presigned URL
        const urlRes = await axios_1.default.post(`${API}/upload/presigned-url`, { fileType: 'jpg', folder: 'bet-proofs' });
        const { data } = await axios_1.default.post(`${API}/bets/${betId}/proof`, {
            mediaType: 'photo',
            mediaUrl: urlRes.data.publicUrl,
            mediaKey: urlRes.data.key,
            caption: 'Another angle of my workout'
        }, { headers: { Authorization: `Bearer ${token}` } });
        pass('Second proof submitted');
        console.log(`   Proof ID: ${data.proof.proofId}`);
        // Verify count
        const proofsRes = await axios_1.default.get(`${API}/bets/${betId}/proofs`, { headers: { Authorization: `Bearer ${token}` } });
        if (proofsRes.data.count === 2) {
            pass('Multiple proofs allowed (count: 2)');
        }
        else {
            fail(`Expected 2 proofs, got ${proofsRes.data.count}`);
        }
    }
    catch (err) {
        fail('Failed to submit second proof: ' + (err.response?.data?.error ?? err.message));
    }
    // ── TEST 5: Authorization check ─────────────────────────
    section('TEST 5: Non-Creator Cannot Submit Proof for Self Bet');
    try {
        const urlRes = await axios_1.default.post(`${API}/upload/presigned-url`, { fileType: 'jpg', folder: 'bet-proofs' });
        await axios_1.default.post(`${API}/bets/${betId}/proof`, {
            mediaType: 'photo',
            mediaUrl: urlRes.data.publicUrl,
            mediaKey: urlRes.data.key
        }, { headers: { Authorization: `Bearer ${token2}` } });
        fail('Should have rejected unauthorized proof submission');
    }
    catch (err) {
        if (err.response?.status === 400 && err.response.data.error.includes('Only the bet creator')) {
            pass('Correctly rejected unauthorized submission (400)');
            console.log(`   Error: "${err.response.data.error}"`);
        }
        else {
            fail(`Wrong response: ${err.response?.status}`);
        }
    }
    // ── TEST 6: Delete own proof ────────────────────────────
    section('TEST 6: Delete Own Proof');
    try {
        await axios_1.default.delete(`${API}/bets/proofs/${proofId}`, { headers: { Authorization: `Bearer ${token}` } });
        pass('Proof deleted successfully');
        // Verify count decreased
        const proofsRes = await axios_1.default.get(`${API}/bets/${betId}/proofs`, { headers: { Authorization: `Bearer ${token}` } });
        if (proofsRes.data.count === 1) {
            pass('Proof count decreased to 1');
        }
        else {
            fail(`Expected 1 proof after deletion, got ${proofsRes.data.count}`);
        }
    }
    catch (err) {
        fail('Failed to delete proof: ' + (err.response?.data?.error ?? err.message));
    }
    // ── TEST 7: Cannot delete others' proofs ────────────────
    section('TEST 7: Cannot Delete Other User\'s Proof');
    // Get the remaining proof ID
    let remainingProofId;
    try {
        const proofsRes = await axios_1.default.get(`${API}/bets/${betId}/proofs`, { headers: { Authorization: `Bearer ${token}` } });
        remainingProofId = proofsRes.data.proofs[0].proofId;
    }
    catch (err) {
        fail('Failed to get remaining proof');
        process.exit(1);
    }
    try {
        await axios_1.default.delete(`${API}/bets/proofs/${remainingProofId}`, { headers: { Authorization: `Bearer ${token2}` } });
        fail('Should have rejected deleting others\' proof');
    }
    catch (err) {
        if (err.response?.status === 403) {
            pass('Correctly rejected deletion of others\' proof (403)');
            console.log(`   Error: "${err.response.data.error}"`);
        }
        else {
            fail(`Wrong response: ${err.response?.status}`);
        }
    }
    // ── TEST 8: Missing fields ──────────────────────────────
    section('TEST 8: Missing Required Fields');
    try {
        await axios_1.default.post(`${API}/bets/${betId}/proof`, { mediaType: 'photo' }, // Missing mediaUrl and mediaKey
        { headers: { Authorization: `Bearer ${token}` } });
        fail('Should have rejected missing fields');
    }
    catch (err) {
        if (err.response?.status === 400) {
            pass('Correctly rejected missing fields (400)');
            console.log(`   Error: "${err.response.data.error}"`);
        }
        else {
            fail(`Wrong response: ${err.response?.status}`);
        }
    }
    // ── TEST 9: Invalid mediaType ───────────────────────────
    section('TEST 9: Invalid Media Type');
    try {
        const urlRes = await axios_1.default.post(`${API}/upload/presigned-url`, { fileType: 'jpg', folder: 'bet-proofs' });
        await axios_1.default.post(`${API}/bets/${betId}/proof`, {
            mediaType: 'audio', // Invalid
            mediaUrl: urlRes.data.publicUrl,
            mediaKey: urlRes.data.key
        }, { headers: { Authorization: `Bearer ${token}` } });
        fail('Should have rejected invalid mediaType');
    }
    catch (err) {
        if (err.response?.status === 400) {
            pass('Correctly rejected invalid mediaType (400)');
            console.log(`   Error: "${err.response.data.error}"`);
        }
        else {
            fail(`Wrong response: ${err.response?.status}`);
        }
    }
    // ── Summary ─────────────────────────────────────────────
    console.log('\n' + '═'.repeat(70));
    console.log('📊 TEST SUMMARY');
    console.log('═'.repeat(70));
    console.log(`✅ Passed: ${passed}`);
    console.log(`❌ Failed: ${failed}`);
    if (failed === 0) {
        console.log('\n🎉 ALL TESTS PASSED!');
        console.log('   Proof submission system is working correctly.\n');
    }
    else {
        console.log(`\n❌ ${failed} test(s) failed.\n`);
    }
    process.exit(failed === 0 ? 0 : 1);
}
run().catch((err) => {
    console.error('❌ Test suite crashed:', err.message);
    process.exit(1);
});
//# sourceMappingURL=test-proof-submission.js.map
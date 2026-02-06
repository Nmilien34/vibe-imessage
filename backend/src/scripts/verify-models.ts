import {
  Bet,
  BetParticipant,
  BetProof,
  BetResolution,
  AuraTransaction,
  TeaSpill,
  TeaGuess,
  ChatMember,
  UserConnection,
  VisibilityPermission,
  JoinRequest,
  JoinRequestVote
} from '../models';

async function verifyModels() {
  console.log('Verifying all models export correctly...\n');

  const models: Record<string, unknown> = {
    Bet,
    BetParticipant,
    BetProof,
    BetResolution,
    AuraTransaction,
    TeaSpill,
    TeaGuess,
    ChatMember,
    UserConnection,
    VisibilityPermission,
    JoinRequest,
    JoinRequestVote
  };

  for (const [name, Model] of Object.entries(models)) {
    if (!Model) {
      console.error(`FAIL ${name} — undefined`);
      process.exit(1);
    }

    if (typeof Model !== 'function') {
      console.error(`FAIL ${name} — not a constructor`);
      process.exit(1);
    }

    console.log(`OK   ${name}`);
  }

  console.log('\nAll 12 models verified');
}

verifyModels();

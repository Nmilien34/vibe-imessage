"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const models_1 = require("../models");
async function verifyModels() {
    console.log('Verifying all models export correctly...\n');
    const models = {
        Bet: models_1.Bet,
        BetParticipant: models_1.BetParticipant,
        BetProof: models_1.BetProof,
        BetResolution: models_1.BetResolution,
        AuraTransaction: models_1.AuraTransaction,
        TeaSpill: models_1.TeaSpill,
        TeaGuess: models_1.TeaGuess,
        ChatMember: models_1.ChatMember,
        UserConnection: models_1.UserConnection,
        VisibilityPermission: models_1.VisibilityPermission,
        JoinRequest: models_1.JoinRequest,
        JoinRequestVote: models_1.JoinRequestVote
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
//# sourceMappingURL=verify-models.js.map
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const s3Upload_1 = require("../utils/s3Upload");
const router = express_1.default.Router();
const validTypes = ['mp4', 'mov', 'jpg', 'jpeg', 'png', 'gif'];
router.post('/presigned-url', async (req, res) => {
    try {
        const { fileType, folder } = req.body;
        if (!fileType) {
            return res.status(400).json({ error: 'fileType is required' });
        }
        if (!validTypes.includes(fileType.toLowerCase())) {
            return res.status(400).json({ error: 'Invalid file type' });
        }
        const { uploadUrl, publicUrl, key } = await (0, s3Upload_1.getUploadUrl)(fileType, folder || 'vibes');
        res.json({ uploadUrl, publicUrl, key });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        res.status(500).json({ error: message });
    }
});
exports.default = router;
//# sourceMappingURL=upload.js.map
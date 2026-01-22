const express = require('express');
const router = express.Router();
const { getUploadUrl } = require('../utils/s3Upload');

// Get a presigned URL for uploading media
router.post('/presigned-url', async (req, res) => {
  try {
    const { fileType, folder } = req.body;

    if (!fileType) {
      return res.status(400).json({ error: 'fileType is required' });
    }

    const validTypes = ['mp4', 'mov', 'jpg', 'jpeg', 'png', 'gif'];
    if (!validTypes.includes(fileType.toLowerCase())) {
      return res.status(400).json({ error: 'Invalid file type' });
    }

    const { uploadUrl, publicUrl, key } = await getUploadUrl(
      fileType,
      folder || 'vibes'
    );

    res.json({ uploadUrl, publicUrl, key });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

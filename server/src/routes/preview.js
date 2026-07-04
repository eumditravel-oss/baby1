const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

router.post('/preview-hook', upload.single('audio'), async (req, res) => {
  try {
    const isMock = process.env.USE_MOCK_API === 'true';
    
    // Clean up uploaded file
    if (req.file) {
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
    }

    if (isMock) {
      console.log('[MOCK] Returning dummy preview audio');
      const baseUrl = req.protocol + '://' + req.get('host');
      return res.json({ 
        url: `${baseUrl}/public/assets/mock.mp3` 
      });
    }

    // Real API Call Logic would go here
    return res.status(501).json({ error: "Real ElevenLabs API integration pending." });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

module.exports = router;

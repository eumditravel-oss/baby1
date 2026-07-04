const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const FormData = require('form-data');
const axios = require('axios');

const upload = multer({ dest: path.join(__dirname, '../../public/uploads/') });

router.get('/voices', (req, res) => {
  try {
    const configPath = path.join(__dirname, '../../config/voices_config.json');
    if (!fs.existsSync(configPath)) {
      return res.status(404).json({ error: "Voices config not found" });
    }
    
    const configData = fs.readFileSync(configPath, 'utf8');
    const voices = JSON.parse(configData);
    
    res.json(voices);
  } catch (error) {
    console.error('Error reading voices config:', error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

router.post('/voice/clone', upload.single('audio'), async (req, res) => {
  try {
    const { name, consent } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ error: "Audio file is required" });
    }
    if (consent !== 'true') {
      return res.status(400).json({ error: "Consent is required" });
    }

    const useMock = process.env.USE_MOCK_API === 'true';

    if (useMock) {
      console.log(`[MOCK] Cloning voice for ${name}...`);
      // Simulate delay
      await new Promise(resolve => setTimeout(resolve, 2000));
      const fakeVoiceId = `mock_voice_${Date.now()}`;
      
      // Clean up uploaded file
      if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
      
      return res.json({ voice_id: fakeVoiceId });
    }

    // Actual ElevenLabs IVC Call
    const apiKey = process.env.ELEVENLABS_API_KEY;
    if (!apiKey) {
      throw new Error("ELEVENLABS_API_KEY is missing");
    }

    const form = new FormData();
    form.append('name', name);
    form.append('files', fs.createReadStream(file.path), file.originalname);

    const response = await axios.post('https://api.elevenlabs.io/v1/voices/add', form, {
      headers: {
        'xi-api-key': apiKey,
        ...form.getHeaders()
      }
    });

    // Clean up uploaded file
    if (fs.existsSync(file.path)) fs.unlinkSync(file.path);

    res.json({ voice_id: response.data.voice_id });

  } catch (error) {
    console.error('Error cloning voice:', error.response?.data || error.message);
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    res.status(500).json({ error: "Failed to clone voice" });
  }
});

module.exports = router;

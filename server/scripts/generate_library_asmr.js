const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { processStoryAudio } = require('../src/audioProcessor');

const JSON_PATH = path.join(__dirname, '../../app/assets/data/stories_v2.json');
const AUDIO_DIR = path.join(__dirname, '../../app/assets/audio');
const API_KEY = process.env.ELEVENLABS_API_KEY;

async function generateLibraryASMR() {
  if (!API_KEY) {
    console.error('Error: ELEVENLABS_API_KEY is missing');
    process.exit(1);
  }

  const rawData = fs.readFileSync(JSON_PATH, 'utf8');
  const data = JSON.parse(rawData);
  const stories = data.stories.slice(10); // 11번 동화부터 끝까지
  
  const narratorProfile = data.voice_profiles.narrator_warm;
  const voiceId = narratorProfile.voice_id; // 5n5gqmaQi9Ewevrz7bOS
  const voiceSettings = narratorProfile.voice_settings;
  const modelId = narratorProfile.model_id;

  console.log(`Starting generation for 10 stories with voice: ${voiceId} (ASMR)`);

  if (!fs.existsSync(AUDIO_DIR)) {
    fs.mkdirSync(AUDIO_DIR, { recursive: true });
  }

  for (const story of stories) {
    const text = story.tts_text || story.content || story.desc;
    const finalName = `${story.id}.mp3`;
    const outputPath = path.join(AUDIO_DIR, finalName);
    const rawOutputPath = path.join(AUDIO_DIR, `raw_${finalName}`);

    console.log(`\n[${story.id}] Generating...`);

    // MOCK_API 체크 (크레딧 낭비 방지용)
    if (process.env.USE_MOCK_API === 'true') {
      console.log(`[MOCK] Skipping real API call for ${story.id}`);
      fs.writeFileSync(outputPath, "dummy audio content");
      continue;
    }

    try {
      // 1. Generate audio from ElevenLabs
      const response = await axios.post(
        `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
        {
          text: text,
          model_id: modelId,
          voice_settings: voiceSettings
        },
        {
          headers: {
            'Accept': 'audio/mpeg',
            'xi-api-key': API_KEY,
            'Content-Type': 'application/json'
          },
          responseType: 'arraybuffer'
        }
      );

      fs.writeFileSync(rawOutputPath, response.data);

      // 2. Post-processing (trim, fade out, normalize)
      console.log(`[${story.id}] Processing audio (LUFS & Trim)...`);
      await processStoryAudio(rawOutputPath, outputPath);

      if (fs.existsSync(rawOutputPath)) {
        fs.unlinkSync(rawOutputPath);
      }

      console.log(`✅ Success: ${finalName}`);
    } catch (error) {
      console.error(`❌ Failed to generate audio for ${story.id}:`);
      if (error.response) {
        console.error(`HTTP ${error.response.status}:`, error.response.data.toString('utf8'));
      } else {
        console.error(error.message);
      }
    }
  }

  console.log('\n🎉 ASMR Library generation completed!');
}

generateLibraryASMR();

const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const JSON_PATH = path.join(__dirname, '../../app/assets/data/sleep_stories.json');
const AUDIO_DIR = path.join(__dirname, '../../app/assets/audio');
const API_KEY = process.env.ELEVENLABS_API_KEY; // Ensure this is in .env

const DEFAULT_VOICE_ID = 'Q1wB6QOqrVg9MQRdXb6n'; // Working voice ID

async function buildAudioAssets() {
  if (!API_KEY) {
    console.error('Error: ELEVENLABS_API_KEY is not defined in server/.env');
    process.exit(1);
  }

  const rawData = fs.readFileSync(JSON_PATH, 'utf8');
  const stories = JSON.parse(rawData);

  console.log(`Loaded ${stories.length} stories. Starting audio generation...`);

  if (!fs.existsSync(AUDIO_DIR)) {
    fs.mkdirSync(AUDIO_DIR, { recursive: true });
  }

  for (const story of stories) {
    const text = story.content || story.desc;
    if (!text) {
      console.log(`Skipping ${story.id}: No content or description.`);
      continue;
    }

    const voiceId = story.voiceId || DEFAULT_VOICE_ID;
    const outputPath = path.join(AUDIO_DIR, `${story.id}.mp3`);

    console.log(`\nGenerating audio for ${story.id}...`);
    console.log(`- Voice ID: ${voiceId}`);
    console.log(`- Output: ${outputPath}`);

    try {
      const response = await axios.post(
        `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
        {
          text: text,
          model_id: 'eleven_multilingual_v2',
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.75,
            style: 0.0,
            use_speaker_boost: true
          }
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

      fs.writeFileSync(outputPath, response.data);
      console.log(`✅ Success: Saved ${story.id}.mp3`);
    } catch (error) {
      console.error(`❌ Failed to generate audio for ${story.id}:`);
      if (error.response) {
        console.error(`HTTP ${error.response.status}:`, error.response.data.toString('utf8'));
      } else {
        console.error(error.message);
      }
    }
    
    // Add a small delay to avoid hitting rate limits
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  console.log('\n🎉 Audio generation completed!');
}

buildAudioAssets();

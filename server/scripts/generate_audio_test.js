const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const jsonPath = path.join(__dirname, '../../app/assets/data/sleep_stories.json');
const audioDir = path.join(__dirname, '../../app/assets/audio');

// Define default ElevenLabs voices if mapping is missing
const voiceMap = {
  'std_01': 'EXAVITQu4vr4xnSDxMaL', // Bella (Works)
  'std_02': 'EXAVITQu4vr4xnSDxMaL',
};

async function delay(ms) {
  return new Promise(res => setTimeout(res, ms));
}

async function run() {
  console.log('Loading stories from JSON...');
  let stories = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  
  // Only process the first 3 stories for the test
  const numToTest = 3;
  
  for (let i = 0; i < numToTest; i++) {
    const story = stories[i];
    const text = story.content || story.desc || '';
    const filename = `story_${story.id}.mp3`;
    const filepath = path.join(audioDir, filename);

    if (fs.existsSync(filepath)) {
      console.log(`[${i+1}/${numToTest}] Skipping ${story.title}, audio already exists.`);
      continue;
    }

    console.log(`[${i+1}/${numToTest}] Generating audio for: ${story.title}`);
    try {
      const elevenVoiceId = voiceMap['std_01']; 

      const ttsResponse = await axios.post(
        `https://api.elevenlabs.io/v1/text-to-speech/${elevenVoiceId}`,
        {
          text: text,
          model_id: "eleven_multilingual_v2",
          voice_settings: { stability: 0.7, similarity_boost: 0.8 }
        },
        {
          headers: {
            'Accept': 'audio/mpeg',
            'xi-api-key': process.env.ELEVENLABS_API_KEY,
            'Content-Type': 'application/json',
          },
          responseType: 'arraybuffer'
        }
      );

      fs.writeFileSync(filepath, ttsResponse.data);
      console.log(`Successfully saved ${filename}. Waiting 3 seconds...`);
      
      await delay(3000); // 3 seconds delay to avoid rate limiting
    } catch (e) {
      console.error(`Failed for ${story.title}:`, e.response?.data?.toString() || e.message);
    }
  }
  console.log('Test generation done!');
}

run();

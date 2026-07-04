const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const jsonPath = path.join(__dirname, '../../app/assets/data/sleep_stories.json');
const audioDir = path.join(__dirname, '../../app/assets/audio');

// 3 Soft/Calm Voices to test
const candidateVoices = [
  { id: '21m00Tcm4TlvDq8ikWAM', name: 'Rachel' }, // Calm Narration
  { id: 'MF3mGyEYCl7XYWbV9V6O', name: 'Elli' },   // Emotional, soft
  { id: 'SAz9YHcvj6GT2YYXdXww', name: 'River' }   // Relaxed, calm
];

function processTextForCalmReading(text) {
  // 1. Add longer pauses at the end of sentences
  let processed = text.replace(/\. /g, '. ... ');
  // 2. Add extra pauses at paragraph breaks
  processed = processed.replace(/\n\n/g, '\n\n ... ');
  // 3. Make commas have slightly longer pauses
  processed = processed.replace(/, /g, ', .. ');
  return processed;
}

async function run() {
  console.log('Loading stories from JSON...');
  let stories = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  
  // Test only Story 1
  const story = stories[0];
  const originalText = story.content || story.desc || '';
  const calmText = processTextForCalmReading(originalText);

  for (const voice of candidateVoices) {
    const filename = `story_${story.id}_${voice.name}.mp3`;
    const filepath = path.join(audioDir, filename);

    console.log(`Generating audio for: ${voice.name}...`);
    try {
      const ttsResponse = await axios.post(
        `https://api.elevenlabs.io/v1/text-to-speech/${voice.id}`,
        {
          text: calmText,
          model_id: "eleven_multilingual_v2",
          voice_settings: { 
            stability: 0.35,       // Lower stability = less robotic, more emotive
            similarity_boost: 0.85, // High similarity = keeps original human-like cadence
            style: 0.2,            // Exaggerate style slightly
            use_speaker_boost: true
          }
        },
        {
          headers: {
            'Accept': 'audio/mpeg',
            'xi-api-key': process.env.ELEVENLABS_API_KEY.trim(),
            'Content-Type': 'application/json',
          },
          responseType: 'arraybuffer'
        }
      );

      fs.writeFileSync(filepath, ttsResponse.data);
      console.log(`Successfully saved ${filename}.`);
      await new Promise(res => setTimeout(res, 3000));
    } catch (e) {
      console.error(`Failed for ${voice.name}:`, e.response?.data?.toString() || e.message);
    }
  }
  console.log('Voice test generation done!');
}

run();

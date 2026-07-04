const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const StoryProcessor = require('../src/storyProcessor');

const jsonPath = path.join(__dirname, '../../app/assets/data/sleep_stories.json');
const audioDir = path.join(__dirname, '../../app/assets/audio');

const processor = new StoryProcessor(jsonPath);

// 사용자가 지정한 보이스 매핑
const customVoices = {
  'story_01': 'jhRwPcHZjcfER84hHhYm',
  'story_02': '5n5gqmaQi9Ewevrz7bOS',
  'story_03': '1AamIfcz4K3qg7gQ6NhP',
  'story_04': 'BNr4zvrC1bGIdIstzjFQ',
  'story_05': 'v1jVu1Ky28piIPEJqRrm'
};

async function run() {
  console.log('Loading Story Processor (Human Realism Tone)...');
  const stories = processor.loadStories();
  
  // Test only story_05
  for (let i = 4; i < 5; i++) {
    const storyId = stories[i].id;
    const rawText = processor.getStoryText(storyId);
    
    // 1. 사람 호흡 전처리 (물음표/느낌표 복원으로 문맥 유지)
    const processedText = processor.applySleepTone(rawText);
    console.log(`\n[Story ${storyId}] Original length: ${rawText.length}, Processed length: ${processedText.length}`);

    // 2. 인간적인 파라미터 (stability 0.45 등)
    const voiceSettings = processor.getVoiceSettings();
    const VOICE_ID = customVoices[storyId];

    // 3. 파일명 유지 (UI수정 없이 바로 듣도록 덮어쓰기)
    const filename = `story_${storyId}_ASMR.mp3`;
    const filepath = path.join(audioDir, filename);

    console.log(`Generating audio for ${storyId} with Voice ID ${VOICE_ID}...`);
    try {
      const ttsResponse = await axios.post(
        `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`,
        {
          text: processedText,
          model_id: "eleven_multilingual_v2",
          voice_settings: voiceSettings
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
      console.error(`Failed for ${storyId}:`, e.response?.data?.toString() || e.message);
    }
  }
  console.log('Custom Voice generation done!');
}

run();

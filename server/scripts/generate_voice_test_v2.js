const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const StoryProcessor = require('../src/storyProcessor');

const jsonPath = path.join(__dirname, '../../app/assets/data/sleep_stories.json');
const audioDir = path.join(__dirname, '../../app/assets/audio');

const processor = new StoryProcessor(jsonPath);

// 사용자가 지정한 고정 보이스 ID (Bella)
const VOICE_ID = processor.getDefaultVoiceId(); 

async function run() {
  console.log('Loading Story Processor (Kindergarten Teacher Tone)...');
  const stories = processor.loadStories();
  
  // Test story_06 specifically
  const storyId = 'story_06';
  const rawText = processor.getStoryText(storyId);
  
  // 1. 텍스트 전처리 적용 (applyKindergartenTeacherTone)
  const processedText = processor.applyKindergartenTeacherTone(rawText);
  console.log(`\n[Story ${storyId}] Original length: ${rawText.length}, Processed length: ${processedText.length}`);
  console.log(`\n[Processed Text Sample]\n${processedText}\n`);

  // 2. 고정 파라미터 가져오기
  const voiceSettings = processor.getVoiceSettings();

  // 3. 파일명 변경 (앱 캐시를 우회하기 위해 새 이름 사용)
  const filename = `story_${storyId}_KINDER.mp3`;
  const filepath = path.join(audioDir, filename);

  console.log(`Generating audio for ${storyId}...`);
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
  } catch (e) {
    console.error(`Failed for ${storyId}:`, e.response?.data?.toString() || e.message);
  }
  console.log('Kids Audiobook Tone test generation done!');
}

run();

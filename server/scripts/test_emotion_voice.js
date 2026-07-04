const fs = require('fs');
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { processStoryAudio } = require('../src/audioProcessor');

const AUDIO_DIR = path.join(__dirname, '../../app/assets/audio/test');
const API_KEY = process.env.ELEVENLABS_API_KEY;

const voiceId = "5n5gqmaQi9Ewevrz7bOS"; // ASMR voice

const originalText = `우와! 하늘 높은 곳, 구름으로 만들어진 솜사탕 마을이에요! 짠! 여기에 작고 포동포동한, 곰돌이 뭉게가 살고 있었답니다! 뭉게의 집은요, 하얀 구름 침대가 있는, 너무 포근한 곳이었어요! <break time="1.2s" /> 어머나! 어느 날 저녁이었어요. 달님이 뭉게의 창문을, 똑똑! 하고 살며시 두드렸죠! "자 뭉게야! 오늘 밤, 나랑 같이 마을을 한 바퀴 걸을래?" 헤헤! 달님의 목소리는요, 따뜻한 꿀처럼 아주 달콤했어요!`;

// Variation 1: Lower stability, higher style
const var1Settings = {
  stability: 0.3,
  similarity_boost: 0.8,
  style: 0.75,
  use_speaker_boost: true
};

// Variation 2: Much lower stability, moderate style + modified text with extreme punctuation
const var2Settings = {
  stability: 0.2,
  similarity_boost: 0.8,
  style: 0.6,
  use_speaker_boost: true
};
const var2Text = `우와아!!! 하늘 높은 곳, 구름으로 만들어진 솜사탕 마을이에요! 짠!! 여기에 작고 포동포동한, 곰돌이 뭉게가 살고 있었답니다! 뭉게의 집은요, 하얀 구름 침대가 있는, 너무 포근한 곳이었어요! <break time="1.2s" /> 어머나! 어느 날 저녁이었어요. 달님이 뭉게의 창문을, 똑똑! 하고 살며시 두드렸죠! <break time="0.5s" /> "자, 뭉게야!! 오늘 밤, 나랑 같이 마을을 한 바퀴 걸을래?!" <break time="0.5s" /> 헤헤! 달님의 목소리는요, 따뜻한 꿀처럼 아주 달콤했어요!`;

async function generateTest(name, text, settings) {
  const finalName = `${name}.mp3`;
  const outputPath = path.join(AUDIO_DIR, finalName);
  const rawOutputPath = path.join(AUDIO_DIR, `raw_${finalName}`);

  console.log(`\nGenerating ${name}...`);
  try {
    const response = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        text: text,
        model_id: 'eleven_multilingual_v2',
        voice_settings: settings
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
    await processStoryAudio(rawOutputPath, outputPath);
    if (fs.existsSync(rawOutputPath)) fs.unlinkSync(rawOutputPath);
    console.log(`✅ Success: ${finalName}`);
  } catch (error) {
    console.error(`❌ Failed:`, error.message);
  }
}

async function run() {
  if (!fs.existsSync(AUDIO_DIR)) fs.mkdirSync(AUDIO_DIR, { recursive: true });
  await generateTest('test_emotion_var1', originalText, var1Settings);
  await generateTest('test_emotion_var2', var2Text, var2Settings);
}

run();

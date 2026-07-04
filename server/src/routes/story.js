const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const axios = require('axios');
const { processStoryAudio } = require('../audioProcessor');
const authMiddleware = require('../middleware/auth');
const { generateSignedUrl } = require('../utils/signedUrl');

// v2.1: Load voice profiles
let voiceProfiles = {};
const storiesPath = path.join(__dirname, '../../public/assets/data/stories_v2.json');
try {
  if (fs.existsSync(storiesPath)) {
    const data = JSON.parse(fs.readFileSync(storiesPath, 'utf8'));
    if (data.voice_profiles) {
      voiceProfiles = data.voice_profiles;
    }
  }
} catch (e) {
  console.error('Failed to load stories_v2.json', e);
}

// v2.1: auth 미들웨어 추가 및 req.body.isSubscribed 제거
router.post('/story/generate', authMiddleware, async (req, res) => {
  try {
    const { voice_id, story_id } = req.body;
    const userId = req.user.id;
    const isSubscribed = req.user.isSubscribed;

    if (!voice_id || !story_id) {
      return res.status(400).json({ error: "voice_id and story_id are required" });
    }

    const outputFileName = `${voice_id}_${story_id}.mp3`;
    const outputPath = path.join(__dirname, '../../public/outputs', outputFileName);
    const rawOutputPath = path.join(__dirname, '../../public/outputs', `raw_${outputFileName}`);

    // N5: 나레이터 프로필 키 기반 생성 자격 검증 (캐시 히트 전에 수행)
    // narrator_ 접두사 키가 아니면 커스텀 voice → 구독자만 허용
    let profileKey = Object.keys(voiceProfiles).find(k => voiceProfiles[k].voice_id === voice_id);
    const isNarratorProfile = profileKey && profileKey.startsWith('narrator_');
    if (!isNarratorProfile && !isSubscribed) {
      return res.status(403).json({ error: "Subscription required to use custom voice" });
    }

    // 1. 영구 캐시 확인: 이미 생성된 파일이 있다면 즉시 반환
    if (fs.existsSync(outputPath)) {
      console.log(`[CACHE HIT] Returning existing story for ${voice_id}_${story_id}`);
      return res.json({ url: generateSignedUrl(outputFileName) }); // v2.1: N4 서명 URL로 반환
    }

    // 2. 동화 텍스트 조회
    let ttsText = "안녕하세요, 오류가 발생했습니다.";
    if (fs.existsSync(storiesPath)) {
      const data = JSON.parse(fs.readFileSync(storiesPath, 'utf8'));
      const story = data.stories?.find(s => s.id === story_id);
      if (story && story.tts_text) {
        ttsText = story.tts_text;
      }
    }

    const useMock = process.env.USE_MOCK_API === 'true';

    if (useMock) {
      console.log(`[MOCK] Generating story audio for ${voice_id}_${story_id}...`);
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      const dummySource = path.join(__dirname, '../../public/assets/audio/story_01.mp3');
      if (fs.existsSync(dummySource)) {
        fs.copyFileSync(dummySource, outputPath);
      } else {
        fs.writeFileSync(outputPath, "dummy audio content");
      }
      return res.json({ url: generateSignedUrl(outputFileName) });
    }

    // ── v2.1: 동적 Voice Settings 반영 ──
    let targetModelId = "eleven_multilingual_v2";
    let targetVoiceSettings = { stability: 0.5, similarity_boost: 0.75, style: 0.0, use_speaker_boost: true };
    
    // profileKey는 캐시 히트 전에 이미 계산됨 (N5 검증에서 사용)

    if (!profileKey && isSubscribed) {
      // 커스텀 보이스인 경우
      profileKey = 'parent_voice';
    }

    if (profileKey && voiceProfiles[profileKey]) {
      const profile = voiceProfiles[profileKey];
      targetModelId = profile.model_id || targetModelId;
      if (profile.voice_settings) {
        targetVoiceSettings = profile.voice_settings;
      }
    }

    // 3. 실제 ElevenLabs TTS API 호출
    const apiKey = process.env.ELEVENLABS_API_KEY;
    if (!apiKey) {
      throw new Error("ELEVENLABS_API_KEY is missing");
    }

    console.log(`Calling ElevenLabs for ${voice_id}_${story_id}...`);
    const response = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice_id}`,
      {
        text: ttsText,
        model_id: targetModelId,
        voice_settings: targetVoiceSettings
      },
      {
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json'
        },
        responseType: 'arraybuffer'
      }
    );

    // 4. 원본 오디오 임시 저장
    fs.writeFileSync(rawOutputPath, response.data);

    // 5. FFMPEG 후처리
    console.log(`Processing audio for ${voice_id}_${story_id}...`);
    await processStoryAudio(rawOutputPath, outputPath);

    // 6. 임시 원본 삭제
    if (fs.existsSync(rawOutputPath)) {
      fs.unlinkSync(rawOutputPath);
    }

    res.json({ url: generateSignedUrl(outputFileName) });

  } catch (error) {
    console.error('Error generating story:', error.response?.data?.toString() || error.message);
    res.status(500).json({ error: "Failed to generate story audio" });
  }
});

module.exports = router;

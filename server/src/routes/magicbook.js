const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const axios = require('axios');
const { OpenAI } = require('openai');
const { processStoryAudio } = require('../audioProcessor');
const authMiddleware = require('../middleware/auth');
const { generateSignedUrl } = require('../utils/signedUrl');

const {
  getUsageCount,
  incrementUsage,
  getRefillTickets,
  addRefillTickets,
  consumeRefillTicket
} = require('../db');

// v2.1: stories_v2.json에서 나레이터 기본값 및 프로필 읽기
let narratorVoiceId = 'zrHiDhphv9ZnVXBqCLjz'; // fallback
let voiceProfiles = {};
const storiesPath = path.join(__dirname, '../../public/assets/data/stories_v2.json');
try {
  if (fs.existsSync(storiesPath)) {
    const data = JSON.parse(fs.readFileSync(storiesPath, 'utf8'));
    if (data.voice_profiles) {
      voiceProfiles = data.voice_profiles;
      if (voiceProfiles.narrator_warm && voiceProfiles.narrator_warm.voice_id) {
        narratorVoiceId = voiceProfiles.narrator_warm.voice_id;
      }
    }
  }
} catch (e) {
  console.error('Failed to load stories_v2.json', e);
}

const MONTHLY_LIMIT = 10;

// 금칙어 필터 단순 구현 (F6 보강)
const PROFANITY_LIST = ['죽음', '피', '귀신', '괴물', '살인', '폭력', '자살', '마약', '성폭행', '납치', '유괴', '강도'];

router.post('/magicbook/generate', authMiddleware, async (req, res) => {
  try {
    const { name, event, character, voiceId, voiceName } = req.body;
    const userId = req.user.id;
    const isSubscribed = req.user.isSubscribed;

    if (!name || !voiceId) {
      return res.status(400).json({ error: "name and voiceId are required" });
    }

    // 금칙어 검사
    const contentText = `${name} ${event || ''} ${character || ''}`;
    for (const word of PROFANITY_LIST) {
      if (contentText.includes(word)) {
        return res.status(400).json({ error: 'profanity_detected', message: '적절하지 않은 단어가 포함되어 있습니다.' });
      }
    }

    // ── v2.1: 서버 측 과금 정책 강제 ──
    const currentUsage = getUsageCount(userId);
    let willConsumeTicket = false;

    if (isSubscribed) {
      // 구독자: 월 10회 체크 -> 초과시 회수권 검사
      if (currentUsage >= MONTHLY_LIMIT) {
        if (getRefillTickets(userId) <= 0) {
          return res.status(429).json({
            error: "monthly_limit_exceeded",
            message: `이번 달 마법의 책 ${MONTHLY_LIMIT}회를 모두 사용했습니다. 회수권을 구매해주세요.`,
            used: currentUsage,
            limit: MONTHLY_LIMIT,
            refillRemaining: 0
          });
        }
        willConsumeTicket = true;
      }
    } else {
      // 비구독자: 체험 1회
      if (currentUsage >= 1) {
        return res.status(429).json({
          error: "trial_limit_exceeded",
          message: "무료 체험 1회를 이미 사용했습니다. 구독하면 매달 10회 생성할 수 있어요.",
          used: currentUsage,
          limit: 1,
        });
      }
    }

    // v2.1: 비구독 체험은 나레이터 목소리로 강제 치환
    const effectiveVoiceId = isSubscribed ? voiceId : narratorVoiceId;
    const effectiveVoiceName = isSubscribed ? (voiceName || '선택한 성우') : '포근한 선생님';

    // 해당 보이스 프로필 설정 찾기
    let targetModelId = "eleven_multilingual_v2";
    let targetVoiceSettings = { stability: 0.5, similarity_boost: 0.75, style: 0.0, use_speaker_boost: true };
    
    // narrator_warm 인지 narrator_lively 인지 찾기
    let profileKey = Object.keys(voiceProfiles).find(k => voiceProfiles[k].voice_id === effectiveVoiceId);
    if (!profileKey && isSubscribed) {
      // 사용자의 커스텀 목소리인 경우 parent_voice 설정 적용
      profileKey = 'parent_voice';
    }

    if (profileKey && voiceProfiles[profileKey]) {
      const profile = voiceProfiles[profileKey];
      targetModelId = profile.model_id || targetModelId;
      if (profile.voice_settings) {
        targetVoiceSettings = profile.voice_settings;
      }
    }

    const useMock = process.env.USE_MOCK_API === 'true';
    const magicStoryId = `magic_${Date.now()}`;
    const outputFileName = `${effectiveVoiceId}_${magicStoryId}.mp3`;
    const outputPath = path.join(__dirname, '../../public/outputs', outputFileName);
    const rawOutputPath = path.join(__dirname, '../../public/outputs', `raw_${outputFileName}`);

    let generatedText = "이것은 마법의 책에서 만들어진 임시 동화입니다.";
    let generatedTitle = `${name}의 특별한 하루`;

    if (useMock) {
      console.log(`[MOCK] Generating magic story text for ${name}...`);
      await new Promise(resolve => setTimeout(resolve, 2000));
      generatedText = `${name}는 오늘 ${event || '즐거운 시간'}을 보냈어요. 꿈속에서 ${character || '귀여운 요정'}을 만나 함께 신나는 모험을 떠났답니다. 모두 함께 행복하게 웃었어요. 끝.`;
      
      console.log(`[MOCK] Generating magic story audio...`);
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      const dummySource = path.join(__dirname, '../../public/assets/audio/story_01.mp3');
      if (fs.existsSync(dummySource)) {
        fs.copyFileSync(dummySource, outputPath);
      } else {
        fs.writeFileSync(outputPath, "dummy audio content");
      }
    } else {
      // 1. OpenAI Text Generation
      const openaiKey = process.env.OPENAI_API_KEY;
      if (!openaiKey) {
        throw new Error("OPENAI_API_KEY is missing");
      }
      
      const openai = new OpenAI({ apiKey: openaiKey });
      console.log(`Calling OpenAI for magic story generation...`);
      
      const prompt = `당신은 아이들을 위한 전문 동화 작가입니다. 다음 정보를 바탕으로 짧고 재미있는 동화를 작성해주세요.
주인공 이름: ${name}
오늘 있었던 일: ${event || '특별한 일 없음'}
좋아하는 캐릭터/소재: ${character || '없음'}

조건:
- 텍스트 분량은 약 300~400자.
- 폭력적, 공포, 실존인물 관련 금칙어를 피하세요.
- 첫 줄에 제목을 적어주세요 (예: 제목: 지우의 모험)
- 아이가 들을 때 따뜻하고 포근한 느낌이 나게 해주세요.
- 물결표(~)나 말줄임표(...) 사용을 자제하고 마침표를 명확히 찍어주세요.`;

      const completion = await openai.chat.completions.create({
        messages: [{ role: "user", content: prompt }],
        model: "gpt-4o-mini",
        temperature: 0.7,
      });

      const fullText = completion.choices[0].message.content.trim();
      
      const lines = fullText.split('\n');
      if (lines[0].startsWith('제목:')) {
        generatedTitle = lines[0].replace('제목:', '').trim();
        generatedText = lines.slice(1).join('\n').trim();
      } else {
        generatedText = fullText;
      }

      // 1-2. 생성된 텍스트 필터링 (F6 보강)
      for (const word of PROFANITY_LIST) {
        if (generatedText.includes(word)) {
          console.warn(`[Profanity Filter] Generated text blocked due to word: ${word}`);
          generatedText = "오늘은 포포와 함께 포근한 구름 위를 산책했어요. 정말 평화롭고 행복한 하루였답니다.";
          break;
        }
      }

      // 2. ElevenLabs TTS Generation
      const elevenlabsKey = process.env.ELEVENLABS_API_KEY;
      if (!elevenlabsKey) {
        throw new Error("ELEVENLABS_API_KEY is missing");
      }

      console.log(`Calling ElevenLabs for magic story audio (voice: ${effectiveVoiceId})...`);
      const response = await axios.post(
        `https://api.elevenlabs.io/v1/text-to-speech/${effectiveVoiceId}`,
        {
          text: generatedText,
          model_id: targetModelId,
          voice_settings: targetVoiceSettings
        },
        {
          headers: {
            'xi-api-key': elevenlabsKey,
            'Content-Type': 'application/json'
          },
          responseType: 'arraybuffer'
        }
      );

      fs.writeFileSync(rawOutputPath, response.data);

      // 3. FFMPEG Post-processing
      console.log(`Processing magic audio...`);
      await processStoryAudio(rawOutputPath, outputPath);

      if (fs.existsSync(rawOutputPath)) {
        fs.unlinkSync(rawOutputPath);
      }
    }

    // 성공적으로 오디오 생성을 마친 후 차감 수행
    if (willConsumeTicket) {
      consumeRefillTicket(userId);
    } else {
      incrementUsage(userId);
    }

    res.json({
      id: magicStoryId,
      title: generatedTitle,
      text: generatedText,
      audioUrl: generateSignedUrl(outputFileName), // v2.1: N4 서명 URL로 반환
      imageUrl: 'https://placehold.co/600x600/6A0DAD/FFFFFF?text=Magic+Book',
      voiceName: effectiveVoiceName,
      duration: 60,
      usage: {
        used: getUsageCount(userId),
        limit: isSubscribed ? MONTHLY_LIMIT : 1,
        refillRemaining: getRefillTickets(userId)
      },
    });

  } catch (error) {
    console.error('Error generating magic story:', error.response?.data?.toString() || error.message);
    res.status(500).json({ error: "Failed to generate magic story" });
  }
});

module.exports = router;
module.exports.addRefillTickets = addRefillTickets;

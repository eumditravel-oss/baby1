const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
const ffprobePath = require('@ffprobe-installer/ffprobe').path;
const axios = require('axios');
const OpenAI = require('openai');

ffmpeg.setFfmpegPath(ffmpegPath);
ffmpeg.setFfprobePath(ffprobePath);

// Define default ElevenLabs voices if mapping is missing
const voiceMap = {
  'std_01': 'pNInz6obbfDQGcgMyIGD', // Default IDs (can be changed in env/config)
  'std_02': 'EXAVITQu4vr4xnSDxMaL',
  'custom_cloned': process.env.CUSTOM_CLONE_VOICE_ID || 'pNInz6obbfDQGcgMyIGD'
};

router.post('/generate-video', async (req, res) => {
  try {
    const isMock = process.env.USE_MOCK_API === 'true';
    const publicDir = path.join(__dirname, '../../public');
    const outputsDir = path.join(publicDir, 'outputs');
    const assetsDir = path.join(publicDir, 'assets');
    const outputFileName = `output_${Date.now()}.mp4`;
    const outputPath = path.join(outputsDir, outputFileName);
    const baseUrl = req.protocol + '://' + req.get('host');
    
    const { name, event, character, voiceId } = req.body;

    if (isMock) {
      console.log('[MOCK] Starting mock video pipeline...');
      const mockAudio = path.join(assetsDir, 'mock.mp3');
      const mockImage = path.join(assetsDir, 'mock.png');
      const lullabyAudio = path.join(assetsDir, 'lullaby.mp3');

      ffmpeg()
        .input(mockImage)
        .input(mockAudio)
        .input(lullabyAudio)
        .complexFilter([
          { filter: 'zoompan', options: 'z=\'min(zoom+0.0015,1.5)\':d=75:s=1920x1080:fps=25', inputs: '0:v', outputs: 'v_out' },
          { filter: 'volume', options: '0.1', inputs: '2:a', outputs: 'bg_music' },
          { filter: 'amix', options: 'inputs=2:duration=first:dropout_transition=2', inputs: ['1:a', 'bg_music'], outputs: 'a_out' }
        ])
        .outputOptions(['-map [v_out]', '-map [a_out]', '-c:v libx264', '-pix_fmt yuv420p', '-c:a aac', '-shortest'])
        .save(outputPath)
        .on('end', () => res.json({ url: `${baseUrl}/public/outputs/${outputFileName}`, title: '마법의 Mock 동화책' }))
        .on('error', (err) => res.status(500).json({ error: "FFmpeg Error" }));
      return;
    }

    // ================= REAL API PIPELINE =================
    console.log('[REAL] Starting AI Pipeline...');
    
    if (!process.env.OPENAI_API_KEY || !process.env.ELEVENLABS_API_KEY) {
      return res.status(500).json({ error: "API keys are missing in .env" });
    }

    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    
    // Step 1: OpenAI Text Generation
    console.log('[Step 1] Generating story text...');
    const prompt = `주인공 이름: ${name}, 오늘 있었던 일: ${event}, 좋아하는 캐릭터: ${character}. 
이 내용들을 바탕으로 아주 부드럽고 다정한 유아용 수면 동화를 1편 써줘. (약 300~400자). 
JSON 형식으로 { "title": "동화 제목", "story": "동화 본문", "imagePrompt": "Dall-E에 넣을 동화책 삽화용 영문 프롬프트" } 를 반환해.`;

    const chatCompletion = await openai.chat.completions.create({
      messages: [{ role: 'user', content: prompt }],
      model: 'gpt-4o-mini',
      response_format: { type: "json_object" },
    });

    const aiData = JSON.parse(chatCompletion.choices[0].message.content);
    const { title, story, imagePrompt } = aiData;
    console.log(`[Step 1 Done] Title: ${title}`);

    // Step 2: OpenAI Image Generation
    console.log('Generating image with DALL-E...');
    const imageResponse = await openai.images.generate({
      model: "gpt-image-2",
      prompt: `A beautiful, magical illustration for a children's bedtime story about: ${title}. ${character} is featured. Soft, dreamy colors.`,
      n: 1,
      size: "1024x1024"
    });
    const imageUrl = imageResponse.data[0].url;
    
    // Download image
    const imagePath = path.join(outputsDir, `img_${Date.now()}.png`);
    const imgBuffer = await axios.get(imageUrl, { responseType: 'arraybuffer' });
    fs.writeFileSync(imagePath, imgBuffer.data);
    console.log('[Step 2 Done] Image downloaded.');

    // Step 3: ElevenLabs TTS
    console.log('[Step 3] Generating ElevenLabs Audio...');
    const elevenVoiceId = voiceMap[voiceId] || voiceMap['std_01']; 
    const audioPath = path.join(outputsDir, `audio_${Date.now()}.mp3`);
    
    const ttsResponse = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${elevenVoiceId}`,
      {
        text: story,
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
    fs.writeFileSync(audioPath, ttsResponse.data);
    console.log('[Step 3 Done] Audio generated.');

    // Step 4: FFmpeg Merging
    console.log('[Step 4] Merging with FFmpeg...');
    const lullabyAudio = path.join(assetsDir, 'lullaby.mp3');

    ffmpeg()
      .input(imagePath)
      .input(audioPath)
      .input(lullabyAudio)
      .complexFilter([
        { filter: 'zoompan', options: 'z=\'min(zoom+0.0015,1.5)\':d=250:s=1920x1080:fps=25', inputs: '0:v', outputs: 'v_out' },
        { filter: 'volume', options: '0.1', inputs: '2:a', outputs: 'bg_music' },
        { filter: 'amix', options: 'inputs=2:duration=first:dropout_transition=2', inputs: ['1:a', 'bg_music'], outputs: 'a_out' }
      ])
      .outputOptions(['-map [v_out]', '-map [a_out]', '-c:v libx264', '-pix_fmt yuv420p', '-c:a aac', '-shortest'])
      .save(outputPath)
      .on('end', () => {
        console.log('[Step 4 Done] Pipeline Complete!');
        res.json({ 
          url: `${baseUrl}/public/outputs/${outputFileName}`,
          title: title,
          story: story,
          thumbnailUrl: `${baseUrl}/public/outputs/${path.basename(imagePath)}`
        });
      })
      .on('error', (err) => {
        console.error('[FFmpeg Error]', err);
        res.status(500).json({ error: "FFmpeg Error" });
      });

  } catch (error) {
    console.error('[API Pipeline Error]', error.response?.data || error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

router.post('/generate-audio', async (req, res) => {
  try {
    const { text, voiceId, storyId } = req.body;
    
    if (!text || !storyId) {
      return res.status(400).json({ error: "Text and storyId are required" });
    }

    const isMock = process.env.USE_MOCK_API === 'true';
    const publicDir = path.join(__dirname, '../../public');
    const outputsDir = path.join(publicDir, 'outputs');
    const outputFileName = `audio_${storyId}_${Date.now()}.mp3`;
    const audioPath = path.join(outputsDir, outputFileName);
    const baseUrl = req.protocol + '://' + req.get('host');

    if (isMock) {
      console.log('[MOCK] Skipping ElevenLabs, returning mock audio');
      const mockAudio = path.join(publicDir, 'assets', 'mock.mp3');
      fs.copyFileSync(mockAudio, audioPath);
      return res.json({ url: `${baseUrl}/public/outputs/${outputFileName}` });
    }

    console.log(`[Audio API] Requesting ElevenLabs for story: ${storyId}`);
    const elevenVoiceId = voiceMap[voiceId] || voiceId || voiceMap['std_01']; 

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
    
    fs.writeFileSync(audioPath, ttsResponse.data);
    console.log(`[Audio API] Successfully generated audio for story: ${storyId}`);
    
    res.json({ url: `${baseUrl}/public/outputs/${outputFileName}` });
  } catch (error) {
    console.error('[Audio API Error]', error.response?.data || error.message);
    res.status(500).json({ error: "Failed to generate audio" });
  }
});

module.exports = router;

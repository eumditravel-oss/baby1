const https = require('https');
const fs = require('fs');
const path = require('path');

const API_KEY = 'sk_53c3cf47cfe90011b1371f52c73b0aa1c1fae9f625ac8fb1';
const VOICE_ID = 'Q1wB6QOqrVg9MQRdXb6n';
const OUTPUT_DIR = 'C:/Users/User/.gemini/antigravity-ide/brain/6dab3922-83b8-41c9-8045-ecf98a8ea8b8/scratch';
const OUTPUT_PATH = path.join(OUTPUT_DIR, 'story_01_example.mp3');

const data = JSON.stringify({
  text: `우와! 하늘 높~은 곳, 구름으로 만들어진 솜사탕 마을이에요!
짠! 여기에 작고 포동포동~한, 곰돌이 뭉게가 살고 있었답니다!
뭉게의 집은요, 하~얀 구름 침대가 있는, 너~~무 포근한 곳이었어요!

어머나! 어느 날 저녁이었어요.
달님이 뭉게의 창문을, 똑똑! 하고 살~며시 두드렸죠!
"자~ 뭉게야! 오늘 밤, 나랑 같이 마을을 한 바퀴 걸을래~?"
헤헤! 달님의 목소리는요, 따뜻~한 꿀처럼 아~~주 달콤했어요!

뭉게는요, 폭신폭신~한 구름 길을, 달님과 함께 천천~히 걸었어요!
발밑에서는 구름이, 보송보송! 하게 느껴졌고요,
하늘에는 별들이 조용히, 반짝반짝~ 빛나고 있었답니다!
별 하나, 별 둘, 별 셋...

별을 세다 보니, 뭉게의 눈꺼풀이 조~금씩 무거워졌어요.
으쌰으쌰! 달님이 뭉게를 살~며시 안아서, 구름 침대에 눕혀 주었답니다!
"잘 자, 뭉게야~!"
달님의 목소리가, 멀~리서 들려오는 것 같았어요.
뭉게는 작게 하품을 하고는...

스르르~ 깊고 포근한 꿈나라로 떠나갔답니다! 안~녕~!`,
  model_id: 'eleven_multilingual_v2',
  voice_settings: {
    stability: 0.25,
    similarity_boost: 0.85,
    style: 0.20,
    use_speaker_boost: true
  }
});

const options = {
  hostname: 'api.elevenlabs.io',
  path: '/v1/text-to-speech/' + VOICE_ID,
  method: 'POST',
  headers: {
    'Accept': 'audio/mpeg',
    'xi-api-key': API_KEY,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
};

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

const req = https.request(options, (res) => {
  if (res.statusCode !== 200) {
    console.error('Error:', res.statusCode);
    res.on('data', d => console.error(d.toString()));
    return;
  }
  const fileStream = fs.createWriteStream(OUTPUT_PATH);
  res.pipe(fileStream);
  fileStream.on('finish', () => {
    console.log('Audio saved to', OUTPUT_PATH);
  });
});

req.on('error', (e) => {
  console.error('Problem with request:', e.message);
});

req.write(data);
req.end();

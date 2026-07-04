const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const authMiddleware = require('../middleware/auth');
const { verifySignedUrl } = require('../utils/signedUrl');

// v2.1: 보안 오디오 스트리밍 엔드포인트
// N3: 나레이터 판별을 voice_profiles의 narrator_ 키 voice_id 목록과 대조
// N4: Bearer 헤더 또는 서명 토큰 쿼리 중 하나를 검증
router.get('/audio/:filename', (req, res) => {
  const filename = req.params.filename;
  
  // 보안 검증: 상위 디렉토리 접근 차단
  if (filename.includes('..') || filename.includes('/')) {
    return res.status(403).json({ error: 'Invalid filename' });
  }

  const filePath = path.join(__dirname, '../../public/outputs', filename);

  // 파일 존재 여부 확인
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Audio file not found' });
  }

  // ── N4: 인증 분기 — Bearer 헤더 또는 서명 토큰 쿼리 ──
  const authHeader = req.headers.authorization;
  const signToken = req.query.token;
  const signExpires = req.query.expires;

  let authenticated = false;
  let user = { id: 'anonymous', isSubscribed: false };

  if (signToken && signExpires) {
    // 서명 토큰 검증
    try {
      if (verifySignedUrl(filename, signToken, signExpires)) {
        authenticated = true;
        // 서명 URL은 이미 생성 시점에 자격 검증을 거쳤으므로 접근 허용
        // 서명 URL로 접근 시에는 나레이터/구독 판별을 건너뜀 (생성 시점에 이미 검증됨)
        return streamAudio(filePath, req, res);
      }
    } catch (e) {
      // 서명 검증 실패 — 아래에서 403 반환
    }
  }

  if (!authenticated && authHeader && authHeader.startsWith('Bearer ')) {
    // Bearer 토큰 인증 — authMiddleware와 동일 로직 적용
    const token = authHeader.split(' ')[1];
    if (token === 'mock_subscribed_token') {
      user = { id: 'user_subscribed_123', isSubscribed: true };
      authenticated = true;
    } else if (token === 'mock_unsubscribed_token') {
      user = { id: 'user_unsubscribed_456', isSubscribed: false };
      authenticated = true;
    } else if (token) {
      user = { id: token, isSubscribed: false };
      authenticated = true;
    }
  }

  // 앱 레거시 호환: 서명 url(만료기간)이 없고 authHeader도 없을 때 query.token을 Bearer로 취급
  if (!authenticated && signToken && !signExpires) {
    const token = signToken;
    if (token === 'mock_subscribed_token') {
      user = { id: 'user_subscribed_123', isSubscribed: true };
      authenticated = true;
    } else if (token === 'mock_unsubscribed_token') {
      user = { id: 'user_unsubscribed_456', isSubscribed: false };
      authenticated = true;
    } else if (token) {
      user = { id: token, isSubscribed: false };
      authenticated = true;
    }
  }

  if (!authenticated) {
    return res.status(403).json({ error: 'Authentication required. Provide Bearer token or signed URL.' });
  }

  // ── N3: 나레이터 판별 — voice_profiles에서 narrator_ 키만 필터링 ──
  // Load stories_v2.json to get narrator voice IDs
  let narratorIds = ['zrHiDhphv9ZnVXBqCLjz', '5n5gqmaQi9Ewevrz7bOS']; // Fallbacks
  const storiesPath = path.join(__dirname, '../../public/assets/data/stories_v2.json');
  try {
    if (fs.existsSync(storiesPath)) {
      const data = JSON.parse(fs.readFileSync(storiesPath, 'utf8'));
      if (data.voice_profiles) {
        // N3 수정: narrator_ 접두사 키만 필터링하여 parent_voice(PER_USER) 제외
        narratorIds = Object.entries(data.voice_profiles)
          .filter(([key, p]) => key.startsWith('narrator_') && p.voice_id)
          .map(([, p]) => p.voice_id);
      }
    }
  } catch (e) {
    console.error('Failed to load narrator IDs in audio.js', e);
  }

  const isNarrator = narratorIds.some(id => filename.startsWith(id));
  
  if (!isNarrator && !user.isSubscribed) {
    return res.status(403).json({ error: 'Subscription required to access custom voice audio' });
  }

  // 스트리밍 지원 (Range 헤더 처리)
  streamAudio(filePath, req, res);
});

/**
 * 오디오 파일을 스트리밍한다. Range 헤더를 지원한다.
 */
function streamAudio(filePath, req, res) {
  const stat = fs.statSync(filePath);
  const fileSize = stat.size;
  const range = req.headers.range;

  if (range) {
    const parts = range.replace(/bytes=/, "").split("-");
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

    if (start >= fileSize) {
      res.status(416).send('Requested range not satisfiable\n' + start + ' >= ' + fileSize);
      return;
    }

    const chunksize = (end - start) + 1;
    const file = fs.createReadStream(filePath, { start, end });
    const head = {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunksize,
      'Content-Type': 'audio/mpeg',
    };

    res.writeHead(206, head);
    file.pipe(res);
  } else {
    const head = {
      'Content-Length': fileSize,
      'Content-Type': 'audio/mpeg',
    };
    res.writeHead(200, head);
    fs.createReadStream(filePath).pipe(res);
  }
}

module.exports = router;

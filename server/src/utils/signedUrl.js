/**
 * v2.1: 서명 URL 유틸리티 — 오디오 파일 접근을 위한 만료형 서명 토큰
 * 근거: docs/qa/verification_20260704_v21policy_r2.md N4
 */
const crypto = require('crypto');

const SECRET = process.env.AUDIO_SIGN_SECRET || 'babystory_audio_sign_secret_v21';
const DEFAULT_EXPIRES_MINUTES = 15;

/**
 * 서명 URL 경로를 생성한다.
 * @param {string} filename - 오디오 파일명 (예: 5n5gqmaQi9Ewevrz7bOS_story_01.mp3)
 * @param {number} [expiresInMinutes=15] - 만료 시간(분)
 * @returns {string} /api/audio/{filename}?token={signature}&expires={timestamp}
 */
function generateSignedUrl(filename, expiresInMinutes = DEFAULT_EXPIRES_MINUTES) {
  const expires = Math.floor(Date.now() / 1000) + (expiresInMinutes * 60);
  const payload = `${filename}:${expires}`;
  const token = crypto.createHmac('sha256', SECRET).update(payload).digest('hex');
  return `/api/audio/${filename}?token=${token}&expires=${expires}`;
}

/**
 * 서명 토큰과 만료 시각을 검증한다.
 * @param {string} filename - 오디오 파일명
 * @param {string} token - HMAC 서명 토큰
 * @param {string|number} expires - 만료 Unix timestamp (초)
 * @returns {boolean} 유효하면 true
 */
function verifySignedUrl(filename, token, expires) {
  const expiresNum = parseInt(expires, 10);
  if (isNaN(expiresNum)) return false;

  // 만료 확인
  const now = Math.floor(Date.now() / 1000);
  if (now > expiresNum) return false;

  // 서명 확인
  const payload = `${filename}:${expiresNum}`;
  const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('hex');

  // 타이밍 공격 방지 — 길이가 다르면 즉시 거부
  const tokenBuf = Buffer.from(token, 'hex');
  const expectedBuf = Buffer.from(expected, 'hex');
  if (tokenBuf.length !== expectedBuf.length) return false;
  return crypto.timingSafeEqual(tokenBuf, expectedBuf);
}

module.exports = { generateSignedUrl, verifySignedUrl };

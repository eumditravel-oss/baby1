/**
 * v2.1: stories_v2.json 동기화 스크립트
 * app/assets/data/stories_v2.json → server/public/assets/data/ 자동 동기화
 * 근거: docs/qa/verification_20260704_v21policy_r2.md N1
 * 
 * - 서버 시작 시 prestart/predev 훅으로 자동 수행 (package.json)
 * - 해시(MD5) 비교 후 변경 시에만 복사
 * - 대상 파일 부재 시 즉시 복사 (자동 복원)
 * - NUL 바이트 트리밍 + JSON 유효성 검증 포함
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const sourcePath = path.join(__dirname, '../../app/assets/data/stories_v2.json');
const destDir = path.join(__dirname, '../public/assets/data');
const destPath = path.join(destDir, 'stories_v2.json');

function md5(content) {
  return crypto.createHash('md5').update(content, 'utf8').digest('hex');
}

try {
  // Ensure destination directory exists
  if (!fs.existsSync(destDir)) {
    fs.mkdirSync(destDir, { recursive: true });
  }

  if (!fs.existsSync(sourcePath)) {
    console.warn(`[SYNC] Source stories_v2.json not found at ${sourcePath}`);
    process.exit(0);
  }

  // Read source, trim NUL bytes, validate JSON
  const rawData = fs.readFileSync(sourcePath, 'utf8');
  const cleanedData = rawData.replace(/\0/g, '').trim();
  const parsedData = JSON.parse(cleanedData);
  const cleanedJson = JSON.stringify(parsedData, null, 2);
  const sourceHash = md5(cleanedJson);

  // N1: 해시 비교 — 변경 시에만 복사
  if (fs.existsSync(destPath)) {
    const destData = fs.readFileSync(destPath, 'utf8');
    const destHash = md5(destData);

    if (sourceHash === destHash) {
      console.log(`[SYNC] stories_v2.json is up to date (hash: ${sourceHash.slice(0, 8)}…). No copy needed.`);
      process.exit(0);
    }
    console.log(`[SYNC] Hash mismatch detected (source: ${sourceHash.slice(0, 8)}… ≠ dest: ${destHash.slice(0, 8)}…). Updating...`);
  } else {
    console.log(`[SYNC] Destination file missing. Restoring from app source...`);
  }

  // Write clean JSON
  fs.writeFileSync(destPath, cleanedJson, 'utf8');
  console.log(`[SYNC] Successfully synced stories_v2.json to server/public/assets/data/`);
} catch (e) {
  console.error(`[SYNC] Failed to sync stories_v2.json:`, e.message);
}

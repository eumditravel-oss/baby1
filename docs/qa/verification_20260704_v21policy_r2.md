# 재검증 보고서 (R2) — v2.1 과금정책 반려 5건 수정분
- 일자: 2026-07-04 / 검수자: Cowork (QA 리드)
- 범위: F1~F8 표적 재검증 (현 코드베이스 새로 읽음, 이전 보고서 재사용 없음)
- **판정: 반려 지속 (신규 치명 1, 높음 3, 중간 3)** — 단 F1~F5 구조 자체는 크게 개선됨

---

## 1. 이전 반려 항목 재판정

| # | 판정 | 근거 |
|---|---|---|
| F1 정적 서빙 | **통과(구조)** | index.js:22 — outputs 제외, assets만 static. audio.js — /api/audio/:filename + Range(206) 스트리밍, 경로 탈출 차단(:13). 잔여 구멍은 N3·N4 |
| F2 구독 신뢰 | **부분 통과** | req.body isSubscribed 제거, authMiddleware 도입(story.js:24, magicbook.js:69, audio.js:9). 잔여: N5(생성 자격 미검증)·N6(MOCK 토큰) |
| F3 회수권 서버화 | **통과(서버측)** | magicbook.js:38-44(consumeRefillTicket), :92-101(10회 초과 시 회수권 소비), iap.js:26-30(/iap/verify 지급). 잔여: 클라이언트 미연동(F8) |
| F4 확정 음성 치환 | **통과(데이터)** | stories_v2.json narrator_warm.voice_id = `5n5gqmaQi9Ewevrz7bOS` (02 확정 반영). 잔여: magicbook.js:47 폴백이 다른 ID(`zrHiDhphv9ZnVXBqCLjz`) 하드코딩 |
| F5 voice_settings | **통과(코드)** | story.js:69-85, magicbook.js:122-139 — voice_profiles에서 model_id·settings 로드, 커스텀은 parent_voice 적용. **단 N1로 인해 런타임 무효였음** |
| F6 금칙어 필터 | **부분 통과** | magicbook.js:67,79-85 입력 필터(6단어). 출력(생성문) 필터 없음, 단어 목록 빈약 |
| F7 문구 블록 D | **반려 유지** | 목소리 등록 완료 화면 문구 grep 0건 |
| F8 IAP 연동 | **반려 유지** | pubspec에 in_app_purchase 없음. purchaseMagicBookRefill(subscription_service.dart:181)은 로컬 증가만 — /iap/verify 미호출 → 서버 회수권과 영구 불일치 |

## 2. 신규 발견 결함

### N1 [치명] 서버가 stories_v2.json을 찾지 못함 → F5 수정이 런타임 무효
- story.js:11, magicbook.js:49 → `server/public/assets/data/stories_v2.json` 참조. **해당 파일 부재였음.**
- 결과: voiceProfiles={} → 기본 하드코딩 설정 사용, tts_text 폴백 `"안녕하세요, 오류가 발생했습니다."`로 생성될 위험, 나레이터 폴백 ID 사용.
- **[QA 직접 조치] app 사본을 server/public/assets/data/로 복사 완료(검증: narrator_warm=5n5g…, stories 50).** 단, 빌드/배포 시 동기화 스크립트는 Antigravity 구현 필요.

### N2 [치명 → QA 직접 수정 완료] stories_v2.json 말미 NUL 바이트 ~100개
- 파일 끝 `}` 뒤 \x00 연속 → json.loads 실패 재현(char 67361). Dart 로더도 실패 위험.
- **트리밍 후 파싱 검증 완료.** 원인(파일 저장 도구)은 Antigravity가 확인할 것.

### N3 [높음] audio.js 나레이터 판별 로직 오류 — 체험 사용자 자기 오디오 403
- audio.js:33 `filename.includes('narrator_')` — 실제 파일명은 `{실제 voice_id}_{story_id}.mp3`라 나레이터 트랙도 'narrator_' 미포함.
- 결과: 비구독 체험자가 방금 만든 마법의 책 오디오 재생 → 403. 나레이터 온디맨드 트랙도 차단.

### N4 [높음] 플레이어 인증 전달 수단 부재 — 구독자도 재생 403 예상
- api_service.dart:133-136 주석으로 미해결 자인. /api/audio는 Bearer 헤더만 검사, 오디오 플레이어 URL 로드에 헤더/쿼리 토큰 전달 코드 없음.

### N5 [높음] 생성 자격 미검증 — 비구독자가 임의 voice_id로 TTS 생성 가능
- story.js:24-32 — 인증은 거치지만 비구독자가 부모 클론 voice_id로 POST 시 **생성은 수행됨**(스트리밍만 차단). TTS 원가 공격 경로 잔존.

### N6 [중간] auth.js가 MOCK 토큰 — 실검증 부재 명시 필요
- auth.js:15-24 문자열 비교. 스캐폴드로 인정하되 출시 게이트 항목.

### N7 [중간] 사용량·회수권 인메모리 — 서버 재시작 시 회수권 소실 = 결제 자산 증발
- magicbook.js:11-12. 회수권은 유료 자산이므로 DB 영속화는 결제 오픈 전 필수.

## 3. 별도 이슈 (기록)
- tts_text 발음 표기(따뜻한→따뜨탄 15쌍)는 의도적 설계로 판정. tools/audio_qa.py STT 대조 시 발음 화이트리스트 필요
- 마법의 책 생성이 gpt-4o-mini(문서 1.4는 Claude) — 결정 필요 (R1 보고서 별도이슈 1 유지)
- flutter 미설치 환경이라 analyze/test 미실행 — 사용자 측 실행 요청

## 4. 남은 구현 로드맵 (우선순위)
1. **N3+N4 오디오 재생 경로 복구** — 서명 URL(만료형 토큰 쿼리) 또는 플레이어 헤더 전달. 나레이터 판별은 파일명이 아니라 voice_id→profiles 대조로
2. **N5 생성 자격 검증** — /story/generate에서 나레이터 외 voice_id는 구독자만 허용
3. **N1 데이터 동기화 스크립트** — app/assets ↔ server/public/assets 빌드 시 자동 복사
4. **F8 스토어 결제 실연동** — in_app_purchase 도입, 영수증 → /iap/verify → 서버 지급 → 클라이언트는 서버 값 표시(로컬 카운트 폐기)
5. **N6 실인증** — 계정/기기 ID + 스토어 구독 상태 서버 검증
6. **N7 사용량·회수권 DB 영속화**
7. **F7 블록 D 문구** — 목소리 등록 완료 화면
8. **F6 출력 금칙어 필터 보강**
9. 이후: 광고(C6 미구현), 백그라운드 오디오/잠금화면(5장 기준), 클로닝 실플로우, 캐시 암호화(클라이언트 측)

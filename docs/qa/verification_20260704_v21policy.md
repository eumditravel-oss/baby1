# 검수 보고서 — v2.1 과금정책 반영 Task
- 일자: 2026-07-04 / 검수자: Cowork (QA 리드)
- 범위: v2.1 지시문 5개 항목 + 치명 결함 C1~C6 스캔
- **판정: 반려 (치명 2건, 높음 3건, 중간 3건)**

---

## 1. 치명 결함 스캔 결과

| # | 판정 | 근거 |
|---|---|---|
| C1 키 노출 | **통과** | `grep -rniE "sk-|xi-api-key|elevenlabs" app/lib app/assets` 0건(문서 주석 제외). 키는 서버 env 참조: `server/src/routes/story.js:54`, `magicbook.js:99,137` |
| C2 음성 유출 | **반려(치명)** | 아래 F1 |
| C3 중복 생성 | **통과** | `story.js:21-24` 캐시 존재 시 즉시 반환 (`[CACHE HIT]`) |
| C4 구독 잠금 | **반려(치명)** | 아래 F2. 클라이언트 게이트는 존재(`canPlayCustomVoice` 호출 4곳: home_screen.dart:215, library_screen.dart:209, radio_screen.dart:193,232) |
| C5 하드코딩 | **통과(조건부)** | 스토리 텍스트·voice_id는 stories_v2.json 단일 원본. 단 서버 voice_settings 하드코딩은 F5 |
| C6 광고 정책 | **미확인(미구현)** | pubspec.yaml에 google_mobile_ads 없음 — 광고 자체가 미구현. 구현 시 재검수 필요 |

금지 단어: `grep -rn "수면\|꿈나라" app/lib` **0건 통과.**

## 2. 반려 항목 (심각도순)

### F1 [치명] 부모 음성·마법의 책 산출물이 무인증 공개 URL로 서빙됨
- `server/src/index.js:21` — `app.use('/public', express.static(publicDir))`
- `story.js:23,91`, `magicbook.js:180` — 응답이 `/public/outputs/{voice}_{story}.mp3` 정적 경로
- 문제: URL만 알면 **인증 없이 누구나 부모 목소리 mp3를 다운로드** 가능. 해지 후에도 재생 가능. 마스터 6.1 절대규칙 3(스트리밍 전용·암호화·내보내기 경로 금지)과 2.5장 잠금 전략 전체 무력화.

### F2 [치명] 구독 상태를 클라이언트 주장으로 신뢰 (서버 검증 부재)
- `magicbook.js:37` — `isSubscribed`를 req.body에서 수신 (전송처: home_screen.dart:134)
- `story.js:8-14` — 부모 목소리 생성 요청에 구독 검증 자체가 없음
- 문제: 요청 body 조작만으로 비구독자가 무제한 생성 가능 = TTS 원가 공격 + 잠금 우회. 스토어 영수증 서버 검증 필요.

### F3 [높음] 회수권이 서버에 존재하지 않음 — 유료 기능 작동 불능
- `magicbook.js:33,49-57` — `MONTHLY_LIMIT=10` 고정, 주석 "회수권은 클라이언트에서 별도 관리"
- `subscription_service.dart:106-114` — 클라이언트는 회수권 보유 시 10회 초과 허용
- 문제: 회수권 구매 후에도 서버가 429 반환 → **돈 받고 기능이 안 됨.** 환불 분쟁 직행 코스.

### F4 [높음] 확정 나레이터(02) voice_id 미치환 — 우선순위 역전
- `stories_v2.json` voice_profiles: narrator_warm(02 확정) = `REPLACE_WITH_FIXED_VOICE_ID`, 반면 2순위 후보 narrator_lively(03)만 실 voice_id(`Q1wB6QOqrVg9MQRdXb6n`) 보유
- `magicbook.js:30` — 나레이터 폴백도 `narrator_warm_placeholder`
- 문제: 확정 음성이 실제로 연결되지 않음. 비구독 체험이 placeholder로 호출되어 500 오류 예상.

### F5 [높음] 서버 TTS 설정이 voice_profiles를 무시하고 하드코딩
- `story.js:65-68`, `magicbook.js:148-151` — 전 보이스 공통 stability 0.5 / similarity 0.75, style·speed 누락
- 기준: stories_v2.json warm(0.5/0.8/0.3/0.93), parent(0.55/0.9/0.15/0.93). 문서 3.1장·4장 "전역 1곳 관리" 위배.

### F6 [중간] 금칙어 필터 서버 측 부재 + 프롬프트 주입 가능
- `magicbook.js:107-117` — name/event/character를 프롬프트에 무필터 삽입, 생성 결과 검수 없음. 기준 5장 "금칙어 필터 서버 측 존재" 미달.

### F7 [중간] 안내 문구 블록 D(목소리 등록 완료 화면) 미반영
- 블록 A ✅ paywall_modal.dart:102,212 / B ✅ settings_screen.dart:165-170 / C ✅ home_screen.dart:325,330 / **D ❌ 0건**

### F8 [중간] IAP 스토어 결제 미연동 (정책 로직만 존재)
- pubspec.yaml에 in_app_purchase 계열 패키지 없음. `purchaseMagicBookRefill()`(subscription_service.dart:166) 등은 로컬 상태 변경뿐. 스캐폴드로 인정하되 "완료" 주장과 불일치 — 미구현임을 명시해야 함.

## 3. 통과 항목 (v2.1 지시문 대조)
- 월 10회 서버 강제·이월 없음: magicbook.js:11-33,46-57 ✅
- 비구독 체험 1회 + 나레이터 강제 치환: magicbook.js:58-72 ✅
- 재청취 미차감(생성 시에만 카운트): magicbook.js:173-174 ✅
- 온디맨드 생성+영구 캐시: story.js:16-24 ✅
- 라디오 프리페치: radio_screen.dart:181,271-278 + api_service.dart:99-113 ✅
- 잠금 게이트(클라이언트): canPlayCustomVoice 4곳 ✅
- 음성 확정 주석(02 확정/03 보류): stories_v2.json notes ✅ (단 F4)
- 429 처리 UX: api_service.dart:127-130 ✅

## 4. 별도 이슈 (이번 Task 범위 밖 — 기록만)
1. 마법의 책 텍스트 생성이 Claude API가 아닌 OpenAI gpt-4o-mini(magicbook.js:119-123) — 문서 1.4장과 충돌. 문서 수정 또는 코드 수정 결정 필요
2. 캐시 파일명이 `{voiceId}_{storyId}.mp3` — 기준 B-4는 `{storyId}_{voiceId}.mp3` (역순)
3. monthlyUsage가 인메모리(재시작 시 소실) — 코드 내 TODO 주석 존재, 출시 게이트에 포함할 것
4. server/config/voices_config.json의 표준 보이스 4종(할아버지·요정·곰·언니)이 문서의 보이스 3종 체계와 충돌
5. library_screen.dart:253 availableFiles 하드코딩 (개발용 폴백으로 보임)

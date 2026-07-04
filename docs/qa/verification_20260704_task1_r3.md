# 재검증 보고서 (R3) — Task 1 (N3·N4·N5·N1·F7)
- 일자: 2026-07-04 / 검수자: Cowork (QA 리드)
- 방법: 코드 정독 + **실서버 기동 통합 테스트** (USE_MOCK_API=true, 샌드박스에서 ffmpeg 경로 주입)
- **판정: 부분 통과 — 핵심 보안 3건(N3·N4·N5) 통과, 경미 반려 2건**

## 1. 실행 테스트 로그 (증거)
```
[T1] GET /public/outputs/any.mp3            → 404 ✅ (정적 서빙 차단)
[T2] 비구독+커스텀 voice /story/generate     → 403 ✅ "Subscription required to use custom voice"
[T3] 비구독+나레이터 /story/generate         → 200, 서명 URL 반환
     서명 URL 재생                           → 200 ✅
     토큰 제거 / 만료 변조 / 과거 만료        → 403 / 403 / 403 ✅
[T4] 비구독 마법의책 체험 생성               → 200 (선행 실행에서 성공, 체험 오디오 재생 200)
[T5] 체험 2회차 (서버 재시작 후에도)          → 429 ✅ — db.json 영속화 동작 확인
[T6] /iap/verify magicbook_refill            → refillRemaining: 5 ✅
[T7] 비구독 Bearer로 체험 오디오(나레이터) GET → 200 — 정책상 수용(아래 3-1)
```

## 2. 항목별 판정
| 항목 | 판정 | 근거 |
|---|---|---|
| N3 나레이터 판별 | **통과** | audio.js:67-85 — voice_profiles의 narrator_ 키 voice_id 목록과 파일명 접두 대조. 체험 오디오 재생 가능 확인(T4) |
| N4 서명 URL | **통과** | utils/signedUrl.js — HMAC-SHA256+만료+timingSafeEqual. story.js:50, magicbook.js:222 서명 URL 반환. 위조·만료 전 케이스 403(T3) |
| N5 생성 자격 | **통과** | story.js:39-45 — 나레이터 프로필 외 voice는 구독자만. 캐시 히트 이전에 검사(순서 올바름) |
| N1 데이터 동기화 | **반려(중간)** | scripts/sync_data.js 자체는 우수(해시 비교+NUL 정리, 실행 로그 확인). **그러나 package.json에 "start"/"dev" 스크립트가 없어 prestart 훅이 실행될 경로가 없음** — `npm start` 자체가 "Missing script" 오류 |
| F7 블록 D | **통과** | voice_recording_flow.dart:153-180 — 등록 완료 문구 4항목 반영 |
| (보너스) N7 영속화 | **선구현 확인** | src/db.js — db.json 파일 영속화. 서버 재시작 후 사용량 유지(T5). 위치가 public/ 하위지만 static은 /public/assets만 서빙하므로 노출 없음 확인 |
| (보너스) F6 | **개선 확인** | 금칙어 12단어로 확장(magicbook.js:40). 출력 필터는 여전히 없음 — 기존 F6 잔여 |

## 3. 신규 발견
### 3-1 [판정 메모] 체험 오디오의 개방성
체험 마법의 책 오디오는 나레이터 보이스 파일명이라 인증만 되면 누구나 접근 가능(T7).
부모 음성 미포함이므로 유출 리스크는 없다고 판정. 단 개인 맞춤 텍스트가 담기므로
장기적으로 파일-userId 바인딩 권장(별도 이슈).

### M1 [중간] 생성 실패 시에도 사용량·회수권 선차감
- magicbook.js:66(consumeRefillTicket), :76·:88(incrementUsage)이 **생성 시도 전** 실행.
- OpenAI/ElevenLabs 오류로 500이 나도 체험 1회·월 카운트·회수권이 소모됨 = 분쟁 유발.
- 유료 자산(회수권)이 무산출 소모되는 경로 — 결제 오픈 전 반드시 수정.

### M2 [낮음] audio.js:48-60이 auth 미들웨어 로직을 중복 구현 — 드리프트 위험
### M3 [낮음] 테스트 잔재: server/test_body.json, public/data/db.json 내 테스트 사용량·회수권 5매, outputs 테스트 mp3 — 출시 전 정리 목록에 추가

## 4. 판정
핵심 보안 경로(무인증 접근·서명 위조·생성 자격)는 실측으로 전부 통과. **컨펌 보류 사유는
N1 실행 불가(start 스크립트 부재)와 M1(선차감) 2건.** 이 2건은 소규모 수정이며, 완료 시
Task 1 컨펌 예정.

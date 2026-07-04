#!/usr/bin/env python3
# tools/validate_stories.py — stories_v2.json 무결성 전수 검증 (COWORK_QA_MASTER 기준 A)
# 사용: python3 tools/validate_stories.py [json경로]
import json, re, sys, os, hashlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_JSON = os.path.join(ROOT, 'app/assets/data/stories_v2.json')
SRV_JSON = os.path.join(ROOT, 'server/public/assets/data/stories_v2.json')
IMG_DIR = os.path.join(ROOT, 'app/assets')
AUD_DIR = os.path.join(ROOT, 'app/assets/audio')
PUBSPEC = os.path.join(ROOT, 'app/pubspec.yaml')

VALID_CATEGORIES = {'cozy', 'adventure', 'daily'}
issues = []


def add(sev, sid, msg):
    issues.append((sev, sid, msg))


def strip_breaks(t):
    return re.sub(r'<break[^>]*/>', '', t)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else APP_JSON
    raw = open(path, encoding='utf-8').read()
    if raw != raw.rstrip('\x00 \n\t') + '\n' and '\x00' in raw:
        add('치명', '-', 'NUL 바이트 잔존')
    data = json.loads(raw)

    if str(data.get('schema_version')) != '2.0':
        add('높음', '-', f"schema_version={data.get('schema_version')} (기대 2.0)")

    vp = data.get('voice_profiles', {})
    for key, exp_st in [('narrator_warm', 0.5), ('narrator_lively', 0.4), ('parent_voice', 0.55)]:
        p = vp.get(key)
        if not p:
            add('치명', '-', f'voice_profiles.{key} 누락'); continue
        st = p.get('voice_settings', {}).get('stability')
        if st != exp_st:
            add('높음', '-', f'{key}.stability={st} (문서 기준 {exp_st})')
        if 'REPLACE' in str(p.get('voice_id', '')) or not p.get('voice_id'):
            add('높음', '-', f'{key}.voice_id 미치환: {p.get("voice_id")}')

    stories = data.get('stories', [])
    if len(stories) != 50:
        add('치명', '-', f'스토리 수 {len(stories)} (기대 50)')

    ids = []
    for s in stories:
        sid = s.get('id', '?')
        ids.append(sid)
        tts = s.get('tts_text', '')
        content = s.get('content', '')
        plain = strip_breaks(tts)

        # 1) 물결표 / 말줄임표 (tts_text 기준 — 낭독 텍스트가 대상)
        if '~' in tts:
            add('높음', sid, f'tts_text 물결표 {tts.count("~")}개')
        if '…' in tts or '...' in tts:
            add('높음', sid, f'tts_text 말줄임표 {tts.count("…") + tts.count("...")}개')

        # 2) 글자수 (break 태그 제거, 공백 포함 — 문서 2.2장 "평균 450자" 기준과 일치)
        n = len(plain)
        if not (400 <= n <= 520):  # 420~510은 신규 기준, 기존 50편은 ±20 완충
            add('중간', sid, f'글자수 {n} (기준 420~510, 완충 400~520 밖)')

        # 3) 느낌표 문단당 ≤2
        for i, para in enumerate(plain.split('\n')):
            if para.count('!') > 2:
                add('중간', sid, f'문단{i + 1} 느낌표 {para.count("!")}개')

        # 4) 문장 종결부호 완결 (마지막 문자)
        last = plain.rstrip()[-1:] if plain.rstrip() else ''
        if last not in '.!?"’”':
            add('중간', sid, f'끝 문자 "{last}" — 종결부호 미완결')

        # 5) id 형식 연번
        if not re.match(r'^story_\d+$', sid):
            add('중간', sid, 'id 형식 이상')

        # 6) category
        if s.get('category') not in VALID_CATEGORIES:
            add('중간', sid, f"category={s.get('category')}")

        # 7) imageUrl 실존
        img = s.get('imageUrl', '')
        if not os.path.exists(os.path.join(ROOT, 'app', img)):
            add('높음', sid, f'이미지 없음: {img}')

        # 8) 오디오 실존 (나레이터 사전 생성분)
        num = re.sub(r'\D', '', sid)
        if not os.path.exists(os.path.join(AUD_DIR, f'story_{num}.mp3')):
            add('높음', sid, '나레이터 mp3 없음')

        # 9) break 태그 문법
        for b in re.findall(r'<break[^>]*>', tts):
            if not re.match(r'<break time="[\d.]+s" ?/>', b):
                add('중간', sid, f'break 태그 문법 이상: {b}')

    # 연번 검사
    nums = sorted(int(re.sub(r'\D', '', i)) for i in ids)
    missing = [i for i in range(1, 51) if i not in nums]
    dup = len(nums) != len(set(nums))
    if missing:
        add('치명', '-', f'연번 누락: {missing}')
    if dup:
        add('치명', '-', 'id 중복 존재')

    # pubspec 등록
    ps = open(PUBSPEC, encoding='utf-8').read()
    for need in ['assets/data/stories_v2.json', 'assets/images/', 'assets/audio/']:
        if need not in ps:
            add('치명', '-', f'pubspec 미등록: {need}')

    # app ↔ server 사본 일치
    if os.path.exists(SRV_JSON):
        h1 = hashlib.md5(open(APP_JSON, 'rb').read()).hexdigest()
        h2 = hashlib.md5(open(SRV_JSON, 'rb').read()).hexdigest()
        if h1 != h2:
            add('높음', '-', 'app/server stories_v2.json 사본 불일치')
    else:
        add('치명', '-', '서버 사본 없음: ' + SRV_JSON)

    # 결과 출력
    print(f'검사 대상: {path}')
    print(f'스토리 {len(stories)}편 / 발견 이슈 {len(issues)}건')
    for sev in ['치명', '높음', '중간', '낮음']:
        rows = [x for x in issues if x[0] == sev]
        if rows:
            print(f'\n[{sev}] {len(rows)}건')
            for _, sid, msg in rows:
                print(f'  {sid}: {msg}')
    if not issues:
        print('\n전 항목 통과')
    return 1 if any(x[0] in ('치명', '높음') for x in issues) else 0


if __name__ == '__main__':
    sys.exit(main())
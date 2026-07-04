const fs = require('fs');
const path = require('path');

class StoryProcessor {
  constructor(jsonPath) {
    this.jsonPath = jsonPath;
    this.stories = null; // 메모리 캐싱용
  }

  /**
   * [1. JSON Loader]
   * 파일을 한 번만 읽어 메모리에 캐싱하고, 요청 시 빠르게 서빙
   */
  loadStories() {
    if (!this.stories) {
      const data = fs.readFileSync(this.jsonPath, 'utf8');
      this.stories = JSON.parse(data);
    }
    return this.stories;
  }

  getStoryText(storyId) {
    const stories = this.loadStories();
    const story = stories.find(s => s.id === storyId);
    if (!story) throw new Error(`Story ID ${storyId} not found`);
    return story.content || story.desc || '';
  }

  /**
   * [2. Text Pre-processing (유치원 선생님 그림책 톤)]
   * 다정함을 끌어내는 텍스트 전처리 엔진
   */
  applyKindergartenTeacherTone(text) {
    if (!text) return '';
    let processed = text;

    // 1. 느낌표(!) 부드럽게 치환:
    // 문장 끝의 느낌표는 AI가 소리를 지르게 만들어 한국어 발음이 뭉개지거나 쇳소리를 유발함.
    // 모든 !를 ~ (물결표)로 바꾸어 "정말 멋지다~" 처럼 끝을 둥글게 늘여서 다정하게 읽게 함.
    processed = processed.replace(/!/g, '~');

    // 2. 어미 변환 (다정함 극대화):
    // "다.", "요." 로 끝나는 단호한 어미를 "다~.", "요~." 로 살짝 변환하여 유치원 교사 특유의 상냥함을 부여.
    processed = processed.replace(/(다|요)\./g, '$1~.');

    // 3. 마침표 호흡 늘리기:
    // 문장이 끝나는 마침표(.) 뒤에 ... 을 치환해서, 아이와 눈을 맞추는 듯한 여유로운 쉼표(Pause)를 생성.
    processed = processed.replace(/\./g, '. ... ');

    // 4. 쉼표(,) 호흡 추가:
    // 접속사 뒤에 강제로 쉼표(,)를 넣어 선생님처럼 한 박자 천천히 또박또박 읽도록 유도.
    processed = processed.replace(/(그리고|그래서|그런데)(?!,)/g, '$1,');

    return processed;
  }

  /**
   * [3. ElevenLabs API 파라미터 최적화]
   * 발음 보호(Softness)를 위한 파라미터 세팅
   */
  getVoiceSettings() {
    return {
      // 톤이 위아래로 심하게 날뛰어 발음이 깨지는 것을 막고, 일정한 다정함을 유지
      stability: 0.60,
      // 부드러운 원본 목소리 질감 극대화
      similarity_boost: 0.85,
      // 한국어 모델에서 억지 연기와 센 발음을 원천 차단하기 위해 무조건 0.0 설정
      style: 0.0,
      use_speaker_boost: true
    };
  }

  /**
   * Mimi - 맑고 부드러운 20대 여성 성우 (유치원 선생님 톤에 최적)
   */
  getDefaultVoiceId() {
    // ElevenLabs Mimi Voice ID
    return 'zrHiDhphv9ZnVXBqCLjz'; 
  }
}

module.exports = StoryProcessor;

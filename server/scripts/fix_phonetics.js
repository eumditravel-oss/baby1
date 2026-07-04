const fs = require('fs');
const path = require('path');

const JSON_PATH = path.join(__dirname, '../../app/assets/data/stories_v2.json');
const data = JSON.parse(fs.readFileSync(JSON_PATH, 'utf8'));

const replacements = [
  { target: /따뜻한/g, replacement: '따뜨탄' },
  { target: /따뜻해졌어요/g, replacement: '따뜨태져써요' },
  { target: /따뜻함이/g, replacement: '따뜨타미' },
  { target: /않았어요/g, replacement: '아나써요' },
  { target: /않아도/g, replacement: '아나도' },
  { target: /닿으면/g, replacement: '다으면' },
  { target: /덮고/g, replacement: '덥꼬' }
];

let updatedCount = 0;

for (const story of data.stories) {
  if (!story.tts_text) continue;
  
  let original = story.tts_text;
  let text = original;
  
  for (const { target, replacement } of replacements) {
    text = text.replace(target, replacement);
  }
  
  if (text !== original) {
    story.tts_text = text;
    updatedCount++;
    console.log(`Updated story [${story.id}]`);
  }
}

fs.writeFileSync(JSON_PATH, JSON.stringify(data, null, 2), 'utf8');
console.log(`Successfully applied phonetic fixes to ${updatedCount} stories.`);

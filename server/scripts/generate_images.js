const fs = require('fs');
const path = require('path');
const https = require('https');
const { OpenAI } = require('openai');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const jsonPath = path.join(__dirname, '../../app/assets/data/sleep_stories.json');
const imgDir = path.join(__dirname, '../../app/assets/images');

if (!fs.existsSync(imgDir)) fs.mkdirSync(imgDir, { recursive: true });

async function downloadImage(url, filepath) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode === 200) {
        res.pipe(fs.createWriteStream(filepath))
           .on('error', reject)
           .once('close', () => resolve(filepath));
      } else {
        res.resume();
        reject(new Error(`Request Failed With a Status Code: ${res.statusCode}`));
      }
    }).on('error', reject);
  });
}

async function delay(ms) {
  return new Promise(res => setTimeout(res, ms));
}

async function run() {
  console.log('Loading stories from JSON...');
  let stories = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  
  for (let i = 0; i < stories.length; i++) {
    const story = stories[i];
    // Check if it's already generated and downloaded
    if (story.imageUrl && story.imageUrl.startsWith('assets/images/')) {
      console.log(`[${i+1}/${stories.length}] Skipping ${story.id}, image already exists.`);
      continue;
    }

    console.log(`[${i+1}/${stories.length}] Generating image for: ${story.title}`);
    try {
      const response = await openai.images.generate({
        model: "gpt-image-2",
        prompt: `A beautiful, magical illustration for a children's bedtime story about: ${story.title}. Soft, dreamy colors, 3d pixar style.`,
        n: 1,
        size: "1024x1024"
      });

      const url = response.data[0].url;
      const filename = `${story.id}.png`;
      const filepath = path.join(imgDir, filename);
      
      console.log(`Downloading image for ${story.title}...`);
      await downloadImage(url, filepath);
      
      story.imageUrl = `assets/images/${filename}`;
      fs.writeFileSync(jsonPath, JSON.stringify(stories, null, 2)); // Save after every successful generation
      console.log(`Successfully saved ${filename}. Waiting 3 seconds...`);
      
      await delay(3000); // 3 seconds delay to avoid rate limiting
    } catch (e) {
      console.error(`Failed for ${story.title}:`, e.message);
    }
  }
  console.log('All done!');
}

run();

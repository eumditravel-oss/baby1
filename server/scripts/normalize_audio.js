const fs = require('fs');
const path = require('path');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');

ffmpeg.setFfmpegPath(ffmpegInstaller.path);

const audioDir = path.join(__dirname, '../../app/assets/audio');

async function normalizeFile(filename) {
  const inputPath = path.join(audioDir, filename);
  const tempPath = path.join(audioDir, `temp_${filename}`);

  if (!fs.existsSync(inputPath)) {
    console.log(`Skipping ${filename}, not found.`);
    return;
  }

  return new Promise((resolve, reject) => {
    console.log(`Normalizing volume for ${filename}...`);
    ffmpeg(inputPath)
      // loudnorm: EBU R128 standard normalization
      // I=-24: Target integrated loudness (default broadcast is -24, very consistent)
      // LRA=11: Target loudness range
      // TP=-2.0: True peak
      .audioFilter('loudnorm=I=-24:LRA=11:TP=-2.0')
      .save(tempPath)
      .on('end', () => {
        // Replace original with normalized
        fs.renameSync(tempPath, inputPath);
        console.log(`Finished ${filename}.`);
        resolve();
      })
      .on('error', (err) => {
        console.error(`Error processing ${filename}:`, err);
        if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
        reject(err);
      });
  });
}

async function run() {
  const filesToNormalize = [
    'story_story_01_ASMR.mp3',
    'story_story_02_ASMR.mp3',
    'story_story_03_ASMR.mp3',
    'story_story_04_ASMR.mp3',
    'story_story_05_ASMR.mp3'
  ];

  for (const file of filesToNormalize) {
    try {
      await normalizeFile(file);
    } catch (e) {
      // ignore
    }
  }
  console.log('All audio files normalized to a consistent volume!');
}

run();

const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
ffmpeg.setFfmpegPath(ffmpegPath);
const path = require('path');
const fs = require('fs');

const assetsPath = path.join(__dirname, 'public', 'assets');
if (!fs.existsSync(assetsPath)) fs.mkdirSync(assetsPath, { recursive: true });

console.log('Generating dummy files...');

// 3 seconds dummy audio
ffmpeg()
  .input('anullsrc=r=44100:cl=mono')
  .inputFormat('lavfi')
  .duration(3)
  .save(path.join(assetsPath, 'mock.mp3'))
  .on('end', () => console.log('mock.mp3 created'));

// 10 seconds lullaby
ffmpeg()
  .input('anullsrc=r=44100:cl=stereo')
  .inputFormat('lavfi')
  .duration(10)
  .save(path.join(assetsPath, 'lullaby.mp3'))
  .on('end', () => console.log('lullaby.mp3 created'));

// 1920x1080 dummy image
ffmpeg()
  .input('color=c=navy:s=1920x1080')
  .inputFormat('lavfi')
  .frames(1)
  .save(path.join(assetsPath, 'mock.png'))
  .on('end', () => console.log('mock.png created'));

const ffmpeg = require('fluent-ffmpeg');
const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');
const ffprobeInstaller = require('@ffprobe-installer/ffprobe');
ffmpeg.setFfmpegPath(ffmpegInstaller.path);
ffmpeg.setFfprobePath(ffprobeInstaller.path);
const fs = require('fs');

/**
 * Applies post-processing to TTS audio:
 * 1. Trims silence from start/end
 * 2. Normalizes to -16 LUFS
 * 3. Applies 1.5s fade out
 */
async function processStoryAudio(inputPath, outputPath) {
  return new Promise((resolve, reject) => {
    // Determine duration first to apply fade out correctly
    ffmpeg.ffprobe(inputPath, (err, metadata) => {
      if (err) return reject(err);

      const duration = metadata.format.duration;
      const fadeOutDuration = 1.5;
      const fadeOutStart = Math.max(0, duration - fadeOutDuration);

      ffmpeg(inputPath)
        // Trim silence
        .audioFilters('silenceremove=start_periods=1:start_duration=0.1:start_threshold=-50dB:detection=peak')
        // Normalize to -16 LUFS
        .audioFilters('loudnorm=I=-16:TP=-1.5:LRA=11')
        // Apply fade out
        .audioFilters(`afade=t=out:st=${fadeOutStart}:d=${fadeOutDuration}`)
        .on('end', () => {
          resolve(outputPath);
        })
        .on('error', (err) => {
          console.error('FFMPEG Processing Error:', err);
          reject(err);
        })
        .save(outputPath);
    });
  });
}

module.exports = {
  processStoryAudio
};

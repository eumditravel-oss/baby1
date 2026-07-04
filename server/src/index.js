const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const publicDir = path.join(__dirname, '../public');
const outputsDir = path.join(publicDir, 'outputs');
const assetsDir = path.join(publicDir, 'assets');

[publicDir, outputsDir, assetsDir].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// v2.1: outputs 폴더는 보안 스트리밍 API(/api/audio/:file)로만 접근하도록 static 서빙에서 제외
app.use('/public/assets', express.static(assetsDir));

const previewRoutes = require('./routes/preview');
const videoRoutes = require('./routes/video');
const voicesRoutes = require('./routes/voices');
const storyRoutes = require('./routes/story');
const magicbookRoutes = require('./routes/magicbook');
const audioRoutes = require('./routes/audio');
const iapRoutes = require('./routes/iap');

app.use('/api', previewRoutes);
app.use('/api', videoRoutes);
app.use('/api', voicesRoutes);
app.use('/api', storyRoutes);
app.use('/api', magicbookRoutes);
app.use('/api', audioRoutes);
app.use('/api', iapRoutes);

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`USE_MOCK_API is set to: ${process.env.USE_MOCK_API}`);
});

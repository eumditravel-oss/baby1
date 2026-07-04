const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { addRefillTickets } = require('../db');

// v2.1: 서버 측 IAP 영수증 검증 및 회수권 지급
router.post('/iap/verify', authMiddleware, async (req, res) => {
  const { receipt, productId } = req.body;

  if (!req.user || !req.user.id) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!receipt || !productId) {
    return res.status(400).json({ error: 'receipt and productId are required' });
  }

  try {
    // 실제로는 스토어(App Store / Google Play) 서버에 receipt 유효성 검증 요청을 해야 함.
    // 여기서는 MOCK 검증 로직으로 대체
    console.log(`[IAP] Verifying receipt for product: ${productId}, user: ${req.user.id}`);
    
    // 모의 처리: 1초 지연
    await new Promise(resolve => setTimeout(resolve, 1000));

    if (productId === 'magicbook_refill') {
      // 회수권 5회 지급
      const newTotal = addRefillTickets(req.user.id, 5);
      console.log(`[IAP] Granted 5 magicbook refills to ${req.user.id}. Total: ${newTotal}`);
      return res.json({ success: true, message: '회수권이 5회 추가되었습니다.', refillRemaining: newTotal });
    } else if (productId === 'voice_slot_extra') {
      // 보이스 슬롯 확장 처리 (여기서는 성공 응답만)
      return res.json({ success: true, message: '보이스 슬롯이 추가되었습니다.' });
    } else if (productId === 'story_pack_single') {
      // 스토리 팩 단권 처리
      return res.json({ success: true, message: '스토리 팩 구매가 완료되었습니다.' });
    } else {
      return res.status(400).json({ error: 'Unknown product' });
    }

  } catch (error) {
    console.error('IAP validation error:', error);
    res.status(500).json({ error: 'Failed to verify receipt' });
  }
});

module.exports = router;

const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const queryToken = req.query.token;

  // Default to unauthenticated/unsubscribed
  req.user = {
    id: 'anonymous',
    isSubscribed: false,
  };

  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  } else if (queryToken) {
    token = queryToken;
  }
    
  if (token) {
    // v2.1: 토큰 기반 구독 검증 (MOCK)
    // 실제 환경에서는 DB 조회 또는 외부 시스템(Firebase/Apple/Google) 검증 필요
    if (token === 'mock_subscribed_token') {
      req.user = {
        id: 'user_subscribed_123',
        isSubscribed: true,
      };
    } else if (token === 'mock_unsubscribed_token') {
      req.user = {
        id: 'user_unsubscribed_456',
        isSubscribed: false,
      };
    } else {
      // 임의의 토큰은 해당 토큰을 ID로 하는 비구독 유저로 간주
      req.user = {
        id: token,
        isSubscribed: false,
      };
    }
  }

  next();
};

module.exports = authMiddleware;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/subscription_service.dart';

class ApiService {
  static String get baseUrl {
    // 주의: Github Pages(Web)에 배포할 때는 백엔드 서버도 외부(ngrok 등)로 열린 HTTPS 주소여야 합니다.
    // 임시로 로컬 테스트 및 갤탭(실제 기기) 테스트를 위해 현재 PC의 IP(221.163.192.159)를 사용합니다.
    const String backendIp = '221.163.192.159'; // Windows PC의 현재 IP
    const String port = '3001';
    
    if (kIsWeb) {
      return 'http://$backendIp:$port/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 안드로이드 에뮬레이터(10.0.2.2)가 아닌 실제 기기(갤탭)를 위해 PC의 IP를 직접 지정
      return 'http://$backendIp:$port/api';
    }
    return 'http://$backendIp:$port/api';
  }

  // v2.1: 서버 인증을 위한 기본 헤더 생성
  static Map<String, String> _getAuthHeaders() {
    final subService = SubscriptionService();
    // 모의 토큰 사용 (실제 환경에서는 로그인 세션 또는 저장소에서 JWT를 읽어옵니다)
    final token = subService.isSubscribed ? 'mock_subscribed_token' : 'mock_unsubscribed_token';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> fetchVoices() async {
    try {
      var response = await http.get(Uri.parse('$baseUrl/voices')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load voices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error or timeout: $e. Check if backend is running or IP is correct.');
    }
  }

  static Future<String> previewHook(String audioFilePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/preview-hook'));
    request.files.add(await http.MultipartFile.fromPath('audio', audioFilePath));
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['url'];
    } else {
      throw Exception('Failed to get preview hook');
    }
  }

  static Future<String> generateVideo(Map<String, dynamic> formData) async {
    var response = await http.post(
      Uri.parse('$baseUrl/generate-video'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(formData),
    );
    
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['url'];
    } else {
      throw Exception('Failed to generate video');
    }
  }

  // --- 우리집 목소리 파이프라인 신규 함수들 ---

  static Future<String> cloneVoice(String audioFilePath, String name, bool consent) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice/clone'));
    request.fields['name'] = name;
    request.fields['consent'] = consent.toString();
    request.files.add(await http.MultipartFile.fromPath('audio', audioFilePath));
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['voice_id'];
    } else {
      throw Exception('Failed to clone voice');
    }
  }

  static Future<String> generateStoryAudio(String voiceId, String storyId) async {
    var response = await http.post(
      Uri.parse('$baseUrl/story/generate'),
      headers: _getAuthHeaders(), // v2.1 인증 헤더 적용
      body: jsonEncode({
        'voice_id': voiceId,
        'story_id': storyId,
      }),
    ).timeout(const Duration(minutes: 2)); 
    
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return _buildFullUrl(data['url']);
    } else {
      throw Exception('Failed to generate story audio: ${response.statusCode}');
    }
  }

  /// v2.1: 라디오 연속재생 시 다음 트랙 프리페치 (fire-and-forget)
  static Future<void> prefetchStoryAudio(String voiceId, String storyId) async {
    try {
      http.post(
        Uri.parse('$baseUrl/story/generate'),
        headers: _getAuthHeaders(), // v2.1 인증 헤더 적용
        body: jsonEncode({
          'voice_id': voiceId,
          'story_id': storyId,
        }),
      ).timeout(const Duration(minutes: 3));
    } catch (_) {
      // 무시
    }
  }

  static Future<Map<String, dynamic>> generateMagicStory(Map<String, dynamic> formData) async {
    var response = await http.post(
      Uri.parse('$baseUrl/magicbook/generate'),
      headers: _getAuthHeaders(), // v2.1 인증 헤더 적용
      body: jsonEncode(formData),
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      // v2.1: 서버가 내려주는 보안 URL(/api/audio/...)를 안전하게 조합하기 위해 token을 append할 수 있지만
      // Flutter의 just_audio는 헤더 추가가 까다로움. 
      // 현재 모의 테스트에서는 서버가 /api/audio/:file 을 주면,
      // 앱 내에서는 baseUrl + /api/audio/... 형식에 ?token=xxx 를 붙여서 해결 가능
      // 하지만 authMiddleware가 header만 보므로, 편의상 모의용으로 MOCK_API 에서는 header 추가 없이 재생 가능하도록 처리하거나...
      // wait, just_audio의 AudioSource.uri() 에는 headers 매개변수가 있음. 
      // 따라서 오디오 URL 자체는 그대로 반환하고 호출부에서 headers를 추가해야 함.
      // 일단 URL만 파싱
      data['audioUrl'] = _buildFullUrl(data['audioUrl']);
      return data;
    } else if (response.statusCode == 429) {
      var data = jsonDecode(response.body);
      throw Exception(data['message'] ?? '사용 횟수를 초과했습니다.');
    } else if (response.statusCode == 400 && jsonDecode(response.body)['error'] == 'profanity_detected') {
      throw Exception('적절하지 않은 단어가 포함되어 생성할 수 없습니다.');
    } else {
      throw Exception('Failed to generate magic story: ${response.statusCode}');
    }
  }

  /// v2.1: IAP 검증 (회수권, 슬롯 확장 등)
  static Future<Map<String, dynamic>> verifyIapReceipt(String receipt, String productId) async {
    var response = await http.post(
      Uri.parse('$baseUrl/iap/verify'),
      headers: _getAuthHeaders(),
      body: jsonEncode({
        'receipt': receipt,
        'productId': productId,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('IAP 영수증 검증에 실패했습니다: ${response.statusCode}');
    }
  }
  
  static String _buildFullUrl(String relativeUrl) {
    String url = relativeUrl;
    if (!relativeUrl.startsWith('http')) {
      if (relativeUrl.startsWith('/api/audio/')) {
        url = '$baseUrl/audio/${relativeUrl.split('/api/audio/')[1]}';
      } else {
        String base = baseUrl.replaceAll('/api', '');
        url = relativeUrl.startsWith('/') ? '$base$relativeUrl' : '$base/$relativeUrl';
      }
    }

    if (url.contains('/api/audio/') && !url.contains('expires=')) {
      final authHeader = _getAuthHeaders()['Authorization'] ?? '';
      if (authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7);
        url += url.contains('?') ? '&token=$token' : '?token=$token';
      }
    }
    
    return url;
  }
}

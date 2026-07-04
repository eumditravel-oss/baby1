import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api_service.dart';

/// 구독·과금·잠금 정책 통합 서비스 (v2.1)
///
/// STORYBOOK_MASTER.md 기준:
/// - 구독: 월 6,900 / 연 49,000, 7일 체험(목소리 1개 + 동화 3편)
/// - 마법의 책: 구독 전용 월 10회(서버 강제, 이월 없음), 비구독 체험 1회(나레이터 전용)
/// - 산출물 잠금: 해지 시 재생 중지, 보관함 보존, 재구독 즉시 복구
/// - IAP: 회수권 +5회 ₩2,500(구독자 전용), 스토리 팩 단권 ₩3,900, 보이스 슬롯 +1 ₩9,900
class SubscriptionService {
  static const String _keyIsSubscribed = 'sub_is_subscribed';
  static const String _keyTrialStartedAt = 'sub_trial_started_at';
  static const String _keyVoiceCloneCount = 'sub_voice_clone_count';
  static const String _keyMagicBookTrialUsed = 'sub_magic_book_trial_used';
  static const String _keyVoiceSlotExtra = 'sub_voice_slot_extra';

  // 월별 마법의 책 사용량 키 (YYYY-MM 형식)
  static String _magicBookMonthKey(DateTime date) =>
      'sub_magic_book_${date.year}_${date.month.toString().padLeft(2, '0')}';

  // 마법의 책 회수권 잔여 키
  static const String _keyMagicBookRefill = 'sub_magic_book_refill';

  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  SubscriptionService._internal();

  bool _isSubscribed = false;
  DateTime? _trialStartedAt;
  int _voiceCloneCount = 0;
  int _magicBookMonthlyUsed = 0;
  bool _magicBookTrialUsed = false;
  int _magicBookRefillRemaining = 0;
  int _voiceSlotExtra = 0;

  bool _isInitialized = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 월 최대 마법의 책 생성 횟수 (2.4장: 10회)
  static const int magicBookMonthlyLimit = 10;

  /// 기본 보이스 슬롯 (1.3장: 엄마+아빠 = 2)
  static const int baseVoiceSlots = 2;

  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isSubscribed = prefs.getBool(_keyIsSubscribed) ?? false;

    final trialStr = prefs.getString(_keyTrialStartedAt);
    if (trialStr != null) {
      _trialStartedAt = DateTime.tryParse(trialStr);
    }

    _voiceCloneCount = prefs.getInt(_keyVoiceCloneCount) ?? 0;
    _magicBookTrialUsed = prefs.getBool(_keyMagicBookTrialUsed) ?? false;
    _magicBookRefillRemaining = prefs.getInt(_keyMagicBookRefill) ?? 0;
    _voiceSlotExtra = prefs.getInt(_keyVoiceSlotExtra) ?? 0;

    // 이번 달 마법의 책 사용량 로드 (이월 없음 — 다른 달 키는 무시)
    final now = DateTime.now();
    _magicBookMonthlyUsed = prefs.getInt(_magicBookMonthKey(now)) ?? 0;

    _isInitialized = true;
    
    // v2.1: IAP 스트림 리스너 등록
    final purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      // handle error
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Verify and deliver product
          _verifyAndDeliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      final receipt = purchaseDetails.verificationData.serverVerificationData;
      final productId = purchaseDetails.productID;
      final result = await ApiService.verifyIapReceipt(receipt, productId);
      
      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        if (productId == 'magicbook_refill') {
          _magicBookRefillRemaining = result['refillRemaining'] ?? (_magicBookRefillRemaining + 5);
          await prefs.setInt(_keyMagicBookRefill, _magicBookRefillRemaining);
        } else if (productId == 'voice_slot_extra') {
          _voiceSlotExtra++;
          await prefs.setInt(_keyVoiceSlotExtra, _voiceSlotExtra);
        }
        // Notify listeners if you use ChangeNotifier, else UI updates on next build
      }
    } catch (e) {
      // Failed to verify
    }
  }

  // ── Getters ──

  bool get isSubscribed => _isSubscribed;
  DateTime? get trialStartedAt => _trialStartedAt;
  int get voiceCloneCount => _voiceCloneCount;
  int get magicBookMonthlyUsed => _magicBookMonthlyUsed;
  bool get magicBookTrialUsed => _magicBookTrialUsed;
  int get magicBookRefillRemaining => _magicBookRefillRemaining;

  bool get isTrialActive {
    if (_trialStartedAt == null) return false;
    final now = DateTime.now();
    final expiry = _trialStartedAt!.add(const Duration(days: 7));
    return now.isBefore(expiry);
  }

  bool get hasActiveSubscription {
    return _isSubscribed || isTrialActive;
  }

  /// 마법의 책 잔여 횟수 (구독자 기준, 회수권 포함)
  int get magicBookRemaining {
    if (!_isSubscribed) return _magicBookTrialUsed ? 0 : 1;
    final base = magicBookMonthlyLimit - _magicBookMonthlyUsed;
    return (base > 0 ? base : 0) + _magicBookRefillRemaining;
  }

  /// 보이스 슬롯 총 수 (기본 2 + 확장 IAP)
  int get maxVoiceSlots => baseVoiceSlots + _voiceSlotExtra;

  // ── 권한 체크 ──

  /// 마법의 책 생성 가능 여부
  /// - 구독자: 월 10회 + 회수권 잔여
  /// - 비구독자: 체험 1회 (나레이터 전용)
  bool canUseMagicBook() {
    if (_isSubscribed) {
      return _magicBookMonthlyUsed < magicBookMonthlyLimit ||
          _magicBookRefillRemaining > 0;
    }
    // 비구독: 체험 1회
    if (!_magicBookTrialUsed) return true;
    return false;
  }

  /// 비구독 상태에서 마법의 책 사용 시 나레이터 전용 여부
  bool get isMagicBookNarratorOnly => !_isSubscribed;

  bool canCloneVoice() {
    if (_isSubscribed) return _voiceCloneCount < maxVoiceSlots;
    if (isTrialActive && _voiceCloneCount < 1) return true;
    return false;
  }

  /// 우리집 목소리 / 마법의 책 산출물 재생 가능 여부 (잠금 정책)
  bool canPlayCustomVoice() {
    return hasActiveSubscription;
  }

  /// 회수권 IAP 구매 가능 여부 (구독자 전용, 2.6장 R1)
  bool canPurchaseRefillPack() => _isSubscribed;

  /// 보이스 슬롯 확장 IAP 구매 가능 여부 (구독자 전용, 2.6장 R3)
  bool canPurchaseVoiceSlot() => _isSubscribed;

  // ── 사용량 기록 ──

  /// 마법의 책 서버 응답의 usage 데이터로 로컬 캐시 동기화
  Future<void> syncMagicBookUsage(Map<String, dynamic> usage) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (usage.containsKey('used')) {
      _magicBookMonthlyUsed = usage['used'];
      await prefs.setInt(_magicBookMonthKey(DateTime.now()), _magicBookMonthlyUsed);
      if (!_isSubscribed && _magicBookMonthlyUsed > 0) {
        _magicBookTrialUsed = true;
        await prefs.setBool(_keyMagicBookTrialUsed, true);
      }
    }
    
    if (usage.containsKey('refillRemaining')) {
      _magicBookRefillRemaining = usage['refillRemaining'];
      await prefs.setInt(_keyMagicBookRefill, _magicBookRefillRemaining);
    }
  }

  /// 마법의 책 1회 사용 기록 (로컬 단독 처리는 레거시, 서버 동기화로 대체됨)
  Future<void> incrementMagicBookUsage() async {
    // 실제 차감은 서버에서 수행하므로, 여기서는 임시 상태 반영만
    if (_isSubscribed) {
      if (_magicBookMonthlyUsed < magicBookMonthlyLimit) {
        _magicBookMonthlyUsed++;
      } else if (_magicBookRefillRemaining > 0) {
        _magicBookRefillRemaining--;
      }
    } else {
      _magicBookTrialUsed = true;
    }
  }

  Future<void> incrementVoiceCloneUsage() async {
    _voiceCloneCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVoiceCloneCount, _voiceCloneCount);
  }

  // ── IAP 처리 ──

  /// 마법의 책 회수권 구매 (+5회, ₩2,500, 구독자 전용)
  Future<void> purchaseMagicBookRefill() async {
    if (!_isSubscribed) return;
    
    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({'magicbook_refill'});
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      throw Exception('상품을 찾을 수 없습니다.');
    }
    
    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
  }

  /// 보이스 슬롯 확장 (+1, ₩9,900)
  Future<void> purchaseVoiceSlot() async {
    if (!_isSubscribed) return;
    
    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({'voice_slot_extra'});
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      throw Exception('상품을 찾을 수 없습니다.');
    }
    
    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
  }

  // ── 구독/체험 ──

  Future<void> startTrial() async {
    if (_trialStartedAt != null) return; // Cannot restart
    _trialStartedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrialStartedAt, _trialStartedAt!.toIso8601String());
  }

  // ── DEBUG METHODS ──

  Future<void> debugSetSubscribed(bool value) async {
    _isSubscribed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsSubscribed, value);
  }

  Future<void> debugExpireTrial() async {
    _trialStartedAt = DateTime.now().subtract(const Duration(days: 8));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrialStartedAt, _trialStartedAt!.toIso8601String());
  }

  Future<void> debugResetAll() async {
    _isSubscribed = false;
    _trialStartedAt = null;
    _voiceCloneCount = 0;
    _magicBookMonthlyUsed = 0;
    _magicBookTrialUsed = false;
    _magicBookRefillRemaining = 0;
    _voiceSlotExtra = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsSubscribed);
    await prefs.remove(_keyTrialStartedAt);
    await prefs.remove(_keyVoiceCloneCount);
    await prefs.remove(_keyMagicBookTrialUsed);
    await prefs.remove(_keyMagicBookRefill);
    await prefs.remove(_keyVoiceSlotExtra);
    // 이번 달 사용량도 초기화
    await prefs.remove(_magicBookMonthKey(DateTime.now()));
  }
}

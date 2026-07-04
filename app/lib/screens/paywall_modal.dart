import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

class PaywallModal extends StatefulWidget {
  const PaywallModal({Key? key}) : super(key: key);

  @override
  State<PaywallModal> createState() => _PaywallModalState();
}

class _PaywallModalState extends State<PaywallModal> {
  final SubscriptionService _subService = SubscriptionService();
  bool _isLoading = false;

  Future<void> _handleSubscribe(bool isAnnual) async {
    setState(() => _isLoading = true);
    
    // Simulate network delay for IAP
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock success
    await _subService.debugSetSubscribed(true);
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context, true); // Return true to indicate success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 프리미엄 구독이 완료되었습니다!')),
      );
    }
  }

  Future<void> _handleStartTrial() async {
    setState(() => _isLoading = true);
    
    await Future.delayed(const Duration(seconds: 1));
    await _subService.startTrial();
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ 7일 무료 체험이 시작되었습니다!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canStartTrial = _subService.trialStartedAt == null;

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFE2B714).withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE2B714).withOpacity(0.15), blurRadius: 30, spreadRadius: 5),
                ]
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFFE2B714), size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      '이야기 서재 프리미엄',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif'),
                    ),
                    const SizedBox(height: 20),

                    // ── 블록 A: subscription_guide_app.md ──
                    const _BlockAFeature(
                      title: '우리집 목소리로, 모든 동화를.',
                      desc: '엄마·아빠 목소리를 한 번만 등록하면, 동화 서재의 모든 이야기와 앞으로 추가되는 새 이야기 팩까지 전부 우리집 목소리로 들을 수 있어요.\n이야기 라디오도 우리집 목소리로 이어서 들려드려요.',
                    ),
                    const _BlockAFeature(
                      title: '마법의 책, 매달 10권.',
                      desc: '아이 이름과 오늘 있었던 일을 넣으면 세상에 하나뿐인 동화가 만들어져요.\n매달 10회, 선택한 목소리(우리집 목소리 포함)로 들려드립니다.',
                    ),
                    const _BlockAFeature(
                      title: '광고 없이, 이야기에만 집중.',
                      desc: '모든 화면에서 광고가 사라져요.',
                    ),

                    const SizedBox(height: 8),
                    // 가격 안내
                    const Text(
                      '월 6,900원 / 연 49,000원 (월 4,083원 상당 · 58% 아낌)',
                      style: TextStyle(color: Color(0xFFE2B714), fontSize: 13, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '(현재 결제는 테스트 모드로 실제 청구되지 않습니다)',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    
                    if (canStartTrial) ...[
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleStartTrial,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2B714),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 8,
                          shadowColor: const Color(0xFFE2B714).withOpacity(0.5),
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('✨ 7일 무료 체험 시작하기', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '체험 기간 동안 목소리 1개, 동화 3편을 무료로 만들어볼 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Annual Plan
                    _buildPlanButton(
                      title: '연간 구독 (추천)',
                      price: '₩49,000 / 년',
                      subtitle: '월 4,083원 상당 (58% 아낌)',
                      isPopular: true,
                      onTap: () => _handleSubscribe(true),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Monthly Plan
                    _buildPlanButton(
                      title: '월간 구독',
                      price: '₩6,900 / 월',
                      isPopular: false,
                      onTap: () => _handleSubscribe(false),
                    ),

                    // ── v2.1: IAP 상품 3종 (2.6장) ──
                    if (_subService.isSubscribed) ...[
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('부가 상품', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildIapButton(
                        title: '마법의 책 회수권',
                        desc: '+5회',
                        price: '₩2,500',
                        onTap: () async {
                          await _subService.purchaseMagicBookRefill();
                          if (mounted) {
                            Navigator.pop(context, true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✨ 회수권 5회가 추가되었습니다!')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildIapButton(
                        title: '보이스 슬롯 확장',
                        desc: '+1개 (할머니·할아버지)',
                        price: '₩9,900',
                        onTap: () async {
                          await _subService.purchaseVoiceSlot();
                          if (mounted) {
                            Navigator.pop(context, true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✨ 보이스 슬롯이 추가되었습니다!')),
                            );
                          }
                        },
                      ),
                    ],

                    // 비구독자 전용: 스토리 팩 단권 IAP
                    if (!_subService.isSubscribed) ...[
                      const SizedBox(height: 16),
                      _buildIapButton(
                        title: '스토리 팩 단권',
                        desc: '나레이터 음원 10편 소장',
                        price: '₩3,900',
                        onTap: () {
                          // TODO: 실제 IAP 연동
                          Navigator.pop(context);
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    // 블록 D: 정기결제 및 환불 정책
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            '[알아두세요]\n구독을 해지하면 우리집 목소리 재생은 멈추지만, 만들어진 이야기는 보관함에 안전하게 보존되며 재구독 시 즉시 다시 들을 수 있어요.',
                            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• 정기결제는 현재 결제 주기가 끝나기 24시간 전에 해지하지 않으면 자동 갱신됩니다.\n• 결제 취소(환불)는 스토어 정책에 따라 구매 후 7일 이내, 서비스 미이용 시에만 가능합니다.',
                            style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('다음에 할게요', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }



  Widget _buildPlanButton({
    required String title,
    required String price,
    String? subtitle,
    required bool isPopular,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isPopular ? const Color(0xFFE2B714) : Colors.white24,
            width: isPopular ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isPopular ? const Color(0xFFE2B714).withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: isPopular ? FontWeight.bold : FontWeight.normal)),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2B714),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('BEST', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ]
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xFFE2B714), fontSize: 12)),
                  ]
                ],
              ),
            ),
            Text(price, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildIapButton({
    required String title,
    required String desc,
    required String price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Text(price, style: const TextStyle(color: Color(0xFFE2B714), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _BlockAFeature extends StatelessWidget {
  final String title;
  final String desc;

  const _BlockAFeature({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE2B714).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 12, color: Color(0xFFE2B714)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import 'paywall_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SubscriptionService _subService = SubscriptionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSubscriptionStatus(),
          const SizedBox(height: 32),
          
          const Text('앱 정보', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildListTile('이용 약관', Icons.article),
          _buildListTile('개인정보 처리방침', Icons.privacy_tip),
          _buildListTile('음성 데이터 처리 고지', Icons.record_voice_over),
          _buildListTile('버전 정보', Icons.info, trailing: const Text('v2.0.0', style: TextStyle(color: Colors.white54))),
          
          const SizedBox(height: 48),
          
          // Debug Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('[디버그] 개발자 전용 도구', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('구독 상태 강제 적용 (Mock)', style: TextStyle(color: Colors.white)),
                  value: _subService.isSubscribed,
                  activeColor: const Color(0xFFE2B714),
                  onChanged: (val) async {
                    await _subService.debugSetSubscribed(val);
                    setState(() {});
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _subService.debugExpireTrial();
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('무료 체험을 8일 전으로 되돌려 만료시켰습니다.')));
                    }
                  },
                  child: const Text('무료 체험 즉시 만료시키기'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _subService.debugResetAll();
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('구독 및 횟수 정보가 모두 초기화되었습니다.')));
                    }
                  },
                  child: const Text('모든 구독/횟수 정보 초기화'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSubscriptionStatus() {
    final bool isSubscribed = _subService.isSubscribed;
    final bool isTrialActive = _subService.isTrialActive;
    
    String statusTitle = '무료 회원';
    String statusDesc = '지금 프리미엄을 구독하고 우리집 목소리로 모든 동화를 들어보세요.';
    Color statusColor = Colors.white54;
    
    if (isSubscribed) {
      statusTitle = '프리미엄 구독 중';
      statusDesc = '우리집 목소리 무제한 · 마법의 책(잔여 ${_subService.magicBookRemaining}/10) · 광고 제거';
      statusColor = const Color(0xFFE2B714);
    } else if (isTrialActive) {
      statusTitle = '7일 무료 체험 중';
      statusDesc = '마법의 책(잔여 ${1 - (_subService.magicBookTrialUsed ? 1 : 0)}회) · 목소리 등록 가능';
      statusColor = Colors.lightBlueAccent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF232336),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isSubscribed || isTrialActive ? Icons.workspace_premium : Icons.person_outline, color: statusColor, size: 28),
              const SizedBox(width: 12),
              Text(statusTitle, style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusDesc, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          if (!isSubscribed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2B714),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final result = await showDialog<bool>(context: context, builder: (context) => const PaywallModal());
                if (result == true) {
                  setState(() {});
                }
              },
              child: const Text('프리미엄 구독 알아보기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (isSubscribed)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showCancelDialog(),
              child: const Text('구독 관리 / 해지'),
            ),
        ],
      ),
    );
  }

  /// v2.1: 해지 화면 (블록 B)
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232336),
        title: const Text('해지 전에 꼭 확인해 주세요', style: TextStyle(color: Colors.white)),
        content: const Text(
          '• 해지하면 우리집 목소리와 마법의 책 이야기 재생이 중지됩니다.\n'
          '• 하지만 보관함은 삭제되지 않아요. 그동안 만든 이야기 목록과 표지는 그대로 남아 있습니다.\n'
          '• 재구독하면 즉시, 전부 다시 들을 수 있어요. 다시 만들 필요도, 추가 비용도 없습니다.\n'
          '• 나레이터 목소리 동화와 이야기 라디오는 해지 후에도 계속 무료로 들을 수 있어요.',
          style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('유지하기', style: TextStyle(color: Color(0xFFE2B714), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Mock cancellation
              await _subService.debugSetSubscribed(false);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('구독이 해지되었습니다. 남은 기간 동안은 계속 이용 가능합니다.')),
                );
              }
            },
            child: const Text('해지할게요', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(String title, IconData icon, {Widget? trailing}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white54),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: () {
        // TODO: Show terms or policies
      },
    );
  }
}

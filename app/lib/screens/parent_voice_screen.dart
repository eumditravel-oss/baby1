import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_service.dart';
import 'paywall_modal.dart';
import 'voice_recording_flow.dart';

class ParentVoiceScreen extends StatefulWidget {
  const ParentVoiceScreen({Key? key}) : super(key: key);

  @override
  State<ParentVoiceScreen> createState() => _ParentVoiceScreenState();
}

class _ParentVoiceScreenState extends State<ParentVoiceScreen> {
  List<String> _clonedVoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final prefs = await SharedPreferences.getInstance();
    final voices = prefs.getStringList('cloned_voices') ?? [];
    setState(() {
      _clonedVoices = voices;
      _isLoading = false;
    });
  }

  Future<void> _addVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    final voices = prefs.getStringList('cloned_voices') ?? [];
    if (!voices.contains(voiceId)) {
      voices.add(voiceId);
      await prefs.setStringList('cloned_voices', voices);
      setState(() {
        _clonedVoices = voices;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE2B714))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('우리집 목소리', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _clonedVoices.isEmpty ? _buildEmptyState() : _buildVoiceList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.record_voice_over, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              '아직 등록된 우리집 목소리가 없습니다.',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '엄마, 아빠의 목소리를 녹음하여\n아이에게 친숙한 목소리로 동화를 들려주세요!',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2B714),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final subService = SubscriptionService();
                if (!subService.canCloneVoice()) {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const PaywallModal(),
                  );
                  if (result != true) return;
                }

                final newVoiceId = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoiceRecordingFlow()),
                );
                if (newVoiceId != null && newVoiceId is String) {
                  _addVoice(newVoiceId);
                  await subService.incrementVoiceCloneUsage();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('새 목소리 등록하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _clonedVoices.length + 1,
      itemBuilder: (context, index) {
        if (index == _clonedVoices.length) {
          // Add new voice button
          if (_clonedVoices.length >= 2) return const SizedBox.shrink(); // 최대 2개 슬롯
          
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final subService = SubscriptionService();
                if (!subService.canCloneVoice()) {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const PaywallModal(),
                  );
                  if (result != true) return;
                }

                final newVoiceId = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoiceRecordingFlow()),
                );
                if (newVoiceId != null && newVoiceId is String) {
                  _addVoice(newVoiceId);
                  await subService.incrementVoiceCloneUsage();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('새 목소리 추가 (최대 2개)'),
            ),
          );
        }

        final voiceId = _clonedVoices[index];
        return Card(
          color: const Color(0xFF232336),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE2B714).withOpacity(0.2),
              child: const Icon(Icons.person, color: Color(0xFFE2B714)),
            ),
            title: Text('등록된 목소리 ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('동화 서재에서 이 목소리로 동화를 들을 수 있습니다.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                _clonedVoices.remove(voiceId);
                await prefs.setStringList('cloned_voices', _clonedVoices);
                setState(() {});
              },
            ),
          ),
        );
      },
    );
  }
}

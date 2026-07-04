import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/api_service.dart';
import '../models/voice_model.dart';
import '../models/story_model.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../widgets/voice_card.dart';
import 'paywall_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  final _eventController = TextEditingController();
  final _characterController = TextEditingController();
  
  List<VoiceModel> _voices = [];
  bool _isLoadingVoices = true;
  VoiceModel? _selectedVoice;
  
  List<StoryModel> _savedStories = [];
  bool _isLoadingStories = true;
  bool _isGenerating = false;

  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadVoices();
    _loadSavedStories();
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    _nameController.dispose();
    _eventController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedStories() async {
    final stories = await StorageService.getCustomStories();
    setState(() {
      // Show newest first
      _savedStories = stories.reversed.toList();
      _isLoadingStories = false;
    });
  }

  Future<void> _loadVoices() async {
    try {
      final data = await ApiService.fetchVoices();
      final List<VoiceModel> loadedVoices = [];
      
      if (data['premium'] != null) {
        loadedVoices.add(VoiceModel.fromJson(data['premium'], isPremium: true));
      }
      
      if (data['standard'] != null) {
        for (var v in data['standard']) {
          loadedVoices.add(VoiceModel.fromJson(v, isPremium: false));
        }
      }
      
      setState(() {
        _voices = loadedVoices;
        if (_voices.isNotEmpty) {
          _selectedVoice = _voices.first;
        }
        _isLoadingVoices = false;
      });
    } catch (e) {
      print('Error loading voices: $e');
      setState(() {
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _onGenerateStory() async {
    final subService = SubscriptionService();
    if (!subService.canUseMagicBook()) {
      // v2.1: 구독자 회수권 안내 vs 비구독 구독 유도
      if (subService.isSubscribed && subService.magicBookRemaining <= 0) {
        _showRefillDialog();
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => const PaywallModal(),
      );
      if (result != true) return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이 이름을 입력해주세요!')),
      );
      return;
    }

    if (_selectedVoice == null) return;

    // v2.1: 비구독 체험은 나레이터 목소리로만 생성
    final effectiveVoiceId = subService.isMagicBookNarratorOnly
        ? 'narrator_warm_placeholder'
        : _selectedVoice!.id;
    final effectiveVoiceName = subService.isMagicBookNarratorOnly
        ? '포근한 선생님'
        : _selectedVoice!.name;

    setState(() {
      _isGenerating = true;
    });

    try {
      final response = await ApiService.generateMagicStory({
        'name': _nameController.text.trim(),
        'event': _eventController.text.trim(),
        'character': _characterController.text.trim(),
        'voiceId': effectiveVoiceId,
        'voiceName': effectiveVoiceName,
      });

      final newStory = StoryModel(
        id: response['id'],
        title: response['title'],
        desc: '마법의 책에서 만든 나만의 동화',
        category: 'magic',
        content: response['text'] ?? '',
        ttsText: response['text'] ?? '',
        audioUrl: response['audioUrl'],
        imageUrl: response['imageUrl'],
        voiceName: response['voiceName'],
        durationEstSec: response['duration'] ?? 60,
        isCustom: true,
      );

      await StorageService.saveStory(newStory);
      if (response.containsKey('usage')) {
        await subService.syncMagicBookUsage(response['usage']);
      }
      await _loadSavedStories();

      if (mounted) {
        _nameController.clear();
        _eventController.clear();
        _characterController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ 마법 동화책이 완성되었어요!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동화 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// v2.1: 회수권 IAP 안내 (구독자 전용, 2.6장 R1)
  void _showRefillDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232336),
        title: const Text('이번 달 횟수를 다 사용했어요', style: TextStyle(color: Colors.white)),
        content: const Text(
          '횟수를 다 쓰셨다면 회수권(5회 · 2,500원)을 구매할 수 있어요.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Mock IAP purchase
              await SubscriptionService().purchaseMagicBookRefill();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✨ 회수권 5회가 추가되었습니다!')),
                );
              }
            },
            child: const Text('회수권 구매 (₩2,500)', style: TextStyle(color: Color(0xFFE2B714), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _playStory(StoryModel story) async {
    final subService = SubscriptionService();
    if (!subService.canPlayCustomVoice()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF232336),
          title: const Text('재생 불가', style: TextStyle(color: Colors.white)),
          content: const Text('구독이 만료되어 재생할 수 없습니다.\n해지 시 재생이 중지되며, 보관함 데이터는 삭제되지 않고 재구독 즉시 복구됩니다.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(context: context, builder: (context) => const PaywallModal());
              },
              child: const Text('구독하기', style: TextStyle(color: Color(0xFFE2B714), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await _previewPlayer.stop();
      final audioSource = AudioSource.uri(
        Uri.parse(story.audioUrl ?? ''),
        tag: MediaItem(
          id: story.id,
          title: story.title,
          artist: story.voiceName ?? '성우',
          artUri: Uri.parse(story.imageUrl),
        ),
      );
      await _previewPlayer.setAudioSource(audioSource);
      _previewPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재생 실패: $e')),
        );
      }
    }
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFF232336),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          appBar: AppBar(
            title: const Text('마법의 책', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Lottie Animation for visual appeal
                      SizedBox(
                        height: 150,
                        child: Lottie.network(
                          'https://assets9.lottiefiles.com/packages/lf20_xwnzix1l.json', // Magic book / stars animation (placeholder)
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_awesome, size: 80, color: Color(0xFFE2B714)),
                        ),
                      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 16),
                      const Text('새로운 이야기 짓기', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      // v2.1: 블록 C 안내 + 잔여 횟수
                      Builder(builder: (context) {
                        final sub = SubscriptionService();
                        final remaining = sub.magicBookRemaining;
                        if (sub.isSubscribed) {
                          return Text(
                            '매달 10회 새 이야기를 만들 수 있어요. 한 번 만든 이야기는 몇 번을 다시 들어도 횟수가 줄지 않아요.\n남은 횟수: $remaining회',
                            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                          );
                        } else if (!sub.magicBookTrialUsed) {
                          return const Text(
                            '1회 무료 체험이 가능해요. 체험 동화는 포근한 선생님 목소리로 만들어지고, 우리집 목소리로 들으려면 구독이 필요해요.',
                            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                          );
                        } else {
                          return const Text(
                            '무료 체험을 이미 사용했어요. 구독하면 매달 10회, 우리집 목소리로 들을 수 있어요.',
                            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                          );
                        }
                      }),
                      const SizedBox(height: 32),
                      
                      _buildTextField('아이 이름 (필수)', '예: 지우', _nameController),
                      _buildTextField('오늘 있었던 일', '예: 처음으로 자전거를 탔어요', _eventController),
                      _buildTextField('좋아하는 캐릭터', '예: 용감한 사자', _characterController),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('누구의 목소리로 들을까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (!_isLoadingVoices)
                        Text('${_voices.length}개의 목소리', style: const TextStyle(color: Color(0xFFE2B714), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Horizontal Voice Cards
                SizedBox(
                  height: 200,
                  child: _isLoadingVoices
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B714)))
                      : _voices.isEmpty
                          ? const Center(child: Text('성우 정보를 불러올 수 없습니다.', style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              scrollDirection: Axis.horizontal,
                              itemCount: _voices.length,
                              itemBuilder: (context, index) {
                                final voice = _voices[index];
                                return VoiceCard(
                                  voice: voice,
                                  isSelected: _selectedVoice?.id == voice.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedVoice = voice;
                                    });
                                  },
                                );
                              },
                            ),
                ),
                
                const SizedBox(height: 48),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: const Color(0xFFE2B714),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFFE2B714).withOpacity(0.5),
                    ),
                    onPressed: _isLoadingVoices || _isGenerating ? null : _onGenerateStory,
                    child: const Text('✨ 마법 동화책 만들기', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.4))
                   .scaleXY(end: 1.02, duration: 1000.ms),
                ),
                const SizedBox(height: 48),
                
                // Saved Stories Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: const Text('나만의 보관함', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                
                _isLoadingStories 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B714)))
                    : _savedStories.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
                            child: Center(
                              child: Text('아직 저장된 동화책이 없어요.\n첫 번째 이야기를 만들어보세요!', 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, height: 1.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _savedStories.length,
                            itemBuilder: (context, index) {
                              final story = _savedStories[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF232336),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      story.imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(width: 60, height: 60, color: Colors.black26),
                                    ),
                                  ),
                                  title: Text(story.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text('${story.voiceName ?? "성우"} 님이 읽어주는 이야기', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE2B714), size: 36),
                                    onPressed: () => _playStory(story),
                                  ),
                                  onTap: () => _playStory(story),
                                ),
                              );
                            },
                          ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Full Screen Loading Overlay
        if (_isGenerating)
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    child: Lottie.network(
                      'https://assets4.lottiefiles.com/packages/lf20_t2v9x22v.json', // Writing/magic animation
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const CircularProgressIndicator(color: Color(0xFFE2B714)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('✨ 마법의 책을 쓰고 있어요...\n잠시만 기다려주세요.', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5)
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .fade(begin: 0.5, end: 1.0, duration: 1000.ms),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }
}

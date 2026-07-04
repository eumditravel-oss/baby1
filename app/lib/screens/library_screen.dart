import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/story_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/subscription_service.dart';
import 'paywall_modal.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<StoryModel> _stories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final String response = await rootBundle.loadString('assets/data/stories_v2.json');
      final data = await json.decode(response);
      final List<dynamic> storiesJson = data['stories'] ?? [];
      
      setState(() {
        _stories = storiesJson.map((s) => StoryModel.fromJson(s)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stories: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('동화 서재', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B714)))
          : _errorMessage != null
              ? Center(child: Text('에러 발생:\n$_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    mainAxisExtent: 270, 
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _stories.length,
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    return GestureDetector(
                      onTap: () {
                        _showStoryDetail(context, story);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 120,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (story.imageUrl.startsWith('assets/'))
                                  ? Image.asset(
                                      story.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(color: const Color(0xFF232336)),
                                    )
                                  : Image.network(
                                      story.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(color: const Color(0xFF232336)),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            story.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${story.durationEstSec ~/ 60}분 ${story.durationEstSec % 60}초',
                            style: const TextStyle(color: Color(0xFFE2B714), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              story.desc,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: (index * 50).ms).slideY(begin: 0.1, end: 0, duration: 500.ms);
                  },
                ),
    );
  }

  void _showStoryDetail(BuildContext context, StoryModel story) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _StoryDetailSheet(story: story);
      },
    );
  }
}

class _StoryDetailSheet extends StatefulWidget {
  final StoryModel story;
  const _StoryDetailSheet({Key? key, required this.story}) : super(key: key);

  @override
  State<_StoryDetailSheet> createState() => _StoryDetailSheetState();
}

class _StoryDetailSheetState extends State<_StoryDetailSheet> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  
  List<String> _clonedVoices = [];
  String? _selectedVoiceId;

  @override
  void initState() {
    super.initState();
    _loadVoices();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
    _audioPlayer.processingStateStream.listen((state) {
      if (mounted && state == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
        });
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
  }

  Future<void> _loadVoices() async {
    final prefs = await SharedPreferences.getInstance();
    final voices = prefs.getStringList('cloned_voices') ?? [];
    if (mounted) {
      setState(() {
        _clonedVoices = voices;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    final storyId = widget.story.id;

    setState(() {
      _isLoadingAudio = true;
    });

    try {
      if (_selectedVoiceId != null) {
        final subService = SubscriptionService();
        if (!subService.canPlayCustomVoice()) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF232336),
              title: const Text('재생 불가', style: TextStyle(color: Colors.white)),
              content: const Text('구독이 만료되어 우리집 목소리로 재생할 수 없습니다.\n해지 시 재생이 중지되며, 보관함 데이터는 삭제되지 않고 재구독 즉시 복구됩니다.', style: TextStyle(color: Colors.white70)),
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
          setState(() {
            _isLoadingAudio = false;
          });
          return;
        }

        // 우리집 목소리로 온디맨드 생성 및 재생
        final url = await ApiService.generateStoryAudio(_selectedVoiceId!, storyId);
        final audioSource = AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: storyId,
            title: widget.story.title,
            artist: '우리집 목소리',
          ),
        );
        await _audioPlayer.setAudioSource(audioSource);
        _audioPlayer.play();
      } else {
        // 기본 에셋 음원 재생 — 파일명 해석
        String audioUri = 'asset:///assets/audio/$storyId.mp3';
        // story_01 → story_story_01.mp3 형태도 시도
        const availableFiles = {'story_01', 'story_story_01', 'story_story_02', 'story_story_03'};
        if (!availableFiles.contains(storyId)) {
          final prefixed = 'story_$storyId';
          if (availableFiles.contains(prefixed)) {
            audioUri = 'asset:///assets/audio/$prefixed.mp3';
          } else {
            audioUri = 'asset:///assets/audio/story_01.mp3'; // 폴백
          }
        }
        final audioSource = AudioSource.uri(
          Uri.parse(audioUri),
          tag: MediaItem(
            id: storyId,
            title: widget.story.title,
            artist: '포포의 서재',
          ),
        );
        await _audioPlayer.setAudioSource(audioSource);
        _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오디오 재생 실패: $e')));
        // 실패 시 기본 음원으로 폴백 시도
        try {
          final fallbackSource = AudioSource.uri(
            Uri.parse('asset:///assets/audio/story_01.mp3'),
            tag: MediaItem(
              id: 'story_01',
              title: widget.story.title,
              artist: '포포의 서재',
            ),
          );
          await _audioPlayer.setAudioSource(fallbackSource);
          _audioPlayer.play();
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle for dragging
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Story Title & Image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (widget.story.imageUrl.startsWith('assets/'))
                      ? Image.asset(
                          widget.story.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: const Color(0xFF232336)),
                        )
                      : Image.network(
                          widget.story.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: const Color(0xFF232336)),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.story.title,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      
                      // Voice Selector
                      if (_clonedVoices.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedVoiceId,
                              dropdownColor: const Color(0xFF232336),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('기본 목소리'),
                                ),
                                ..._clonedVoices.asMap().entries.map((e) => DropdownMenuItem(
                                  value: e.value,
                                  child: Text('우리집 목소리 ${e.key + 1}'),
                                )).toList(),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedVoiceId = val;
                                  if (_isPlaying) {
                                    _audioPlayer.stop();
                                    _isPlaying = false;
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Play Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2B714),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _isLoadingAudio ? null : _togglePlay,
                        icon: _isLoadingAudio
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 20),
                        label: Text(_isLoadingAudio ? '생성 및 불러오는 중...' : (_isPlaying ? '일시정지' : '동화 듣기'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Divider(color: Colors.white24),
          ),
          // Story Full Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Text(
                widget.story.content,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

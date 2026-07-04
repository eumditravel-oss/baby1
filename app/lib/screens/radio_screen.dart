import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_service.dart';
import '../services/api_service.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({Key? key}) : super(key: key);

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final AudioPlayer _player = AudioPlayer();
  late ConcatenatingAudioSource _playlist;

  bool _isPlaying = false;
  bool _isLoadingAudio = true;
  bool _isShuffle = false;
  int _timerOption = 0; // 0: 끄기, 15: 15분, 30: 30분, 60: 60분, -1: 이번 동화 끝날 때
  Timer? _sleepTimer;
  StreamSubscription? _indexSub;
  StreamSubscription? _stateSub;

  Map<String, dynamic>? _currentStory;
  List<dynamic> _allStories = [];
  bool _isLoading = true;
  String? _errorMessage;

  // v2.1: 우리집 목소리 모드 (1.3-6항)
  bool _isCustomVoiceMode = false;
  String? _customVoiceId;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  // 실제 assets/audio/ 에 존재하는 파일명 (확장자 제외)
  // 새 오디오 파일을 추가하면 여기도 업데이트 필요
  // v2.1 음성 확정: story_story_02_ASMR = narrator_warm 1순위
  static const Set<String> _availableAudioFiles = {
    'story_01',
    'story_story_01',
    'story_story_01_ASMR',
    'story_story_02',
    'story_story_02_ASMR',
    'story_story_03',
    'story_story_03_ASMR',
    'story_story_04_ASMR',
    'story_story_05_ASMR',
    'story_story_06_KIDS',
    'story_story_06_KINDER',
  };

  /// storyId에 매칭되는 에셋 오디오 경로를 반환, 없으면 null
  String? _resolveAudioAsset(String storyId) {
    // 1) 정확히 storyId.mp3가 있는지
    if (_availableAudioFiles.contains(storyId)) {
      return 'asset:///assets/audio/$storyId.mp3';
    }
    // 2) story_ prefix가 붙은 형태 (story_01 → story_story_01)
    final prefixed = 'story_$storyId';
    if (_availableAudioFiles.contains(prefixed)) {
      return 'asset:///assets/audio/$prefixed.mp3';
    }
    return null;
  }

  Future<void> _initAudio() async {
    try {
      final String response = await rootBundle.loadString('assets/data/stories_v2.json');
      final data = await json.decode(response);
      _allStories = data['stories'] ?? [];

      List<AudioSource> audioSources = [];
      List<dynamic> playableStories = []; // 플레이리스트에 실제 들어간 스토리만 추적
      
      for (int i = 0; i < _allStories.length; i++) {
        final story = _allStories[i];
        final storyId = story['id'] ?? '';
        final audioPath = _resolveAudioAsset(storyId);

        // 오디오 파일이 없는 스토리는 건너뛰기
        if (audioPath == null) continue;

        // 구독 유도 프롬프트를 3번째 트랙 위치에 삽입
        if (audioSources.length == 2) {
          audioSources.add(
            AudioSource.uri(
              Uri.parse('asset:///assets/audio/story_01.mp3'),
              tag: MediaItem(
                id: 'upsell_prompt',
                title: '엄마 아빠 목소리로 듣고 싶다면?',
                artist: '포포의 서재',
                artUri: Uri.parse('https://placehold.co/600x600/E2B714/1A1A2E?text=Subscription'),
              ),
            ),
          );
        }

        audioSources.add(
          AudioSource.uri(
            Uri.parse(audioPath),
            tag: MediaItem(
              id: storyId,
              title: story['title'] ?? '알 수 없는 이야기',
              artist: '포포의 서재',
              artUri: story['imageUrl'] != null && !story['imageUrl'].startsWith('assets/')
                  ? Uri.parse(story['imageUrl'])
                  : Uri.parse('https://placehold.co/600x600/2A2A4A/E2B714?text=Dream+Radio'),
            ),
          ),
        );
        playableStories.add(story);
      }

      if (audioSources.isEmpty) {
        // 재생 가능한 오디오가 하나도 없는 경우
        setState(() {
          _isLoading = false;
          _errorMessage = '재생 가능한 동화 오디오가 없습니다.';
        });
        return;
      }

      _playlist = ConcatenatingAudioSource(children: audioSources);
      await _player.setAudioSource(_playlist, initialIndex: 0, initialPosition: Duration.zero);
      await _player.setLoopMode(LoopMode.all);

      // Listen to state changes
      _stateSub = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            _isLoadingAudio = state.processingState == ProcessingState.loading || 
                              state.processingState == ProcessingState.buffering;
          });
        }
      });

      // Listen to track changes to update UI and handle "Stop at end of track" timer
      _indexSub = _player.currentIndexStream.listen((index) {
        if (index == null) return;
        
        if (_timerOption == -1) {
          // "이번 동화 끝날 때" 였고 트랙이 넘어갔다면 일시정지
          _player.pause();
          setState(() => _timerOption = 0);
          return;
        }

        // 구독 유도 트랙인지 검사
        if (index < _playlist.children.length) {
          final seq = _playlist.children[index].sequence;
          if (seq.isNotEmpty) {
            final currentTag = seq.first.tag as MediaItem;
            
            if (mounted) {
              setState(() {
                if (currentTag.id == 'upsell_prompt') {
                  _currentStory = {
                    'id': 'upsell',
                    'title': currentTag.title,
                    'imageUrl': currentTag.artUri?.toString()
                  };
                } else {
                  _currentStory = _allStories.firstWhere(
                    (s) => s['id'] == currentTag.id, 
                    orElse: () => _allStories.isNotEmpty ? _allStories.first : {'id': '', 'title': '알 수 없는 이야기'},
                  );
                }
              });
            }
            // v2.1: 우리집 목소리 모드 시 다음 트랙 프리페치 (1.3-6항)
            if (_isCustomVoiceMode && _customVoiceId != null) {
              _prefetchNextTrack(index);
            }
          }
        }
      });

      // v2.1: 저장된 우리집 목소리 모드 상태 복원
      final prefs = await SharedPreferences.getInstance();
      _customVoiceId = prefs.getString('radio_custom_voice_id');
      _isCustomVoiceMode = prefs.getBool('radio_custom_voice_mode') ?? false;
      if (_isCustomVoiceMode && !SubscriptionService().canPlayCustomVoice()) {
        _isCustomVoiceMode = false; // 구독 해지 시 자동 전환
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Radio init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _indexSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// v2.1: 우리집 목소리 모드 토글 (1.3-6항)
  Future<void> _toggleCustomVoiceMode() async {
    final subService = SubscriptionService();
    if (!subService.canPlayCustomVoice()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독하면 우리집 목소리로 이야기 라디오를 들을 수 있어요.')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final voices = prefs.getStringList('cloned_voices') ?? [];
    if (voices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 우리집 목소리를 등록해주세요.')),
        );
      }
      return;
    }

    setState(() {
      _isCustomVoiceMode = !_isCustomVoiceMode;
      if (_isCustomVoiceMode) {
        _customVoiceId = voices.first;
      }
    });

    await prefs.setBool('radio_custom_voice_mode', _isCustomVoiceMode);
    if (_customVoiceId != null) {
      await prefs.setString('radio_custom_voice_id', _customVoiceId!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isCustomVoiceMode ? '우리집 목소리 모드로 전환했어요.' : '나레이터 목소리로 전환했어요.')),
      );
    }
  }

  /// v2.1: 다음 트랙 1편 프리페치 — 대기시간을 숨기기 위해 미리 생성 요청
  void _prefetchNextTrack(int currentIndex) {
    if (_customVoiceId == null) return;
    final nextIndex = (currentIndex + 1) % _allStories.length;
    if (nextIndex < _allStories.length) {
      final nextStory = _allStories[nextIndex];
      final nextId = nextStory['id'] ?? '';
      ApiService.prefetchStoryAudio(_customVoiceId!, nextId);
    }
  }

  Future<void> _toggleShuffle() async {
    final enable = !_isShuffle;
    await _player.setShuffleModeEnabled(enable);
    setState(() {
      _isShuffle = enable;
    });
  }

  void _setTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() => _timerOption = minutes);
    
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (mounted) {
          _player.pause();
          setState(() => _timerOption = 0);
        }
      });
    }
  }

  void _showTimerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232336),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('취침 타이머 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('타이머 끄기', style: TextStyle(color: Colors.white)),
                trailing: _timerOption == 0 ? const Icon(Icons.check, color: Color(0xFFE2B714)) : null,
                onTap: () {
                  _setTimer(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('이번 동화 끝날 때', style: TextStyle(color: Colors.white)),
                trailing: _timerOption == -1 ? const Icon(Icons.check, color: Color(0xFFE2B714)) : null,
                onTap: () {
                  _setTimer(-1); // -1 signifies "end of current track" handled in currentIndexStream
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('15분 후', style: TextStyle(color: Colors.white)),
                trailing: _timerOption == 15 ? const Icon(Icons.check, color: Color(0xFFE2B714)) : null,
                onTap: () {
                  _setTimer(15);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('30분 후', style: TextStyle(color: Colors.white)),
                trailing: _timerOption == 30 ? const Icon(Icons.check, color: Color(0xFFE2B714)) : null,
                onTap: () {
                  _setTimer(30);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('1시간 후', style: TextStyle(color: Colors.white)),
                trailing: _timerOption == 60 ? const Icon(Icons.check, color: Color(0xFFE2B714)) : null,
                onTap: () {
                  _setTimer(60);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('이야기 라디오', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          // v2.1: 우리집 목소리 모드 토글
          IconButton(
            icon: Icon(
              _isCustomVoiceMode ? Icons.record_voice_over : Icons.record_voice_over_outlined,
              color: _isCustomVoiceMode ? const Color(0xFFE2B714) : Colors.white54,
            ),
            tooltip: _isCustomVoiceMode ? '우리집 목소리 ON' : '나레이터 목소리',
            onPressed: _toggleCustomVoiceMode,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE2B714)))
        : _errorMessage != null
            ? Center(child: Text('에러 발생:\n$_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))
            : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album Art
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE2B714).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (_currentStory?['imageUrl']?.startsWith('http') ?? false)
                  ? Image.network(
                      _currentStory!['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(color: const Color(0xFF232336)),
                    )
                  : Image.asset(
                      _currentStory?['imageUrl'] ?? 'assets/images/story_01.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(color: const Color(0xFF232336)),
                    ),
            ),
          ),
          const SizedBox(height: 40),
          
          // Track Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _currentStory?['title'] ?? '알 수 없는 이야기', 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
            ),
          ),
          const SizedBox(height: 8),
          const Text('동화 서재 연속 재생 중...', style: TextStyle(fontSize: 14, color: Colors.white54)),
          const SizedBox(height: 48),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.shuffle, color: _isShuffle ? const Color(0xFFE2B714) : Colors.white54),
                iconSize: 28,
                onPressed: _toggleShuffle,
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 40,
                onPressed: () => _player.seekToPrevious(),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2B714),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoadingAudio
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.black,
                          size: 40,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 40,
                onPressed: () => _player.seekToNext(),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: Icon(Icons.timer, color: _timerOption != 0 ? const Color(0xFFE2B714) : Colors.white54),
                iconSize: 28,
                onPressed: _showTimerBottomSheet,
              ),
            ],
          ),
          
          if (_timerOption > 0) ...[
            const SizedBox(height: 32),
            Text('타이머: $_timerOption분 뒤 종료', style: const TextStyle(color: Color(0xFFE2B714), fontSize: 14)),
          ] else if (_timerOption == -1) ...[
            const SizedBox(height: 32),
            const Text('타이머: 이번 동화 끝날 때 종료', style: TextStyle(color: Color(0xFFE2B714), fontSize: 14)),
          ]
        ],
      ),
    );
  }
}

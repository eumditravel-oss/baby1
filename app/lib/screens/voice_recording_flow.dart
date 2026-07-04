import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

class VoiceRecordingFlow extends StatefulWidget {
  const VoiceRecordingFlow({Key? key}) : super(key: key);

  @override
  State<VoiceRecordingFlow> createState() => _VoiceRecordingFlowState();
}

class _VoiceRecordingFlowState extends State<VoiceRecordingFlow> {
  late AudioRecorder _record;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;

  bool _isUploading = false;
  bool _consentChecked = false;
  
  // Noise monitoring
  StreamSubscription<Amplitude>? _amplitudeSub;
  double _currentDb = -160.0;
  bool _isTooNoisy = false;
  bool _hasSpokenLoudly = false;

  final String _scriptText = '''안녕? 오늘은 아주 재미있는 이야기를 들려줄게.
옛날 옛날, 숲속 마을에 작은 곰돌이가 살았어요.
곰돌이는 아침마다 노래를 부르며 꿀을 찾으러 갔답니다.
"오늘은 어떤 신나는 일이 생길까?"
하늘은 파랗고, 바람은 살랑살랑 불었어요. 우와, 저기 좀 봐! 반짝반짝 빛나는 시냇물이 흐르고 있네.
곰돌이는 폴짝폴짝 뛰어가서 시원한 물을 마셨어요. 정말 달콤하고 시원했지요.
해가 저물자 곰돌이는 집으로 돌아왔어요. 오늘도 참 즐거운 하루였구나.
우리 내일 또 만나자. 사랑해.''';

  @override
  void initState() {
    super.initState();
    _record = AudioRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _record.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/parent_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _record.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

        setState(() {
          _isRecording = true;
          _audioPath = path;
          _recordDuration = 0;
          _hasSpokenLoudly = false;
          _isTooNoisy = false;
        });

        _startTimer();
        _amplitudeSub = _record.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amp) {
          setState(() {
            _currentDb = amp.current;
            // -10 ~ -5 dBFS is considered loud speech. -40 or lower is silence/background.
            if (_currentDb > -15.0) {
              _hasSpokenLoudly = true;
            }
            if (_currentDb > -2.0) {
               // Clipping/too noisy
              _isTooNoisy = true;
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('녹음 오류: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    final path = await _record.stop();
    setState(() {
      _isRecording = false;
      if (path != null) _audioPath = path;
    });

    if (!_hasSpokenLoudly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목소리가 너무 작게 녹음되었습니다. 조금 더 크게 다시 녹음해 주세요.'))
        );
      }
    } else if (_isTooNoisy) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주변 소음이 컸거나 목소리가 너무 컸습니다. 다시 녹음해 주세요.'))
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _recordDuration++);
      // Auto stop after 3 minutes just in case
      if (_recordDuration >= 180) {
        _stopRecording();
      }
    });
  }

  Future<void> _uploadVoice() async {
    if (_audioPath == null) return;
    if (!_consentChecked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('목소리 사용 동의가 필요합니다.')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final voiceId = await ApiService.cloneVoice(_audioPath!, "엄마 목소리 (테스트)", _consentChecked);
      if (mounted) {
        // F7: docs/policy/subscription_guide_app.md 블록 D 문구 반영
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF232336),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFFE2B714), size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '등록 완료! 이제 이렇게 들려드려요',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlockDItem(
                  icon: Icons.library_music,
                  text: '동화 서재의 모든 이야기를 우리집 목소리로 재생할 수 있어요.',
                ),
                SizedBox(height: 12),
                _BlockDItem(
                  icon: Icons.hourglass_bottom,
                  text: '각 이야기는 처음 재생할 때 한 번만 목소리로 만들어지고, 그다음부터는 바로 재생돼요. 첫 재생 시 잠시 준비 시간이 있을 수 있어요.',
                ),
                SizedBox(height: 12),
                _BlockDItem(
                  icon: Icons.inventory_2,
                  text: '만들어진 이야기는 보관함에 차곡차곡 쌓여요.',
                ),
                SizedBox(height: 12),
                _BlockDItem(
                  icon: Icons.shield,
                  text: '소중한 목소리를 지키기 위해 다운로드는 제공하지 않아요. 앱 안에서 안전하게 보관·재생됩니다.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인', style: TextStyle(color: Color(0xFFE2B714), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context, voiceId); // Return voice_id
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('생성 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('목소리 녹음하기', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '조용한 방에서 입과 20cm 정도 거리를 두고, 평소보다 반 톤 밝게 아래 대본을 읽어주세요.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF232336),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _scriptText,
                    style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isRecording)
              Column(
                children: [
                  SizedBox(
                    height: 80,
                    child: Lottie.network(
                      'https://assets2.lottiefiles.com/packages/lf20_tcvqmq4o.json', // Audio waveform Lottie
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.mic, color: Color(0xFFE2B714), size: 40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '녹음 중... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xFFE2B714), fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 1000.ms),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRecording && _audioPath == null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2B714),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      elevation: 8,
                      shadowColor: const Color(0xFFE2B714).withOpacity(0.5),
                    ),
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('녹음 시작', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scaleXY(end: 1.05, duration: 1000.ms)
                   .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.4)),
                if (_isRecording)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('녹음 중지', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.02, duration: 800.ms),
                if (!_isRecording && _audioPath != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        _audioPath = null;
                        _hasSpokenLoudly = false;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 녹음'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2B714),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isUploading ? null : _uploadVoice,
                      child: _isUploading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('목소리 만들기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ]
              ],
            ),
            if (!_isRecording && _audioPath != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _consentChecked,
                    onChanged: (val) {
                      setState(() => _consentChecked = val ?? false);
                    },
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFE2B714);
                      }
                      return Colors.white24;
                    }),
                  ),
                  const Expanded(
                    child: Text(
                      '본인의 목소리이며 이 앱의 낭독 생성에 사용함에 동의합니다.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

/// F7: 블록 D 문구 다이얼로그 항목 위젯
/// 근거: docs/policy/subscription_guide_app.md § D
class _BlockDItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BlockDItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFE2B714), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}

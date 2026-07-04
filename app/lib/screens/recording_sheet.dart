import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import 'paywall_modal.dart';

class RecordingSheet extends StatefulWidget {
  const RecordingSheet({Key? key}) : super(key: key);

  @override
  State<RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends State<RecordingSheet> {
  late AudioRecorder _record;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;
  
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _record = AudioRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _record.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _record.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        
        setState(() {
          _isRecording = true;
          _audioPath = path;
        });
        _startTimer();
      }
    } catch (e) {
      print('Recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _record.stop();
    setState(() {
      _isRecording = false;
      if (path != null) _audioPath = path;
    });
  }

  void _startTimer() {
    _recordDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
      if (_recordDuration >= 60) {
        _stopRecording();
      }
    });
  }

  Future<void> _previewHook() async {
    if (_audioPath == null) return;
    
    setState(() => _isLoadingPreview = true);
    try {
      String previewUrl = await ApiService.previewHook(_audioPath!);
      
      final player = AudioPlayer();
      await player.setUrl(previewUrl);
      player.play();
      
      // Listen for when audio finishes playing
      player.processingStateStream.where((s) => s == ProcessingState.completed).listen((event) {
        Navigator.pop(context); // Close bottom sheet
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PaywallModal(),
        );
      });
      
    } catch (e) {
      print('Preview error: $e');
      setState(() => _isLoadingPreview = false);
      
      // Fallback modal if API fails (for demo purposes)
      Navigator.pop(context); 
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PaywallModal(),
      );
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A4A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      height: 450,
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('아래 대본을 읽어주세요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('(최대 1분 녹음 가능)', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '"우리 아이야, 오늘 하루도 참 고생 많았어. 엄마(아빠)가 재미있는 이야기 들려줄게."',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white, fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Text(_formatDuration(_recordDuration), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()])),
          const Spacer(),
          if (_isLoadingPreview)
            const Column(
              children: [
                CircularProgressIndicator(color: Color(0xFFE2B714)),
                SizedBox(height: 16),
                Text('목소리에 마법을 거는 중...', style: TextStyle(fontSize: 16)),
              ],
            )
          else if (_audioPath == null || _isRecording)
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.white : Colors.black),
              label: Text(_isRecording ? '녹음 정지' : '🎙 녹음 시작', style: TextStyle(color: _isRecording ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.redAccent : Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _previewHook,
              icon: const Icon(Icons.play_arrow, color: Colors.black),
              label: const Text('✨ 10초 미리 듣기', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            ),
        ],
      ),
    );
  }
}

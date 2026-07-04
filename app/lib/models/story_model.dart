

class StoryModel {
  final String id;
  final String title;
  final String desc; // description -> desc
  final String category;
  final String content;
  final String ttsText; // tts_text
  final String imageUrl;
  final int durationEstSec; // duration_est_sec

  // 기존 유저 생성 동화를 위한 호환성 필드 (추가 가능성 있음)
  final String? audioUrl;
  final String? voiceName;
  final DateTime? createdAt;
  final bool isCustom;

  StoryModel({
    required this.id,
    required this.title,
    required this.desc,
    required this.category,
    required this.content,
    required this.ttsText,
    required this.imageUrl,
    required this.durationEstSec,
    this.audioUrl,
    this.voiceName,
    this.createdAt,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'desc': desc,
      'category': category,
      'content': content,
      'tts_text': ttsText,
      'imageUrl': imageUrl,
      'duration_est_sec': durationEstSec,
      'audioUrl': audioUrl,
      'voiceName': voiceName,
      'createdAt': createdAt?.toIso8601String(),
      'isCustom': isCustom,
    };
  }

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      desc: json['desc'] ?? '',
      category: json['category'] ?? 'cozy',
      content: json['content'] ?? '',
      ttsText: json['tts_text'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      durationEstSec: json['duration_est_sec'] ?? 0,
      audioUrl: json['audioUrl'],
      voiceName: json['voiceName'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      isCustom: json['isCustom'] ?? false,
    );
  }
}

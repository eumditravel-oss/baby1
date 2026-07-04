class VoiceModel {
  final String id;
  final String name;
  final String desc;
  final String imageUrl;
  final bool isPremium;

  VoiceModel({
    required this.id,
    required this.name,
    required this.desc,
    required this.imageUrl,
    this.isPremium = false,
  });

  factory VoiceModel.fromJson(Map<String, dynamic> json, {bool isPremium = false}) {
    return VoiceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      isPremium: isPremium,
    );
  }
}

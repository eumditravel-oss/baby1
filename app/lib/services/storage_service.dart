import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/story_model.dart';

class StorageService {
  static const String _keyCustomStories = 'custom_stories';

  static Future<void> saveStory(StoryModel story) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> storiesJson = prefs.getStringList(_keyCustomStories) ?? [];
    
    // Check if exists, update or add new
    int index = storiesJson.indexWhere((s) {
      final decoded = jsonDecode(s);
      return decoded['id'] == story.id;
    });

    if (index >= 0) {
      storiesJson[index] = jsonEncode(story.toJson());
    } else {
      storiesJson.insert(0, jsonEncode(story.toJson())); // Add to top
    }

    await prefs.setStringList(_keyCustomStories, storiesJson);
  }

  static Future<List<StoryModel>> getCustomStories() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> storiesJson = prefs.getStringList(_keyCustomStories) ?? [];
    
    return storiesJson.map((s) => StoryModel.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> deleteStory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> storiesJson = prefs.getStringList(_keyCustomStories) ?? [];
    
    storiesJson.removeWhere((s) {
      final decoded = jsonDecode(s);
      return decoded['id'] == id;
    });

    await prefs.setStringList(_keyCustomStories, storiesJson);
  }

  // --- Audio Caching ---

  static Future<String> getLocalAudioPath(String storyId, String voiceId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/audio_${storyId}_${voiceId}.mp3';
  }

  static Future<bool> isAudioCached(String storyId, String voiceId) async {
    final path = await getLocalAudioPath(storyId, voiceId);
    return File(path).existsSync();
  }

  static Future<String> downloadAndCacheAudio(String url, String storyId, String voiceId) async {
    final path = await getLocalAudioPath(storyId, voiceId);
    
    if (defaultTargetPlatform == TargetPlatform.android && url.contains('127.0.0.1')) {
      url = url.replaceAll('127.0.0.1', '10.0.2.2');
    }

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);
      return path;
    } else {
      throw Exception('Failed to download audio from $url');
    }
  }
}

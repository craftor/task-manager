import '../../../data/datasources/remote/remote_datasource.dart';

/// List of emoji keys used by the mood picker (mirrors the Appwrite
/// `data` JSON column shape — a list of emoji strings).
const moodEmojis = ['😊', '😢', '😡', '😴', '😐', '🎉', '😰', '❤️'];

const moodLabels = {
  '😊': 'Happy',
  '😢': 'Sad',
  '😡': 'Angry',
  '😴': 'Tired',
  '😐': 'Neutral',
  '🎉': 'Excited',
  '😰': 'Anxious',
  '❤️': 'Loved',
};

/// Persistence boundary for mood entries (up to 3 emojis per date).
/// Mutating methods take a [RemoteDatasource] because mood writes
/// fan-out to both the local cache and the remote collection.
abstract class MoodRepository {
  Future<Map<String, List<String>>> getAll();
  Future<List<String>> getMoods(String dateKey);
  Future<void> setMoods(RemoteDatasource remote, String dateKey, List<String> emojis);
  Future<void> removeMoods(RemoteDatasource remote, String dateKey);
  Future<Map<String, int>> getDistribution(DateTime start, DateTime end);
  Future<void> pullFromRemote(RemoteDatasource remote);
}
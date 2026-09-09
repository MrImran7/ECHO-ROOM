import 'scene.dart';
class ChapterDefinition {
  const ChapterDefinition({required this.id, required this.title, required this.levelIds, this.available = false});
  final int id;
  final String title;
  final List<int> levelIds;
  final bool available;
  factory ChapterDefinition.fromJson(Json j) => ChapterDefinition(id: j['id'] as int, title: j['title'] as String,
    levelIds: (j['levelIds'] as List<dynamic>).cast<int>(), available: j['available'] as bool? ?? false);
}

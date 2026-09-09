import 'dart:math' as math;
import '../models/scene.dart';

class HitRegion {
  const HitRegion(this.object, {this.historical = false});
  final RoomObject object;
  final bool historical;
  double padding(double minimum) => math.max(object.hitPadding, minimum);
}

/// Stable z-order, exact-hit preference within a layer, then nearest center.
/// The answer never receives hidden priority over another overlapping object.
class HitTester {
  HitTester(RoomState before, RoomState after, Set<String> targets)
      : regions = List.unmodifiable([
          for (final o in after.objects) if (o.visible) HitRegion(o),
          for (final id in targets)
            if (before.object(id).visible && (!after.object(id).visible ||
                before.object(id).x != after.object(id).x || before.object(id).y != after.object(id).y))
              HitRegion(before.object(id), historical: true),
        ]);
  final List<HitRegion> regions;
  String? resolve(double x, double y, {double minimumPadding = .025}) {
    HitRegion? best; var bestExact = false; var bestDistance = double.infinity;
    for (final region in regions) {
      final o = region.object;
      if (!o.contains(x, y, padding: region.padding(minimumPadding))) continue;
      final exact = o.contains(x, y);
      final dx = (x - o.x) * 400, dy = (y - o.y) * 440;
      final distance = dx * dx + dy * dy;
      if (best == null || o.z > best.object.z || (o.z == best.object.z &&
          ((exact && !bestExact) || (exact == bestExact && distance < bestDistance)))) {
        best = region; bestExact = exact; bestDistance = distance;
      }
    }
    return best?.object.id;
  }
}
String? detectObject(RoomState before, RoomState after, Set<String> targets,
    double x, double y, {double minimumPadding = .025}) =>
    HitTester(before, after, targets).resolve(x, y, minimumPadding: minimumPadding);

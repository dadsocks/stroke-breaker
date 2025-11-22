import '../models/putting_session.dart';
import '../models/strokes_gained_baseline.dart';

double calculateStrokesGained(PuttingSession session) {
  double total = 0;

  for (final hole in session.holes) {
    final firstDistance = hole.scenario.distanceFeet.toDouble();
    if (hole.firstPuttMade) {
      total += strokesGainedForPutt(
        startDistanceFeet: firstDistance,
        endDistanceFeet: 0,
      );
      continue;
    }

    final secondDistanceFeet = (hole.secondDistance?.feet ?? 2).toDouble();
    total += strokesGainedForPutt(
      startDistanceFeet: firstDistance,
      endDistanceFeet: secondDistanceFeet,
    );

    final secondEndDistance = (hole.secondMade ?? false) ? 0 : 2;
    total += strokesGainedForPutt(
      startDistanceFeet: secondDistanceFeet,
      endDistanceFeet: secondEndDistance.toDouble(),
    );

    if (!(hole.secondMade ?? false)) {
      total += strokesGainedForPutt(
        startDistanceFeet: 2,
        endDistanceFeet: 0,
      );
    }
  }

  return double.parse(total.toStringAsFixed(2));
}

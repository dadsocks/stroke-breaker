import 'dart:math';

import '../models/distance_bucket.dart';
import '../models/putt_scenario.dart';

class RandomPuttGenerator {
  RandomPuttGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  PuttScenario generate({required bool includeSlope, DistanceBucket? bucket}) {
    final distance = _distanceForBucket(bucket);
    final lie = LieType.values[_random.nextInt(LieType.values.length)];
    final breakType = BreakType.values[_random.nextInt(BreakType.values.length)];

    double? slope;
    if (includeSlope && breakType != BreakType.straight) {
      final value = _randomDouble(min: 0.5, max: 5);
      slope = double.parse(value.toStringAsFixed(1));
    }

    return PuttScenario(
      distanceFeet: distance,
      lie: lie,
      breakType: breakType,
      slopePercent: slope,
    );
  }

  int _distanceForBucket(DistanceBucket? bucket) {
    if (bucket == null) {
      return _random.nextInt(37) + 4;
    }
    final min = bucket.minFeet;
    final max = bucket.maxFeet;
    return _random.nextInt(max - min + 1) + min;
  }

  double _randomDouble({required double min, required double max}) {
    return min + _random.nextDouble() * (max - min);
  }
}

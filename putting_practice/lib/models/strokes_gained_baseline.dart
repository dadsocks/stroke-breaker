const Map<int, double> kPgaPuttingBaseline = {
  1: 1.00,
  2: 1.02,
  3: 1.05,
  4: 1.10,
  5: 1.15,
  6: 1.20,
  8: 1.30,
  10: 1.40,
  12: 1.50,
  15: 1.60,
  20: 1.70,
  25: 1.80,
  30: 1.87,
  40: 1.95,
  50: 1.99,
  60: 2.03,
};

double expectedPuttsForDistance(double distanceFeet) {
  if (distanceFeet <= 0) return 0;

  final sortedKeys = kPgaPuttingBaseline.keys.toList()..sort();
  final minKey = sortedKeys.first;
  final maxKey = sortedKeys.last;

  if (distanceFeet <= minKey) return kPgaPuttingBaseline[minKey]!;
  if (distanceFeet >= maxKey) return kPgaPuttingBaseline[maxKey]!;

  for (var i = 1; i < sortedKeys.length; i++) {
    final lower = sortedKeys[i - 1];
    final upper = sortedKeys[i];
    if (distanceFeet <= upper) {
      final lowerValue = kPgaPuttingBaseline[lower]!;
      final upperValue = kPgaPuttingBaseline[upper]!;
      final t = (distanceFeet - lower) / (upper - lower);
      return lowerValue + t * (upperValue - lowerValue);
    }
  }

  return kPgaPuttingBaseline[maxKey]!;
}

double strokesGainedForPutt({
  required double startDistanceFeet,
  required double endDistanceFeet,
}) {
  final startExpected = expectedPuttsForDistance(startDistanceFeet);
  final endExpected = expectedPuttsForDistance(endDistanceFeet);
  return startExpected - (1 + endExpected);
}

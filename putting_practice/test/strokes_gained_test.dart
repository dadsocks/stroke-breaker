import 'package:flutter_test/flutter_test.dart';

import 'package:putting_practice/models/hole_result.dart';
import 'package:putting_practice/models/putt_scenario.dart';
import 'package:putting_practice/models/putting_session.dart';
import 'package:putting_practice/models/strokes_gained_baseline.dart';
import 'package:putting_practice/services/strokes_gained_calculator.dart';

void main() {
  test('expectedPuttsForDistance interpolates and clamps', () {
    expect(expectedPuttsForDistance(10), 1.40);
    expect(expectedPuttsForDistance(9), closeTo(1.35, 0.01));
    expect(expectedPuttsForDistance(0), 0);
    expect(expectedPuttsForDistance(80), 2.03);
  });

  test('strokes gained for holed 10ft putt', () {
    final sg = strokesGainedForPutt(startDistanceFeet: 10, endDistanceFeet: 0);
    expect(sg, closeTo(0.40, 0.0001));
  });

  test('strokes gained for 30ft putt to 3ft', () {
    final sg = strokesGainedForPutt(startDistanceFeet: 30, endDistanceFeet: 3);
    final expected = expectedPuttsForDistance(30) - (1 + expectedPuttsForDistance(3));
    expect(sg, closeTo(expected, 0.0001));
  });

  test('calculateStrokesGained sums all putts', () {
    final session = PuttingSession(
      id: 'test',
      holeCount: 2,
      startedAt: DateTime.now(),
      includeSlope: true,
      holes: [
        HoleResult(
          holeNumber: 1,
          scenario: const PuttScenario(
            distanceFeet: 10,
            lie: LieType.flat,
            breakType: BreakType.straight,
          ),
          firstFeedback: FirstPuttFeedback.made,
        ),
        HoleResult(
          holeNumber: 2,
          scenario: const PuttScenario(
            distanceFeet: 30,
            lie: LieType.flat,
            breakType: BreakType.straight,
          ),
          firstFeedback: FirstPuttFeedback.left,
          secondDistance: SecondPuttDistance.three,
          secondMade: true,
        ),
      ],
    );

    final total = calculateStrokesGained(session);
    final expected = strokesGainedForPutt(startDistanceFeet: 10, endDistanceFeet: 0) +
        strokesGainedForPutt(startDistanceFeet: 30, endDistanceFeet: 3) +
        strokesGainedForPutt(startDistanceFeet: 3, endDistanceFeet: 0);
    expect(total, closeTo(expected, 0.01));
  });
}

import 'hole_result.dart';
import 'putting_session.dart';
import 'putt_result.dart';
import 'putt_scenario.dart';
import 'session_stats.dart';
import '../services/strokes_gained_calculator.dart';
import 'strokes_gained_baseline.dart';

class FirstPuttBucketStat {
  const FirstPuttBucketStat({
    required this.label,
    required this.attempts,
    required this.makes,
  });

  final String label;
  final int attempts;
  final int makes;

  double get makeRate => attempts == 0 ? 0 : makes / attempts;
}

class RoundSummary {
  RoundSummary({
    required this.stats,
    required this.missCounts,
    required this.secondLeaveDistribution,
    required this.bucketStats,
    required this.dispersionResults,
    required this.strokesGained,
    required this.strokeBreakdown,
  });

  final SessionStats stats;
  final Map<FirstPuttFeedback, int> missCounts;
  final Map<SecondLeaveCategory, int> secondLeaveDistribution;
  final List<FirstPuttBucketStat> bucketStats;
  final List<PuttResult> dispersionResults;
  final double strokesGained;
  final List<PuttStrokeSummary> strokeBreakdown;

  static RoundSummary fromSession(PuttingSession session) {
    final holes = session.holes;
    final stats = session.stats;

    final missCounts = {
      for (final feedback in FirstPuttFeedback.values.where((f) => f != FirstPuttFeedback.made))
        feedback: 0,
    };

    final secondLeaveDistribution = {
      SecondLeaveCategory.tapIn: 0,
      SecondLeaveCategory.threeToEight: 0,
      SecondLeaveCategory.overNine: 0,
    };

    const bucketDefinitions = [
      _DistanceBucket(label: '4–6 ft', min: 4, max: 6),
      _DistanceBucket(label: '7–10 ft', min: 7, max: 10),
      _DistanceBucket(label: '11–20 ft', min: 11, max: 20),
      _DistanceBucket(label: '21–40 ft', min: 21, max: 40),
    ];

    final bucketStats = bucketDefinitions
        .map(
          (bucket) => FirstPuttBucketStat(
            label: bucket.label,
            attempts: 0,
            makes: 0,
          ),
        )
        .toList(growable: false);

    for (final hole in holes) {
      final scenario = hole.scenario;
      final distance = scenario.distanceFeet;

      for (var i = 0; i < bucketDefinitions.length; i++) {
        final bucket = bucketDefinitions[i];
        if (distance >= bucket.min && distance <= bucket.max) {
          final stat = bucketStats[i];
          bucketStats[i] = FirstPuttBucketStat(
            label: stat.label,
            attempts: stat.attempts + 1,
            makes: stat.makes + (hole.firstPuttMade ? 1 : 0),
          );
          break;
        }
      }

      if (!hole.firstPuttMade) {
        missCounts[hole.firstFeedback] =
            (missCounts[hole.firstFeedback] ?? 0) + 1;
      }

      if (hole.secondDistance != null) {
        final category = secondLeaveCategoryFromDistance(hole.secondDistance!);
        secondLeaveDistribution[category] =
            (secondLeaveDistribution[category] ?? 0) + 1;
      }
    }

    return RoundSummary(
      stats: stats,
      missCounts: missCounts,
      secondLeaveDistribution: secondLeaveDistribution,
      bucketStats: bucketStats,
      dispersionResults: _buildDispersion(session),
      strokesGained: calculateStrokesGained(session),
      strokeBreakdown: _buildStrokeBreakdown(session),
    );
  }

  static String toCsv(PuttingSession session) {
    final buffer = StringBuffer()
      ..writeln(
        'Hole,Distance,Lie,Break,Slope %,First Result,Second Distance,Second Made,Total Putts',
      );

    for (final hole in session.holes) {
      final scenario = hole.scenario;
      final slope = scenario.slopePercent?.toStringAsFixed(1) ?? '';
      final secondDistance = hole.secondDistance?.label ?? '';
      final secondMade = hole.secondMade == null ? '' : (hole.secondMade! ? 'Made' : 'Missed');
      buffer.writeln([
        hole.holeNumber,
        scenario.distanceFeet,
        scenario.lie.label,
        scenario.breakType.label,
        slope,
        hole.firstFeedback.label,
        secondDistance,
        secondMade,
        hole.totalPutts,
      ].join(','));
    }

    return buffer.toString();
  }
}

List<PuttResult> _buildDispersion(PuttingSession session) {
  const horizontalFactor = 0.35;
  return session.holes.map((hole) {
    final distance = hole.scenario.distanceFeet.toDouble();
    final slopePercent = hole.scenario.slopePercent?.abs() ?? 0;
    final slopeFactor = 1 + slopePercent / 6; // steeper slopes spread farther

    double yOffset = 0;
    switch (hole.scenario.lie) {
      case LieType.downhill:
        yOffset = distance * slopeFactor;
        break;
      case LieType.uphill:
        yOffset = -distance * slopeFactor;
        break;
      case LieType.flat:
        yOffset = 0;
        break;
    }

    double xOffset = 0;
    switch (hole.scenario.breakType) {
      case BreakType.leftToRight:
        xOffset = -distance * horizontalFactor * (slopeFactor);
        break;
      case BreakType.rightToLeft:
        xOffset = distance * horizontalFactor * (slopeFactor);
        break;
      case BreakType.straight:
        xOffset = 0;
        break;
    }

    return PuttResult(
      x: xOffset,
      y: yOffset,
      putts: hole.totalPutts,
    );
  }).toList();
}

enum SecondLeaveCategory { tapIn, threeToEight, overNine }

extension SecondLeaveCategoryLabels on SecondLeaveCategory {
  String get label {
    switch (this) {
      case SecondLeaveCategory.tapIn:
        return 'Tap-in';
      case SecondLeaveCategory.threeToEight:
        return '3–8 ft';
      case SecondLeaveCategory.overNine:
        return '>9 ft';
    }
  }
}

SecondLeaveCategory secondLeaveCategoryFromDistance(SecondPuttDistance distance) {
  switch (distance) {
    case SecondPuttDistance.tapIn:
      return SecondLeaveCategory.tapIn;
    case SecondPuttDistance.three:
    case SecondPuttDistance.four:
    case SecondPuttDistance.five:
    case SecondPuttDistance.six:
    case SecondPuttDistance.seven:
    case SecondPuttDistance.eight:
      return SecondLeaveCategory.threeToEight;
    case SecondPuttDistance.overNine:
      return SecondLeaveCategory.overNine;
  }
}

class _DistanceBucket {
  const _DistanceBucket({required this.label, required this.min, required this.max});

  final String label;
  final int min;
  final int max;
}

class PuttStrokeSummary {
  PuttStrokeSummary({
    required this.holeNumber,
    required this.distanceFeet,
    required this.strokesGained,
  });

  final int holeNumber;
  final double distanceFeet;
  final double strokesGained;
}

List<PuttStrokeSummary> _buildStrokeBreakdown(PuttingSession session) {
  final strokes = <PuttStrokeSummary>[];

  for (final hole in session.holes) {
    final scenario = hole.scenario;
    final firstDistance = scenario.distanceFeet.toDouble();
    final firstEnd = hole.firstPuttMade ? 0.0 : (hole.secondDistance?.feet ?? 0).toDouble();
    strokes.add(
      PuttStrokeSummary(
        holeNumber: hole.holeNumber,
        distanceFeet: firstDistance,
        strokesGained: strokesGainedForPutt(
          startDistanceFeet: firstDistance,
          endDistanceFeet: firstEnd,
        ),
      ),
    );

    if (!hole.firstPuttMade) {
      final secondDistance = (hole.secondDistance?.feet ?? 2).toDouble();
      final secondEnd = (hole.secondMade ?? false) ? 0.0 : 2.0;
      strokes.add(
        PuttStrokeSummary(
          holeNumber: hole.holeNumber,
          distanceFeet: secondDistance,
          strokesGained: strokesGainedForPutt(
            startDistanceFeet: secondDistance,
            endDistanceFeet: secondEnd,
          ),
        ),
      );

      if (!(hole.secondMade ?? false)) {
        strokes.add(
          PuttStrokeSummary(
            holeNumber: hole.holeNumber,
            distanceFeet: 2,
            strokesGained: strokesGainedForPutt(
              startDistanceFeet: 2,
              endDistanceFeet: 0,
            ),
          ),
        );
      }
    }
  }

  return strokes;
}
